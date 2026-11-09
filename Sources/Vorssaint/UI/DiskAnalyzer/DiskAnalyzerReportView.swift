// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import SwiftUI

/// One result: the open folder's items in a list beside them as rings or
/// tiles, the path above and the collector below.
struct DiskAnalyzerReportView: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.diskAnalyzerViewMode) private var viewMode = "rings"
    let path: String

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }

    var body: some View {
        if let report = service.results[path] {
            VStack(spacing: 0) {
                toolbar(report)
                Divider()
                if showsAccessHint(report) { accessHint }
                HSplitView {
                    DiskAnalyzerItemList(report: report)
                        .frame(minWidth: 260, idealWidth: 330, maxWidth: 480)
                    chart(report)
                        .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                }
                Divider()
                DiskAnalyzerCollectorBar()
            }
        }
    }

    @ViewBuilder
    private func chart(_ report: DiskUsageReport) -> some View {
        if viewMode == "tiles" {
            DiskAnalyzerTileChart(report: report, hues: service.hues[path] ?? [])
        } else {
            DiskAnalyzerRingChart(report: report, hues: service.hues[path] ?? [])
        }
    }

    // MARK: Toolbar

    private func toolbar(_ report: DiskUsageReport) -> some View {
        HStack(spacing: 8) {
            ControlGroup {
                Button { service.update { $0.goBack() } } label: { Image(systemName: "chevron.left") }
                    .disabled(!report.canGoBack).help(strings.back)
                Button { service.update { $0.goForward() } } label: { Image(systemName: "chevron.right") }
                    .disabled(!report.canGoForward).help(strings.forward)
            }
            .fixedSize()
            Button { service.update { $0.goUp() } } label: { Image(systemName: "arrow.up") }
                .disabled(!report.canGoUp).help(strings.up)
            Button { service.showStartPage() } label: { Image(systemName: "house") }
                .help(strings.home)
            pathBar(report)
            Spacer(minLength: 8)
            Menu {
                Button(strings.rescan) { service.rescanResult() }
                Button(strings.rescanFolder) { service.rescanFolder(report.current) }
                    .disabled(report.current == report.tree.root)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(strings.rescan)
            .disabled(service.scan != nil)
            Picker("", selection: $viewMode) {
                Image(systemName: "chart.pie").help(strings.rings).tag("rings")
                Image(systemName: "square.grid.2x2").help(strings.tiles).tag("tiles")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func pathBar(_ report: DiskUsageReport) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                let chain = report.tree.chain(to: report.current)
                ForEach(Array(chain.enumerated()), id: \.element) { index, id in
                    if index > 0 {
                        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                    Button(service.displayName(report, id)) { service.update { $0.navigate(to: id) } }
                        .buttonStyle(.borderless)
                        .font(.system(size: 12, weight: id == report.current ? .semibold : .regular))
                        .foregroundStyle(id == report.current ? .primary : .secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: Full Disk Access

    private func showsAccessHint(_ report: DiskUsageReport) -> Bool {
        guard !permissions.fullDiskAccess else { return false }
        return report.tree.nodes[report.tree.root].children.contains {
            report.tree.nodes[$0].kind == .hidden && report.tree.nodes[$0].size > 0
        }
    }

    private var accessHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(strings.fullDiskAccessTitle).font(.system(size: 12, weight: .semibold))
                Text(strings.fullDiskAccessMessage).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(strings.openSettings) { Permissions.shared.openFullDiskAccessSettings() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.08))
    }
}

// MARK: - Item list

private struct DiskAnalyzerItemList: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var l10n = L10n.shared
    let report: DiskUsageReport
    @State private var showsSmaller = false
    @State private var hovered: Int?

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }

    var body: some View {
        let listing = report.listing(of: report.current)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(service.displayName(report, report.current))
                    .font(.system(size: 15, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                Text(DiskAnalyzerFormat.bytes(report.shownSize(report.current)))
                    .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
            }
            .padding(12)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(listing.items, id: \.self) { id in row(id) }
                    if !listing.smaller.isEmpty {
                        smallerRow(listing.smaller)
                        if showsSmaller {
                            ForEach(listing.smaller, id: \.self) { id in row(id, indent: true) }
                        }
                    }
                    if listing.items.isEmpty && listing.smaller.isEmpty {
                        Text(strings.emptyFolder).foregroundStyle(.secondary).padding(20)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onChange(of: report.current) { _, _ in showsSmaller = false }
    }

    private func row(_ id: Int, indent: Bool = false) -> some View {
        let node = report.tree.nodes[id]
        let collected = report.isCollected(id)
        let base = Double(max(1, report.sizes[report.current]))
        let share = Double(report.sizes[id]) / base
        let highlighted = hovered == id || report.selected == id
        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DiskAnalyzerPalette.color(for: id, in: report, hues: service.hues[service.openPath ?? ""] ?? []))
                .frame(width: 10, height: 10)
            Image(systemName: symbol(node))
                .font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 14)
            VStack(alignment: .leading, spacing: 3) {
                Text(service.displayName(report, id))
                    .font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                    .strikethrough(collected)
                    .foregroundStyle(collected ? .secondary : .primary)
                GeometryReader { geometry in
                    Capsule().fill(.quaternary)
                        .overlay(alignment: .leading) {
                            Capsule().fill(.secondary.opacity(0.6)).frame(width: geometry.size.width * min(1, share))
                        }
                }
                .frame(height: 3)
            }
            Text(DiskAnalyzerFormat.bytes(collected ? node.size : report.sizes[id]))
                .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                .strikethrough(collected)
        }
        .padding(.leading, indent ? 26 : 12)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .background(highlighted ? Color.accentColor.opacity(0.14) : Color.clear)
        .contentShape(Rectangle())
        .help(helpText(node))
        .onHover { inside in
            hovered = inside ? id : (hovered == id ? nil : hovered)
            service.hovered = inside ? id : (service.hovered == id ? nil : service.hovered)
        }
        .onTapGesture { service.activate(id) }
        .onDrag {
            NSItemProvider(object: report.tree.path(of: id) as NSString)
        }
        .contextMenu { DiskAnalyzerItemMenu(report: report, id: id) }
    }

    private func smallerRow(_ items: [Int]) -> some View {
        let total = items.reduce(UInt64(0)) { $0 + (report.isCollected($1) ? 0 : report.sizes[$1]) }
        return Button {
            showsSmaller.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showsSmaller ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold)).frame(width: 10)
                Text(String(format: strings.smallerItemsFormat, items.count)).font(.system(size: 12))
                Spacer()
                Text(DiskAnalyzerFormat.bytes(total)).font(.system(size: 11)).monospacedDigit()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func symbol(_ node: DiskUsageNode) -> String {
        switch node.kind {
        case .directory: return node.isPackage ? "shippingbox" : "folder"
        case .file: return "doc"
        case .hidden: return "eye.slash"
        case .purgeable: return "arrow.3.trianglepath"
        case .free: return "circle.dashed"
        }
    }

    private func helpText(_ node: DiskUsageNode) -> String {
        switch node.kind {
        case .hidden: return strings.hiddenHelp
        case .purgeable: return strings.purgeableHelp
        default: return ""
        }
    }
}

/// The actions for one item, shared by the list and the charts.
struct DiskAnalyzerItemMenu: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var l10n = L10n.shared
    let report: DiskUsageReport
    let id: Int

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }

    var body: some View {
        let node = report.tree.nodes[id]
        if node.kind.isOnDisk {
            Button(strings.showInFinder) { service.showInFinder(id) }
            Button(strings.openInTerminal) { service.openInTerminal(id) }
            Button(strings.quickLook) { service.quickLook(id) }
            Divider()
            if node.isPackage && node.kind == .directory && !report.expanded.contains(id) && !node.children.isEmpty {
                Button(strings.showPackageContents) { service.update { $0.openPackage(id) } }
            }
            if node.kind == .directory {
                Button(strings.rescanFolder) { service.rescanFolder(id) }
                    .disabled(service.scan != nil)
            }
            Divider()
            if report.isCollected(id) {
                Button(strings.removeFromCollector) { service.uncollect(id) }
            } else {
                Button(strings.addToCollector) { service.collect(id) }
            }
        }
    }
}

// MARK: - Collector

private struct DiskAnalyzerCollectorBar: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var isTargeted = false

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "tray.full").foregroundStyle(.secondary)
                Text(strings.collector).font(.system(size: 12, weight: .semibold))
                if service.marks.isEmpty {
                    Text(strings.collectorHint).font(.system(size: 12)).foregroundStyle(.secondary)
                } else {
                    Text(String(format: strings.itemsFormat, service.marks.count,
                                DiskAnalyzerFormat.bytes(service.markedBytes)))
                        .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer()
                controls
            }
            if !service.marks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(service.markedItems, id: \.path) { item in chip(item) }
                    }
                }
            }
            if let message = service.message {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isTargeted ? Color.accentColor.opacity(0.12) : Color.clear)
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard let path = object as? String else { return }
                    DispatchQueue.main.async { service.collect(path: path) }
                }
            }
            return true
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch service.collectorState {
        case .idle:
            if !service.marks.isEmpty {
                Button(strings.removeAll) { service.clearCollector() }
                Button(role: .destructive) {
                    service.startCountdown()
                } label: {
                    Label(strings.moveToTrash, systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        case .countdown(let left):
            Text(String(format: strings.countdownFormat, left))
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.red).monospacedDigit()
            Button(strings.stop) { service.stopCountdown() }
                .keyboardShortcut(.cancelAction)
        case .trashing:
            ProgressView().controlSize(.small)
        }
    }

    private func chip(_ item: (path: String, name: String, size: UInt64)) -> some View {
        HStack(spacing: 4) {
            Text(item.name).lineLimit(1).truncationMode(.middle).frame(maxWidth: 180, alignment: .leading)
            Text(DiskAnalyzerFormat.bytes(item.size)).foregroundStyle(.secondary).monospacedDigit()
            Button {
                service.uncollect(path: item.path)
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(service.collectorState != .idle)
            .help(strings.removeFromCollector)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(.quaternary))
        .help(item.path)
    }
}
