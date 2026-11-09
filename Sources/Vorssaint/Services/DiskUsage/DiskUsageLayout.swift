// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import CoreGraphics
import Foundation

/// What a ring segment or tile stands for.
enum DiskUsageChartItem: Hashable {
    case node(Int)
    /// The grouped smaller items of this folder.
    case smaller(Int)
    /// The open folder has nothing to draw.
    case empty
}

/// The open folder as rings around a centre disc: each ring holds the items
/// one level deeper, every item spanning its share of its folder's angle.
enum DiskUsageRingLayout {
    struct Segment: Equatable {
        var item: DiskUsageChartItem
        /// 1 is the ring around the centre.
        var ring: Int
        /// Start and span as fractions of the full circle, clockwise from 12 o'clock.
        var start: Double
        var span: Double
    }

    static let ringCount = 6
    /// Radius of the centre disc, as a share of the outer radius.
    static let centreShare = 0.3
    /// Relative ring widths, inside out: deep rings are thinner.
    private static let ringWeights: [Double] = [1.0, 0.9, 0.8, 0.7, 0.6, 0.5]

    /// Inner and outer radius of `ring` (1-based) as shares of the outer radius.
    static func bounds(ofRing ring: Int) -> (inner: Double, outer: Double) {
        let total = ringWeights.reduce(0, +)
        let before = ringWeights.prefix(max(0, ring - 1)).reduce(0, +)
        let width = ringWeights[min(ringWeights.count, max(1, ring)) - 1]
        let scale = (1 - centreShare) / total
        return (centreShare + before * scale, centreShare + (before + width) * scale)
    }

    static func segments(of report: DiskUsageReport) -> [Segment] {
        var segments: [Segment] = []
        let base = Double(max(1, report.sizes[report.current]))
        build(report, folder: report.current, ring: 1, start: 0, span: 1, base: base, into: &segments)
        return segments.isEmpty ? [Segment(item: .empty, ring: 1, start: 0, span: 1)] : segments
    }

    @discardableResult
    private static func build(_ report: DiskUsageReport, folder: Int, ring: Int, start: Double, span: Double,
                              base: Double, into segments: inout [Segment]) -> Bool {
        guard ring <= ringCount else { return false }
        let tree = report.tree
        let folderSize = Double(max(1, report.sizes[folder]))
        var position = start
        var smaller = 0.0
        var drewAny = false
        for child in tree.nodes[folder].children {
            let size = report.sizes[child]
            guard size > 0, !report.isCollected(child) else { continue }
            let childSpan = span * Double(size) / folderSize
            if Double(size) / base < DiskUsageReport.minimumShare {
                smaller += childSpan
                continue
            }
            segments.append(Segment(item: .node(child), ring: ring, start: position, span: childSpan))
            drewAny = true
            if report.showsContents(of: child) {
                build(report, folder: child, ring: ring + 1, start: position, span: childSpan, base: base,
                      into: &segments)
            }
            position += childSpan
        }
        // Deeper rings only group when something else of the folder shows.
        if smaller >= DiskUsageReport.minimumShare, ring == 1 || drewAny {
            segments.append(Segment(item: .smaller(folder), ring: ring, start: position, span: smaller))
            drewAny = true
        }
        return drewAny
    }

    /// The segment at a point given as distance from the centre (a share of
    /// the outer radius) and angle (a fraction of the circle from 12 o'clock).
    static func hit(_ segments: [Segment], radius: Double, angle: Double) -> Segment? {
        guard radius >= centreShare, radius <= 1 else { return nil }
        let ring = (1...ringCount).first { bounds(ofRing: $0).outer >= radius } ?? ringCount
        return segments.first { $0.ring == ring && angle >= $0.start && angle < $0.start + $0.span }
    }

    /// Colour position of every folder: its hue is the middle of its span in
    /// the scanned root, so a folder keeps its colour while you move around.
    static func hues(of tree: DiskUsageTree) -> [Double] {
        var hues = [Double](repeating: 0, count: tree.nodes.count)
        let free = Double(tree.freeBytes(under: tree.root))
        let used = max(1, Double(tree.rootSize) - free)
        func walk(_ folder: Int, start: Double) {
            var position = start
            for child in tree.nodes[folder].children where tree.nodes[child].kind != .free {
                let share = Double(tree.nodes[child].size) / used
                hues[child] = (position + share / 2).truncatingRemainder(dividingBy: 1)
                if tree.nodes[child].kind == .directory { walk(child, start: position) }
                position += share
            }
        }
        walk(tree.root, start: 0)
        return hues
    }
}

/// The open folder as nested tiles whose areas are exactly the items' shares.
enum DiskUsageTileLayout {
    struct Tile: Equatable {
        var item: DiskUsageChartItem
        var rect: CGRect
        var size: UInt64
        /// Smaller tiles lie inside it; only its header strip is its own.
        var isNested: Bool
        /// 1 for the open folder's own items, one more for each folder around it.
        var depth = 1
        /// How many items a group of smaller items holds.
        var count = 1
    }

    /// Items whose tile would be smaller than this (square points) are grouped.
    static let minimumTileArea = 400.0
    static let nestMinimumSize = CGSize(width: 60, height: 44)
    static let nestMaximumDepth = 4
    static let headerHeight: CGFloat = 18
    static let nestMargin: CGFloat = 2

    /// The tiles of the open folder inside `area`, each folder before its contents.
    static func tiles(of report: DiskUsageReport, in area: CGRect) -> [Tile] {
        var tiles: [Tile] = []
        build(report, folder: report.current, area: area, depth: 0, into: &tiles)
        return tiles.isEmpty ? [Tile(item: .empty, rect: area, size: 0, isNested: false)] : tiles
    }

    private static func build(_ report: DiskUsageReport, folder: Int, area: CGRect, depth: Int,
                              into tiles: inout [Tile]) {
        let tree = report.tree
        let shown = tree.nodes[folder].children.filter {
            report.sizes[$0] > 0 && !report.isCollected($0) && tree.nodes[$0].kind != .free
        }
        let total = shown.reduce(0.0) { $0 + Double(report.sizes[$1]) }
        guard total > 0, area.width > 0, area.height > 0 else { return }
        let pointsPerByte = Double(area.width * area.height) / total
        var items: [(item: DiskUsageChartItem, size: Double)] = []
        var smaller = 0.0
        var smallerCount = 0
        for child in shown {
            let size = Double(report.sizes[child])
            if size * pointsPerByte < minimumTileArea {
                smaller += size
                smallerCount += 1
            } else {
                items.append((.node(child), size))
            }
        }
        if smaller > 0 { items.append((.smaller(folder), smaller)) }
        items.sort { $0.size > $1.size }
        let rects = squarify(items.map(\.size), in: area)
        for (entry, rect) in zip(items, rects) {
            var nestedFolder: Int?
            if case .node(let child) = entry.item, report.showsContents(of: child),
               !tree.nodes[child].children.isEmpty, depth + 1 < nestMaximumDepth,
               rect.width >= nestMinimumSize.width, rect.height >= nestMinimumSize.height {
                nestedFolder = child
            }
            tiles.append(Tile(item: entry.item, rect: rect, size: UInt64(entry.size), isNested: nestedFolder != nil,
                              depth: depth + 1, count: entry.item == .smaller(folder) ? smallerCount : 1))
            if let nestedFolder {
                let inner = CGRect(x: rect.minX + nestMargin, y: rect.minY + headerHeight,
                                   width: rect.width - 2 * nestMargin, height: rect.height - headerHeight - nestMargin)
                build(report, folder: nestedFolder, area: inner, depth: depth + 1, into: &tiles)
            }
        }
    }

    /// Lays out `values` (biggest first) in `area`, each with its share of the
    /// area and shapes as close to square as possible (squarified treemap).
    static func squarify(_ values: [Double], in area: CGRect) -> [CGRect] {
        let total = values.reduce(0, +)
        guard total > 0, area.width > 0, area.height > 0 else {
            return Array(repeating: CGRect(origin: area.origin, size: .zero), count: values.count)
        }
        let unit = Double(area.width * area.height) / total
        let scaled = values.map { $0 * unit }
        var x = Double(area.minX), y = Double(area.minY)
        var width = Double(area.width), height = Double(area.height)
        var result: [CGRect] = []
        result.reserveCapacity(values.count)
        var first = 0
        while first < scaled.count {
            let side = max(1e-6, min(width, height))
            func worst(_ sum: Double, _ largest: Double, _ smallest: Double) -> Double {
                let sumSquared = sum * sum, sideSquared = side * side
                return max(sideSquared * largest / sumSquared, sumSquared / (sideSquared * max(1e-9, smallest)))
            }
            var last = first
            var sum = 0.0
            var best = Double.infinity
            while last < scaled.count {
                let next = sum + scaled[last]
                let ratio = worst(next, scaled[first], scaled[last])
                if last > first, ratio > best { break }
                best = ratio
                sum = next
                last += 1
            }
            if width >= height {
                let column = height > 0 ? sum / height : 0
                var top = y
                for value in scaled[first..<last] {
                    let cell = column > 0 ? value / column : 0
                    result.append(CGRect(x: x, y: top, width: column, height: cell))
                    top += cell
                }
                x += column
                width = max(0, width - column)
            } else {
                let row = width > 0 ? sum / width : 0
                var left = x
                for value in scaled[first..<last] {
                    let cell = row > 0 ? value / row : 0
                    result.append(CGRect(x: left, y: y, width: cell, height: row))
                    left += cell
                }
                y += row
                height = max(0, height - row)
            }
            first = last
        }
        return result
    }

    /// The deepest tile under a point: later tiles lie on top of earlier ones.
    static func hit(_ tiles: [Tile], at point: CGPoint) -> Tile? {
        tiles.last { $0.rect.contains(point) }
    }
}
