// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

// What the menu bar shows and offers, as pure decisions (the logic part of
// Tagwerk's `menubar.rs`): the status line with its icon, the figures of
// today, which actions appear with which titles, the texts of the submenus
// and the clamping of a chosen time. The panel section and the status item
// in `UI/TimeTracking` only draw what this decides.

/// State the menu bar shows (`menubar.rs` `IconKind`).
enum TTIconKind: CaseIterable, Hashable, Sendable {
    case running
    /// Work away from the Mac (meeting, call …).
    case away
    case paused
    case onBreak
    case outside
    case closed
    /// Absent all day today (vacation, sick …): nothing is recorded.
    case absent

    /// State of the menu bar glyph (`IconKind::glyph`).
    var glyph: TTGlyphState {
        switch self {
        // Work away from the Mac counts like running recording.
        case .running, .away: return .running
        // Locked or asleep: hardly ever seen in the menu bar.
        case .paused, .onBreak: return .onBreak
        case .outside: return .outside
        // Like the end of work: nothing more is recorded today.
        case .closed, .absent: return .closed
        }
    }

    /// SF Symbol for the state (`IconKind::symbol`).
    var symbolName: String {
        switch self {
        case .running: return "clock.fill"
        case .away: return "figure.walk"
        case .paused: return "pause.circle"
        case .onBreak: return "cup.and.saucer.fill"
        case .outside: return "moon.stars"
        case .closed: return "moon.zzz"
        case .absent: return "calendar.badge.minus"
        }
    }

    /// Accessibility description of the glyph (`IconKind::symbol`).
    func description(_ menu: TimeTrackingMenuTexts) -> String {
        switch self {
        case .running: return menu.iconRunning
        case .away: return menu.iconAway
        case .paused: return menu.iconPaused
        case .onBreak: return menu.iconBreak
        case .outside: return menu.iconOutside
        case .closed: return menu.iconClosed
        case .absent: return menu.iconAbsent
        }
    }
}

/// Colour of the status line (`menubar.rs` `status_title`): green while
/// recording, orange on a break, indigo after the end of work, teal when
/// absent; outside the frame the text keeps the label colour with a grey dot.
enum TTStatusTone: Hashable, Sendable {
    case running, onBreak, closed, absent, neutral

    init(_ kind: TTIconKind) {
        switch kind {
        case .running, .away: self = .running
        case .onBreak, .paused: self = .onBreak
        case .closed: self = .closed
        case .absent: self = .absent
        case .outside: self = .neutral
        }
    }
}

/// The status line and its icon.
struct TTStatusLine: Hashable, Sendable {
    let text: String
    let kind: TTIconKind
}

/// What "Pause work" does right now (title and symbol of the item).
enum TTPauseAction: Hashable, Sendable {
    case pause, resume, backAtMac

    func title(_ menu: TimeTrackingMenuTexts) -> String {
        switch self {
        case .pause: return menu.pauseWork
        case .resume: return menu.resumeWork
        case .backAtMac: return menu.backAtMac
        }
    }

    var symbolName: String {
        switch self {
        case .pause: return "pause.fill"
        case .resume: return "play.fill"
        case .backAtMac: return "desktopcomputer"
        }
    }
}

/// Which actions the menu offers (`menubar.rs:813-867`). Every flag is the
/// negation of Tagwerk's `setHidden` condition.
struct TTMenuActions: Hashable, Sendable {
    /// "Record today" on a free day; `countDayChecked` when its time counts.
    var countDay = false
    var countDayChecked = false
    /// "Pause work", "Resume work" or "Back at the Mac".
    var pause = false
    var pauseAction = TTPauseAction.resume
    /// "Keep working away from the Mac ›".
    var away = false
    /// "Count a break as working time ›" with today's breaks.
    var countPause = false
    /// "Set start of work ›".
    var start = false
    /// Last entry of the start submenu: the first unlock again (with its
    /// time) or, without one, removing the manual start.
    var startReset = false
    var startResetUnlock: Int?
    /// "End of work ›".
    var close = false
    /// "Undo end of work".
    var reopen = false
}

/// Everything the menu bar section shows, computed from the tracker at one
/// moment (main thread, after every event and tick).
struct TTMenuModel: Hashable, Sendable {
    var status: TTStatusLine
    var actions: TTMenuActions
    /// Earliest and latest time (seconds since midnight) the "Other time…"
    /// picker of the start and of the end of work allows, and where it opens.
    var startChoice: TTTimeChoice
    var endChoice: TTTimeChoice
}

/// The range of the time picker (`menubar.rs` `chosen_time`): from midnight
/// to now, narrower when limits ask for it and something is left.
struct TTTimeChoice: Hashable, Sendable {
    var earliest: Int
    var latest: Int
    var initial: Int

    /// `limits` are the earliest and latest allowed time in seconds since
    /// midnight; a limit that leaves nothing falls back to midnight…now.
    init(now: Int, initial: Int?, earliest limitFrom: Int?, latest limitTo: Int?) {
        func at(_ s: Int) -> Int { s.ttClamped(0, TTLimits.dayEnd - 60) }
        var lo = Swift.min(limitFrom.map(at) ?? 0, now)
        var hi = Swift.min(limitTo.map(at) ?? now, now)
        if lo > hi { (lo, hi) = (0, now) }
        earliest = lo
        latest = hi
        self.initial = (initial ?? now).ttClamped(lo, hi)
    }

    /// The picked time of day, today and not in the future.
    func clamp(_ picked: Int, now: Int) -> Int {
        picked.ttClamped(earliest, Swift.min(latest, now))
    }
}

enum TTMenu {
    /// Submenu entries "Now", "15 min ago", "30 min ago" (`menubar.rs` `time_menu`).
    static let relativeMinutes = [0, 15, 30]
    /// At most this many warnings show (one line per kind of warning).
    static let maxWarnings = 6
    /// Longest error line in the menu (`menubar.rs` `DB_ERROR_MAX`).
    static let dbErrorMax = 90
    /// Room for the reason in a count-pause tag (more than there are reasons).
    static let countPauseReasons = 8

    // MARK: Model

    static func model(_ tracker: TTTracker, now t: TTDateTime, texts: TimeTrackingTexts,
                      menu: TimeTrackingMenuTexts) -> TTMenuModel {
        model(tracker, now: t, info: tracker.today(t), pauses: tracker.pausesToday(t), texts: texts, menu: menu)
    }

    /// The same with today's figures and breaks already at hand (they are
    /// the expensive part).
    static func model(_ tracker: TTTracker, now t: TTDateTime, info: TTTodayInfo, pauses: [TTSpan],
                      texts: TimeTrackingTexts, menu: TimeTrackingMenuTexts) -> TTMenuModel {
        let status = statusLine(tracker, now: t, texts: texts, menu: menu)
        let actions = self.actions(status: tracker.status(t), mode: info.mode, counting: tracker.counting(t.date),
                                   running: tracker.isRunning, away: tracker.onAway, onBreak: tracker.onBreak,
                                   hasPauses: !pauses.isEmpty, startManual: info.startManual,
                                   autoFirst: info.autoFirst,
                                   beforeFrame: t.secs <= tracker.settings.rules(t.date).frameFrom)
        // After the end of work the start must lie before it.
        var end: Int?
        if case let .closed(at) = info.mode { end = at - 60 }
        let startChoice = TTTimeChoice(now: t.secs, initial: info.firstStart, earliest: nil, latest: end)
        // The end of work lies after the manual start and within the frame.
        let frameFrom = tracker.settings.rules(t.date).frameFrom
        let earliest = info.startManual ? Swift.max(info.firstStart ?? frameFrom, frameFrom) : frameFrom
        let endChoice = TTTimeChoice(now: t.secs, initial: nil, earliest: earliest + 60, latest: nil)
        return TTMenuModel(status: status, actions: actions, startChoice: startChoice, endChoice: endChoice)
    }

    /// Which actions show (`menubar.rs:813-867`).
    static func actions(status: TTStatus, mode: TTMode, counting: Bool?, running: Bool, away: Bool,
                        onBreak: Bool, hasPauses: Bool, startManual: Bool, autoFirst: Int?,
                        beforeFrame: Bool) -> TTMenuActions {
        var a = TTMenuActions()
        let closed = mode != .auto
        // Absent all day: nothing to record, so nothing to control.
        let absent = status == .absent
        // Free day: "Record today" with a checkmark once the recorded time
        // counts; not after the end of work. While it does not count, it is
        // the only way in: the other actions only appear afterwards.
        a.countDay = counting != nil && !closed && !absent
        a.countDayChecked = counting == true
        let uncounted = counting == false
        a.start = !absent && !uncounted
        a.startReset = startManual
        a.startResetUnlock = autoFirst
        // What runs can always be ended, even when "Record today" is off by
        // now (work away from the Mac counts then too, and a pause stands in
        // the status).
        let endsSomething = away || onBreak
        a.pause = !(closed || absent || (uncounted && !endsSomething))
        a.pauseAction = running ? .pause : away ? .backAtMac : .resume
        a.away = !(closed || away || absent || uncounted)
        // Like the other actions only once the recorded time counts.
        a.countPause = hasPauses && !absent && !uncounted
        // Before the frame nothing counts today yet: there is nothing to end
        // (shortly after midnight an end of work would lock the new day).
        a.close = !(closed || absent || uncounted || beforeFrame)
        a.reopen = closed && !absent
        return a
    }

    // MARK: Status line

    /// Status line and icon (`menubar.rs` `status_line`).
    static func statusLine(_ tracker: TTTracker, now t: TTDateTime, texts: TimeTrackingTexts,
                           menu: TimeTrackingMenuTexts) -> TTStatusLine {
        let settings = tracker.settings
        if let absence = tracker.absent(t.date) {
            return TTStatusLine(text: String(format: menu.statusAbsentFormat, absence.label(texts)), kind: .absent)
        }
        if case let .closed(at) = tracker.mode(t) {
            return TTStatusLine(text: String(format: menu.statusClosedFormat, clock(at, menu)), kind: .closed)
        }
        switch tracker.status(t) {
        case let .away(since, activity) where !tracker.inFrame(t):
            // Outside the frame work away from the Mac does not count either.
            let text = String(format: menu.statusOutsideSuffixFormat,
                              awayText(since: since, now: t, activity: activity, texts: texts, menu: menu))
            return TTStatusLine(text: text, kind: .outside)
        case let .away(since, activity):
            return TTStatusLine(text: awayText(since: since, now: t, activity: activity, texts: texts, menu: menu),
                                kind: .away)
        case let .onBreak(since):
            return TTStatusLine(text: breakText(since: since, now: t, minPause: settings.rules(t.date).minPause,
                                                menu: menu),
                                kind: .onBreak)
        case .freeDay where tracker.freeDay(t.date) == .stopped:
            return TTStatusLine(text: menu.statusFreeDayStopped, kind: .outside)
        case .freeDay:
            return TTStatusLine(text: menu.statusFreeDay, kind: .outside)
        case .outside:
            return TTStatusLine(text: String(format: menu.statusOutsideFormat,
                                             settings.rules(t.date).frameText(texts)),
                                kind: .outside)
        case .running:
            return TTStatusLine(text: menu.statusRunning, kind: .running)
        case .paused, .closed, .absent:
            let text: String
            if let p = tracker.pausedSince, p.date == t.date, tracker.onIdle {
                text = String(format: menu.statusIdleFormat, clock(p.secs, menu))
            } else if let p = tracker.pausedSince, p.date == t.date {
                text = String(format: menu.statusPausedSinceFormat, clock(p.secs, menu))
            } else {
                text = menu.statusPaused
            }
            return TTStatusLine(text: text, kind: .paused)
        }
    }

    /// `12:03 Uhr`, from another day `16.11. 12:03 Uhr`.
    static func since(_ since: TTDateTime, now t: TTDateTime, menu: TimeTrackingMenuTexts) -> String {
        if since.date == t.date { return clock(since.secs, menu) }
        return String(format: menu.dateClockFormat, since.date.day, since.date.month, TTFormat.clock(since.secs))
    }

    /// "On a break since 12:03"; while the minimum break is not reached, with
    /// the note that the time still counts as work (`menubar.rs` `break_text`).
    static func breakText(since: TTDateTime, now t: TTDateTime, minPause: Int, menu: TimeTrackingMenuTexts) -> String {
        let at = self.since(since, now: t, menu: menu)
        if seconds(from: since, to: t) < minPause {
            return String(format: menu.statusBreakPendingFormat, at, minPause / 60)
        }
        return String(format: menu.statusBreakFormat, at)
    }

    /// "Away from the Mac since 12:03 – Meeting" (`menubar.rs` `away_text`).
    static func awayText(since: TTDateTime, now t: TTDateTime, activity: TTActivity, texts: TimeTrackingTexts,
                         menu: TimeTrackingMenuTexts) -> String {
        let at = self.since(since, now: t, menu: menu)
        let note = activity.note(texts)
        return note.isEmpty ? String(format: menu.statusAwayFormat, at)
            : String(format: menu.statusAwayNoteFormat, at, note)
    }

    /// `08:05 Uhr` / `08:05`.
    static func clock(_ secs: Int, _ menu: TimeTrackingMenuTexts) -> String {
        String(format: menu.clockFormat, TTFormat.clock(secs))
    }

    static func seconds(from a: TTDateTime, to b: TTDateTime) -> Int {
        (b.date.ordinal - a.date.ordinal) * TTLimits.dayEnd + b.secs - a.secs
    }

    // MARK: Texts of items

    /// Entry under "Count a break as working time": `15:25 – 15:45 Uhr  (20 Min.)`.
    /// The length follows the shown times, as in the week view (`menubar.rs` `pause_title`).
    static func pauseTitle(_ p: TTSpan, texts: TimeTrackingTexts, menu: TimeTrackingMenuTexts) -> String {
        let len = TTSpan.shownLen(from: p.from, to: p.to)
        return String(format: menu.pauseTitleFormat, TTFormat.clock(p.from), TTFormat.clock(p.to),
                      minutes(len, texts))
    }

    /// `55 Min.` or `1:20 h` (`menubar.rs` `fmt_minutes`).
    static func minutes(_ secs: Int, _ texts: TimeTrackingTexts) -> String {
        secs < 3600 ? String(format: texts.minutesFormat, secs / 60) : TTExport.hoursMinutesUnit(secs)
    }

    /// Tag of an entry under "Count a break as working time": start of the
    /// break (seconds since midnight) and reason in one number (`count_pause_tag`).
    static func countPauseTag(from: Int, activity: TTActivity) -> Int {
        from * countPauseReasons + activity.id
    }

    static func countPause(fromTag tag: Int) -> (from: Int, activity: TTActivity) {
        (tag / countPauseReasons, TTActivity.from(id: tag % countPauseReasons))
    }

    /// Titles of "Now (09:12)", "15 min ago (08:57)" … for `now`; never
    /// before midnight.
    static func relativeTitle(minutes: Int, now: Int, menu: TimeTrackingMenuTexts) -> String {
        let at = relativeTime(minutes: minutes, now: now)
        return minutes == 0 ? String(format: menu.nowFormat, clock(at, menu))
            : String(format: menu.minutesAgoFormat, minutes, clock(at, menu))
    }

    /// `minutes` ago, at the earliest midnight (`chosen_time`).
    static func relativeTime(minutes: Int, now: Int) -> Int {
        Swift.max(now - minutes * 60, 0)
    }

    /// Last entry of "Set start of work": the first unlock with its time, or
    /// removing the manual start.
    static func startResetTitle(unlock: Int?, menu: TimeTrackingMenuTexts) -> String {
        unlock.map { String(format: menu.useFirstUnlockFormat, clock($0, menu)) } ?? menu.removeManualStart
    }

    /// Working time next to the menu bar icon: `6:12`, without a unit
    /// (`menubar.rs` `bar_time`).
    static func barTime(_ workSecs: Int) -> String {
        let m = Swift.max(workSecs, 0) / 60
        return String(format: "%d:%02d", m / 60, m % 60)
    }

    /// Is a balance negative? Under a minute it counts as even (shown as
    /// `+0:00 h`) (`palette.rs` `is_minus`).
    static func isMinus(_ balance: Int) -> Bool {
        balance < -59
    }

    /// Tooltip of the menu bar icon.
    static func tooltip(kind: TTIconKind, status: TTStatus, workSecs: Int, pauseSecs: Int, error: String?,
                        title: String, menu: TimeTrackingMenuTexts) -> String {
        let state: String
        switch kind {
        case .running: state = menu.tipRunning
        case .away: state = menu.tipAway
        case .paused: state = menu.tipPaused
        case .onBreak: state = menu.tipBreak
        case .outside where status == .freeDay: state = menu.tipFreeDay
        case .outside: state = menu.tipOutside
        case .closed: state = menu.tipClosed
        case .absent: state = menu.tipAbsent
        }
        var tip = String(format: menu.tooltipFormat, title, state, TTExport.hoursMinutesUnit(workSecs),
                         TTExport.hoursMinutesUnit(pauseSecs))
        if let error { tip += "\n" + error }
        return tip
    }

    // MARK: Database errors

    /// `Speichern fehlgeschlagen: database is locked`, on one line and short
    /// enough not to blow up the menu (`menubar.rs` `db_error_text`).
    static func dbErrorText(what: String, detail: String) -> String {
        let text = "\(what): " + detail.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if text.count <= dbErrorMax { return text }
        var cut = String(text.prefix(dbErrorMax - 1))
        while cut.last?.isWhitespace == true { cut.removeLast() }
        return cut + "…"
    }

    /// What failed and what follows from it (`menubar.rs` `report_db_error`).
    static func dbFailure(_ kind: TTDatabaseFailure, _ menu: TimeTrackingMenuTexts)
        -> (what: String, consequence: String) {
        switch kind {
        case .open: return (menu.dbOpenFailed, menu.dbOpenConsequence)
        case .read: return (menu.dbReadFailed, menu.dbReadConsequence)
        case .write: return (menu.dbWriteFailed, menu.dbWriteConsequence)
        }
    }
}

/// Which part of the database failed (mirrors `TimeTrackingDatabaseFault.Kind`,
/// which lives with the runtime).
enum TTDatabaseFailure: Hashable, Sendable {
    case open, read, write
}
