// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Automatic work time tracking, ported from Tagwerk. Time counts while the
/// Mac is unlocked; locks, sleep and session switches end a period.
///
/// This is the groundwork: the service follows the hub and its own switch,
/// but does not observe anything yet. The tracker, the database and the event
/// sources arrive in later milestones (see docs/TIME-TRACKING-PLAN.md).
final class TimeTrackingService: ObservableObject {
    static let shared = TimeTrackingService()

    /// Whether the feature is installed and its switch is on.
    @Published private(set) var isActive = false

    private init() {}

    /// Called by the hub, by the settings switch and at launch. An
    /// uninstalled feature keeps nothing resident.
    func syncWithPreferences() {
        let active = AppFeature.timeTracking.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.timeTrackingEnabled)
        guard active != isActive else { return }
        isActive = active
    }

    /// Saves what is running before the app quits. Nothing to save yet.
    func shutdown() {}
}
