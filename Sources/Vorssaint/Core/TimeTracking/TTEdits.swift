// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

// Corrections of a day in the Records window and their undo history (the
// logic of Tagwerk's `records.rs`): what an edit is, when a day refuses it,
// how it changes the day, and how undo and redo take back exactly what a step
// changed (`Corrections::rewind`, a three-way merge per entry).

/// A change made in the inspector (`records.rs` `Edit`).
enum TTEdit: Hashable, Sendable {
    case setStart(Int?)
    case setEnd(Int?)
    case addBreak(Int, Int)
    /// Index in `TTDay.breaks`.
    case removeBreak(Int)
    case addWork(Int, Int, String)
    /// Index in `TTDay.work`.
    case removeWork(Int)
    /// Deletes work away from the Mac in this range (week view).
    case cutWork(Int, Int)
    /// Enters, changes or (`nil`) removes the absence.
    case setAbsence(TTAbsence?)
    /// Free day: the recorded time counts or does not (see `TTDay.freeDay`).
    case setCounting(Bool)
    /// Deletes every entry of the day, manual and recorded.
    case clearDay

    /// What changed, for "Undo …" (and whether two steps are the same input).
    var name: TTEditName {
        switch self {
        case .setStart: return .setStart
        case .setEnd: return .setEnd
        case .addBreak: return .addBreak
        case .removeBreak: return .removeBreak
        case .addWork: return .addWork
        case .removeWork, .cutWork: return .removeWork
        case .setAbsence: return .setAbsence
        case .setCounting(true): return .countOn
        case .setCounting(false): return .countOff
        case .clearDay: return .clearDay
        }
    }

    /// The input in the inspector a note about this change stands above.
    var input: TTEditInput? {
        switch self {
        case .setStart: return .start
        case .setEnd: return .end
        case .addBreak, .removeBreak: return .breaks
        case .addWork, .removeWork, .cutWork: return .work
        case .setAbsence: return .absence
        case .setCounting, .clearDay: return nil
        }
    }

    /// The start or end of work this sets (for the note that it cut work away from the Mac).
    var bound: TTEditBound? {
        switch self {
        case .setStart: return .start
        case .setEnd: return .end
        default: return nil
        }
    }

    /// Does it create an entry (see `TTSettings.missingWorkdays`)? Removing,
    /// clearing and the mere decision about recording on a free day do not.
    var addsEntry: Bool {
        switch self {
        case .setStart(.some), .setEnd(.some), .addBreak, .addWork, .setAbsence(.some): return true
        default: return false
        }
    }
}

/// The name of an edit (`Edit::name`): language-independent, so the history
/// can tell whether two steps belong to the same input.
enum TTEditName: Hashable, Sendable {
    case setStart, setEnd, addBreak, removeBreak, addWork, removeWork, setAbsence, countOn, countOff, clearDay

    func title(_ s: TimeTrackingRecordsStrings) -> String {
        switch self {
        case .setStart: return s.editSetStart
        case .setEnd: return s.editSetEnd
        case .addBreak: return s.editAddBreak
        case .removeBreak: return s.editRemoveBreak
        case .addWork: return s.editAddWork
        case .removeWork: return s.editRemoveWork
        case .setAbsence: return s.editSetAbsence
        case .countOn: return s.editCountOn
        case .countOff: return s.editCountOff
        case .clearDay: return s.editClearDay
        }
    }
}

/// An input of the inspector a note can stand above (`records.rs` `Input`).
enum TTEditInput: Hashable, Sendable, CaseIterable {
    case absence, start, breaks, work, end
}

/// Start or end of work (`records.rs` `Bound`).
enum TTEditBound: Hashable, Sendable {
    case start, end
}

/// What an edit did to a day (`records.rs` `store_edit`).
struct TTEditOutcome: Hashable, Sendable {
    /// The corrections before and after, as the history keeps them.
    var before: TTCorrections
    var after: TTCorrections
    /// Why the day refused the edit (shown above the input); `nil` when it
    /// went through or was refused silently (`TTEdits.refuses`).
    var refusal: String?

    /// Did a new start or end of work cut work away from the Mac?
    func cut(_ edit: TTEdit) -> TTEditBound? {
        before.work != after.work ? edit.bound : nil
    }
}

/// The edits of the Records window as pure functions.
enum TTEdits {
    /// Why the day `d` does not take `edit` (`nil`: it does): times in the
    /// future (on future days only an absence, today nothing after `now`), a
    /// start of work not before the end, or a new absence on a day without a
    /// target. Removing always works (`records.rs` `refusal`).
    static func refusal(_ d: TTDay, _ edit: TTEdit, settings: TTSettings, now: TTDateTime,
                        _ texts: TimeTrackingTexts, _ s: TimeTrackingRecordsStrings) -> String? {
        let today = now.date
        let latest: Int?
        switch edit {
        case let .setStart(t?), let .setEnd(t?): latest = t
        case let .addBreak(_, to), let .addWork(_, to, _): latest = to
        default: latest = nil
        }
        var counting = false
        if case .setCounting = edit { counting = true }
        if d.date > today && (latest != nil || counting) {
            return s.futureText
        }
        let clock = now.secs
        if d.date == today, let latest, latest > clock {
            return String(format: s.laterThanNowFormat, TTFormat.clock(clock))
        }
        switch edit {
        case let .setStart(start?) where !TTDay.boundsInOrder(start: start, end: d.end):
            return String(format: texts.refusedStartNotBeforeEndFormat, TTFormat.clock(d.end ?? 0))
        case let .setEnd(end?) where !TTDay.boundsInOrder(start: d.start, end: end):
            return String(format: texts.refusedEndNotAfterStartFormat, TTFormat.clock(d.start ?? 0))
        case let .setAbsence(absence?) where !settings.isWorkday(d.date) && d.absence != absence:
            return s.freeDayAbsence
        default:
            return nil
        }
    }

    /// Does the day `d` silently not allow the edit? A full-day absence only
    /// lets itself change or the day be cleared. On a free day whose recorded
    /// time does not count there is no start, break or end until "Count
    /// recorded time" (as in the menu and the week view); removing always
    /// works, and so does work away from the Mac (`records.rs` `refuses`).
    static func refuses(_ d: TTDay, _ edit: TTEdit) -> Bool {
        let locked: Bool
        switch edit {
        case .setAbsence, .clearDay: locked = false
        default: locked = d.locksEntries
        }
        let uncounted: Bool
        switch edit {
        case .setStart(.some), .setEnd(.some), .addBreak: uncounted = d.uncounted
        default: uncounted = false
        }
        return locked || uncounted
    }

    /// The text of the question before an entry on `date` lies before the
    /// first day with entries so far (`days`: all days, `today`: today). It
    /// becomes the first day then, and every workday in between counts its
    /// target (see `TTSettings.missingWorkdays`). `nil` when that changes
    /// nothing: there is no entry at all, the day is not before the first,
    /// or no workday up to yesterday lies in between (`before_first_text`).
    static func beforeFirstText(_ days: [TTDay], date: TTDate, settings: TTSettings, today: TTDate,
                                _ texts: TimeTrackingTexts, _ s: TimeTrackingRecordsStrings) -> String? {
        guard let first = days.first(where: { $0.hasEntries || $0.absence != nil })?.date, date < first else {
            return nil
        }
        var gap: [TTDate] = []
        var d = date.adding(days: 1)
        while d < first && d < today {
            if settings.isWorkday(d) { gap.append(d) }
            d = d.adding(days: 1)
        }
        if gap.isEmpty { return nil }
        let target = gap.reduce(0) { $0 + settings.dailyTarget($1) }
        let between = gap.count == 1 ? s.beforeFirstBetweenOne : String(format: s.beforeFirstBetweenManyFormat, gap.count)
        return String(format: s.beforeFirstFormat, TTFormat.day(first, texts), TTFormat.day(date, texts), between,
                      (target + 1800) / 3600)
    }

    /// Applies `edit` to the day `d` as it stands in the database (`now`: now).
    /// A refused edit leaves the day as it is. The corrections before and
    /// after are what the history keeps: with the recorded periods when they
    /// are part of the step (clearing the day, a full-day absence today that
    /// deletes today's recorded time), so undo brings them back
    /// (`records.rs` `store_edit`).
    static func apply(_ edit: TTEdit, to d: inout TTDay, settings: TTSettings, now: TTDateTime,
                      _ texts: TimeTrackingTexts, _ s: TimeTrackingRecordsStrings) -> TTEditOutcome {
        let today = d.date == now.date
        var clears = false
        if case let .setAbsence(absence) = edit { clears = d.clearsForAbsence(absence, today: today) }
        var whole = clears
        if case .clearDay = edit { whole = true }
        let snapshot: (TTDay) -> TTCorrections = whole ? TTCorrections.whole : TTCorrections.of
        let before = snapshot(d)
        let rejected = refusal(d, edit, settings: settings, now: now, texts, s)
        if !refuses(d, edit) && rejected == nil {
            switch edit {
            // Work away from the Mac before the start or after the end goes:
            // the latest entry wins.
            case let .setStart(start): d.setStart(start)
            case let .setEnd(end): d.setEnd(end)
            case let .addBreak(from, to): d.addBreak(from: from, to: to)
            case let .removeBreak(i):
                if d.breaks.indices.contains(i) { d.breaks.remove(at: i) }
            case let .addWork(from, to, note): d.addWork(from: from, to: to, note: note)
            case let .removeWork(i):
                if d.work.indices.contains(i) { d.work.remove(at: i) }
            case let .cutWork(from, to): d.cutWork(from: from, to: to)
            case let .setAbsence(absence):
                // A whole day only on an empty day (the inspector offers it
                // only then); today the recorded time goes with it.
                if d.acceptsAbsence(absence, today: today) {
                    if clears { d.periods = [] }
                    d.absence = absence
                }
            case let .setCounting(on):
                d.freeDay = on ? .counted : .uncounted
            case .clearDay:
                // Today on a free day recording stays off afterwards, even
                // after "Record today", until it is chosen again (otherwise it
                // would go on at once and the day would be back).
                let free = today ? d.freeDay : nil
                d = TTDay(date: d.date)
                d.freeDay = free == nil ? nil : .stopped
            }
        }
        return TTEditOutcome(before: before, after: snapshot(d), refusal: rejected)
    }

    /// The note when a new start or end of work cut work away from the Mac.
    static func cutText(_ bound: TTEditBound, _ s: TimeTrackingRecordsStrings) -> String {
        bound == .start ? s.startCut : s.endCut
    }

    /// `a, b and c`
    static func joinAnd(_ parts: [String], _ texts: TimeTrackingTexts) -> String {
        guard let last = parts.last else { return "" }
        if parts.count == 1 { return last }
        return parts.dropLast().joined(separator: texts.listSeparator) + texts.andSeparator + last
    }

    /// Title and text after undoing or redoing (`redo`) the step `name` of
    /// the day `date` when it did not fully work (`nil`: it did)
    /// (`records.rs` `rewind_note`).
    static func rewindNote(redo: Bool, name: String, date: TTDate, _ rewind: TTRewind,
                           _ texts: TimeTrackingTexts, _ s: TimeTrackingRecordsStrings) -> (title: String, text: String)? {
        let step = String(format: s.rewindStepFormat, name, TTFormat.day(date, texts))
        switch rewind {
        case .done:
            return nil
        case let .partial(kept):
            let list = joinAnd(kept.map { $0.label(s) }, texts)
            return (redo ? s.partialRedoTitle : s.partialUndoTitle,
                    String(format: redo ? s.partialRedoFormat : s.partialUndoFormat, step, list))
        case let .refused(block):
            let why: String
            switch block {
            case let .changed(kept): why = String(format: s.whyChangedFormat, joinAnd(kept.map { $0.label(s) }, texts))
            case .order: why = s.whyOrder
            case .absenceBesideEntries: why = s.whyAbsenceBesideEntries
            }
            return (redo ? s.refusedRedoTitle : s.refusedUndoTitle,
                    String(format: redo ? s.refusedRedoFormat : s.refusedUndoFormat, step, why))
        }
    }

    /// `Undo Remove Break` or, without a step, `Undo` (`history_title`).
    static func historyTitle(redo: Bool, name: String?, _ s: TimeTrackingRecordsStrings) -> String {
        let verb = redo ? s.redo : s.undo
        guard let name else { return verb }
        return String(format: s.historyTitleFormat, verb, name)
    }

    /// What "Delete All Entries" takes from the day (`clear_day_text`).
    static func clearDayText(_ day: TTDay, isToday: Bool, _ texts: TimeTrackingTexts,
                             _ s: TimeTrackingRecordsStrings) -> String {
        func count(_ n: Int, _ one: String, _ many: String) -> String {
            n == 1 ? one : String(format: many, n)
        }
        var parts: [String] = []
        if !day.periods.isEmpty {
            parts.append(count(day.periods.count, s.clearPeriodsOne, s.clearPeriodsManyFormat))
        }
        if day.start != nil { parts.append(s.clearStart) }
        if !day.breaks.isEmpty {
            parts.append(count(day.breaks.count, s.clearBreaksOne, s.clearBreaksManyFormat))
        }
        if !day.work.isEmpty {
            parts.append(count(day.work.count, s.clearWorkOne, s.clearWorkManyFormat))
        }
        if day.end != nil { parts.append(s.clearEnd) }
        if let absence = day.absence {
            parts.append(String(format: s.clearAbsenceFormat, absence.label(texts)))
        }
        var text = String(format: s.clearAffectsFormat, parts.isEmpty ? s.clearNothing : joinAnd(parts, texts))
        if isToday && day.freeDay != nil {
            text += s.clearTodayFreeDay
        } else if isToday {
            text += s.clearTodayContinues
        }
        return text + s.undoHint
    }

    /// The explanation in the question about a full-day absence today
    /// (`recorded`: seconds recorded today; `half`: there is a half day of it)
    /// (`absence_today_text`).
    static func absenceTodayText(recorded: Int, half: Bool, _ texts: TimeTrackingTexts,
                                 _ s: TimeTrackingRecordsStrings) -> String {
        let text = String(format: s.absenceTodayFormat, TTRecords.shortDuration(recorded, texts))
        return half ? text + s.absenceTodayHalf : text
    }
}

/// The manual corrections of a day: everything the window can change. The
/// recorded periods only belong to a step that deleted them (`whole`): undo
/// otherwise restores only corrections and keeps time recorded since
/// (`records.rs` `Corrections`).
struct TTCorrections: Hashable, Sendable {
    var start: Int?
    var end: Int?
    var breaks: [TTBreak] = []
    var work: [TTWorkBlock] = []
    var absence: TTAbsence?
    var freeDay: TTFreeDay?
    /// Recorded periods (`nil`: left alone).
    var periods: [TTSpan]?

    init(start: Int? = nil, end: Int? = nil, breaks: [TTBreak] = [], work: [TTWorkBlock] = [],
         absence: TTAbsence? = nil, freeDay: TTFreeDay? = nil, periods: [TTSpan]? = nil) {
        self.start = start
        self.end = end
        self.breaks = breaks
        self.work = work
        self.absence = absence
        self.freeDay = freeDay
        self.periods = periods
    }

    static func of(_ day: TTDay) -> TTCorrections {
        TTCorrections(start: day.start, end: day.end, breaks: day.breaks, work: day.work, absence: day.absence,
                      freeDay: day.freeDay)
    }

    /// The whole day including the recorded periods.
    static func whole(_ day: TTDay) -> TTCorrections {
        var c = of(day)
        c.periods = day.periods
        return c
    }

    /// Replays the step from `done` (the state it left) to `target` on the day
    /// `day`: for undo `target` is the state before, for redo the one after. A
    /// three-way merge per entry: only what the step changed and what is still
    /// as it left it goes back. What changed differently since (end of work,
    /// "Keep working away from the Mac", "Record today" from the menu …)
    /// stays. Recorded time (part of the step only after clearing the day or a
    /// full-day absence today) comes back or goes without losing what was
    /// recorded since. If that gives no valid day, the day stays as it is.
    static func rewind(_ day: inout TTDay, done: TTCorrections, target: TTCorrections) -> TTRewind {
        var kept: [TTCorrectionField] = []
        var result = day
        func pick<T: Equatable>(_ cur: T, _ done: T, _ target: T, _ field: TTCorrectionField) -> T {
            if done != target && cur == done { return target }
            // Untouched, already as wanted, or changed differently since.
            if done != target && cur != target { kept.append(field) }
            return cur
        }
        result.start = pick(day.start, done.start, target.start, .start)
        result.breaks = pick(day.breaks, done.breaks, target.breaks, .breaks)
        result.work = pick(day.work, done.work, target.work, .work)
        result.end = pick(day.end, done.end, target.end, .end)
        result.absence = pick(day.absence, done.absence, target.absence, .absence)
        result.freeDay = pick(day.freeDay, done.freeDay, target.freeDay, .counting)
        if let donePeriods = done.periods, let targetPeriods = target.periods {
            // What was recorded since the step stays in any case.
            var since = day.periods
            for cut in donePeriods { since = TTSpan.subtract(since, cut) }
            result.periods = TTSpan.union(targetPeriods + since)
        }
        if result == day {
            return kept.isEmpty ? .done : .refused(.changed(kept))
        }
        // A day that was like that before (older data) stays undoable.
        if let why = inconsistency(result), inconsistency(day) == nil {
            return .refused(why)
        }
        day = result
        return kept.isEmpty ? .done : .partial(kept)
    }

    /// Why the day `d` must not be like that (`nil`: it may): a start of work
    /// not before the end, or a full-day absence next to other entries.
    static func inconsistency(_ d: TTDay) -> TTRewindBlock? {
        if !TTDay.boundsInOrder(start: d.start, end: d.end) { return .order }
        if d.locksEntries && d.hasEntries { return .absenceBesideEntries }
        return nil
    }
}

/// An entry of the corrections, named when undo keeps it.
enum TTCorrectionField: Hashable, Sendable {
    case start, breaks, work, end, absence, counting

    func label(_ s: TimeTrackingRecordsStrings) -> String {
        switch self {
        case .start: return s.fieldStart
        case .breaks: return s.fieldBreaks
        case .work: return s.fieldWork
        case .end: return s.fieldEnd
        case .absence: return s.fieldAbsence
        case .counting: return s.fieldCounting
        }
    }
}

/// Result of `TTCorrections.rewind`.
enum TTRewind: Hashable, Sendable {
    /// Fully undone or redone.
    case done
    /// Only partly: these entries changed differently since and stay as they are.
    case partial([TTCorrectionField])
    /// Not at all; the day stays as it is.
    case refused(TTRewindBlock)
}

/// Why a step cannot be undone or redone.
enum TTRewindBlock: Hashable, Sendable {
    /// Everything it changed has changed differently since.
    case changed([TTCorrectionField])
    /// The start of work would not be before the end.
    case order
    /// A full-day absence would stand next to other entries.
    case absenceBesideEntries
}

/// A step to undo or redo: the corrections of the day before and after.
struct TTEditStep: Hashable, Sendable {
    var name: TTEditName
    var date: TTDate
    var before: TTCorrections
    var after: TTCorrections
}

/// The history of corrections (the latest step last) (`records.rs` `History`).
struct TTEditHistory: Hashable, Sendable {
    var undo: [TTEditStep] = []
    var redo: [TTEditStep] = []

    /// At most this many steps can be undone.
    static let max = 50

    /// Records a new change. `followUp`: the input goes on (arrow keys in a
    /// time field); if it belongs to the same entry as the last step, that
    /// step stays, so one undo takes back the whole input.
    mutating func record(_ step: TTEditStep, followUp: Bool) {
        redo.removeAll()
        if followUp, let last = undo.last, last.date == step.date, last.name == step.name {
            // The state before the whole input stays; the one after is new.
            undo[undo.count - 1].after = step.after
            return
        }
        undo.append(step)
        if undo.count > Self.max { undo.removeFirst() }
    }
}
