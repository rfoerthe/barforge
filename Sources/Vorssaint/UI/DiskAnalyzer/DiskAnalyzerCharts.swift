// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import SwiftUI

/// Colours shared by the list and both charts. A folder's hue is its place
/// in the scanned root; deeper folders are paler, files are grey.
enum DiskAnalyzerPalette {
    static let file = Color(white: 0.62)
    static let smaller = Color(white: 0.62).opacity(0.35)
    static let free = Color(white: 0.78).opacity(0.45)
    static let hidden = Color(red: 0.74, green: 0.58, blue: 0.86)
    static let purgeable = Color(red: 0.86, green: 0.66, blue: 0.86)

    static func color(for id: Int, in report: DiskUsageReport, hues: [Double], depth: Int? = nil) -> Color {
        let node = report.tree.nodes[id]
        switch node.kind {
        case .file: return file
        case .free: return free
        case .hidden: return hidden
        case .purgeable: return purgeable
        case .directory:
            let level = depth ?? max(1, report.tree.chain(to: id).count - report.tree.chain(to: report.current).count)
            let hue = hues.indices.contains(id) ? hues[id] : 0.6
            return Color(hue: hue, saturation: max(0.18, 0.62 - 0.07 * Double(level - 1)), brightness: 0.9)
        }
    }

    static func color(for item: DiskUsageChartItem, in report: DiskUsageReport, hues: [Double], depth: Int) -> Color {
        switch item {
        case .node(let id): return color(for: id, in: report, hues: hues, depth: depth)
        case .smaller: return smaller
        case .empty: return free
        }
    }
}

/// What the centre of the rings or the caption under the tiles describes.
private struct DiskAnalyzerChartCaption: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var l10n = L10n.shared
    let report: DiskUsageReport
    let item: DiskUsageChartItem?

    var body: some View {
        let strings = FeatureStrings.diskAnalyzer(l10n.language)
        let (title, size): (String, UInt64) = {
            switch item {
            case .node(let id): return (service.displayName(report, id), report.sizes[id])
            case .smaller(let folder):
                let smaller = report.listing(of: folder).smaller
                return (String(format: strings.smallerItemsFormat, smaller.count),
                        smaller.reduce(0) { $0 + (report.isCollected($1) ? 0 : report.sizes[$1]) })
            case .empty, nil:
                return (service.displayName(report, report.current), report.shownSize(report.current))
            }
        }()
        VStack(spacing: 2) {
            Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
                .truncationMode(.middle)
            Text(DiskAnalyzerFormat.bytes(size)).font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}

// MARK: - Rings

struct DiskAnalyzerRingChart: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    let report: DiskUsageReport
    let hues: [Double]
    @State private var hovered: DiskUsageChartItem?
    @State private var menuItem: Int?

    var body: some View {
        let segments = DiskUsageRingLayout.segments(of: report)
        GeometryReader { geometry in
            let radius = max(10, min(geometry.size.width, geometry.size.height) / 2 - 16)
            let centre = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                Canvas { context, _ in
                    for segment in segments { draw(segment, in: &context, centre: centre, radius: radius) }
                    let disc = Path(ellipseIn: CGRect(x: centre.x - radius * DiskUsageRingLayout.centreShare,
                                                      y: centre.y - radius * DiskUsageRingLayout.centreShare,
                                                      width: 2 * radius * DiskUsageRingLayout.centreShare,
                                                      height: 2 * radius * DiskUsageRingLayout.centreShare))
                    context.fill(disc, with: .color(Color(nsColor: .windowBackgroundColor)))
                    context.stroke(disc, with: .color(.secondary.opacity(0.25)), lineWidth: 1)
                }
                DiskAnalyzerChartCaption(report: report, item: hovered)
                    .frame(width: radius * DiskUsageRingLayout.centreShare * 1.7)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    let item = item(at: point, segments: segments, centre: centre, radius: radius)
                    if item != hovered { hovered = item }
                    if case .node(let id) = item { service.hovered = id } else { service.hovered = nil }
                case .ended:
                    hovered = nil
                    service.hovered = nil
                }
            }
            .gesture(SpatialTapGesture().onEnded { value in
                let distance = hypot(value.location.x - centre.x, value.location.y - centre.y) / radius
                if distance < DiskUsageRingLayout.centreShare {
                    service.update { $0.goUp() }
                } else if case .node(let id) = item(at: value.location, segments: segments, centre: centre, radius: radius) {
                    service.activate(id)
                }
            })
            .contextMenu {
                if let id = service.hovered { DiskAnalyzerItemMenu(report: report, id: id) }
            }
        }
        .padding(8)
        .onChange(of: report.current) { _, _ in hovered = nil }
    }

    private func item(at point: CGPoint, segments: [DiskUsageRingLayout.Segment],
                      centre: CGPoint, radius: CGFloat) -> DiskUsageChartItem? {
        let dx = point.x - centre.x, dy = point.y - centre.y
        let distance = hypot(dx, dy) / radius
        var angle = atan2(dx, -dy) / (2 * .pi)
        if angle < 0 { angle += 1 }
        return DiskUsageRingLayout.hit(segments, radius: distance, angle: angle)?.item
    }

    private func draw(_ segment: DiskUsageRingLayout.Segment, in context: inout GraphicsContext,
                      centre: CGPoint, radius: CGFloat) {
        let bounds = DiskUsageRingLayout.bounds(ofRing: segment.ring)
        let isHovered = hovered == segment.item
        let swell: CGFloat = isHovered ? 3 : 0
        let inner = radius * bounds.inner + 1 - swell
        let outer = radius * bounds.outer - 1 + swell
        // A hairline gap between neighbours, unless the segment is too thin to keep one.
        let gap = min(0.5 / max(1, Double(outer)) / (2 * .pi), segment.span / 4)
        let start = Angle(radians: (segment.start + gap) * 2 * .pi - .pi / 2)
        let end = Angle(radians: (segment.start + segment.span - gap) * 2 * .pi - .pi / 2)
        var path = Path()
        if segment.span >= 0.9999 {
            path.addEllipse(in: CGRect(x: centre.x - outer, y: centre.y - outer, width: 2 * outer, height: 2 * outer))
            path.addEllipse(in: CGRect(x: centre.x - inner, y: centre.y - inner, width: 2 * inner, height: 2 * inner))
        } else {
            path.addArc(center: centre, radius: outer, startAngle: start, endAngle: end, clockwise: false)
            path.addArc(center: centre, radius: inner, startAngle: end, endAngle: start, clockwise: true)
            path.closeSubpath()
        }
        var color = DiskAnalyzerPalette.color(for: segment.item, in: report, hues: hues, depth: segment.ring)
        if case .node(let id) = segment.item, report.selected == id { color = color.opacity(0.75) }
        context.fill(path, with: .color(color), style: FillStyle(eoFill: true))
        if isHovered {
            context.stroke(path, with: .color(.primary.opacity(0.5)), lineWidth: 1)
        }
    }
}

// MARK: - Tiles

struct DiskAnalyzerTileChart: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    let report: DiskUsageReport
    let hues: [Double]
    @State private var hovered: DiskUsageChartItem?

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let area = CGRect(origin: .zero, size: geometry.size)
                let tiles = DiskUsageTileLayout.tiles(of: report, in: area)
                Canvas { context, _ in
                    for tile in tiles { draw(tile, in: &context) }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        let item = DiskUsageTileLayout.hit(tiles, at: point)?.item
                        if item != hovered { hovered = item }
                        if case .node(let id) = item { service.hovered = id } else { service.hovered = nil }
                    case .ended:
                        hovered = nil
                        service.hovered = nil
                    }
                }
                .gesture(SpatialTapGesture().onEnded { value in
                    if case .node(let id) = DiskUsageTileLayout.hit(tiles, at: value.location)?.item {
                        service.activate(id)
                    }
                })
                .contextMenu {
                    if let id = service.hovered { DiskAnalyzerItemMenu(report: report, id: id) }
                }
            }
            DiskAnalyzerChartCaption(report: report, item: hovered)
        }
        .padding(10)
        .onChange(of: report.current) { _, _ in hovered = nil }
    }

    private func draw(_ tile: DiskUsageTileLayout.Tile, in context: inout GraphicsContext) {
        let rect = tile.rect.insetBy(dx: 0.5, dy: 0.5)
        guard rect.width > 0, rect.height > 0 else { return }
        let shape = Path(roundedRect: rect, cornerRadius: 2)
        var color = DiskAnalyzerPalette.color(for: tile.item, in: report, hues: hues, depth: tile.depth)
        if case .smaller = tile.item {
            // Opaque, so the folder around it does not show through.
            color = Color(white: 0.5)
        }
        if hovered == tile.item { color = color.opacity(0.75) }
        context.fill(shape, with: .color(color))
        if hovered == tile.item {
            context.stroke(shape, with: .color(.primary.opacity(0.6)), lineWidth: 1.5)
        }
        guard rect.width >= 28, rect.height >= 15 else { return }
        let title: String
        switch tile.item {
        case .node(let id): title = service.displayName(report, id)
        case .smaller:
            title = String(format: FeatureStrings.diskAnalyzer(L10n.shared.language).smallerItemsFormat, tile.count)
        case .empty: return
        }
        let label = context.resolve(Text(title)
            .font(.system(size: 11, weight: tile.isNested ? .semibold : .regular))
            .foregroundColor(Color.black.opacity(0.78)))
        // One line from the top left, cut off at the tile's edge.
        context.drawLayer { layer in
            layer.clip(to: Path(rect.insetBy(dx: 3, dy: 1)))
            layer.draw(label, at: CGPoint(x: rect.minX + 4, y: rect.minY + 2), anchor: .topLeading)
        }
    }
}
