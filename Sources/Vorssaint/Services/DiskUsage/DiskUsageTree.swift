// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// One item of a disk usage scan. Folders have no size of their own: theirs
/// is the sum of what they hold, after shared data was counted once.
struct DiskUsageNode: Equatable {
    enum Kind: Equatable {
        case directory
        case file
        /// Free space of the scanned volume.
        case free
        /// Space the volume reports as used that the scan could not reach.
        case hidden
        /// Space macOS can reclaim on its own (caches, local snapshots).
        case purgeable

        /// Files and folders exist on disk; the other kinds only describe the volume.
        var isOnDisk: Bool { self == .directory || self == .file }
    }

    /// The item's file name. Volume entries (free, hidden, purgeable) have
    /// none; the interface names them from their kind.
    var name: String
    var size: UInt64
    var kind: Kind
    var parent: Int?
    /// Children, biggest first; volume entries follow the folder's own items.
    var children: [Int]
    /// Deleted on disk or replaced by a rescan. Kept in the array so indices stay valid.
    var isRemoved = false
    /// A package (app, bundle, `.git` …) that is shown as one item until opened.
    var isPackage = false
}

/// The result of one scan: a flat node array in which every node's parent
/// precedes it. The root is always index 0.
struct DiskUsageTree: Equatable {
    var nodes: [DiskUsageNode]
    /// The scanned folder or volume mount point.
    var rootPath: String
    /// Total capacity of the volume when a whole volume was scanned.
    var volumeCapacity: UInt64?

    let root = 0

    var rootSize: UInt64 { nodes[root].size }

    /// Free space directly under `id` (only a scanned volume's root has any).
    func freeBytes(under id: Int) -> UInt64 {
        nodes[id].children.reduce(0) { total, child in
            nodes[child].kind == .free ? total + nodes[child].size : total
        }
    }

    /// The file system path of a file or folder node.
    func path(of id: Int) -> String {
        var parts: [String] = []
        var current: Int? = id
        while let node = current, node != root {
            parts.append(nodes[node].name)
            current = nodes[node].parent
        }
        return parts.reversed().reduce(rootPath) { path, part in
            path.hasSuffix("/") ? path + part : path + "/" + part
        }
    }

    /// Ancestors from the root down to `id`, both included.
    func chain(to id: Int) -> [Int] {
        var result = [id]
        var current = nodes[id].parent
        while let node = current {
            result.append(node)
            current = nodes[node].parent
        }
        return result.reversed()
    }

    func isAncestorOrSelf(_ ancestor: Int, of id: Int) -> Bool {
        var current: Int? = id
        while let node = current {
            if node == ancestor { return true }
            current = nodes[node].parent
        }
        return false
    }

    /// The node a mark on `path` covers in this result: the item at that path,
    /// or the root when the mark is on the scanned folder or a folder above it.
    func node(coveredBy path: String) -> Int? {
        if Self.path(rootPath, isInsideOrEqualTo: path) { return root }
        guard Self.path(path, isInsideOrEqualTo: rootPath) else { return nil }
        let relative = path.dropFirst(rootPath.count).split(separator: "/")
        var current = root
        for part in relative {
            guard let match = nodes[current].children.first(where: { child in
                let node = nodes[child]
                return !node.isRemoved && node.kind.isOnDisk && node.name == part
            }) else { return nil }
            current = match
        }
        return current
    }

    /// Removes an item that was deleted on disk and shrinks the folders above it.
    mutating func remove(_ id: Int) {
        guard id != root, !nodes[id].isRemoved else { return }
        let size = nodes[id].size
        markRemoved(id)
        if let parent = nodes[id].parent {
            nodes[parent].children.removeAll { $0 == id }
        }
        var current = nodes[id].parent
        while let node = current {
            nodes[node].size -= min(nodes[node].size, size)
            current = nodes[node].parent
        }
    }

    /// The scanned folder itself was deleted: nothing remains below the root.
    mutating func emptyRoot() {
        for child in nodes[root].children { markRemoved(child) }
        nodes[root].children = []
        nodes[root].size = 0
    }

    /// Replaces the contents of folder `id` with a fresh scan of that folder.
    /// The old children stay in the array as removed nodes, the new ones are
    /// appended, and every folder above changes by the difference.
    mutating func graft(_ fresh: DiskUsageTree, into id: Int) {
        for child in nodes[id].children { markRemoved(child) }
        let base = nodes.count
        func map(_ index: Int) -> Int { index == fresh.root ? id : base + index - 1 }
        let oldSize = nodes[id].size
        let newSize = fresh.rootSize
        for index in fresh.nodes.indices where index != fresh.root {
            var node = fresh.nodes[index]
            node.parent = node.parent.map(map)
            node.children = node.children.map(map)
            nodes.append(node)
        }
        nodes[id].children = fresh.nodes[fresh.root].children.map(map)
        nodes[id].size = newSize
        var current = nodes[id].parent
        while let node = current {
            let grown = nodes[node].size + newSize
            nodes[node].size = grown - min(grown, oldSize)
            current = nodes[node].parent
        }
    }

    private mutating func markRemoved(_ id: Int) {
        var stack = [id]
        while let node = stack.popLast() {
            nodes[node].isRemoved = true
            stack.append(contentsOf: nodes[node].children)
        }
    }

    /// Whether `path` is `container` or lies inside it, by whole path components.
    static func path(_ path: String, isInsideOrEqualTo container: String) -> Bool {
        if path == container || container == "/" { return path.hasPrefix("/") }
        return path.hasPrefix(container) && path.dropFirst(container.count).first == "/"
    }
}
