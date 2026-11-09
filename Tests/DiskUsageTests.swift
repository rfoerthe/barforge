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
        reportNavigation(suite)
        reportCollector(suite)
        ringLayout(suite)
        tileLayout(suite)
        keptFolders(suite)
        strings(suite)
    }

    // MARK: - Report model

    /// /r: A (a1 400, a2 200), B.app (b1 300), c 99, tiny 1 — 1000 bytes in all.
    private static func sampleTree() -> DiskUsageTree {
        func node(_ name: String, _ size: UInt64, _ kind: DiskUsageNode.Kind, _ parent: Int?,
                  _ children: [Int] = [], package: Bool = false) -> DiskUsageNode {
            DiskUsageNode(name: name, size: size, kind: kind, parent: parent, children: children, isPackage: package)
        }
        return DiskUsageTree(nodes: [
            node("r", 1000, .directory, nil, [1, 4, 6, 7]),
            node("A", 600, .directory, 0, [2, 3]),
            node("a1", 400, .file, 1),
            node("a2", 200, .file, 1),
            node("B.app", 300, .directory, 0, [5], package: true),
            node("b1", 300, .file, 4),
            node("c", 99, .file, 0),
            node("tiny", 1, .file, 0),
        ], rootPath: "/r")
    }

    private static func reportNavigation(_ suite: TestSuite) {
        var report = DiskUsageReport(tree: sampleTree())
        suite.expect(report.current == 0 && !report.canGoBack && !report.canGoForward && !report.canGoUp,
                     "a new result opens at its root with no history")
        suite.expect(report.canOpen(1) && !report.canOpen(2) && !report.canOpen(4),
                     "folders open, while files and closed packages are selected instead")
        report.navigate(to: 1)
        suite.expect(report.current == 1 && report.canGoBack && report.canGoUp, "opening a folder records history")
        report.goBack()
        suite.expect(report.current == 0 && report.canGoForward, "back returns to the previous folder")
        report.goForward()
        suite.expect(report.current == 1, "forward repeats the step")
        report.goUp()
        report.goBack()
        suite.expect(report.current == 1 && report.canGoForward, "going up is a step of its own in the history")
        report.navigate(to: 1)
        report.goBack()
        report.navigate(to: 4)
        suite.expect(!report.canGoForward && report.history.last == 4, "a new step drops the way forward")
        report.openPackage(4)
        suite.expect(report.current == 4 && report.canOpen(4) && report.showsContents(of: 4),
                     "an opened package shows its contents")
        report.selected = 5
        report.navigate(to: 0)
        suite.expect(report.selected == nil, "moving to another folder clears the selection")

        let listing = report.listing(of: 0)
        suite.expect(listing.items == [1, 4, 6] && listing.smaller == [7],
                     "items below the share threshold are grouped as smaller items")
    }

    private static func reportCollector(_ suite: TestSuite) {
        var report = DiskUsageReport(tree: sampleTree())
        report.navigate(to: 1)
        report.apply(marks: ["/r/A"])
        suite.expect(report.collected == [1] && report.isCollected(2) && !report.isCollected(4),
                     "a mark collects the item and everything inside it")
        suite.expect(report.sizes[0] == 400 && report.sizes[1] == 600 && report.collectedBytes == 600,
                     "collected items leave the folders above them but keep their own size")
        suite.expect(report.current == 0, "the open folder moves out of a collected one")
        report.apply(marks: ["/r/A/a1", "/elsewhere", "/r/A/a1"])
        suite.expect(report.collected == [2] && report.sizes[1] == 200 && report.sizes[0] == 600,
                     "marks from other results are ignored and duplicates count once")
        report.apply(marks: ["/"])
        suite.expect(report.collected == [0], "a mark above the scanned folder covers the root")
        report.apply(marks: [])
        suite.expect(report.collected.isEmpty && report.sizes == report.tree.nodes.map(\.size),
                     "clearing the marks restores every size")

        suite.expect(DiskUsageMarks.adding("/r/A", to: ["/r/A/a1", "/r/c"]) == ["/r/c", "/r/A"],
                     "a mark replaces the marks inside it")
        suite.expect(DiskUsageMarks.adding("/r/A/a2", to: ["/r/A"]) == ["/r/A"],
                     "a mark inside an existing one adds nothing")
        suite.expect(DiskUsageMarks.adding("/r/AB", to: ["/r/A"]) == ["/r/A", "/r/AB"],
                     "a sibling that shares a name prefix is a mark of its own")

        let noSystem: (String) -> Bool = { _ in false }
        let writable: (String) -> DiskUsageReadOnlyReason? = { _ in nil }
        suite.expect(report.refusal(for: 0, isSystemPath: noSystem, readOnlyReason: writable) == .notAnItem,
                     "the scanned folder itself cannot be collected")
        suite.expect(report.refusal(for: 2, isSystemPath: noSystem, readOnlyReason: writable) == nil,
                     "an ordinary file can be collected")
        suite.expect(report.refusal(for: 2, isSystemPath: { $0 == "/r/A/a1" }, readOnlyReason: writable)
                     == .neededBySystem(name: "a1"), "system paths are refused by name")
        suite.expect(report.refusal(for: 2, isSystemPath: noSystem, readOnlyReason: { _ in .item }) == .locked(name: "a1")
                     && report.refusal(for: 2, isSystemPath: noSystem, readOnlyReason: { _ in .folder("/r/A") })
                         == .readOnlyFolder(path: "/r/A")
                     && report.refusal(for: 2, isSystemPath: noSystem, readOnlyReason: { _ in .volume("/") })
                         == .readOnlyVolume(path: "/"),
                     "read-only items, folders and volumes are refused with their reason")
        var backup = DiskUsageTree(nodes: [
            DiskUsageNode(name: "Backups.backupdb", size: 1, kind: .directory, parent: nil, children: [1]),
            DiskUsageNode(name: "Mac", size: 1, kind: .directory, parent: 0, children: []),
        ], rootPath: "/Volumes/TM/Backups.backupdb")
        backup.volumeCapacity = nil
        suite.expect(DiskUsageReport(tree: backup).refusal(for: 1, isSystemPath: noSystem, readOnlyReason: writable)
                     == .timeMachineBackup, "Time Machine backups are left to Time Machine")
        var volume = sampleTree()
        DiskUsageScanner.appendVolumeEntries(DiskUsageVolumeSpace(capacity: 5000, free: 3000, purgeable: 200),
                                             to: &volume)
        let volumeReport = DiskUsageReport(tree: volume)
        suite.expect(volume.nodes.indices.filter { !volume.nodes[$0].kind.isOnDisk }.allSatisfy {
            volumeReport.refusal(for: $0, isSystemPath: noSystem, readOnlyReason: writable) == .notAnItem
        }, "hidden, purgeable and free space cannot be collected")
        suite.expect(volumeReport.shownSize(0) == 2000, "a volume's root shows its used space without free space")

        var edited = DiskUsageReport(tree: sampleTree())
        edited.apply(marks: ["/r/A/a1"])
        edited.navigate(to: 1)
        edited.dropDeleted(path: "/r/A/a1")
        suite.expect(edited.collected.isEmpty && edited.sizes[1] == 200 && edited.sizes[0] == 600
                     && edited.tree.nodes[2].isRemoved && edited.current == 1,
                     "a trashed item leaves the result and the collector")
        let fresh = DiskUsageTree(nodes: [
            DiskUsageNode(name: "A", size: 50, kind: .directory, parent: nil, children: [1]),
            DiskUsageNode(name: "new", size: 50, kind: .file, parent: 0, children: []),
        ], rootPath: "/r/A")
        edited.apply(marks: ["/r/A/a2"])
        edited.graft(fresh, into: 1)
        suite.expect(edited.collected.isEmpty && edited.sizes[0] == 450 && edited.current == 1
                     && edited.listing(of: 1).items.map { edited.tree.nodes[$0].name } == ["new"],
                     "a rescanned folder replaces its contents and drops marks on what is gone")
    }

    // MARK: - Charts

    private static func ringLayout(_ suite: TestSuite) {
        var report = DiskUsageReport(tree: sampleTree())
        report.openPackage(4)
        report.navigate(to: 0)
        let segments = DiskUsageRingLayout.segments(of: report)
        let first = segments.filter { $0.ring == 1 }
        suite.expect(first.map(\.item) == [.node(1), .node(4), .node(6), .smaller(0)] || first.map(\.item) == [.node(1), .node(4), .node(6)],
                     "the first ring holds the open folder's items in order")
        suite.expectClose(first.first { $0.item == .node(1) }?.span ?? 0, 0.6, "a folder's span is its share")
        suite.expect(segments.contains { $0.ring == 2 && $0.item == .node(2) }
                     && segments.contains { $0.ring == 2 && $0.item == .node(5) },
                     "folders and opened packages continue into the next ring")
        let a1 = segments.first { $0.item == .node(2) }
        suite.expect(a1.map { abs($0.start - 0) < 1e-9 && abs($0.span - 0.4) < 1e-9 } == true,
                     "children share their folder's angle")
        suite.expect(DiskUsageRingLayout.hit(segments, radius: 0.1, angle: 0.1) == nil,
                     "the centre disc is not a segment")
        let ringOne = DiskUsageRingLayout.bounds(ofRing: 1)
        suite.expect(DiskUsageRingLayout.hit(segments, radius: (ringOne.inner + ringOne.outer) / 2, angle: 0.7)?.item == .node(4),
                     "a point inside a segment finds it")
        let last = DiskUsageRingLayout.bounds(ofRing: DiskUsageRingLayout.ringCount)
        suite.expect(abs(last.outer - 1) < 1e-9 && ringOne.inner == DiskUsageRingLayout.centreShare
                     && (1..<DiskUsageRingLayout.ringCount).allSatisfy {
                         abs(DiskUsageRingLayout.bounds(ofRing: $0).outer - DiskUsageRingLayout.bounds(ofRing: $0 + 1).inner) < 1e-9
                     }, "the rings fill the space from the centre disc to the edge without gaps")

        var collected = report
        collected.apply(marks: ["/r/A"])
        suite.expect(!DiskUsageRingLayout.segments(of: collected).contains { $0.item == .node(1) || $0.item == .node(2) },
                     "collected items leave the rings")
        var empty = DiskUsageReport(tree: DiskUsageTree(
            nodes: [DiskUsageNode(name: "e", size: 0, kind: .directory, parent: nil, children: [])], rootPath: "/e"))
        empty.selected = nil
        suite.expect(DiskUsageRingLayout.segments(of: empty) == [.init(item: .empty, ring: 1, start: 0, span: 1)],
                     "an empty folder draws one empty ring")
        let hues = DiskUsageRingLayout.hues(of: sampleTree())
        suite.expect(hues.allSatisfy { $0 >= 0 && $0 < 1 } && hues[1] != hues[4],
                     "every item gets a hue, and neighbours differ")
    }

    private static func tileLayout(_ suite: TestSuite) {
        let area = CGRect(x: 10, y: 20, width: 400, height: 300)
        let values = [50.0, 30, 15, 5]
        let rects = DiskUsageTileLayout.squarify(values, in: area)
        let total = values.reduce(0, +)
        suite.expect(rects.count == values.count, "every value gets a tile")
        for (value, rect) in zip(values, rects) {
            suite.expectClose(Double(rect.width * rect.height), value / total * Double(area.width * area.height),
                              "a tile's area is its share", tol: 0.5)
            suite.expect(area.insetBy(dx: -0.01, dy: -0.01).contains(rect), "tiles stay inside the area")
        }
        suite.expect(DiskUsageTileLayout.squarify([], in: area).isEmpty
                     && DiskUsageTileLayout.squarify([1], in: .zero) == [.zero],
                     "empty input or area lays out nothing visible")

        var report = DiskUsageReport(tree: sampleTree())
        report.openPackage(4)
        report.navigate(to: 0)
        let tiles = DiskUsageTileLayout.tiles(of: report, in: area)
        let folder = tiles.first { $0.item == .node(1) }
        suite.expect(folder?.isNested == true && folder?.depth == 1
                     && tiles.contains { $0.item == .node(2) && $0.depth == 2 },
                     "large folders show their contents inside, one level deeper")
        if let folder, let inner = tiles.first(where: { $0.item == .node(2) }) {
            suite.expect(folder.rect.contains(inner.rect)
                         && DiskUsageTileLayout.hit(tiles, at: CGPoint(x: inner.rect.midX, y: inner.rect.midY))?.item == .node(2),
                         "nested tiles lie inside their folder and are found first")
        }
        suite.expect(tiles.allSatisfy { $0.item != .node(7) }, "a tile too small to see is grouped")
    }

    private static func keptFolders(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.disk-analyzer"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        DiskAnalyzerFolder.saveKept([DiskAnalyzerFolder(path: "/b", keptAt: 20),
                                     DiskAnalyzerFolder(path: "/session", keptAt: nil),
                                     DiskAnalyzerFolder(path: "/a", keptAt: 10)], defaults: defaults)
        suite.expect(DiskAnalyzerFolder.loadKept(defaults: defaults).map(\.path) == ["/a", "/b"],
                     "only kept folders are saved, listed in the order they were kept")
        DiskAnalyzerFolder.saveKept([], defaults: defaults)
        suite.expect(defaults.object(forKey: DefaultsKey.diskAnalyzerKeptFolders) == nil,
                     "forgetting the last folder removes the key")
        suite.expect(!SettingsBackupSupport.exportKeys().contains(DefaultsKey.diskAnalyzerKeptFolders)
                     && SettingsBackupSupport.exportKeys().contains(DefaultsKey.diskAnalyzerViewMode)
                     && SettingsBackupSupport.exportKeys().contains(DefaultsKey.panelUtilityDiskAnalyzer),
                     "the view choice and panel tile travel with backups, this Mac's folder paths do not")
    }

    private static func strings(_ suite: TestSuite) {
        let english = DiskAnalyzerFeatureStrings.enUS
        for language in AppLanguage.allCases where language != .enUS {
            let text = FeatureStrings.diskAnalyzer(language)
            suite.expect(text.title != english.title && text.hubDescription != english.hubDescription
                         && text.collectorHint != english.collectorHint,
                         "\(language.rawValue) translates the Disk Analyzer")
        }
        suite.expect(AppFeature.diskAnalyzer.group == .tools && !AppFeature.diskAnalyzer.installedByDefault
                     && AppFeature.diskAnalyzer.permissions == [.fullDiskAccess],
                     "the Disk Analyzer is an opt-in tool that can use Full Disk Access")
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
        suite.expect(space.used == 400 && DiskUsageVolumeSpace(capacity: 10, free: 20, purgeable: 0).used == 0,
                     "used space is capacity minus free space and never underflows")
        let usage = DiskAnalyzerFeatureStrings.enUS.usageFormat
        suite.expect(String(format: usage, "1 GB", "2 GB", "3 GB") == "1 GB used · 2 GB free · 3 GB total",
                     "a disk row names its used, free and total space")
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
        let order: [[UInt8]] = [[], [0x2F], [0x2F, 0x61], [0x2F, 0x61, 0x2D], [0x2F, 0x61, 0x2F], [0x2F, 0x62]]
        suite.expect(zip(order, order.dropFirst()).allSatisfy { DiskUsageScanner.sortsFirst($0, $1) && !DiskUsageScanner.sortsFirst($1, $0) }
                     && !DiskUsageScanner.sortsFirst([0x2F, 0x61], [0x2F, 0x61]),
                     "shared paths sort by bytes, a prefix first, equal paths not before each other")
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
        suite.expect(progress.fraction == 1 && progress.isEvaluating,
                     "a finished scan reports full progress and that its result was put together")
        let reading = DiskUsageScanProgress()
        reading.doneMillionths.store(2_000_000, ordering: .relaxed)
        reading.expectedBytes.store(10, ordering: .relaxed)
        reading.bytes.store(50, ordering: .relaxed)
        suite.expect(reading.fraction < 1 && !reading.isEvaluating,
                     "progress never shows full while folders are still being read")
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

        let sharedProgress = DiskUsageScanProgress()
        let tree = DiskUsageScanner.scan(folder, progress: sharedProgress)
        suite.expect(sharedProgress.bytes.load(ordering: .relaxed) == tree.rootSize,
                     "scan progress counts hard-linked and cloned data once, as the result does")
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
