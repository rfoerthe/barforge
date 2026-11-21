// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

// Which notifications Time Tracking posts, with Tagwerk's ids and texts
// (`menubar.rs`, `notify.rs`), and the question after a long lock. Pure
// decisions; `TimeTrackingNotifications` posts them.

/// One notification. A new one replaces an older one with the same `id`.
struct TTNotice: Hashable, Sendable {
    /// Prefix of every id, so Time Tracking's notifications are told apart
    /// from those of other features (banner while Barforge is in front).
    static let idPrefix = "timeTracking."

    let id: String
    let title: String
    let body: String

    init(id: String, title: String, body: String) {
        self.id = TTNotice.idPrefix + id
        self.title = title
        self.body = body
    }

    static func isTimeTracking(_ identifier: String) -> Bool {
        identifier.hasPrefix(idPrefix)
    }

    // MARK: Reminders (rules.rs)

    static func limit(_ alert: TTLimitAlert, _ texts: TimeTrackingTexts) -> TTNotice {
        TTNotice(id: alert.id, title: alert.title(texts), body: alert.body(texts))
    }

    static func breakReminder(_ alert: TTBreakAlert, _ texts: TimeTrackingTexts) -> TTNotice {
        TTNotice(id: alert.id, title: alert.title(texts), body: alert.body(texts))
    }

    // MARK: Entries from the menu (menubar.rs)

    /// A start or end of work was not taken (`notify_refused`): the menu is
    /// closed by then, so a notification says why.
    static func entryRefused(start: Bool, _ why: TTRefused, texts: TimeTrackingTexts,
                             menu: TimeTrackingMenuTexts) -> TTNotice {
        TTNotice(id: "entry-refused", title: start ? menu.startRefusedTitle : menu.endRefusedTitle,
                 body: why.text(texts))
    }

    /// A start or end of work cut work away from the Mac (the latest entry
    /// wins, `notify_cut_work`). `nil` when nothing was cut.
    static func workCut(_ blocks: [TTWorkBlock], beforeStart: Bool, texts: TimeTrackingTexts,
                        menu: TimeTrackingMenuTexts) -> TTNotice? {
        if blocks.isEmpty { return nil }
        let what = blocks.map { $0.describe(texts) }.joined(separator: texts.listSeparator)
        let format = beforeStart ? menu.workCutBeforeStartFormat : menu.workCutAfterEndFormat
        return TTNotice(id: "work-cut", title: menu.workCutTitle, body: String(format: format, what))
    }

    /// Work away from the Mac nobody ended until midnight (`report_forgotten_away`).
    static func forgottenAway(_ forgotten: TTForgottenAway, texts: TimeTrackingTexts,
                              menu: TimeTrackingMenuTexts) -> TTNotice {
        TTNotice(id: "away-forgotten", title: menu.forgottenTitle,
                 body: String(format: menu.forgottenBodyFormat, TTFormat.day(forgotten.date, texts),
                              forgotten.block.describe(texts)))
    }

    /// The database failed (`report_db_error`); posted only for the first error.
    static func databaseError(_ failure: TTDatabaseFailure, detail: String, title: String,
                              menu: TimeTrackingMenuTexts) -> TTNotice {
        let (what, consequence) = TTMenu.dbFailure(failure, menu)
        return TTNotice(id: "db-error", title: String(format: menu.dbErrorTitleFormat, title, what),
                        body: String(format: menu.dbErrorBodyFormat, detail, consequence))
    }
}

/// The answer to the question after a long lock (`notify.rs` `LockAnswer`).
/// Without an answer the lock stays a break.
enum TTLockAnswer: Hashable, Sendable {
    /// Work away from the Mac for this reason.
    case work(TTActivity)
    /// The end of work came with the lock.
    case closeDay

    /// The buttons of the question, in this order.
    static let all: [TTLockAnswer] = [.work(.meeting), .work(.call), .work(.networking), .work(.other), .closeDay]

    /// Identifier of the button (Tagwerk's, with the Time Tracking prefix).
    var actionIdentifier: String {
        switch self {
        case let .work(activity): return TTNotice.idPrefix + "work-" + activity.key
        case .closeDay: return TTNotice.idPrefix + "close-day"
        }
    }

    init?(actionIdentifier: String) {
        guard let answer = TTLockAnswer.all.first(where: { $0.actionIdentifier == actionIdentifier }) else {
            return nil
        }
        self = answer
    }

    /// Title of the button.
    func title(_ texts: TimeTrackingTexts, _ menu: TimeTrackingMenuTexts) -> String {
        switch self {
        case .work(.other): return menu.lockOtherWork
        case let .work(activity): return activity.label(texts)
        case .closeDay: return menu.lockEndOfWork
        }
    }
}

/// The question after a long lock: the day and the lock as it ended
/// (`menubar.rs` `asked_lock`). The answer refers to exactly this lock.
struct TTLockQuestion: Hashable, Sendable {
    /// Category of the notification with the buttons of `TTLockAnswer.all`.
    static let categoryIdentifier = TTNotice.idPrefix + "lock-ask"
    private static let dateKey = "timeTracking.lockDate"
    private static let fromKey = "timeTracking.lockFrom"
    private static let toKey = "timeTracking.lockTo"

    let date: TTDate
    let from: Int
    let to: Int

    /// After an unlock: ask what a long lock was, when the setting is on.
    /// Only for locks of today that began within the working-time frame, not
    /// for the night before; and not when nothing would count anyway (a free
    /// day without "Record today", or after the end of work) (`ask_about_lock`).
    static func ask(_ tracker: TTTracker, from: TTDateTime, to: TTDateTime) -> TTLockQuestion? {
        let settings = tracker.settings
        let long = TTMenu.seconds(from: from, to: to) >= settings.askAfter(from.date)
        guard settings.askAfterLock, long, from.date == to.date,
              settings.rules(from.date).inFrame(from.secs) else { return nil }
        if tracker.counting(to.date) == false { return nil }
        if case .closed = tracker.mode(to) { return nil }
        return TTLockQuestion(date: from.date, from: from.secs, to: to.secs)
    }

    func notice(texts: TimeTrackingTexts, menu: TimeTrackingMenuTexts) -> TTNotice {
        TTNotice(id: "lock-ask",
                 title: String(format: menu.lockTitleFormat,
                               TTMenu.pauseTitle(TTSpan(from, to), texts: texts, menu: menu)),
                 body: menu.lockBody)
    }

    /// What the notification carries, so the answer still finds its lock
    /// after Barforge restarted in between.
    var userInfo: [String: Any] {
        [Self.dateKey: date.iso, Self.fromKey: from, Self.toKey: to]
    }

    init(date: TTDate, from: Int, to: Int) {
        self.date = date
        self.from = from
        self.to = to
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let iso = userInfo[Self.dateKey] as? String, let date = TTDate(iso: iso),
              let from = (userInfo[Self.fromKey] as? NSNumber)?.intValue,
              let to = (userInfo[Self.toKey] as? NSNumber)?.intValue,
              0 <= from, from < to, to <= TTLimits.dayEnd else { return nil }
        self.init(date: date, from: from, to: to)
    }
}

/// The reminders about the maximum working time and breaks: which came
/// today, so each threshold is reported once, when it is crossed while
/// working, and not for what was already reached when recording started
/// (`menubar.rs` `limit`, `breaks` and their `init`).
struct TTReminders: Hashable, Sendable {
    private var limit: TTLimitWatch
    private var breaks: TTBreakWatch

    /// Takes over today's state without a notification.
    init(date: TTDate, work: Int, stretch: Int) {
        limit = TTLimitWatch(date: date, work: work)
        breaks = TTBreakWatch(date: date, stretch: stretch)
    }

    /// New figures of today. The watches always follow; only what the
    /// settings switch on is returned. Both reminders belong to the Working
    /// Hours Act and stay quiet while its hints are off (plan E2).
    mutating func update(date: TTDate, work: Int, stretch: Int, working: Bool, settings: TTSettings,
                         texts: TimeTrackingTexts) -> [TTNotice] {
        var out: [TTNotice] = []
        if let alert = limit.update(date: date, work: work, working: working),
           settings.notifyLimit && settings.legalHints {
            out.append(.limit(alert, texts))
        }
        if let alert = breaks.update(date: date, stretch: stretch, working: working),
           settings.notifyBreak && settings.legalHints {
            out.append(.breakReminder(alert, texts))
        }
        return out
    }
}
