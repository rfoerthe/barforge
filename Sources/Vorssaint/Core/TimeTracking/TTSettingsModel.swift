// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

// The decisions of the settings page as pure code (the logic part of
// Tagwerk's `settings_window.rs`): the list of dated working-time rules, the
// hint in the sheet "Change working time" (which days change, until when the
// rules apply, whether that is retroactive), reading the working-time frame,
// the stepper for work away from the Mac, the note about the question after a
// long lock, and what "Restore defaults" does and says. The page in
// `UI/Settings` only draws what this decides.

/// A span of days: first and last day (`nil`: since always, or without end)
/// (`settings_window.rs` `DaySpan`).
struct TTDaySpan: Hashable, Sendable {
    var first: TTDate?
    var last: TTDate?

    init(_ first: TTDate?, _ last: TTDate?) {
        self.first = first
        self.last = last
    }

    /// Does this span lie completely within `outer`?
    func isWithin(_ outer: TTDaySpan) -> Bool {
        let startInside = outer.first.map { o in first.map { $0 >= o } ?? false } ?? true
        let endInside = outer.last.map { o in last.map { $0 <= o } ?? false } ?? true
        return startInside && endInside
    }
}

/// Which rules the sheet edits (`Sheet::editing`): new ones, or the existing
/// set from a date (`nil`: the first set, which applies since always and
/// keeps its date).
enum TTRulesEditing: Hashable, Sendable {
    case new
    case existing(TTDate?)

    /// The date of the edited set when it moves (`editing.flatten()`).
    var replaces: TTDate? {
        if case let .existing(from) = self { return from }
        return nil
    }

    var isFirst: Bool { self == .existing(nil) }
}

/// One row of the list of rules (`settings_window.rs` `RuleRow`).
struct TTRuleRow: Hashable, Sendable, Identifiable {
    var from: TTDate?
    /// Valid from, week, workdays, frame, break from, days off.
    var cells: [String]
    /// Applies today.
    var current: Bool
    /// Applies only from a future day.
    var planned: Bool

    /// The first set sorts first; there is at most one set per day.
    var id: Int { from?.ordinal ?? 0 }
}

/// Why the typed working-time frame does not read (`parse_frame`).
enum TTFrameError: Error, Hashable, Sendable {
    /// Not two times such as 07:00 and 24:00.
    case times
    /// The end is 00:00; midnight as the end is 24:00.
    case midnight
    /// The end does not come after the start.
    case order

    func text(_ t: TimeTrackingSettingsStrings) -> String {
        switch self {
        case .times: return t.errorFrameTimes
        case .midnight: return t.errorFrameMidnight
        case .order: return t.errorFrameOrder
        }
    }
}

/// Whether macOS lets the app notify (`notify.rs` `Permission`).
enum TTNotificationPermission: Hashable, Sendable {
    /// Without an app bundle there are no notifications.
    case unavailable
    /// macOS has not asked yet.
    case notDetermined
    /// Turned off in System Settings.
    case denied
    /// Allowed, but neither as banners nor in Notification Center (style "None").
    case hidden
    case allowed

    /// From the authorization status and whether notifications show as
    /// alerts or in Notification Center.
    init(authorized: Bool?, visible: Bool) {
        switch authorized {
        case nil: self = .notDetermined
        case false?: self = .denied
        case true?: self = visible ? .allowed : .hidden
        }
    }

    /// Something to change in System Settings (not allowed or hidden).
    var needsSettings: Bool {
        switch self {
        case .notDetermined, .denied, .hidden: return true
        case .allowed, .unavailable: return false
        }
    }

    func text(_ t: TimeTrackingSettingsStrings) -> String {
        switch self {
        case .unavailable: return t.permissionUnavailable
        case .notDetermined: return t.permissionUndetermined
        case .denied: return t.permissionDenied
        case .hidden: return t.permissionHidden
        case .allowed: return t.permissionAllowed
        }
    }

    func note(_ t: TimeTrackingSettingsStrings) -> String {
        switch self {
        case .allowed: return t.noteAllowed
        case .hidden: return t.noteHidden
        case .notDetermined, .denied: return t.noteDenied
        case .unavailable: return t.noteUnavailable
        }
    }
}

enum TTSettingsModel {
    /// Step of the arrows for the minimum length of work away from the Mac (minutes).
    static let workStep = 5
    /// Idle minutes offered while idle detection is off (`IDLE_DEFAULT`).
    static let idleDefault = 10 * 60

    // MARK: Rules

    /// `39 Std./Woche (Mo–Fr, 7:48 Std. pro Arbeitstag)  ·  Rahmen 07:00–22:00 Uhr  ·  Pausen ab 15 Min.`
    /// (`rules_line`).
    static func rulesLine(_ r: TTWorkRules, _ t: TimeTrackingSettingsStrings, _ texts: TimeTrackingTexts) -> String {
        String(format: t.rulesLineFormat, TTFormat.hours(r.weeklyTarget, texts), r.workdaysText(texts),
               r.dailyTargetText(texts), r.frameText(texts), r.minPause / 60,
               r.freeDaysCount ? texts.rulesSummaryFreeDays : "")
    }

    /// `4-Tage-Woche  ·  9:45 Std. pro Arbeitstag` under the workdays in the sheet.
    static func dailyNote(_ r: TTWorkRules, _ t: TimeTrackingSettingsStrings, _ texts: TimeTrackingTexts) -> String {
        String(format: t.dailyNoteFormat, r.weekText(texts), r.dailyTargetText(texts))
    }

    /// The set of rules that applies on `today` (`nil` when none does, which
    /// `TTSettings.normalized` never leaves).
    private static func currentIndex(_ s: TTSettings, today: TTDate) -> Int? {
        s.work.lastIndex { period in period.from.map { $0 <= today } ?? true }
    }

    /// Above the list: which rules apply today and which are planned next,
    /// each with the target of a workday the list does not show
    /// (`rules_now_text`).
    static func rulesNowText(_ s: TTSettings, today: TTDate, _ t: TimeTrackingSettingsStrings,
                             _ texts: TimeTrackingTexts) -> String {
        func perDay(_ r: TTWorkRules) -> String {
            String(format: t.perWorkdayFormat, r.dailyTargetText(texts), r.weekText(texts))
        }
        let current = currentIndex(s, today: today).map { s.work[$0] } ?? s.work[0]
        let since = current.from.map { String(format: t.currentFromFormat, TTFormat.day($0, texts)) }
            ?? t.currentSinceBeginning
        var text = String(format: t.currentRulesFormat, since, perDay(current.rules))
        if let next = s.work.first(where: { $0.from.map { $0 > today } ?? false }), let from = next.from {
            text += "\n" + String(format: t.plannedRulesFormat, TTFormat.day(from, texts), perDay(next.rules))
        }
        return text
    }

    /// The rows of the list of rules (`rule_rows`).
    static func ruleRows(_ s: TTSettings, today: TTDate, _ t: TimeTrackingSettingsStrings,
                         _ texts: TimeTrackingTexts) -> [TTRuleRow] {
        let current = currentIndex(s, today: today)
        return s.work.enumerated().map { i, p in
            let r = p.rules
            return TTRuleRow(
                from: p.from,
                cells: [
                    p.from.map { TTFormat.day($0, texts) } ?? t.rowBeginning,
                    String(format: t.weeklyCellFormat, TTFormat.hours(r.weeklyTarget, texts)),
                    r.workdaysText(texts),
                    "\(TTFormat.clock(r.frameFrom))–\(TTFormat.clock(r.frameTo))",
                    String(format: texts.minutesFormat, r.minPause / 60),
                    // Column "Days off": whether work there goes into balance and account.
                    r.freeDaysCount ? t.freeDaysInBalance : "–",
                ],
                current: current == i,
                planned: p.from.map { $0 > today } ?? false)
        }
    }

    /// Tooltip of a row: applies today, planned or applied before.
    static func rowTip(_ row: TTRuleRow, _ t: TimeTrackingSettingsStrings) -> String {
        if row.current { return t.rowTipCurrent }
        return row.planned ? t.rowTipPlanned : t.rowTipPast
    }

    /// The days on which `after` gives other working-time rules than `before`,
    /// adjoining days as one span, sorted by date (`changed_days`). The rules
    /// only change at the dates of the sets, so one day per stretch between
    /// them is enough to compare.
    static func changedDays(_ before: TTSettings, _ after: TTSettings) -> [TTDaySpan] {
        let bounds = Array(Set((before.work + after.work).compactMap(\.from))).sorted()
        let starts: [TTDate?] = [nil] + bounds.map { Optional($0) }
        let ends: [TTDate?] = bounds.map { Optional($0) } + [nil]
        var out: [TTDaySpan] = []
        var open = false
        for (start, end) in zip(starts, ends) {
            // The first stretch reaches until before the first dated set.
            let probe = start ?? .min
            if before.rules(probe) == after.rules(probe) {
                open = false
                continue
            }
            let last = end.map { $0.predecessor ?? $0 }
            if open, !out.isEmpty {
                out[out.count - 1].last = last
            } else {
                out.append(TTDaySpan(start, last))
            }
            open = true
        }
        return out
    }

    /// `ab dem 30.11.2026`, `vom 02.11.2026 bis 29.11.2026 und ab dem 07.12.2026` … (`fmt_spans`).
    static func spansText(_ spans: [TTDaySpan], _ t: TimeTrackingSettingsStrings, _ texts: TimeTrackingTexts) -> String {
        let parts = spans.map { span -> String in
            switch (span.first, span.last) {
            case (nil, nil): return t.spansAll
            case let (nil, e?): return String(format: t.spansUntilFormat, TTFormat.day(e, texts))
            case let (a?, nil): return String(format: t.spansFromFormat, TTFormat.day(a, texts))
            case let (a?, e?) where a == e: return String(format: t.spansDayFormat, TTFormat.day(a, texts))
            case let (a?, e?):
                return String(format: t.spansRangeFormat, TTFormat.day(a, texts), TTFormat.day(e, texts))
            }
        }
        guard let last = parts.last else { return "" }
        if parts.count == 1 { return last }
        return parts.dropLast().joined(separator: texts.listSeparator) + texts.andSeparator + last
    }

    /// Hint in the sheet: until when the rules apply, for which days the rules
    /// change and whether that is retroactive (then `warn`: orange)
    /// (`sheet_hint`). `from` is the date in the sheet (`nil` for the first
    /// set), `draft` its rules.
    ///
    /// It compares the settings before and after "Apply" (the same
    /// `setRules` as there), so the hint is right when a set moves (then the
    /// days between the old and the new date change) or equals the one before
    /// and goes.
    static func sheetHint(_ s: TTSettings, editing: TTRulesEditing, from: TTDate?, draft: TTWorkRules,
                          today: TTDate, _ t: TimeTrackingSettingsStrings,
                          _ texts: TimeTrackingTexts) -> (text: String, warn: Bool) {
        func day(_ d: TTDate) -> String { TTFormat.day(d, texts) }
        var after = s
        after.setRules(from: from, draft, replaces: editing.replaces)
        let changed = changedDays(s, after)
        var parts: [String] = []
        // For which days the set applies after "Apply", if it still exists then.
        let own: (start: TTDate?, next: TTDate?)? = after.work.firstIndex { $0.from == from }.map { i in
            (from, i + 1 < after.work.count ? after.work[i + 1].from : nil)
        }
        if let own {
            switch (own.start, own.next) {
            case let (nil, n?): parts.append(String(format: t.hintAllBeforeFormat, day(n)))
            case (nil, nil): parts.append(t.hintAll)
            case let (f?, n?): parts.append(String(format: t.hintRangeFormat, day(f), day(n.predecessor ?? n)))
            case let (f?, nil): parts.append(String(format: t.hintFromFormat, day(f)))
            }
        }
        // Another set on the same day (not the one being edited).
        let replaced = s.work.contains { $0.from == from && editing != .existing($0.from) }
        if replaced, let f = from {
            parts.append(String(format: t.hintReplacesFormat, day(f)))
        }
        if own == nil {
            parts.append(changed.isEmpty ? t.hintSameNothing : t.hintSameDropped)
        }
        let past = changed.first.map { $0.first.map { $0 < today } ?? true } ?? false
        // The days the set applies to (until before the next).
        let ownSpan = own.map { TTDaySpan($0.start, $0.next?.predecessor) }
        if past {
            parts.append(String(format: t.hintRetroactiveFormat, spansText(changed, t, texts)))
        } else if changed.contains(where: { span in !(ownSpan.map { span.isWithin($0) } ?? false) }) {
            // Days the set does not apply to, the days in between when moving it, for example.
            parts.append(String(format: t.hintOtherFormat, spansText(changed, t, texts)))
        }
        return (parts.joined(separator: " "), past || replaced)
    }

    /// The working-time frame from the fields "from" and "to" in whole
    /// minutes; the end may be 24:00 (midnight at the end of the day)
    /// (`parse_frame`).
    static func parseFrame(_ from: String, _ to: String) -> Result<(from: Int, to: Int), TTFrameError> {
        guard let start = TTFormat.parseClock(from), let end = TTFormat.parseClock(to) else {
            return .failure(.times)
        }
        let (f, e) = (start / 60 * 60, end / 60 * 60)
        if e == 0 { return .failure(.midnight) }
        if e <= f { return .failure(.order) }
        return .success((f, e))
    }

    /// The weekly hours typed in the sheet, in bounds (`set_weekly`).
    static func weeklyTarget(_ text: String) -> Int? {
        TTFormat.parseHours(text).flatMap { TTLimits.weeklyRange.contains($0) ? $0 : nil }
    }

    /// Minutes typed into a field, as seconds within `range` (seconds).
    static func minutes(_ text: String, in range: ClosedRange<Int>) -> Int? {
        guard let m = Int(text.ttTrimmed), m <= Int.max / 60 else { return nil }
        return range.contains(m * 60) ? m * 60 : nil
    }

    /// The new value after a click on the arrows, when `old` minutes applied
    /// before and the stepper reports `stepped` (`step_minutes`): in steps of
    /// five over round values (1 → 5 → 10 …), also from an odd typed value
    /// (12 → 15 or 10), and below 5 straight to the lower bound.
    static func stepMinutes(old: Int, stepped: Int) -> Int {
        let (min, max) = (TTLimits.minWorkRange.lowerBound / 60, TTLimits.minWorkRange.upperBound / 60)
        let value: Int
        if stepped > old {
            value = Swift.max(stepped / workStep * workStep, old + 1)
        } else if stepped < old {
            let up = (stepped + workStep - 1) / workStep * workStep
            value = up < old ? up : min
        } else {
            value = old
        }
        return value.ttClamped(min, max)
    }

    /// The note under "Ask after a long lock" by the rules of `today`
    /// (`ask_note`): the threshold is `TTSettings.askAfter` (30 min, never
    /// shorter than the minimum break), and it only asks when the lock began
    /// within the frame and ends on the same day.
    static func askNote(_ s: TTSettings, today: TTDate, _ t: TimeTrackingSettingsStrings) -> String {
        let after = s.askAfter(today)
        return String(format: t.askNoteFormat, after / 60, after > TTLimits.askAfterLock ? t.askNoteMinBreak : "")
    }

    /// The confirmation before deleting the rules from `from`: title and text
    /// (`confirm_delete_rules`).
    static func deleteInfo(_ s: TTSettings, from: TTDate, today: TTDate, _ t: TimeTrackingSettingsStrings,
                           _ texts: TimeTrackingTexts) -> (title: String, info: String) {
        let before = s.rules(from.predecessor ?? from)
        var info = sentence(String(format: t.deleteInfoFormat, TTFormat.day(from, texts), rulesLine(before, t, texts)))
        if from <= today {
            info += String(format: t.deleteChangesFormat, TTFormat.day(from, texts))
        }
        return (String(format: t.deleteTitleFormat, TTFormat.day(from, texts)), info)
    }

    /// `text` with a full stop at the end, unless it ends with one already
    /// (`Pausen ab 15 Min.`; Tagwerk shows two there).
    private static func sentence(_ text: String) -> String {
        TTSentence.ended(text)
    }

    // MARK: Restore defaults

    /// The settings after "Restore defaults" (`with_defaults`): everything as
    /// at the beginning, only the working-time rules apply like at the
    /// beginning from `today` on. Earlier days keep their sets, planned ones
    /// are dropped.
    static func withDefaults(_ s: TTSettings, today: TTDate) -> TTSettings {
        var fresh = TTSettings()
        fresh.work = s.work.filter { $0.from.map { $0 <= today } ?? true }
        fresh.setRules(from: today, .default)
        return fresh
    }

    /// The text of the confirmation before "Restore defaults": what is reset
    /// (see `withDefaults`) and what stays (`reset_info`).
    static func resetInfo(_ s: TTSettings, today: TTDate, _ t: TimeTrackingSettingsStrings,
                          _ texts: TimeTrackingTexts) -> String {
        let d = TTSettings()
        var parts = [t.resetWhat]
        if s.accountFrom != d.accountFrom || s.accountCarry != d.accountCarry {
            var was: [String] = []
            if let f = s.accountFrom { was.append(String(format: t.resetAccountFromFormat, TTFormat.day(f, texts))) }
            if s.accountCarry != 0 {
                was.append(String(format: t.resetAccountCarryFormat, TTFormat.signedHoursMinutes(s.accountCarry)))
            }
            parts.append(String(format: t.resetAccountFormat, was.joined(separator: texts.listSeparator)))
        }
        if s.rules(today) == .default {
            parts.append(t.resetRulesAlreadyDefault)
        } else {
            parts.append(sentence(String(format: t.resetRulesFormat, TTFormat.day(today, texts),
                                         rulesLine(.default, t, texts))))
        }
        let planned = s.work.compactMap { $0.from.flatMap { $0 > today ? TTFormat.day($0, texts) : nil } }
        if planned.count == 1 {
            parts.append(String(format: t.resetPlannedOneFormat, planned[0]))
        } else if let last = planned.last {
            parts.append(String(format: t.resetPlannedManyFormat,
                                planned.dropLast().joined(separator: texts.listSeparator), last))
        }
        parts.append(t.resetStays)
        return parts.joined(separator: " ")
    }
}
