// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Darwin
import Foundation

/// The disk usage scanner and its tree, run against real folders in a
/// temporary directory: allocated sizes, hard links and APFS clones counted
/// once, packages, symbolic links, cancellation, volume space and the tree
/// edits a later delete or rescan makes.
enum DiskUsageTests {
    static func run(_ suite: TestSuite) {
        volumeSpace(suite)
        systemPaths(suite)
        packages(suite)
        recordDecoding(suite)
        withFixture(suite) { root in
            directoryReaders(suite, root: root)
            scanning(suite, root: root)
            sharedData(suite, root: root)
            treeEdits(suite, root: root)
            readOnly(suite, root: root)
        }
        withFixture(suite) { root in cancellationAndDepth(suite, root: root) }
    }

    // MARK: - Fixture

    private static func withFixture(_ suite: TestSuite, _ body: (String) -> Void) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("barforge-disk-usage-\(getpid())-\(UUID().uuidString)", isDirectory: true)
        // Resolve /var → /private/var so paths compare with what the scanner builds.
        let root = (url.path as NSString).resolvingSymlinksInPath
        defer { try? FileManager.default.removeItem(atPath: root) }
        do {
            try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
            body(root)
        } catch {
            suite.expect(false, "temporary fixture folder: \(error)")
        }
    }

    @discardableResult
    private static func write(_ path: String, bytes: Int) -> Bool {
        let folder = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        return FileManager.default.createFile(atPath: path, contents: Data(repeating: 0x5A, count: bytes))
    }

    private static func allocated(_ path: String) -> UInt64 {
        var info = stat()
        return lstat(path, &info) == 0 ? UInt64(info.st_blocks) * 512 : 0
    }

    private static func node(_ tree: DiskUsageTree, _ relative: String) -> Int? {
        tree.node(coveredBy: tree.rootPath + "/" + relative)
    }

    // MARK: - Pure rules

    private static func volumeSpace(_ suite: TestSuite) {
        let space = DiskUsageVolumeSpace(capacity: 1000, available: 600, availableForImportantUsage: 650)
        suite.expect(space == DiskUsageVolumeSpace(capacity: 1000, free: 600, purgeable: 50),
                     "purgeable space is what important use may take beyond plain free space")
        suite.expect(DiskUsageVolumeSpace(capacity: 1000, available: 600, availableForImportantUsage: 500).purgeable == 0
                     && DiskUsageVolumeSpace(capacity: 1000, available: 600, availableForImportantUsage: nil).purgeable == 0,
                     "a smaller or missing important-use figure never invents purgeable space")
        suite.expect(space.expectedScanBytes == 350, "a volume scan expects used space minus purgeable space")
        suite.expect(DiskUsageVolumeSpace(capacity: 10, free: 20, purgeable: 5).expectedScanBytes == 0,
                     "inconsistent volume figures never underflow")

        var tree = DiskUsageTree(nodes: [DiskUsageNode(name: "/", size: 100, kind: .directory, parent: nil, children: [])],
                                 rootPath: "/")
        DiskUsageScanner.appendVolumeEntries(space, to: &tree)
        suite.expect(tree.nodes.dropFirst().map(\.kind) == [.hidden, .purgeable, .free]
                     && tree.nodes.dropFirst().map(\.size) == [250, 50, 600],
                     "a volume scan adds hidden, purgeable and free space after the items, in that order")
        suite.expect(tree.rootSize == 1000 && tree.volumeCapacity == 1000,
                     "the root of a volume scan spans the whole capacity")
        suite.expect(tree.freeBytes(under: tree.root) == 600, "free space is found under the root")

        var mostlyPurgeable = DiskUsageTree(
            nodes: [DiskUsageNode(name: "/", size: 100, kind: .directory, parent: nil, children: [])], rootPath: "/")
        DiskUsageScanner.appendVolumeEntries(DiskUsageVolumeSpace(capacity: 1000, free: 600, purgeable: 500),
                                             to: &mostlyPurgeable)
        suite.expect(mostlyPurgeable.nodes.dropFirst().map(\.kind) == [.purgeable, .free]
                     && mostlyPurgeable.nodes[1].size == 300 && mostlyPurgeable.rootSize == 1000,
                     "purgeable space is capped at what the scan did not see, leaving no hidden space")

        if let startup = DiskUsageVolumeSpace.read(forVolumeAt: "/") {
            suite.expect(startup.capacity > 0 && startup.free <= startup.capacity,
                         "the startup volume reports a capacity that holds its free space")
        } else {
            suite.expect(false, "the startup volume reports its space")
        }
    }

    private static func systemPaths(_ suite: TestSuite) {
        let home = "/Users/tester"
        let protected = ["/", "/Applications", "/System/Library", "/usr/lib", "/private/etc/hosts",
                         "/System/Volumes/Data/Users", "/System/Volumes/Data", "/Users/tester",
                         "/Users/tester/Library", "/users/TESTER/library/mail", "/Users/tester/Desktop/"]
        for path in protected {
            suite.expect(DiskUsageSupport.isSystemPath(path, home: home), "\(path) is protected")
        }
        let free = ["/Applications/Some.app", "/usr/local/texlive/2024", "/private/tmp/x",
                    "/private/var/log/system.log", "/Users/tester/Library/Caches", "/Users/tester/Desktop/a.txt",
                    "/Users/other/Library", "/Volumes/External/Backups", "/systemish"]
        for path in free {
            suite.expect(!DiskUsageSupport.isSystemPath(path, home: home), "\(path) may be moved to the Trash")
        }
    }

    private static func packages(_ suite: TestSuite) {
        for name in ["Safari.app", "Thing.BUNDLE", ".git", ".GIT", "Library.photoslibrary", "Song.logicx"] {
            suite.expect(DiskUsageSupport.isPackageName(name), "\(name) is a package")
        }
        for name in ["src", ".app", "app", "notes.txt", "a.", ".github"] {
            suite.expect(!DiskUsageSupport.isPackageName(name), "\(name) is not a package")
        }
    }

    private static func recordDecoding(_ suite: TestSuite) {
        var record = [UInt8](repeating: 0, count: 12)
        record[0] = 12
        suite.expect(record.withUnsafeBytes { DiskUsageScanner.decodeEntry($0) } == nil,
                     "a record too short for its returned attributes is skipped, not read past its end")
    }

    // MARK: - Folders on disk

    private static func directoryReaders(_ suite: TestSuite, root: String) {
        write(root + "/readers/small.txt", bytes: 10)
        write(root + "/readers/large.bin", bytes: 100_000)
        write(root + "/readers/Ünïcode name.txt", bytes: 1)
        try? FileManager.default.createDirectory(atPath: root + "/readers/folder", withIntermediateDirectories: true)
        let bulk = DiskUsageScanner.readDirectoryInBulk(root + "/readers")
        suite.expect(bulk != nil, "the bulk reader opens an ordinary folder")
        let slow = DiskUsageScanner.readDirectoryOneByOne(root + "/readers")
        // File attributes such as the link count exist only for files; folders
        // count through what they hold.
        func normalized(_ entries: [DiskUsageScanner.Entry]) -> [String] {
            entries.map {
                "\($0.name.precomposedStringWithCanonicalMapping)|\($0.isDirectory)|\($0.fileID)|\($0.device)"
                    + ($0.isDirectory ? "" : "|\($0.allocatedSize)|\($0.linkCount)")
            }.sorted()
        }
        suite.expect(normalized(bulk ?? []) == normalized(slow) && slow.count == 4,
                     "both folder readers report the same names, kinds, sizes, ids and devices")
        suite.expect(bulk?.first { $0.name == "large.bin" }?.allocatedSize == allocated(root + "/readers/large.bin"),
                     "files count with their allocated size, not their length")
    }

    private static func scanning(_ suite: TestSuite, root: String) {
        write(root + "/sorted/b.txt", bytes: 5000)
        write(root + "/sorted/a.txt", bytes: 5000)
        write(root + "/sorted/big.bin", bytes: 200_000)
        write(root + "/Tool.app/Contents/MacOS/tool", bytes: 3000)
        write(root + "/.git/HEAD", bytes: 20)
        write(root + "/target/payload.bin", bytes: 300_000)
        _ = symlink(root + "/target", root + "/link-to-target")

        let progress = DiskUsageScanProgress()
        let tree = DiskUsageScanner.scan(root + "/", progress: progress)
        suite.expect(tree.rootPath == root, "the scanned path loses its trailing slash")
        suite.expect(tree.nodes[tree.root].kind == .directory && tree.nodes[tree.root].parent == nil,
                     "the root is the scanned folder")
        let fileNodes = tree.nodes.indices.filter { tree.nodes[$0].kind == .file }
        suite.expect(fileNodes.allSatisfy { tree.nodes[$0].size == allocated(tree.path(of: $0)) },
                     "every unshared file keeps its allocated size")
        suite.expect(tree.nodes.indices.allSatisfy { id in
            tree.nodes[id].kind != .directory
                || tree.nodes[id].size == tree.nodes[id].children.reduce(0) { $0 + tree.nodes[$1].size }
        }, "every folder is the sum of its children")
        suite.expect(tree.nodes.indices.allSatisfy { id in
            tree.nodes[id].children.allSatisfy { tree.nodes[$0].parent == id && $0 > id }
        }, "children point back to their parent and follow it in the array")

        if let sorted = node(tree, "sorted") {
            suite.expect(tree.nodes[sorted].children.map { tree.nodes[$0].name } == ["big.bin", "a.txt", "b.txt"],
                         "children are sorted biggest first, equal sizes by name")
        } else {
            suite.expect(false, "the sorted folder is in the result")
        }
        suite.expect(node(tree, "Tool.app").map { tree.nodes[$0].isPackage } == true
                     && node(tree, ".git").map { tree.nodes[$0].isPackage } == true
                     && node(tree, "sorted").map { tree.nodes[$0].isPackage } == false
                     && !tree.nodes[tree.root].isPackage,
                     "app bundles and .git folders are packages, other folders and the root are not")
        if let link = node(tree, "link-to-target") {
            suite.expect(tree.nodes[link].kind == .file && tree.nodes[link].children.isEmpty
                         && tree.nodes[link].size < 300_000,
                         "a symbolic link to a folder is not followed")
        } else {
            suite.expect(false, "the symbolic link is in the result")
        }
        suite.expect(progress.fraction == 1, "a finished folder scan reports full progress")
        suite.expect(progress.files.load(ordering: .relaxed) == UInt64(fileNodes.count),
                     "progress counts every file once")
        suite.expect(tree.nodes.indices.allSatisfy { tree.nodes[$0].kind != .file
                         || FileManager.default.fileExists(atPath: tree.path(of: $0))
                         || tree.nodes[$0].name == "link-to-target" },
                     "every file node's path leads back to the file")
    }

    private static func sharedData(_ suite: TestSuite, root: String) {
        let folder = root + "/shared"
        write(folder + "/Zeta/original.bin", bytes: 400_000)
        try? FileManager.default.createDirectory(atPath: folder + "/alpha", withIntermediateDirectories: true)
        suite.expect(link(folder + "/Zeta/original.bin", folder + "/alpha/hardlink.bin") == 0,
                     "the fixture creates a hard link")
        write(folder + "/Beta/data.bin", bytes: 500_000)
        try? FileManager.default.createDirectory(atPath: folder + "/aux", withIntermediateDirectories: true)
        let cloned = clonefile(folder + "/Beta/data.bin", folder + "/aux/copy.bin", 0) == 0
        suite.expect(cloned, "the fixture's volume makes APFS clones")

        let bulk = DiskUsageScanner.readDirectoryInBulk(folder + "/Beta") ?? []
        suite.expect(bulk.first.map { $0.cloneID != 0 && $0.cloneReferenceCount > 1 } == true,
                     "the bulk reader reports a clone's id and its reference count")

        let tree = DiskUsageScanner.scan(folder)
        let linkSize = allocated(folder + "/Zeta/original.bin")
        let cloneSize = allocated(folder + "/Beta/data.bin")
        suite.expect(node(tree, "alpha/hardlink.bin").map { tree.nodes[$0].size } == linkSize
                     && node(tree, "Zeta/original.bin").map { tree.nodes[$0].size } == 0,
                     "a hard-linked file counts once, under the path that sorts first ignoring case")
        suite.expect(node(tree, "aux/copy.bin").map { tree.nodes[$0].size } == cloneSize
                     && node(tree, "Beta/data.bin").map { tree.nodes[$0].size } == 0,
                     "cloned data counts once, under the path that sorts first ignoring case")
        suite.expect(tree.rootSize == linkSize + cloneSize, "shared data adds to the total only once")
    }

    private static func treeEdits(_ suite: TestSuite, root: String) {
        let folder = root + "/edits"
        write(folder + "/keep/one.bin", bytes: 50_000)
        write(folder + "/drop/two.bin", bytes: 80_000)
        write(folder + "/drop/deeper/three.bin", bytes: 20_000)
        var tree = DiskUsageScanner.scan(folder)
        let total = tree.rootSize

        suite.expect(tree.node(coveredBy: root) == tree.root && tree.node(coveredBy: folder) == tree.root,
                     "a mark on the scanned folder or above it covers the root")
        suite.expect(tree.node(coveredBy: folder + "x") == nil && tree.node(coveredBy: "/elsewhere") == nil,
                     "a mark elsewhere, even sharing a name prefix, covers nothing")
        guard let drop = node(tree, "drop"), let three = node(tree, "drop/deeper/three.bin"),
              let keep = node(tree, "keep") else {
            suite.expect(false, "the edit fixture is in the result")
            return
        }
        suite.expect(tree.chain(to: three).map { tree.nodes[$0].name } == ["edits", "drop", "deeper", "three.bin"],
                     "the chain runs from the root down to the item")
        suite.expect(tree.isAncestorOrSelf(drop, of: three) && !tree.isAncestorOrSelf(keep, of: three),
                     "ancestry follows the parents")

        let threeSize = tree.nodes[three].size
        tree.remove(three)
        suite.expect(tree.nodes[three].isRemoved && tree.rootSize == total - threeSize
                     && node(tree, "drop/deeper/three.bin") == nil,
                     "removing an item shrinks every folder above it and hides it from lookups")
        tree.remove(three)
        suite.expect(tree.rootSize == total - threeSize, "removing an item twice changes nothing")

        write(folder + "/drop/added.bin", bytes: 60_000)
        let fresh = DiskUsageScanner.scan(folder + "/drop")
        let oldDropChildren = tree.nodes[drop].children
        tree.graft(fresh, into: drop)
        let expected = tree.nodes[keep].size + fresh.rootSize
        suite.expect(tree.rootSize == expected && tree.nodes[drop].size == fresh.rootSize,
                     "a rescanned folder replaces its old size in every folder above it")
        suite.expect(oldDropChildren.allSatisfy { tree.nodes[$0].isRemoved }
                     && node(tree, "drop/added.bin") != nil && node(tree, "drop/deeper/three.bin") != nil,
                     "a rescan retires the old children and links in the new ones")
        suite.expect(tree.nodes[drop].children.allSatisfy { tree.nodes[$0].parent == drop },
                     "grafted children point to the folder they were grafted into")

        tree.emptyRoot()
        suite.expect(tree.rootSize == 0 && tree.nodes[tree.root].children.isEmpty
                     && tree.nodes.dropFirst().allSatisfy(\.isRemoved),
                     "an emptied root holds nothing")
    }

    private static func readOnly(_ suite: TestSuite, root: String) {
        let folder = root + "/locked"
        write(folder + "/file.txt", bytes: 1)
        suite.expect(DiskUsageSupport.readOnlyReason(for: folder + "/file.txt") == nil,
                     "an item in a writable folder can be moved to the Trash")
        chmod(folder, 0o555)
        suite.expect(DiskUsageSupport.readOnlyReason(for: folder + "/file.txt") == .folder(folder),
                     "an item in a folder that cannot be written names that folder")
        chmod(folder, 0o755)
        chflags(folder + "/file.txt", UInt32(UF_IMMUTABLE))
        suite.expect(DiskUsageSupport.readOnlyReason(for: folder + "/file.txt") == .item,
                     "a locked item is read-only itself")
        chflags(folder + "/file.txt", 0)
        suite.expect(DiskUsageSupport.readOnlyReason(for: folder + "/missing") == nil,
                     "a missing item has no read-only reason")
    }

    private static func cancellationAndDepth(_ suite: TestSuite, root: String) {
        write(root + "/a/file.bin", bytes: 10_000)
        let cancelled = DiskUsageScanProgress()
        cancelled.cancel()
        let empty = DiskUsageScanner.scan(root, progress: cancelled)
        suite.expect(empty.nodes.count == 1 && empty.rootSize == 0, "a cancelled scan stops before reading")

        var deep = root + "/deep"
        for level in 0..<150 { deep += "/d\(level % 10)" }
        write(deep + "/leaf.bin", bytes: 4096)
        for index in 0..<64 { write(root + "/wide/f\(index)/file.bin", bytes: 4096 * (index + 1)) }
        let tree = DiskUsageScanner.scan(root)
        suite.expect(tree.node(coveredBy: deep + "/leaf.bin") != nil,
                     "a deeply nested file is found")
        suite.expect(node(tree, "wide").map { tree.nodes[$0].children.count } == 64
                     && node(tree, "wide").map { tree.nodes[$0].children.first.map { tree.nodes[$0].name } } == "f63",
                     "every folder scanned in parallel arrives, sorted by size")
    }
}
