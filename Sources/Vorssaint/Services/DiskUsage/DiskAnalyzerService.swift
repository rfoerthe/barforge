// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import SwiftUI

/// A disk the start page offers to scan.
struct DiskAnalyzerDisk: Identifiable, Equatable {
    var id: String { path }
    var path: String
    var name: String
    var space: DiskUsageVolumeSpace
    var isInternal: Bool
}

/// The Disk Analyzer window and everything it shows: the start page with
/// disks and folders, running scans, one result per disk or folder, and the
/// collector whose items go to the Trash together. Results live only while
/// the window is open, so a closed window holds no scan in memory.
final class DiskAnalyzerService: ObservableObject {
    static let shared = DiskAnalyzerService()

    enum Page: Equatable {
        case start
        case scanning(String)
        case report(String)
    }

    enum CollectorState: Equatable {
        case idle
        case countdown(secondsLeft: Int)
        case trashing
    }

    struct Scan {
        let path: String
        let progress: DiskUsageScanProgress
        /// A folder inside an existing result, rescanned in place.
        let graftInto: (resultPath: String, node: Int)?
    }

    @Published private(set) var page: Page = .start
    @Published private(set) var disks: [DiskAnalyzerDisk] = []
    @Published private(set) var folders: [DiskAnalyzerFolder] = []
    @Published private(set) var results: [String: DiskUsageReport] = [:] {
        didSet {
            // Colours follow each result's tree; a fresh scan brings its own
            // from the background, a grafted tree is worked out here.
            for (path, report) in results where hues[path]?.count != report.tree.nodes.count {
                hues[path] = DiskUsageRingLayout.hues(of: report.tree)
            }
            for path in hues.keys where results[path] == nil { hues[path] = nil }
        }
    }
    /// Colour position of every node, per result.
    private(set) var hues: [String: [Double]] = [:]
    private var displayNames: [String: String] = [:]
    @Published private(set) var scan: Scan?
    /// Bumped while a scan runs so its progress redraws.
    @Published private(set) var progressTick = 0
    /// Paths in the collector, oldest first.
    @Published private(set) var marks: [String] = []
    @Published private(set) var collectorState: CollectorState = .idle
    /// Why the last item was refused, or what failed while trashing.
    @Published var message: String?
    /// The item under the pointer in the list or chart of the open result.
    var hovered: Int?

    static let countdownSeconds = 5

    private var window: DiskAnalyzerWindow?
    private var progressTimer: Timer?
    private var countdownTimer: Timer?
    private let scanQueue = DispatchQueue(label: "de.foerther.barforge.disk-analyzer.scan", qos: .userInitiated)

    private init() {}

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(L10n.shared.language) }

    // MARK: Window

    var isVisible: Bool { window?.isVisible == true }

    func show() {
        guard AppFeature.diskAnalyzer.isAvailable else { return }
        let window = self.window ?? makeWindow()
        self.window = window
        if !window.isVisible {
            reloadSources()
            Permissions.shared.refresh()
            WindowActivationPolicy.retain()
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        }
        window.title = strings.title
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Opens the window on a disk or folder, showing its result or scanning it.
    func show(path: String) {
        show()
        guard isVisible else { return }
        if results[path] != nil { page = .report(path) } else { startScan(path) }
    }

    func syncWithPreferences() {
        if !AppFeature.diskAnalyzer.isAvailable {
            window?.close()
            window = nil
        }
    }

    private func makeWindow() -> DiskAnalyzerWindow {
        let host = NSHostingController(rootView: DiskAnalyzerView())
        host.sizingOptions = []
        let window = DiskAnalyzerWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.setContentSize(NSSize(width: 1080, height: 720))
        window.contentMinSize = NSSize(width: 760, height: 520)
        window.center()
        window.setFrameAutosaveName("BarforgeDiskAnalyzer")
        window.onClose = { [weak self] in self?.windowDidClose() }
        window.keyHandler = { [weak self] event in self?.handleKey(event) ?? false }
        window.previewItems = { [weak self] in self?.previewURL().map { [$0] } ?? [] }
        return window
    }

    /// A closed window keeps nothing: scans stop, results and marks go, and
    /// a pending countdown is called off without touching the disk.
    private func windowDidClose() {
        scan?.progress.cancel()
        scan = nil
        progressTimer?.invalidate()
        progressTimer = nil
        stopCountdown()
        results = [:]
        displayNames = [:]
        marks = []
        message = nil
        hovered = nil
        page = .start
        folders = folders.filter(\.isKept)
        WindowActivationPolicy.release()
    }

    // MARK: Sources

    func reloadSources() {
        disks = Self.mountedDisks()
        let kept = DiskAnalyzerFolder.loadKept()
        let session = folders.filter { !$0.isKept && !kept.map(\.path).contains($0.path) }
        folders = kept + session
    }

    static func mountedDisks() -> [DiskAnalyzerDisk] {
        let keys: [URLResourceKey] = [.volumeLocalizedNameKey, .volumeIsBrowsableKey, .volumeIsInternalKey,
                                      .volumeTotalCapacityKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                         options: [.skipHiddenVolumes]) ?? []
        var disks: [DiskAnalyzerDisk] = []
        for url in urls {
            let path = url.path
            guard !path.hasPrefix("/System/Volumes"), !path.hasPrefix("/private/var"),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.volumeIsBrowsable != false,
                  let space = DiskUsageVolumeSpace.read(forVolumeAt: path) else { continue }
            let name = values.volumeLocalizedName ?? FileManager.default.displayName(atPath: path)
            disks.append(DiskAnalyzerDisk(path: path, name: name, space: space,
                                          isInternal: values.volumeIsInternal ?? false))
        }
        return disks.sorted { ($0.path == "/" ? 0 : 1, $0.name) < ($1.path == "/" ? 0 : 1, $1.name) }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = strings.scan
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.startScan(url.standardizedFileURL.path)
        }
    }

    func setKept(_ kept: Bool, folder path: String) {
        guard let index = folders.firstIndex(where: { $0.path == path }) else { return }
        folders[index].keptAt = kept ? Date().timeIntervalSince1970 : nil
        DiskAnalyzerFolder.saveKept(folders.filter(\.isKept))
    }

    /// Discards a result; a folder that is not kept also leaves the list.
    func discardResult(_ path: String) {
        results[path] = nil
        // Names are looked up again on demand; the results left refill theirs.
        displayNames = [:]
        if page == .report(path) { page = .start }
        folders.removeAll { $0.path == path && !$0.isKept }
    }


    // MARK: Scanning

    func startScan(_ path: String) {
        guard scan == nil else { return }
        let isDisk = disks.contains { $0.path == path }
        if !isDisk, !folders.contains(where: { $0.path == path }) {
            folders.append(DiskAnalyzerFolder(path: path, keptAt: nil))
        }
        let volume = isDisk ? DiskUsageVolumeSpace.read(forVolumeAt: path) : nil
        run(Scan(path: path, progress: DiskUsageScanProgress(), graftInto: nil), volume: volume)
    }

    /// Scans the whole disk or folder of the open result again.
    func rescanResult() {
        guard case .report(let path) = page else { return }
        startScan(path)
    }

    /// Scans one folder of the open result again and puts it in place.
    func rescanFolder(_ id: Int) {
        guard scan == nil, case .report(let resultPath) = page, let report = results[resultPath],
              report.tree.nodes[id].kind == .directory else { return }
        if id == report.tree.root { return rescanResult() }
        run(Scan(path: report.tree.path(of: id), progress: DiskUsageScanProgress(),
                 graftInto: (resultPath, id)), volume: nil)
    }

    func cancelScan() {
        scan?.progress.cancel()
    }

    private func run(_ newScan: Scan, volume: DiskUsageVolumeSpace?) {
        scan = newScan
        page = .scanning(newScan.path)
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.progressTick &+= 1
        }
        let progress = newScan.progress
        scanQueue.async { [weak self] in
            let tree = DiskUsageScanner.scan(newScan.path, volume: volume, progress: progress)
            // Work that grows with the tree stays off the main thread.
            let hues = newScan.graftInto == nil && !progress.isCancelled ? DiskUsageRingLayout.hues(of: tree) : nil
            let report = hues == nil ? nil : DiskUsageReport(tree: tree)
            DispatchQueue.main.async { self?.finish(newScan, tree: tree, report: report, hues: hues) }
        }
    }

    private func finish(_ finished: Scan, tree: DiskUsageTree, report prepared: DiskUsageReport? = nil,
                        hues preparedHues: [Double]? = nil) {
        guard scan?.progress === finished.progress else { return }
        scan = nil
        progressTimer?.invalidate()
        progressTimer = nil
        if let graft = finished.graftInto {
            if !finished.progress.isCancelled, var report = results[graft.resultPath] {
                report.graft(tree, into: graft.node)
                report.apply(marks: marks)
                results[graft.resultPath] = report
            }
            page = results[graft.resultPath] == nil ? .start : .report(graft.resultPath)
            return
        }
        guard !finished.progress.isCancelled else {
            page = results[finished.path] == nil ? .start : .report(finished.path)
            if results[finished.path] == nil {
                folders.removeAll { $0.path == finished.path && !$0.isKept }
            }
            return
        }
        var report = prepared ?? DiskUsageReport(tree: tree)
        report.apply(marks: marks)
        if let preparedHues { hues[finished.path] = preparedHues }
        results[finished.path] = report
        page = .report(finished.path)
        Permissions.shared.refresh()
    }

    // MARK: The open result

    var openPath: String? {
        if case .report(let path) = page { return path }
        return nil
    }

    var openReport: DiskUsageReport? { openPath.flatMap { results[$0] } }

    func showStartPage() {
        reloadSources()
        page = .start
    }

    func update(_ change: (inout DiskUsageReport) -> Void) {
        guard let path = openPath, var report = results[path] else { return }
        change(&report)
        results[path] = report
    }

    /// Opens a folder, or selects an item that cannot be opened.
    func activate(_ id: Int) {
        update { report in
            if report.canOpen(id) { report.navigate(to: id) } else { report.selected = id }
        }
    }

    /// The item keyboard commands act on: the one under the pointer, or else the selected one.
    var pointedItem: Int? {
        guard let report = openReport else { return nil }
        if let hovered, report.tree.nodes.indices.contains(hovered),
           report.tree.nodes[hovered].kind.isOnDisk { return hovered }
        return report.selected
    }

    // MARK: Collector

    func collect(_ id: Int) {
        guard collectorState == .idle, let report = openReport else { return }
        if let refusal = report.refusal(for: id) {
            message = text(for: refusal)
            return
        }
        message = nil
        setMarks(DiskUsageMarks.adding(report.tree.path(of: id), to: marks))
    }

    /// Adds a dragged path when the open result holds it.
    func collect(path: String) {
        guard let report = openReport, let id = report.tree.node(coveredBy: path),
              id != report.tree.root else { return }
        collect(id)
    }

    func uncollect(path: String) {
        guard collectorState == .idle else { return }
        setMarks(marks.filter { $0 != path })
    }

    func uncollect(_ id: Int) {
        guard let report = openReport else { return }
        let path = report.tree.path(of: id)
        uncollect(path: marks.first { DiskUsageTree.path(path, isInsideOrEqualTo: $0) } ?? path)
    }

    func clearCollector() {
        guard collectorState == .idle else { return }
        setMarks([])
    }

    private func setMarks(_ newMarks: [String]) {
        marks = newMarks
        for path in results.keys {
            results[path]?.apply(marks: newMarks)
        }
    }

    /// Starts the countdown; the items go to the Trash when it runs out.
    func startCountdown() {
        guard collectorState == .idle, !marks.isEmpty else { return }
        message = nil
        collectorState = .countdown(secondsLeft: Self.countdownSeconds)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.countdownTick()
        }
    }

    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        if case .countdown = collectorState { collectorState = .idle }
    }

    private func countdownTick() {
        guard case .countdown(let left) = collectorState else { return }
        if left > 1 {
            collectorState = .countdown(secondsLeft: left - 1)
        } else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            trashMarkedItems()
        }
    }

    private func trashMarkedItems() {
        let paths = marks
        collectorState = .trashing
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var trashed: [String] = []
            for path in paths {
                if (try? FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)) != nil {
                    trashed.append(path)
                }
            }
            DispatchQueue.main.async { self?.finishTrashing(paths, trashed: trashed) }
        }
    }

    private func finishTrashing(_ paths: [String], trashed: [String]) {
        collectorState = .idle
        for path in trashed {
            for key in results.keys { results[key]?.dropDeleted(path: path) }
        }
        setMarks(marks.filter { !trashed.contains($0) })
        let failed = paths.count - trashed.count
        message = failed > 0 ? String(format: strings.trashFailedFormat, failed) : nil
        reloadSources()
    }

    func text(for refusal: DiskUsageRefusal) -> String {
        let manager = FileManager.default
        switch refusal {
        case .notAnItem: return strings.refuseSpace
        case .neededBySystem(let name): return String(format: strings.refuseSystemFormat, name)
        case .timeMachineBackup: return strings.refuseTimeMachine
        case .locked(let name): return String(format: strings.refuseLockedFormat, name)
        case .readOnlyFolder(let path): return String(format: strings.refuseFolderFormat, manager.displayName(atPath: path))
        case .readOnlyVolume(let path): return String(format: strings.refuseVolumeFormat, manager.displayName(atPath: path))
        }
    }

    /// The collector's items with the name and size the results know them by.
    var markedItems: [(path: String, name: String, size: UInt64)] {
        marks.map { path in
            for report in results.values {
                if let id = report.tree.node(coveredBy: path), report.tree.path(of: id) == path {
                    return (path, displayName(report, id), report.tree.nodes[id].size)
                }
            }
            return (path, (path as NSString).lastPathComponent, 0)
        }
    }

    var markedBytes: UInt64 { markedItems.reduce(0) { $0 + $1.size } }

    // MARK: Names

    /// Folders as the Finder names them in the system language, the scanned
    /// disk by its name, files as they are.
    func displayName(_ report: DiskUsageReport, _ id: Int) -> String {
        let node = report.tree.nodes[id]
        switch node.kind {
        case .hidden: return strings.hiddenSpace
        case .purgeable: return strings.purgeableSpace
        case .free: return strings.freeSpace
        case .file: return node.name
        case .directory:
            let path = report.tree.path(of: id)
            if let name = displayNames[path] { return name }
            let name = disks.first { $0.path == path }?.name ?? FileManager.default.displayName(atPath: path)
            displayNames[path] = name
            return name
        }
    }

    func displayName(ofPath path: String) -> String {
        if let disk = disks.first(where: { $0.path == path }) { return disk.name }
        return FileManager.default.displayName(atPath: path)
    }

    // MARK: Finder, Terminal and Quick Look

    func url(of id: Int) -> URL? {
        guard let report = openReport, report.tree.nodes[id].kind.isOnDisk else { return nil }
        return URL(fileURLWithPath: report.tree.path(of: id))
    }

    func showInFinder(_ id: Int) {
        guard let url = url(of: id) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens Terminal at the folder, or at the folder holding a file. Asks
    /// Terminal to open the folder like any document, so no Automation
    /// permission is involved.
    func openInTerminal(_ id: Int) {
        guard let report = openReport, var url = url(of: id) else { return }
        if report.tree.nodes[id].kind != .directory { url.deleteLastPathComponent() }
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
        NSWorkspace.shared.open([url], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }

    func quickLook(_ id: Int? = nil) {
        if let id { update { $0.selected = id } }
        window?.toggleQuickLook()
    }

    private func previewURL() -> URL? {
        pointedItem.flatMap(url(of:))
    }

    // MARK: Keys

    /// Window shortcuts. Returns whether the key was used.
    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command), shift = flags.contains(.shift)
        let key = event.charactersIgnoringModifiers ?? ""
        switch (key, command, shift) {
        case ("o", true, false):
            chooseFolder()
        case ("r", true, false):
            if let id = openReport?.current { rescanFolder(id) } else { return false }
        case ("r", true, true), ("R", true, true):
            rescanResult()
        case ("[", true, false):
            update { $0.goBack() }
        case ("]", true, false):
            update { $0.goForward() }
        case (" ", false, false):
            guard openReport != nil else { return false }
            quickLook()
        default:
            switch (Int(event.keyCode), command, shift) {
            case (126, true, false): update { $0.goUp() }
            case (126, true, true): showStartPage()
            case (51, true, false):
                guard let id = pointedItem else { return false }
                collect(id)
            default: return false
            }
        }
        return true
    }
}
