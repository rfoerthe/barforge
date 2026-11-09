// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import SwiftUI

enum DiskAnalyzerFormat {
    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    static func bytes(_ bytes: UInt64) -> String {
        formatter.string(fromByteCount: Int64(min(bytes, UInt64(Int64.max))))
    }

    static func count(_ value: UInt64) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
}

/// The window's content: the start page, a running scan or a result.
struct DiskAnalyzerView: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Group {
            switch service.page {
            case .start: DiskAnalyzerStartView()
            case .scanning(let path): DiskAnalyzerScanningView(path: path)
            case .report(let path): DiskAnalyzerReportView(path: path)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

// MARK: - Start page

private struct DiskAnalyzerStartView: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var l10n = L10n.shared

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strings.title).font(.title2.weight(.semibold))
                        Text(strings.panelCaption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        service.chooseFolder()
                    } label: {
                        Label(strings.scanFolder, systemImage: "folder.badge.plus")
                    }
                    .keyboardShortcut("o", modifiers: .command)
                    .disabled(service.scan != nil)
                }
                section(strings.disks) {
                    ForEach(service.disks) { disk in
                        DiskAnalyzerSourceRow(path: disk.path, title: disk.name,
                                              symbol: disk.isInternal ? "internaldrive" : "externaldrive",
                                              disk: disk)
                    }
                }
                if !service.folders.isEmpty {
                    section(strings.folders) {
                        ForEach(service.folders) { folder in
                            DiskAnalyzerSourceRow(path: folder.path,
                                                  title: service.displayName(ofPath: folder.path),
                                                  symbol: "folder", folder: folder)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
        }
    }
}

private struct DiskAnalyzerSourceRow: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var l10n = L10n.shared
    let path: String
    let title: String
    let symbol: String
    var disk: DiskAnalyzerDisk?
    var folder: DiskAnalyzerFolder?

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }
    private var hasResult: Bool { service.results[path] != nil }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if let disk {
                    usageBar(disk.space)
                    Text(String(format: strings.usageFormat, DiskAnalyzerFormat.bytes(disk.space.used),
                                DiskAnalyzerFormat.bytes(disk.space.free),
                                DiskAnalyzerFormat.bytes(disk.space.capacity)))
                        .monospacedDigit()
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    Text(path).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer(minLength: 12)
            if let folder {
                Button {
                    service.setKept(!folder.isKept, folder: folder.path)
                } label: {
                    Image(systemName: folder.isKept ? "star.fill" : "star")
                        .foregroundStyle(folder.isKept ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(folder.isKept ? strings.forgetFolder : strings.keepFolder)
            }
            if hasResult {
                Button(strings.show) { service.show(path: path) }
                Button {
                    service.discardResult(path)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help(strings.discardResult)
            } else {
                Button(strings.scan) { service.startScan(path) }
                    .disabled(service.scan != nil)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func usageBar(_ space: DiskUsageVolumeSpace) -> some View {
        let used = space.capacity > 0 ? Double(space.used) / Double(space.capacity) : 0
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(used > 0.9 ? Color.red : used > 0.75 ? Color.orange : Color.accentColor)
                    .frame(width: geometry.size.width * used)
            }
        }
        .frame(width: 220, height: 6)
    }
}

// MARK: - Scanning

private struct DiskAnalyzerScanningView: View {
    @ObservedObject private var service = DiskAnalyzerService.shared
    @ObservedObject private var l10n = L10n.shared
    let path: String

    private var strings: DiskAnalyzerFeatureStrings { FeatureStrings.diskAnalyzer(l10n.language) }

    var body: some View {
        let progress = service.scan?.progress
        let _ = service.progressTick
        VStack(spacing: 14) {
            Text(String(format: strings.scanningFormat, service.displayName(ofPath: path)))
                .font(.title3.weight(.semibold))
            ProgressView(value: progress?.fraction ?? 0)
                .frame(width: 360)
            Text(String(format: strings.filesFormat,
                        DiskAnalyzerFormat.count(progress?.files.load(ordering: .relaxed) ?? 0)))
                .font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
            Text(progress?.currentPath ?? "")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: 480)
            Button(strings.stop) { service.cancelScan() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
