// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import AppKit
import SwiftUI

/// The formatting row: one button per mark, labelled and ordered the same
/// way as the marks themselves.
struct ScratchpadFormatBar: View {
    private static let buttonSize: CGFloat = 26
    private static let cornerRadius: CGFloat = 6

    @ObservedObject private var service = ScratchpadService.shared
    @ObservedObject private var l10n = L10n.shared

    private var text: ScratchpadFeatureStrings { FeatureStrings.scratchpad(l10n.language) }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(ScratchpadMark.allCases, id: \.self) { markButton($0) }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func markButton(_ mark: ScratchpadMark) -> some View {
        Button { service.apply(mark) } label: {
            Group {
                // A letter where one says the thing better than any glyph: every
                // symbol for a heading reads as font size instead.
                if let glyph = mark.glyph {
                    Text(verbatim: glyph).font(.system(size: 13, weight: .semibold))
                } else {
                    Image(systemName: mark.symbol).font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundStyle(.secondary)
            .frame(width: Self.buttonSize, height: Self.buttonSize)
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(text.label(for: mark))
        .accessibilityLabel(text.label(for: mark))
    }
}
