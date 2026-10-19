// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import SwiftUI

/// The on-demand speed test: a start button, then one bar each for latency,
/// download and upload, filled in order as they are measured and updated
/// four times a second while they run. Shared by the Network card and the network
/// detail page.
struct SpeedTestView<Trailing: View>: View {
    @ObservedObject private var speed = SpeedTest.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    private let trailing: () -> Trailing

    init(@ViewBuilder trailing: @escaping () -> Trailing) {
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                if speed.isRunning {
                    ProgressView().controlSize(.small)
                    Text(l10n.s.speedTestTesting)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        speed.cancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(strings.stop)
                    .accessibilityLabel(strings.stop)
                } else {
                    Button {
                        speed.start()
                    } label: {
                        Label(hasResults ? l10n.s.speedTestAgain : l10n.s.speedTestRun,
                              systemImage: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
                trailing()
            }
            if hasResults || speed.isRunning {
                VStack(alignment: .leading, spacing: 6) {
                    SpeedTestBar(title: l10n.s.speedTestLatency,
                                 value: speed.latencyMs.map(latencyText),
                                 fraction: speed.latencyMs.map { SpeedTestScale.fraction($0, upTo: 1000) },
                                 ticks: [10, 100].map { SpeedTestScale.fraction($0, upTo: 1000) },
                                 color: PanelMetricColor.cyan(for: colorScheme),
                                 isActive: speed.phase == .latency)
                    SpeedTestBar(title: l10n.s.networkDownload,
                                 value: speed.downloadMbps.map(mbpsText),
                                 fraction: speed.downloadMbps.map { SpeedTestScale.fraction($0, upTo: 2500) },
                                 ticks: SpeedTestScale.rateTicks,
                                 color: .accentColor,
                                 isActive: speed.phase == .download)
                    SpeedTestBar(title: l10n.s.networkUpload,
                                 value: speed.uploadMbps.map(mbpsText),
                                 fraction: speed.uploadMbps.map { SpeedTestScale.fraction($0, upTo: 2500) },
                                 ticks: SpeedTestScale.rateTicks,
                                 color: PanelMetricColor.green(for: colorScheme),
                                 isActive: speed.phase == .upload)
                }
            }
            if let server = speed.serverName {
                Text("\(strings.server): \(server)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            if case .failed(let failure) = speed.phase {
                Text(failure == .rateLimited ? strings.rateLimited : l10n.s.speedTestFailed)
                    .font(.system(size: 10))
                    .foregroundStyle(PanelMetricColor.orange(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var strings: SpeedTestStrings { .localized(l10n.language) }

    private var hasResults: Bool {
        speed.latencyMs != nil || speed.downloadMbps != nil || speed.uploadMbps != nil
    }

    private func latencyText(_ ms: Double) -> String {
        ms < 1 ? "<1 ms" : "\(Int(ms.rounded())) ms"
    }

    private func mbpsText(_ value: Double) -> String {
        let number = value >= 100 ? String(format: "%.0f", locale: MetricFormat.locale, value)
                                  : String(format: "%.1f", locale: MetricFormat.locale, value)
        return "\(number) Mbps"
    }
}

extension SpeedTestView where Trailing == EmptyView {
    init() {
        self.init(trailing: { EmptyView() })
    }
}

private struct SpeedTestBar: View {
    let title: String
    let value: String?
    let fraction: Double?
    let ticks: [Double]
    let color: Color
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive || value != nil ? .primary : .tertiary)
                .lineLimit(1)
                .frame(width: 62, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    ForEach(ticks, id: \.self) { tick in
                        Rectangle()
                            .fill(Color.primary.opacity(0.14))
                            .frame(width: 1, height: 4)
                            .offset(x: proxy.size.width * tick)
                    }
                    if let fraction {
                        Capsule()
                            .fill(color.opacity(isActive ? 0.75 : 1))
                            .frame(width: max(4, proxy.size.width * fraction))
                            .animation(.linear(duration: 0.25), value: fraction)
                    }
                }
            }
            .frame(height: 6)
            Text(value ?? "–")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(value == nil ? .tertiary : .primary)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.15), value: value)
                .lineLimit(1)
                .frame(width: 78, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value ?? "–")
    }
}
