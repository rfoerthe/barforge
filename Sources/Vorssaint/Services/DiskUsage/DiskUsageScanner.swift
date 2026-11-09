// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Darwin
import Foundation
import Synchronization

/// Live counters of a running scan, shared with whoever shows its progress.
/// Every counter may be read from any thread while the scan writes it.
final class DiskUsageScanProgress: Sendable {
    let files = Atomic<UInt64>(0)
    /// Allocated bytes found so far, before shared data is counted once.
    let bytes = Atomic<UInt64>(0)
    let cancelled = Atomic<Bool>(false)
    /// Finished share of the folder tree, in millionths. Each folder hands its
    /// share on to its subfolders in equal parts; a folder without subfolders
    /// counts its share as done once read.
    let doneMillionths = Atomic<UInt64>(0)
    /// Bytes a whole volume uses, when one is scanned. Progress is then
    /// measured against bytes found instead of folders finished.
    let expectedBytes = Atomic<UInt64>(0)
    private let currentPathLock = Mutex<String>("")

    /// The folder being read most recently.
    var currentPath: String { currentPathLock.withLock { $0 } }

    func cancel() { cancelled.store(true, ordering: .relaxed) }

    var isCancelled: Bool { cancelled.load(ordering: .relaxed) }

    /// 0 … 1.
    var fraction: Double {
        let expected = expectedBytes.load(ordering: .relaxed)
        let value = expected > 0
            ? Double(bytes.load(ordering: .relaxed)) / Double(expected)
            : Double(doneMillionths.load(ordering: .relaxed)) / 1_000_000
        return min(1, max(0, value))
    }

    fileprivate func setCurrentPath(_ path: String) {
        // Only for display: skip the update rather than wait for another thread.
        _ = currentPathLock.withLockIfAvailable { $0 = path }
    }
}

enum DiskUsageScanner {
    /// Scans `rootPath`. Pass the volume's space when a whole volume is scanned:
    /// the result then also holds hidden, purgeable and free space, and the
    /// root's size equals the volume's capacity.
    static func scan(_ rootPath: String,
                     volume: DiskUsageVolumeSpace? = nil,
                     progress: DiskUsageScanProgress = DiskUsageScanProgress()) -> DiskUsageTree {
        let root = normalized(rootPath)
        var context = Context(progress: progress)
        if let device = deviceID(of: root) { context.allowedDevices.insert(device) }
        if root == "/" {
            // User data lives on a second volume that is linked into "/".
            if let data = deviceID(of: "/System/Volumes/Data") { context.allowedDevices.insert(data) }
            context.skippedPaths = ["/System/Volumes", "/Volumes", "/dev", "/net", "/home", "/private/var/vm"]
        }
        if let volume { progress.expectedBytes.store(volume.expectedScanBytes, ordering: .relaxed) }
        let name = root == "/" ? "/" : (root as NSString).lastPathComponent
        let folders = FolderQueue(root: root, name: name, context: context).run()

        var tree = DiskUsageTree(nodes: [], rootPath: root)
        var shared: [SharedFile] = []
        tree.nodes.reserveCapacity(folders.count + Int(progress.files.load(ordering: .relaxed)))
        flatten(folder: 0, of: folders, parent: nil, into: &tree, shared: &shared)
        countSharedDataOnce(in: &tree, shared: shared)
        sortChildren(in: &tree)
        if let volume { appendVolumeEntries(volume, to: &tree) }
        return tree
    }

    /// Adds hidden, purgeable and free space below the root of a volume scan,
    /// after the folder's own items, so that the root then spans the volume.
    static func appendVolumeEntries(_ volume: DiskUsageVolumeSpace, to tree: inout DiskUsageTree) {
        tree.volumeCapacity = volume.capacity
        let scanned = tree.rootSize
        let used = volume.capacity - min(volume.capacity, volume.free)
        let unseen = used - min(used, scanned)
        let purgeable = min(volume.purgeable, unseen)
        let hidden = unseen - purgeable
        for (size, kind) in [(hidden, DiskUsageNode.Kind.hidden), (purgeable, .purgeable), (volume.free, .free)]
            where size > 0 {
            tree.nodes.append(DiskUsageNode(name: "", size: size, kind: kind, parent: tree.root, children: []))
            tree.nodes[tree.root].children.append(tree.nodes.count - 1)
            tree.nodes[tree.root].size += size
        }
    }

    // MARK: - Reading folders

    private struct Context {
        var allowedDevices: Set<Int32> = []
        var skippedPaths: Set<String> = []
        let progress: DiskUsageScanProgress
    }

    struct LinkKey: Hashable {
        var device: Int32
        var fileID: UInt64
    }

    /// One folder entry as the scanner reads it.
    struct Entry: Equatable {
        var name: String
        var device: Int32
        var isDirectory: Bool
        var fileID: UInt64
        var linkCount: UInt32
        var allocatedSize: UInt64
        var cloneID: UInt64
        var cloneReferenceCount: UInt32
    }

    /// A scanned file before it is placed in the flat tree.
    private struct PendingFile {
        var name: String
        var size: UInt64
        /// Set for a file with more than one hard link.
        var linkKey: LinkKey?
        /// Set for a file whose data is shared with APFS clones.
        var cloneID: UInt64?
    }

    /// A scanned folder: its files, then its subfolders by folder id.
    private struct PendingFolder {
        var name: String
        var files: [PendingFile] = []
        var subfolders: [Int] = []
    }

    /// Reads folders on a fixed set of threads. Each thread works depth-first
    /// through its own stack of folders and hands its shallowest ones to the
    /// shared queue while other threads run short, so threads spread over
    /// distant parts of the tree instead of contending for one folder.
    /// Waiting in the kernel dominates a scan, which a fixed pool hides better
    /// than nested parallel loops that block while their children finish.
    private final class FolderQueue: @unchecked Sendable {
        private struct Job {
            var id: Int
            var path: String
            var share: Double
        }

        private let condition = NSCondition()
        private let context: Context
        private let threadCount = max(4, ProcessInfo.processInfo.activeProcessorCount)
        // Guarded by `condition`.
        /// Shared folders waiting for a thread, oldest (shallowest) first.
        private var jobs: [Job]
        private var nextShared = 0
        private var folders: [PendingFolder]
        /// Folders found but not yet read, in the shared queue or a thread's own stack.
        private var outstanding = 1

        init(root: String, name: String, context: Context) {
            self.context = context
            jobs = [Job(id: 0, path: root, share: 1)]
            folders = [PendingFolder(name: name)]
        }

        /// Reads the whole tree and returns every folder; folder 0 is the root.
        func run() -> [PendingFolder] {
            let finished = DispatchGroup()
            for _ in 1..<threadCount {
                finished.enter()
                let thread = Thread { [self] in
                    work()
                    finished.leave()
                }
                thread.qualityOfService = .userInitiated
                thread.start()
            }
            work()
            finished.wait()
            return folders
        }

        private func work() {
            // One buffer per thread: a fresh large allocation for every folder
            // maps and unmaps memory, which serializes the threads in the kernel.
            let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bulkBufferSize, alignment: 8)
            defer { buffer.deallocate() }
            var own: [Job] = []
            while let job = own.popLast() ?? nextSharedJob() {
                let (files, subfolders) = read(job, buffer: buffer)
                finish(job, files: files, subfolders: subfolders, own: &own)
            }
        }

        private func nextSharedJob() -> Job? {
            condition.lock()
            defer { condition.unlock() }
            while nextShared == jobs.count {
                if outstanding == 0 { return nil }
                condition.wait()
            }
            let job = jobs[nextShared]
            nextShared += 1
            if nextShared == jobs.count {
                jobs.removeAll(keepingCapacity: true)
                nextShared = 0
            }
            return job
        }

        private func read(_ job: Job, buffer: UnsafeMutableRawBufferPointer)
            -> ([PendingFile], [(path: String, name: String)]) {
            let progress = context.progress
            guard !progress.isCancelled else { return ([], []) }
            progress.setCurrentPath(job.path)
            var files: [PendingFile] = []
            var subfolders: [(path: String, name: String)] = []
            let entries = readDirectoryInBulk(job.path, buffer: buffer) ?? readDirectoryOneByOne(job.path)
            for entry in entries {
                let entryPath = job.path == "/" ? "/" + entry.name : job.path + "/" + entry.name
                if entry.isDirectory {
                    // A folder counts only through what it holds. Other volumes stay out.
                    guard context.allowedDevices.contains(entry.device),
                          !context.skippedPaths.contains(entryPath) else { continue }
                    subfolders.append((entryPath, entry.name))
                } else {
                    progress.files.add(1, ordering: .relaxed)
                    progress.bytes.add(entry.allocatedSize, ordering: .relaxed)
                    files.append(PendingFile(
                        name: entry.name, size: entry.allocatedSize,
                        linkKey: entry.linkCount > 1 ? LinkKey(device: entry.device, fileID: entry.fileID) : nil,
                        cloneID: entry.cloneReferenceCount > 1 && entry.cloneID != 0 ? entry.cloneID : nil))
                }
            }
            if subfolders.isEmpty {
                progress.doneMillionths.add(UInt64(job.share * 1_000_000), ordering: .relaxed)
            }
            return (files, subfolders)
        }

        private func finish(_ job: Job, files: [PendingFile], subfolders: [(path: String, name: String)],
                            own: inout [Job]) {
            let share = job.share / Double(max(1, subfolders.count))
            condition.lock()
            defer { condition.unlock() }
            let firstID = folders.count
            folders[job.id].files = files
            folders[job.id].subfolders = Array(firstID..<firstID + subfolders.count)
            folders.append(contentsOf: subfolders.map { PendingFolder(name: $0.name) })
            // Pushed in reverse, so the first subfolder is read first.
            for (offset, subfolder) in subfolders.enumerated().reversed() {
                own.append(Job(id: firstID + offset, path: subfolder.path, share: share))
            }
            outstanding += subfolders.count - 1
            // Share the shallowest own folders while the shared queue runs short.
            let waiting = jobs.count - nextShared
            var shared = false
            if waiting < threadCount, own.count > 1 {
                let handed = min(own.count - 1, threadCount - waiting)
                jobs.append(contentsOf: own.prefix(handed))
                own.removeFirst(handed)
                shared = true
            }
            if outstanding == 0 || shared { condition.broadcast() }
        }
    }

    fileprivate static let bulkBufferSize = 256 * 1024
    /// `FSOPT_NOFOLLOW`.
    private static let noFollow: UInt64 = 0x1
    /// `FSOPT_ATTR_CMN_EXTENDED`: `forkattr` then asks for extended common attributes.
    private static let extendedCommonAttributes: UInt64 = 0x20
    /// `ATTR_CMNEXT_CLONEID`, `ATTR_CMNEXT_CLONE_REFCNT`.
    private static let cloneIDAttribute: attrgroup_t = 0x0000_0100
    private static let cloneReferenceCountAttribute: attrgroup_t = 0x0000_1000

    /// Reads a folder with `getattrlistbulk`: name, device, type, file id,
    /// link count and allocated size, plus the APFS clone id and clone
    /// reference count where the file system reports them. Returns nil when
    /// the folder cannot be opened this way. `buffer` receives the records;
    /// without one, a buffer is allocated for this call.
    static func readDirectoryInBulk(_ path: String, buffer: UnsafeMutableRawBufferPointer? = nil) -> [Entry]? {
        let descriptor = open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        let ownBuffer = buffer == nil
            ? UnsafeMutableRawBufferPointer.allocate(byteCount: bulkBufferSize, alignment: 8) : nil
        defer { ownBuffer?.deallocate() }
        guard let buffer = buffer ?? ownBuffer else { return nil }

        var entries: [Entry] = []
        var asksForClones = true
        while true {
            var request = attrlist()
            request.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
            request.commonattr = attrgroup_t(ATTR_CMN_RETURNED_ATTRS) | attrgroup_t(ATTR_CMN_NAME)
                | attrgroup_t(ATTR_CMN_DEVID) | attrgroup_t(ATTR_CMN_OBJTYPE) | attrgroup_t(ATTR_CMN_FILEID)
            request.fileattr = attrgroup_t(ATTR_FILE_LINKCOUNT) | attrgroup_t(ATTR_FILE_ALLOCSIZE)
            var options = noFollow
            if asksForClones {
                request.forkattr = cloneIDAttribute | cloneReferenceCountAttribute
                options |= extendedCommonAttributes
            }
            let count = getattrlistbulk(descriptor, &request, buffer.baseAddress, buffer.count, options)
            if count < 0 {
                if asksForClones, entries.isEmpty {
                    // File systems without the extended attributes refuse the request.
                    asksForClones = false
                    continue
                }
                return entries
            }
            if count == 0 { return entries }
            var offset = 0
            for _ in 0..<count {
                guard offset + 4 <= buffer.count else { break }
                let length = Int(buffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
                guard length > 0, offset + length <= buffer.count else { break }
                if let entry = decodeEntry(UnsafeRawBufferPointer(rebasing: buffer[offset..<offset + length])) {
                    entries.append(entry)
                }
                offset += length
            }
        }
    }

    /// Decodes one `getattrlistbulk` record. Attributes appear in the order of
    /// their group and bit, and only those named in the returned set.
    static func decodeEntry(_ record: UnsafeRawBufferPointer) -> Entry? {
        var position = 4
        func read<T>(_ type: T.Type) -> T? {
            guard position + MemoryLayout<T>.size <= record.count else { return nil }
            defer { position += MemoryLayout<T>.size }
            return record.loadUnaligned(fromByteOffset: position, as: T.self)
        }
        guard let returned = read(attribute_set_t.self) else { return nil }
        var entry = Entry(name: "", device: 0, isDirectory: false, fileID: 0, linkCount: 1,
                          allocatedSize: 0, cloneID: 0, cloneReferenceCount: 0)
        if returned.commonattr & attrgroup_t(ATTR_CMN_NAME) != 0 {
            let start = position
            guard let reference = read(attrreference_t.self) else { return nil }
            let nameStart = start + Int(reference.attr_dataoffset)
            let nameLength = Int(reference.attr_length)
            if nameLength > 1, nameStart >= 0, nameStart + nameLength <= record.count {
                // The length includes the terminating zero.
                entry.name = String(decoding: record[nameStart..<nameStart + nameLength - 1], as: UTF8.self)
            }
        }
        if returned.commonattr & attrgroup_t(ATTR_CMN_DEVID) != 0 {
            entry.device = read(dev_t.self) ?? 0
        }
        if returned.commonattr & attrgroup_t(ATTR_CMN_OBJTYPE) != 0 {
            entry.isDirectory = read(fsobj_type_t.self) == fsobj_type_t(VDIR.rawValue)
        }
        if returned.commonattr & attrgroup_t(ATTR_CMN_FILEID) != 0 {
            entry.fileID = read(UInt64.self) ?? 0
        }
        if returned.fileattr & attrgroup_t(ATTR_FILE_LINKCOUNT) != 0 {
            entry.linkCount = read(UInt32.self) ?? 1
        }
        if returned.fileattr & attrgroup_t(ATTR_FILE_ALLOCSIZE) != 0 {
            entry.allocatedSize = UInt64(max(0, read(off_t.self) ?? 0))
        }
        if returned.forkattr & cloneIDAttribute != 0 {
            entry.cloneID = read(UInt64.self) ?? 0
        }
        if returned.forkattr & cloneReferenceCountAttribute != 0 {
            entry.cloneReferenceCount = read(UInt32.self) ?? 0
        }
        return entry.name.isEmpty ? nil : entry
    }

    /// Fallback for file systems without `getattrlistbulk`.
    static func readDirectoryOneByOne(_ path: String) -> [Entry] {
        guard let directory = opendir(path) else { return [] }
        defer { closedir(directory) }
        var entries: [Entry] = []
        while let item = readdir(directory) {
            let name = withUnsafeBytes(of: item.pointee.d_name) { raw in
                String(decoding: raw.prefix(Int(item.pointee.d_namlen)), as: UTF8.self)
            }
            guard name != ".", name != ".." else { continue }
            var info = stat()
            guard lstat(path == "/" ? "/" + name : path + "/" + name, &info) == 0 else { continue }
            entries.append(Entry(name: name, device: info.st_dev,
                                 isDirectory: mode_t(info.st_mode) & mode_t(S_IFMT) == mode_t(S_IFDIR),
                                 fileID: info.st_ino, linkCount: UInt32(info.st_nlink),
                                 allocatedSize: UInt64(max(0, info.st_blocks)) * 512,
                                 cloneID: 0, cloneReferenceCount: 0))
        }
        return entries
    }

    // MARK: - Building the tree

    private struct SharedFile {
        var node: Int
        var linkKey: LinkKey?
        var cloneID: UInt64?
    }

    /// Places a folder and everything below it in the flat tree: the folder,
    /// then its files, then each subfolder in turn.
    private static func flatten(folder index: Int, of folders: [PendingFolder], parent: Int?,
                                into tree: inout DiskUsageTree, shared: inout [SharedFile]) {
        let folder = folders[index]
        let id = tree.nodes.count
        tree.nodes.append(DiskUsageNode(
            name: folder.name, size: 0, kind: .directory, parent: parent, children: [],
            isPackage: parent != nil && DiskUsageSupport.isPackageName(folder.name)))
        var children: [Int] = []
        children.reserveCapacity(folder.files.count + folder.subfolders.count)
        for file in folder.files {
            let fileID = tree.nodes.count
            children.append(fileID)
            tree.nodes.append(DiskUsageNode(name: file.name, size: file.size, kind: .file, parent: id, children: []))
            if file.linkKey != nil || file.cloneID != nil {
                shared.append(SharedFile(node: fileID, linkKey: file.linkKey, cloneID: file.cloneID))
            }
        }
        for subfolder in folder.subfolders {
            children.append(tree.nodes.count)
            flatten(folder: subfolder, of: folders, parent: id, into: &tree, shared: &shared)
        }
        tree.nodes[id].children = children
    }

    /// Counts shared data once. In each group of hard links, and in each group
    /// of APFS clones, the file whose full path sorts first, ignoring case,
    /// keeps the size and the others count 0. Then every folder's size becomes
    /// the sum of its children.
    private static func countSharedDataOnce(in tree: inout DiskUsageTree, shared: [SharedFile]) {
        if !shared.isEmpty {
            var linkOwners: [LinkKey: (node: Int, path: [UInt8])] = [:]
            var cloneOwners: [UInt64: (node: Int, path: [UInt8])] = [:]
            linkOwners.reserveCapacity(shared.count)
            // Node ids are in path order before sorting, and so are the shared
            // files: one pass keeps the folder path in a single buffer, and on
            // equal paths the earlier file stays the owner.
            var path = lowercasedBytes(tree.rootPath == "/" ? "" : tree.rootPath)
            var folders: [(node: Int, length: Int)] = [(tree.root, path.count)]
            var next = 0
            for id in 1..<tree.nodes.count where next < shared.count {
                let node = tree.nodes[id]
                while let top = folders.last, top.node != node.parent { folders.removeLast() }
                path.removeSubrange(folders[folders.count - 1].length...)
                path.append(UInt8(ascii: "/"))
                path.append(contentsOf: lowercasedBytes(node.name))
                if node.kind == .directory {
                    folders.append((id, path.count))
                    continue
                }
                guard shared[next].node == id else { continue }
                let file = shared[next]
                next += 1
                if let key = file.linkKey,
                   linkOwners[key].map({ path.lexicographicallyPrecedes($0.path) }) ?? true {
                    linkOwners[key] = (id, path)
                }
                if let key = file.cloneID,
                   cloneOwners[key].map({ path.lexicographicallyPrecedes($0.path) }) ?? true {
                    cloneOwners[key] = (id, path)
                }
            }
            for file in shared {
                if let key = file.linkKey, linkOwners[key]?.node != file.node {
                    tree.nodes[file.node].size = 0
                } else if let key = file.cloneID, cloneOwners[key]?.node != file.node {
                    tree.nodes[file.node].size = 0
                }
            }
        }
        // Parents precede their children, so a reverse pass sums bottom-up.
        for id in tree.nodes.indices.reversed() where tree.nodes[id].kind == .directory {
            tree.nodes[id].size = tree.nodes[id].children.reduce(0) { $0 + tree.nodes[$1].size }
        }
    }

    private static func sortChildren(in tree: inout DiskUsageTree) {
        for id in tree.nodes.indices where tree.nodes[id].children.count > 1 {
            // Sort a copy: sorting in place while reading siblings would copy the node array.
            var children = tree.nodes[id].children
            children.sort { lhs, rhs in
                let left = tree.nodes[lhs], right = tree.nodes[rhs]
                return left.size != right.size ? left.size > right.size : left.name < right.name
            }
            tree.nodes[id].children = children
        }
    }

    // MARK: - Paths

    /// UTF-8 bytes with ASCII letters lowered, the order shared files are compared in.
    private static func lowercasedBytes(_ text: String) -> [UInt8] {
        text.utf8.map { $0 >= 65 && $0 <= 90 ? $0 + 32 : $0 }
    }

    private static func normalized(_ path: String) -> String {
        var result = (path as NSString).expandingTildeInPath
        while result.count > 1, result.hasSuffix("/") { result.removeLast() }
        return result
    }

    private static func deviceID(of path: String) -> Int32? {
        var info = stat()
        return stat(path, &info) == 0 ? info.st_dev : nil
    }
}
