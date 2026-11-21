// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

// Recording logic: start and stop automatic periods, enter manual decisions
// (pause work, start of work, end of work) and spread everything over the days
// (port of Tagwerk's `tracker.rs`).
//
// Breaks come from locking the Mac or from "Pause work". An interruption at
// least as long as the minimum break is a break; shorter ones count as working
// time. A break through "Pause work" ends with "Resume work" or at the next
// unlock or wake of the Mac.
//
// "Keep working away from the Mac" (meeting, call …) counts the time until the
// next unlock or "Back at the Mac" as work away from the Mac, also while the
// Mac is locked in between. The end of work ends it. If nobody chooses "Back
// at the Mac" until midnight it was forgotten: the work away from the Mac then
// ends with the working-time frame (after it, it would not count anyway), and
// `TTTracker.forgotten` keeps it for a notification; only the user knows the
// true end.
//
// After the end of work recording goes on, but nothing counts any more
// (`TTDay.unframedSpans` ends there): taking it back returns the time between.
//
// On free days (weekend, deselected workdays) time is recorded but not
// counted if the settings say so: the first unlock marks the day
// `TTFreeDay.uncounted` until "Record today" lets the time count. Deleting all
// entries of the day in the records window keeps recording off for today
// (`TTFreeDay.stopped`), also after "Record today", until it is chosen again.
//
// On a day with a full-day absence nothing is recorded and the manual
// decisions do not apply, until the absence is "None" again.
//
// The logic never reads the clock: "now" always comes in as a `TTDateTime`.

/// Why automatic recording is not running right now (`tracker.rs` `PauseReason`).
enum TTPauseReason: Hashable, Sendable {
    case startup
    /// Quitting the app, end of work and the like (never replaces another reason).
    case manual
    /// The user chose "Pause work" (Tagwerk's `Break`).
    case userBreak
    case locked
    case sleep
    case sessionInactive
    /// The user keeps working away from the Mac (counts as working time).
    case away
    /// The Mac is unlocked but has had no input for a while (idle detection).
    case idle
}

/// Why a start or end of work was not taken (`tracker.rs` `Refused`).
enum TTRefused: Error, Hashable, Sendable {
    /// The start would not lie before the end of work (at this time).
    case startNotBeforeEnd(Int)
    /// The end of work would not lie after the manual start (at this time).
    case endNotAfterStart(Int)
    /// The end of work would lie before the working-time frame (which starts at
    /// this time): today nothing would count. The evening before is meant, and
    /// that day already ended with its frame.
    case endBeforeFrame(Int)

    /// Message for the user.
    func text(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case let .startNotBeforeEnd(end):
            return String(format: texts.refusedStartNotBeforeEndFormat, TTFormat.clock(end))
        case let .endNotAfterStart(start):
            return String(format: texts.refusedEndNotAfterStartFormat, TTFormat.clock(start))
        case let .endBeforeFrame(from):
            return String(format: texts.refusedEndBeforeFrameFormat, TTFormat.clock(from))
        }
    }
}

/// Work away from the Mac that nobody ended until midnight: the day and the
/// entry as it stands now (`tracker.rs` `Tracker::forgotten`).
struct TTForgottenAway: Hashable, Sendable {
    let date: TTDate
    let block: TTWorkBlock
}

/// Figures for today, including the running period (`tracker.rs` `TodayInfo`).
struct TTTodayInfo: Hashable, Sendable {
    var workSecs = 0
    var pauseSecs = 0
    /// Effective start (manual or first unlock).
    var firstStart: Int?
    /// The start was set by hand.
    var startManual = false
    /// First automatic unlock today within the working-time frame.
    var autoFirst: Int?
    var mode = TTMode.auto
    /// Today's target.
    var targetSecs = 0
    /// Balance of this week (Monday to today, see `TTSettings.balance`).
    var weekBalance = 0
    /// State of the time account (see `TTSettings.account`).
    var account = 0
    /// Work in one stretch since the last break of at least 15 minutes.
    var stretchSecs = 0
    /// Warnings about violated rules.
    var warnings: [TTWarning] = []
}

/// The state machine of recording (`tracker.rs` `Tracker`). A value type: the
/// service owns one and persists what `save` hands it.
struct TTTracker {
    var days: [TTDay]
    /// State of the database after the last load or save (so only changes are
    /// written). Internal, not private, because a test sets it like Tagwerk's.
    var saved: [TTDay]
    /// Start of the running automatic period.
    var runningSince: TTDateTime?
    var pausedSince: TTDateTime?
    var pauseReason = TTPauseReason.startup
    /// Kind of work away from the Mac (only with `TTPauseReason.away`).
    var away = TTActivity.other
    /// Work away from the Mac that nobody ended until midnight; the service
    /// reports it at the next unlock and clears it.
    var forgotten: TTForgottenAway?
    var settings: TTSettings
    /// Language of the notes on work away from the Mac (`TTActivity.note`).
    /// Tagwerk's notes are German; Barforge writes them in the app's language.
    var texts: TimeTrackingTexts

    init(days: [TTDay], settings: TTSettings, texts: TimeTrackingTexts) {
        self.days = days
        saved = days
        self.settings = settings
        self.texts = texts
    }

    /// Does `now` lie within the working-time frame? Nothing counts outside it.
    func inFrame(_ now: TTDateTime) -> Bool {
        settings.rules(now.date).inFrame(now.secs)
    }

    var isRunning: Bool { runningSince != nil }

    /// A break through "Pause work" (ends only with "Resume work" or an
    /// unlock or wake, not by itself).
    var onBreak: Bool { runningSince == nil && pauseReason == .userBreak }

    /// "Pause work": stops the running recording.
    @discardableResult
    mutating func takeBreak(_ now: TTDateTime) -> Bool {
        runningSince != nil && stop(now, reason: .userBreak)
    }

    /// Continues a break through "Pause work" that began before the app restarted.
    mutating func restoreBreak(since: TTDateTime) {
        runningSince = nil
        pausedSince = since
        pauseReason = .userBreak
    }

    /// Stopped because the unlocked Mac had no input for a while?
    var onIdle: Bool { runningSince == nil && pauseReason == .idle }

    /// Idle: recording ends backwards at the last input `lastInput` (at the
    /// earliest at the start of the running period), like a lock from then.
    /// Only from the minimum break on it becomes a break.
    @discardableResult
    mutating func goIdle(lastInput: TTDateTime) -> Bool {
        guard let since = runningSince else { return false }
        return stop(Swift.max(lastInput, since), reason: .idle)
    }

    /// Since when the Mac was locked or asleep (`nil` while recording runs or
    /// when it stopped for another reason), for the question at unlock.
    var lockedSince: TTDateTime? {
        let locked = pauseReason == .locked || pauseReason == .sleep || pauseReason == .sessionInactive
        return runningSince == nil && locked ? pausedSince : nil
    }

    /// Is the user working away from the Mac right now (meeting, call …)?
    var onAway: Bool { runningSince == nil && pauseReason == .away }

    /// "Keep working away from the Mac": from now on the time counts as work
    /// away from the Mac, also while the Mac is locked, until the next unlock
    /// or wake or "Back at the Mac".
    @discardableResult
    mutating func goAway(_ now: TTDateTime, activity: TTActivity) -> Bool {
        if onAway || mode(now) != .auto || absent(now.date) != nil { return false }
        if let since = runningSince {
            runningSince = nil
            Self.commit(&days, since, now)
        }
        pausedSince = now
        pauseReason = .away
        away = activity
        return true
    }

    /// Continues "Keep working away from the Mac" that began before the app restarted.
    mutating func restoreAway(since: TTDateTime, activity: TTActivity) {
        runningSince = nil
        pausedSince = since
        pauseReason = .away
        away = activity
    }

    /// Enters work away from the Mac until `until` and ends it (the caller
    /// starts recording).
    mutating func endAway(_ until: TTDateTime) {
        guard onAway else { return }
        if let since = pausedSince {
            let end = Swift.max(until, since)
            // Saved in between was the running work away from the Mac up to
            // "now"; if it ends earlier (at the end of work, say) the rest goes.
            if end.date == since.date, let i = days.firstIndex(where: { $0.date == end.date }) {
                days[i].cutWork(from: end.secs, to: TTLimits.dayEnd)
            }
            Self.commitWork(&days, since, end, note: away.note(texts))
        }
        pausedSince = until
        pauseReason = .manual
    }

    /// Full-day absence on `date` (see `TTDay.locksEntries`): nothing is
    /// recorded or entered by hand then.
    func absent(_ date: TTDate) -> TTAbsence? {
        guard let d = day(date), d.locksEntries else { return nil }
        return d.absence
    }

    /// State for the restart state and the display. Precedence: absent >
    /// closed > away > break > free day > outside > running > paused.
    func status(_ now: TTDateTime) -> TTStatus {
        if absent(now.date) != nil { return .absent }
        if case .closed = mode(now) { return .closed }
        if let since = pausedSince, onAway { return .away(since: since, activity: away) }
        if let since = pausedSince, onBreak { return .onBreak(since: since) }
        if counting(now.date) == false { return .freeDay }
        if !inFrame(now) { return .outside }
        if isRunning { return .running }
        return .paused
    }

    /// What applies to automatic recording on the free day `date` (see
    /// `TTDay.freeDay`). `nil`: no free day, or nothing recorded there yet.
    func freeDay(_ date: TTDate) -> TTFreeDay? {
        day(date)?.freeDay
    }

    /// Does automatic recording count on the free day `date`? `nil` as with `freeDay`.
    func counting(_ date: TTDate) -> Bool? {
        freeDay(date)?.counts
    }

    /// Switches "Record today" on or off: the recorded time of the day counts
    /// (backwards from the first unlock) or no longer counts. After all
    /// entries were deleted (`TTFreeDay.stopped`) the caller records again.
    @discardableResult
    mutating func setCounting(_ date: TTDate, on: Bool) -> Bool {
        let state: TTFreeDay = on ? .counted : .uncounted
        if absent(date) != nil || freeDay(date) == state { return false }
        days[dayIndex(date)].freeDay = state
        return true
    }

    /// First recording on a free day: the time only counts after "Record today".
    private mutating func markFreeDay(_ date: TTDate) {
        if !settings.autoCountsOn(date) && freeDay(date) == nil {
            days[dayIndex(date)].freeDay = .uncounted
        }
    }

    private func day(_ date: TTDate) -> TTDay? {
        days.first { $0.date == date }
    }

    /// Index of the day `date`, inserting an empty one if needed (`day_mut`).
    private mutating func dayIndex(_ date: TTDate) -> Int {
        TTDay.index(of: date, in: &days)
    }

    private mutating func cleanup() {
        days.removeAll { $0.isEmpty }
    }

    /// Today's mode (end of work or automatic).
    func mode(_ now: TTDateTime) -> TTMode {
        day(now.date)?.mode ?? .auto
    }

    /// Starts automatic recording. Nothing happens on a full-day absence.
    /// After the end of work recording goes on; nothing of it counts while the
    /// end stands. Ends "Keep working away from the Mac" (the time until now
    /// counts as work away from the Mac).
    @discardableResult
    mutating func start(_ now: TTDateTime) -> Bool {
        if runningSince != nil || absent(now.date) != nil || freeDay(now.date) == .stopped { return false }
        endAway(now)
        markFreeDay(now.date)
        runningSince = now
        pausedSince = nil
        return true
    }

    @discardableResult
    mutating func stop(_ now: TTDateTime, reason: TTPauseReason) -> Bool {
        guard let since = runningSince else {
            // Working away from the Mac: lock, sleep or quitting change nothing.
            if onAway { return false }
            // Already stopped: only make the reason more precise.
            if reason != .manual { pauseReason = reason }
            return false
        }
        runningSince = nil
        Self.commit(&days, since, now)
        pausedSince = now
        pauseReason = reason
        return true
    }

    /// Day change: splits the running period at midnight. Returns `true` when
    /// something changed (then save).
    @discardableResult
    mutating func rollOver(_ now: TTDateTime) -> Bool {
        var changed = false
        if let since = runningSince, now.date > since.date {
            let midnight = TTDateTime(now.date, 0)
            Self.commit(&days, since, midnight)
            runningSince = midnight
            // Absent all day today: nothing is recorded from midnight on.
            if absent(now.date) != nil {
                runningSince = nil
                pausedSince = midnight
                pauseReason = .manual
            } else {
                markFreeDay(now.date)
            }
            changed = true
        }
        if onAway, let since = pausedSince, now.date > since.date {
            // Nobody chose "Back at the Mac" until midnight: forgotten. The work
            // away from the Mac ends with the working-time frame; after it, it
            // would not count anyway but would stand as work until midnight
            // (and shorten the rest). Begun after the frame, it goes entirely.
            let start = TTDateTime(since.date, 0)
            let frameTo = settings.rules(since.date).frameTo
            let until = Swift.max(since, start.adding(seconds: frameTo))
            let note = away.note(texts)
            endAway(until)
            if until > since {
                let to = until.date > since.date ? TTLimits.dayEnd : until.secs
                forgotten = TTForgottenAway(date: since.date, block: TTWorkBlock(from: since.secs, to: to, note: note))
            }
            // After it, recording only starts again after the next unlock.
            pausedSince = TTDateTime(since.date.adding(days: 1), 0)
            changed = true
        }
        return changed
    }

    /// All days including the running period or the running work away from
    /// the Mac up to `now` (for display and saving).
    func snapshot(_ now: TTDateTime) -> [TTDay] {
        var days = self.days
        if let since = runningSince {
            Self.commit(&days, since, now)
        }
        if onAway, let since = pausedSince {
            Self.commitWork(&days, since, now, note: away.note(texts))
        }
        return days
    }

    /// Today's breaks (gaps between the blocks of work).
    func pausesToday(_ now: TTDateTime) -> [TTSpan] {
        snapshot(now).first { $0.date == now.date }?.pauses(settings) ?? []
    }

    /// Enters work away from the Mac afterwards (counting a break as working time, say).
    mutating func addWork(_ date: TTDate, from: Int, to: Int, note: String) {
        if absent(date) != nil { return }
        days[dayIndex(date)].addWork(from: from, to: to, note: note)
        cleanup()
    }

    /// Deletes work away from the Mac from `from` to `to`; the time counts as
    /// recorded again (a lock from the minimum break on is a break again). If
    /// the running work away from the Mac lies in it, it ends without an
    /// entry; then this returns `true` and the caller may start recording.
    @discardableResult
    mutating func removeWork(_ date: TTDate, from: Int, to: Int, now: TTDateTime) -> Bool {
        if absent(date) != nil { return false }
        var to = to
        let runningAway = onAway
            && pausedSince.map { $0.date == date && from <= $0.secs && $0.secs <= to } == true
        if runningAway {
            // Saved in between was the running work away from the Mac up to "now".
            if now.date == date { to = Swift.max(to, now.secs) }
            pauseReason = .manual
        }
        if let i = days.firstIndex(where: { $0.date == date }) {
            days[i].cutWork(from: from, to: to)
        }
        cleanup()
        return runningAway
    }

    func today(_ now: TTDateTime) -> TTTodayInfo {
        let snap = snapshot(now)
        let s = settings
        let date = now.date
        let monday = date.adding(days: -date.weekday)
        let week = s.balance(snap, from: monday, to: date, today: date)
        var info = TTTodayInfo()
        info.targetSecs = s.dailyTarget(date)
        info.weekBalance = week.work - week.target
        info.account = s.account(snap, today: date)
        guard let d = snap.first(where: { $0.date == date }) else { return info }
        // With an absence its target applies (half a day of vacation: half).
        info.targetSecs = s.dayTarget(date, absence: d.absence)
        if let rec = d.record(s) {
            info.workSecs = rec.shownWorkSecs
            info.pauseSecs = rec.shownPauseSecs
            info.firstStart = rec.workSecs > 0 || d.start != nil ? rec.firstStart : nil
        }
        info.stretchSecs = TTDay.currentStretchSecs(d.spans(s))
        info.startManual = d.start != nil
        info.autoFirst = d.autoBoundsInFrame(s)?.from
        info.mode = d.mode
        info.warnings = TTWarning.dayWarnings(snap, date: date, settings: s)
        return info
    }

    /// Hands only the days that changed since the last load or save to
    /// `write` (changed or new days, then removed ones), so corrections from
    /// the records window on other days survive. When `write` throws nothing
    /// counts as saved and the next save tries again (`tracker.rs` `save`).
    mutating func save(_ now: TTDateTime, write: ([TTDay], [TTDate]) throws -> Void) rethrows {
        let snap = snapshot(now)
        let (changed, removed) = Self.diff(saved, snap)
        try write(changed, removed)
        saved = snap
    }

    /// Changed or new days, and days that no longer exist.
    static func diff(_ old: [TTDay], _ new: [TTDay]) -> (changed: [TTDay], removed: [TTDate]) {
        let changed = new.filter { d in old.first { $0.date == d.date } != d }
        let removed = old.filter { o in !new.contains { $0.date == o.date } }.map(\.date)
        return (changed, removed)
    }

    // MARK: Manual decisions (always for today)

    /// Sets the start of work (`nil`: the first unlock again).
    ///
    /// Work away from the Mac before the new start goes (the latest entry
    /// wins); what went comes back. Running work away from the Mac only counts
    /// from the start. A start not before the end of work is refused (see
    /// `TTDay.boundsInOrder`).
    mutating func setStart(_ now: TTDateTime, at: Int?) -> Result<[TTWorkBlock], TTRefused> {
        if absent(now.date) != nil { return .success([]) }
        let at = at.map { Swift.min($0, now.secs) }
        if case let .closed(end) = mode(now), !TTDay.boundsInOrder(start: at, end: end) {
            return .failure(.startNotBeforeEnd(end))
        }
        if let at, onAway, let since = pausedSince, since.date == now.date, since.secs < at {
            pausedSince = TTDateTime(now.date, at)
        }
        let cut = days[dayIndex(now.date)].setStart(at)
        cleanup()
        return .success(cut)
    }

    /// End of work at `at` (at most now). Work away from the Mac after it goes
    /// (the latest entry wins); what went comes back. Recording goes on but
    /// nothing counts any more.
    ///
    /// Refused is an end with which the day would count nothing: before the
    /// working-time frame (shortly after midnight the evening before is meant;
    /// the new day would otherwise stay locked until someone takes the end
    /// back) or not after the manual start. During "Pause work" the day ends
    /// with the break, not only now: the break before must not become work.
    mutating func closeDay(_ now: TTDateTime, at: Int) -> Result<[TTWorkBlock], TTRefused> {
        if absent(now.date) != nil { return .success([]) }
        var at = at.ttClamped(0, now.secs)
        let frameFrom = settings.rules(now.date).frameFrom
        if at <= frameFrom { return .failure(.endBeforeFrame(frameFrom)) }
        if onBreak, let since = pausedSince, since.date == now.date {
            at = Swift.min(at, since.secs)
        }
        if let start = day(now.date)?.start, !TTDay.boundsInOrder(start: start, end: at) {
            return .failure(.endNotAfterStart(start))
        }
        if onAway {
            endAway(TTDateTime(now.date, at))
        }
        return .success(days[dayIndex(now.date)].setEnd(at))
    }

    /// Takes the end of work back. The caller starts recording (if unlocked).
    mutating func reopenDay(_ now: TTDateTime) {
        if absent(now.date) != nil { return }
        if let i = days.firstIndex(where: { $0.date == now.date }) {
            days[i].end = nil
        }
        cleanup()
    }

    /// Reads the days again after the database changed from outside (the
    /// records window). The running period stays; times saved twice merge.
    mutating func replaceDays(_ newDays: [TTDay], settings: TTSettings, now: TTDateTime) {
        // Day deleted in the records window: what runs counts only from now,
        // or the next save would bring the running period or work away from
        // the Mac back from its start. Deleted means: no entries any more (on
        // a free day the decision about recording stays).
        func hasEntries(_ list: [TTDay], _ date: TTDate) -> Bool {
            list.contains { $0.date == date && $0.hasEntries }
        }
        let saved = self.saved
        func deleted(_ since: TTDateTime) -> Bool {
            hasEntries(saved, since.date) && !hasEntries(newDays, since.date)
        }
        if let since = runningSince, deleted(since) {
            runningSince = now
        }
        if onAway, let since = pausedSince, deleted(since) {
            pausedSince = now
        }
        self.saved = newDays
        days = newDays
        self.settings = settings
        if case let .closed(at) = mode(now), onAway {
            // End of work in the records window: work away from the Mac ends with it.
            endAway(TTDateTime(now.date, at.ttClamped(0, now.secs)))
        }
        // Absent all day today (entered in the records window): what runs ends
        // without an entry; the day takes no times.
        if absent(now.date) != nil && (runningSince?.date == now.date || onAway) {
            runningSince = nil
            pausedSince = now
            pauseReason = .manual
        }
        // Free day, all entries deleted: recording stays off (without an entry).
        if freeDay(now.date) == .stopped && runningSince?.date == now.date {
            runningSince = nil
            pausedSince = now
            pauseReason = .manual
        }
        syncFreeDay(now.date)
    }

    /// After changed settings (workdays, "only on workdays"): if today is no
    /// longer a free day, recording counts again; if it became one while
    /// recording runs, it only counts after "Record today", as at the first unlock.
    mutating func syncFreeDay(_ today: TTDate) {
        if settings.autoCountsOn(today) {
            if counting(today) == false {
                days[dayIndex(today)].freeDay = nil
                cleanup()
            }
        } else if runningSince != nil {
            markFreeDay(today)
        }
    }

    /// Enters work away from the Mac from `start` to `end` (spread over the
    /// days across midnight).
    private static func commitWork(_ days: inout [TTDay], _ start: TTDateTime, _ end: TTDateTime, note: String) {
        if end <= start { return }
        var s = start
        while s.date < end.date {
            days[TTDay.index(of: s.date, in: &days)].addWork(from: s.secs, to: TTLimits.dayEnd, note: note)
            s = TTDateTime(s.date.adding(days: 1), 0)
        }
        days[TTDay.index(of: s.date, in: &days)].addWork(from: s.secs, to: end.secs, note: note)
        days.removeAll { $0.isEmpty }
    }

    private static func commit(_ days: inout [TTDay], _ start: TTDateTime, _ end: TTDateTime) {
        if end < start { return }
        var s = start
        while s.date < end.date {
            days[TTDay.index(of: s.date, in: &days)].addPeriod(from: s.secs, to: TTLimits.dayEnd)
            s = TTDateTime(s.date.adding(days: 1), 0)
        }
        // A period ending exactly at midnight gives the new day no empty
        // period (a vacation day would suddenly have an entry, say).
        if s < end || s == start {
            days[TTDay.index(of: s.date, in: &days)].addPeriod(from: s.secs, to: end.secs)
        }
    }
}
