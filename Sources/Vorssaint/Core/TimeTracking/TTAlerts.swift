// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Notification about the maximum working time (`rules.rs` `LimitAlert`).
enum TTLimitAlert: Int, Comparable, Sendable {
    /// 15 minutes left until 10 hours (from 9:45 h).
    case soon = 0
    /// 10 hours reached.
    case reached = 1

    static func < (lhs: TTLimitAlert, rhs: TTLimitAlert) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Highest level `work` seconds of work have reached.
    static func level(_ work: Int) -> TTLimitAlert? {
        if work >= TTLimits.maxDailyWork { return .reached }
        if work >= TTLimits.maxDailyWork - TTLimits.maxDailyWorkNotice { return .soon }
        return nil
    }

    /// Identifier of the notification (a new one replaces an older one with the same id).
    var id: String {
        switch self {
        case .soon: return "max-hours-soon"
        case .reached: return "max-hours-reached"
        }
    }

    func title(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case .soon: return String(format: texts.limitSoonTitleFormat, TTLimits.maxDailyWorkNotice / 60)
        case .reached: return texts.limitReachedTitle
        }
    }

    func body(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case .soon:
            return String(format: texts.limitSoonBodyFormat,
                          TTFormat.duration(TTLimits.maxDailyWork - TTLimits.maxDailyWorkNotice, texts))
        case .reached: return texts.limitReachedBody
        }
    }
}

/// Reminder to take a break (`rules.rs` `BreakAlert`).
enum TTBreakAlert: Int, Comparable, Sendable {
    /// 15 minutes left until 6 hours in one stretch (from 5:45 h).
    case soon = 0
    /// 6 hours in one stretch reached.
    case reached = 1

    static func < (lhs: TTBreakAlert, rhs: TTBreakAlert) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Highest level `stretch` seconds of work in one stretch have reached.
    static func level(_ stretch: Int) -> TTBreakAlert? {
        if stretch >= TTLimits.maxStretch { return .reached }
        if stretch >= TTLimits.maxStretch - TTLimits.maxStretchNotice { return .soon }
        return nil
    }

    /// Identifier of the notification (a new one replaces an older one with the same id).
    var id: String {
        switch self {
        case .soon: return "break-soon"
        case .reached: return "break-reached"
        }
    }

    func title(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case .soon: return String(format: texts.breakSoonTitleFormat, TTLimits.maxStretchNotice / 60)
        case .reached: return texts.breakReachedTitle
        }
    }

    func body(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case .soon:
            return String(format: texts.breakSoonBodyFormat,
                          TTFormat.duration(TTLimits.maxStretch - TTLimits.maxStretchNotice, texts))
        case .reached: return texts.breakReachedBody
        }
    }
}

/// Remembers per day the highest level already reached, so each threshold is
/// reported once: when it is crossed, not already when the app starts.
struct TTWatch<Alert: Comparable & Hashable & Sendable>: Hashable, Sendable {
    private(set) var date: TTDate?
    private(set) var level: Alert?

    init(date: TTDate?, level: Alert?) {
        self.date = date
        self.level = level
    }

    /// New level of today. Returns it when it was just reached while working
    /// (`working`). If the value falls below a threshold again it is reported
    /// again next time; if it jumps over two thresholds, only the higher comes.
    mutating func update(date: TTDate, level: Alert?, working: Bool) -> Alert? {
        if self.date != date {
            self = TTWatch(date: date, level: nil)
        }
        let previous = self.level
        self.level = level
        // `Option` ordering as in Rust: `None` is below every level.
        guard working, let level else { return nil }
        if let previous, !(previous < level) { return nil }
        return level
    }
}

/// Notifications about the maximum working time: which came today.
struct TTLimitWatch: Hashable, Sendable {
    private var watch: TTWatch<TTLimitAlert>

    /// Takes over the state without a notification (at start: thresholds
    /// already reached are not reported).
    init(date: TTDate, work: Int) {
        watch = TTWatch(date: date, level: TTLimitAlert.level(work))
    }

    /// New working time of today. Returns the notification due when a threshold
    /// was just crossed while working (`working`). Time entered afterwards in
    /// the records gives none. If the working time falls below a threshold
    /// again (correction), it is reported again. If it jumps over both, only
    /// "reached" comes.
    mutating func update(date: TTDate, work: Int, working: Bool) -> TTLimitAlert? {
        watch.update(date: date, level: TTLimitAlert.level(work), working: working)
    }
}

/// Reminders to take a break: which came for the running stretch of work. After
/// a break the stretch starts anew, and the reminders come again.
struct TTBreakWatch: Hashable, Sendable {
    private var watch: TTWatch<TTBreakAlert>

    /// Takes over the state without a notification (at start: thresholds
    /// already reached are not reported).
    init(date: TTDate, stretch: Int) {
        watch = TTWatch(date: date, level: TTBreakAlert.level(stretch))
    }

    /// New length of the work in one stretch (`stretch` seconds, see
    /// `TTDay.currentStretchSecs`). Returns the reminder due.
    mutating func update(date: TTDate, stretch: Int, working: Bool) -> TTBreakAlert? {
        watch.update(date: date, level: TTBreakAlert.level(stretch), working: working)
    }
}
