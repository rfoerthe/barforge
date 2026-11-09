// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Why an item cannot go to the collector. The interface words it.
enum DiskUsageRefusal: Equatable {
    /// Free, hidden or purgeable space, or the scanned folder itself.
    case notAnItem
    case neededBySystem(name: String)
    case timeMachineBackup
    case locked(name: String)
    case readOnlyFolder(path: String)
    case readOnlyVolume(path: String)
}

/// One scan result as the window shows it: which folder is open, the way
/// back and forward, opened packages, and the items in the collector. Sizes
/// leave out what sits in the collector, so the folders above it shrink.
struct DiskUsageReport {
    private(set) var tree: DiskUsageTree
    /// Node sizes without the collected items below them.
    private(set) var sizes: [UInt64]
    private(set) var current: Int
    private(set) var history: [Int]
    private(set) var historyIndex = 0
    /// Packages opened to show their contents.
    private(set) var expanded: Set<Int> = []
    /// Collected nodes, in the order the marks name them.
    private(set) var collected: [Int] = []
    private var collectedSet: Set<Int> = []
    var selected: Int?

    /// Items smaller than this share of the shown folder are grouped.
    static let minimumShare = 1.0 / 200

    init(tree: DiskUsageTree) {
        self.tree = tree
        sizes = tree.nodes.map(\.size)
        current = tree.root
        history = [tree.root]
    }

    // MARK: Collector

    /// Whether the item or a folder above it is in the collector.
    func isCollected(_ id: Int) -> Bool {
        guard !collectedSet.isEmpty else { return false }
        var node: Int? = id
        while let candidate = node {
            if collectedSet.contains(candidate) { return true }
            node = tree.nodes[candidate].parent
        }
        return false
    }

    /// Takes over the collector's marks: the items of this result that the
    /// marked paths cover. The open folder moves up out of a collected one.
    mutating func apply(marks: [String]) {
        var ids: [Int] = []
        for mark in marks {
            if let id = tree.node(coveredBy: mark), !ids.contains(id) { ids.append(id) }
        }
        guard ids != collected else { return }
        collected = ids
        collectedSet = Set(ids)
        recomputeSizes()
        while isCollected(current), let parent = tree.nodes[current].parent {
            navigate(to: parent)
        }
        if let selected, isCollected(selected) { self.selected = nil }
    }

    /// What may keep an item out of the collector, checked on disk.
    func refusal(for id: Int,
                 isSystemPath: (String) -> Bool = { DiskUsageSupport.isSystemPath($0) },
                 readOnlyReason: (String) -> DiskUsageReadOnlyReason? = DiskUsageSupport.readOnlyReason(for:))
        -> DiskUsageRefusal? {
        let node = tree.nodes[id]
        guard id != tree.root, node.kind.isOnDisk, !node.isRemoved else { return .notAnItem }
        let path = tree.path(of: id)
        if isSystemPath(path) { return .neededBySystem(name: node.name) }
        if path.contains("Backups.backupdb/") || path.hasSuffix("Backups.backupdb") { return .timeMachineBackup }
        switch readOnlyReason(path) {
        case .item: return .locked(name: node.name)
        case .folder(let folder): return .readOnlyFolder(path: folder)
        case .volume(let volume): return .readOnlyVolume(path: volume)
        case nil: return nil
        }
    }

    /// Total of the collected items.
    var collectedBytes: UInt64 {
        collected.reduce(0) { $0 + tree.nodes[$1].size }
    }

    // MARK: Navigation

    mutating func navigate(to id: Int) {
        guard id != current, tree.nodes.indices.contains(id) else { return }
        history.removeSubrange((historyIndex + 1)...)
        history.append(id)
        historyIndex = history.count - 1
        current = id
        selected = nil
    }

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex + 1 < history.count }
    var canGoUp: Bool { tree.nodes[current].parent != nil }

    mutating func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        current = history[historyIndex]
        selected = nil
    }

    mutating func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        current = history[historyIndex]
        selected = nil
    }

    mutating func goUp() {
        if let parent = tree.nodes[current].parent { navigate(to: parent) }
    }

    /// Clicking opens a folder; files, closed packages and collected items are selected instead.
    func canOpen(_ id: Int) -> Bool {
        let node = tree.nodes[id]
        return node.kind == .directory && !node.children.isEmpty
            && (!node.isPackage || expanded.contains(id)) && !isCollected(id)
    }

    /// Whether the charts follow a folder into its contents.
    func showsContents(of id: Int) -> Bool {
        let node = tree.nodes[id]
        return node.kind == .directory && (!node.isPackage || expanded.contains(id))
    }

    mutating func openPackage(_ id: Int) {
        expanded.insert(id)
        navigate(to: id)
    }

    // MARK: Sizes and listings

    /// The size shown for a folder: a scanned volume's root leaves out its free space.
    func shownSize(_ id: Int) -> UInt64 {
        let free = tree.freeBytes(under: id)
        return sizes[id] - min(sizes[id], free)
    }

    /// The items of `folder`, split as the charts split them: those below
    /// `minimumShare` of the open folder are the smaller items. Collected
    /// items stay listed so they can be shown crossed out.
    func listing(of folder: Int) -> (items: [Int], smaller: [Int]) {
        let base = Double(max(1, sizes[current]))
        var items: [Int] = []
        var smaller: [Int] = []
        for child in tree.nodes[folder].children {
            let node = tree.nodes[child]
            if !isCollected(child), sizes[child] == 0, node.kind != .directory { continue }
            if node.kind.isOnDisk, Double(sizes[child]) / base < Self.minimumShare {
                smaller.append(child)
            } else {
                items.append(child)
            }
        }
        return (items, smaller)
    }

    // MARK: Changes on disk

    /// An item left the disk: it leaves this result too.
    mutating func dropDeleted(path: String) {
        guard let id = tree.node(coveredBy: path) else { return }
        if id == tree.root {
            tree.emptyRoot()
            current = id
        } else {
            tree.remove(id)
        }
        collected.removeAll { tree.nodes[$0].isRemoved || $0 == id }
        collectedSet = Set(collected)
        if tree.nodes[current].isRemoved { navigate(to: tree.root) }
        if let selected, tree.nodes[selected].isRemoved { self.selected = nil }
        recomputeSizes()
    }

    /// Puts a fresh scan of folder `id` in place of its old contents.
    mutating func graft(_ fresh: DiskUsageTree, into id: Int) {
        tree.graft(fresh, into: id)
        collected.removeAll { tree.nodes[$0].isRemoved }
        collectedSet = Set(collected)
        expanded = expanded.filter { !tree.nodes[$0].isRemoved }
        selected = nil
        history = history.filter { !tree.nodes[$0].isRemoved }
        if history.isEmpty { history = [tree.root] }
        historyIndex = min(historyIndex, history.count - 1)
        if tree.nodes[current].isRemoved { current = id }
        recomputeSizes()
    }

    private mutating func recomputeSizes() {
        sizes = tree.nodes.map(\.size)
        for id in collected {
            let size = tree.nodes[id].size
            var parent = tree.nodes[id].parent
            while let folder = parent {
                sizes[folder] -= min(sizes[folder], size)
                parent = tree.nodes[folder].parent
            }
        }
    }
}

/// The collector's marks: paths in the order they were added. A mark
/// replaces the marks inside it and is ignored when one above it exists.
enum DiskUsageMarks {
    static func adding(_ path: String, to marks: [String]) -> [String] {
        if marks.contains(where: { DiskUsageTree.path(path, isInsideOrEqualTo: $0) }) { return marks }
        return marks.filter { !DiskUsageTree.path($0, isInsideOrEqualTo: path) } + [path]
    }
}
