// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import SwiftUI

/// Settings page of Time Tracking. For now only the switch; the working
/// time rules, recording and notification options follow with the tracker.
struct TimeTrackingSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.timeTrackingEnabled) private var enabled = false

    private var strings: TimeTrackingFeatureStrings { FeatureStrings.timeTracking(l10n.language) }

    var body: some View {
        Form {
            Section(strings.title) {
                Toggle(strings.recordToggle, isOn: $enabled)
                    .onChange(of: enabled) { _, _ in
                        TimeTrackingService.shared.syncWithPreferences()
                    }
                Text(strings.recordCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(strings.betaNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}
