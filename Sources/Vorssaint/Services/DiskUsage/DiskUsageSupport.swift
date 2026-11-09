// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Darwin
import Foundation

/// What a volume reports about its space. `purgeable` is the part of the
/// space available for important use that is not plain free space, which
/// macOS can reclaim by itself.
struct DiskUsageVolumeSpace: Equatable {
    var capacity: UInt64
    var free: UInt64
    var purgeable: UInt64

    init(capacity: UInt64, free: UInt64, purgeable: UInt64) {
        self.capacity = capacity
        self.free = free
        self.purgeable = purgeable
    }

    init(capacity: UInt64, available: UInt64, availableForImportantUsage: UInt64?) {
        let important = availableForImportantUsage ?? available
        self.init(capacity: capacity, free: available,
                  purgeable: important > available ? important - available : 0)
    }

    /// Reads the volume that holds `path`, or nil when it reports no capacity.
    static func read(forVolumeAt path: String) -> DiskUsageVolumeSpace? {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey,
                                         .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? url.resourceValues(forKeys: keys),
              let capacity = values.volumeTotalCapacity, capacity > 0 else { return nil }
        let available = UInt64(max(0, values.volumeAvailableCapacity ?? 0))
        let important = values.volumeAvailableCapacityForImportantUsage.map { UInt64(max(0, $0)) }
        return DiskUsageVolumeSpace(capacity: UInt64(capacity), available: available,
                                    availableForImportantUsage: important)
    }

    /// Bytes the scan is expected to find: what the volume uses, without
    /// the space macOS can reclaim. Drives the progress of a volume scan.
    var expectedScanBytes: UInt64 {
        let used = capacity - min(capacity, free)
        return used - min(used, purgeable)
    }
}

/// Why an item cannot be moved to the Trash.
enum DiskUsageReadOnlyReason: Equatable {
    /// The item itself is locked.
    case item
    /// The folder holding it is not writable.
    case folder(String)
    /// The whole volume is mounted read-only.
    case volume(String)
}

enum DiskUsageSupport {
    /// Folder extensions treated as packages: shown as one item until opened.
    /// A cheap stand-in for asking Launch Services about every folder.
    static let packageExtensions: Set<String> = [
        "app", "bundle", "framework", "plugin", "kext", "appex", "xpc", "photoslibrary",
        "musiclibrary", "tvlibrary", "photolibrary", "aplibrary", "fcpbundle", "logicx", "band",
        "xcodeproj", "xcworkspace", "playground", "rtfd", "pkg", "mpkg",
    ]

    static func isPackageName(_ name: String) -> Bool {
        if name.caseInsensitiveCompare(".git") == .orderedSame { return true }
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return false }
        return packageExtensions.contains(name[name.index(after: dot)...].lowercased())
    }

    // Paths macOS needs, which may never be moved to the Trash from a scan.
    // Matched case-insensitively, after removing the data volume's prefix.
    private static let systemExact: Set<String> = [
        "/", "/applications", "/library", "/network", "/users", "/volumes",
    ]
    private static let systemInHome: Set<String> = [
        "", "/desktop", "/library", "/library/mail", "/music/itunes",
    ]
    private static let systemPrefixes = [
        "/system", "/private", "/volumes/recovery", "/.dbfseventsd", "/.file", "/.fseventsd",
        "/.hotfiles.btree", "/.vol", "/bin", "/cores", "/dev", "/etc", "/home", "/mach_kernel",
        "/net", "/sbin", "/tmp", "/usr", "/var", "/vol",
    ]
    /// Places inside the system prefixes that hold disposable user data.
    private static let systemExceptions = [
        "/private/var/log", "/private/var/tmp", "/private/tmp", "/private/var/root/.trash",
        "/usr/local/texlive",
    ]
    private static let dataVolumePrefix = "/system/volumes/data"

    static func isSystemPath(_ path: String, home: String = NSHomeDirectory()) -> Bool {
        var lowered = path.lowercased()
        while lowered.count > 1, lowered.hasSuffix("/") { lowered.removeLast() }
        if DiskUsageTree.path(lowered, isInsideOrEqualTo: dataVolumePrefix) {
            let rest = String(lowered.dropFirst(dataVolumePrefix.count))
            lowered = rest.isEmpty ? "/" : rest
        }
        if systemExact.contains(lowered) { return true }
        let loweredHome = home.lowercased()
        if !loweredHome.isEmpty, loweredHome != "/",
           DiskUsageTree.path(lowered, isInsideOrEqualTo: loweredHome),
           systemInHome.contains(String(lowered.dropFirst(loweredHome.count))) {
            return true
        }
        func longestMatch(_ list: [String]) -> Int {
            list.filter { DiskUsageTree.path(lowered, isInsideOrEqualTo: $0) }.map(\.count).max() ?? 0
        }
        let prefix = longestMatch(systemPrefixes)
        return prefix > 0 && longestMatch(systemExceptions) < prefix
    }

    /// Asks the file system whether `path` could be moved to the Trash without
    /// administrator rights: the item, then its volume, then its folder.
    static func readOnlyReason(for path: String) -> DiskUsageReadOnlyReason? {
        var info = stat()
        guard lstat(path, &info) == 0 else { return nil }
        if info.st_flags & UInt32(UF_IMMUTABLE | SF_IMMUTABLE) != 0 { return .item }
        var volume = statfs()
        if statfs(path, &volume) == 0, volume.f_flags & UInt32(MNT_RDONLY) != 0 {
            let mount = withUnsafeBytes(of: volume.f_mntonname) { raw in
                String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
            }
            return .volume(mount)
        }
        let parent = (path as NSString).deletingLastPathComponent
        guard !parent.isEmpty, parent != path else { return nil }
        if access(parent, W_OK) != 0 { return .folder(parent) }
        return nil
    }
}
