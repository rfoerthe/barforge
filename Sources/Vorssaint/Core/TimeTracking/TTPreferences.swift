// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// The part of `TTSettings` that lives in UserDefaults (plan E5): how the app
/// records and reminds. The dated working-time rules and the time account
/// belong to the data and stay in the database (`TimeTrackingDatabase`).
enum TTPreferences {
    /// Every key this mapping reads and writes.
    static let keys = [
        DefaultsKey.timeTrackingMinWorkSeconds,
        DefaultsKey.timeTrackingIconSet,
        DefaultsKey.timeTrackingShowTime,
        DefaultsKey.timeTrackingHotkeys,
        DefaultsKey.timeTrackingAutoWorkdaysOnly,
        DefaultsKey.timeTrackingIdleSeconds,
        DefaultsKey.timeTrackingAskAfterLock,
        DefaultsKey.timeTrackingNotifyLimit,
        DefaultsKey.timeTrackingNotifyBreak,
    ]

    /// `settings` with the preference fields read from `defaults`. A key
    /// without a value keeps what `settings` has (Tagwerk's default for a
    /// fresh `TTSettings()`), so an unregistered suite reads like a new install.
    static func read(from defaults: UserDefaults, into settings: TTSettings = TTSettings()) -> TTSettings {
        var s = settings
        func int(_ key: String, _ fallback: Int) -> Int {
            (defaults.object(forKey: key) as? NSNumber)?.intValue ?? fallback
        }
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            (defaults.object(forKey: key) as? NSNumber)?.boolValue ?? fallback
        }
        s.minWork = int(DefaultsKey.timeTrackingMinWorkSeconds, s.minWork)
        s.iconSet = TTIconSet.from(id: int(DefaultsKey.timeTrackingIconSet, s.iconSet.id))
        s.showTime = bool(DefaultsKey.timeTrackingShowTime, s.showTime)
        s.hotkeys = bool(DefaultsKey.timeTrackingHotkeys, s.hotkeys)
        s.autoWorkdaysOnly = bool(DefaultsKey.timeTrackingAutoWorkdaysOnly, s.autoWorkdaysOnly)
        s.idleSecs = int(DefaultsKey.timeTrackingIdleSeconds, s.idleSecs)
        s.askAfterLock = bool(DefaultsKey.timeTrackingAskAfterLock, s.askAfterLock)
        s.notifyLimit = bool(DefaultsKey.timeTrackingNotifyLimit, s.notifyLimit)
        s.notifyBreak = bool(DefaultsKey.timeTrackingNotifyBreak, s.notifyBreak)
        return s.sanitized
    }

    /// Writes the preference fields of `settings` (sanitized) to `defaults`.
    static func write(_ settings: TTSettings, to defaults: UserDefaults) {
        let s = settings.sanitized
        defaults.set(s.minWork, forKey: DefaultsKey.timeTrackingMinWorkSeconds)
        defaults.set(s.iconSet.id, forKey: DefaultsKey.timeTrackingIconSet)
        defaults.set(s.showTime, forKey: DefaultsKey.timeTrackingShowTime)
        defaults.set(s.hotkeys, forKey: DefaultsKey.timeTrackingHotkeys)
        defaults.set(s.autoWorkdaysOnly, forKey: DefaultsKey.timeTrackingAutoWorkdaysOnly)
        defaults.set(s.idleSecs, forKey: DefaultsKey.timeTrackingIdleSeconds)
        defaults.set(s.askAfterLock, forKey: DefaultsKey.timeTrackingAskAfterLock)
        defaults.set(s.notifyLimit, forKey: DefaultsKey.timeTrackingNotifyLimit)
        defaults.set(s.notifyBreak, forKey: DefaultsKey.timeTrackingNotifyBreak)
    }

    /// Tagwerk's keys in its `settings` table (`store.rs` `KEY_*`) for the
    /// fields above, with how a stored integer applies. Used once, when the
    /// data is taken over from Tagwerk.
    static let tagwerkKeys: [(key: String, apply: @Sendable (inout TTSettings, Int) -> Void)] = [
        ("min_work_s", { $0.minWork = $1 }),
        ("icon_set", { $0.iconSet = TTIconSet.from(id: $1) }),
        ("menubar_time", { $0.showTime = $1 != 0 }),
        ("global_hotkeys", { $0.hotkeys = $1 != 0 }),
        ("idle_s", { $0.idleSecs = $1 }),
        ("auto_workdays_only", { $0.autoWorkdaysOnly = $1 != 0 }),
        ("ask_after_lock", { $0.askAfterLock = $1 != 0 }),
        ("notify_limit", { $0.notifyLimit = $1 != 0 }),
        ("notify_break", { $0.notifyBreak = $1 != 0 }),
    ]
}
