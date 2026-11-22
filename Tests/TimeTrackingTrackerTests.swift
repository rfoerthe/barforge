// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// The tests of Tagwerk's `tracker.rs`, one function per `#[test]`. "Now" is
/// always passed in, like Tagwerk's tests do with their fixed `dt(…)`.
enum TimeTrackingTrackerTests {
    static func run(_ suite: TestSuite) {
        workAndPause(suite)
        manualBreakUntilResumed(suite)
        lockDuringBreakEndsItOnUnlock(suite)
        awayCountsWhileLockedUntilUnlock(suite)
        awayOverMidnightAndFromBreak(suite)
        deletedDayRestartsRunningCapture(suite)
        fullDayAbsenceStopsCapture(suite)
        pauseCountedAsWork(suite)
        removeRunningAwayWork(suite)
        idleEndsAtTheLastInput(suite)
        todayReportsStretchAndAccount(suite)
        midnightSplit(suite)
        shortLockCountsAsWorkLongLockAsPause(suite)
        nothingCountedOutsideFrame(suite)
        closedDayCountsNothingUntilReopened(suite)
        closeDayRefusesWhatWouldCountNothing(suite)
        closeDayDuringABreakEndsWithTheBreak(suite)
        forgottenAwayEndsWithTheFrame(suite)
        manualStartEarlierAndReset(suite)
        startAfterAnAppointmentDropsIt(suite)
        saveWritesOnlyChangedDays(suite)
        freeDayIsRecordedButNotCounted(suite)
        workdaysAndSettingOffCountAsBefore(suite)
        midnightIntoFreeDayAndSettingsChange(suite)
        clearingAnUncountedFreeDayStopsRecording(suite)
    }

    /// November 2026 at `hh:mm` (the 16th is a Monday, the 21st a Saturday).
    static func dt(_ d: Int, _ hh: Int, _ mm: Int) -> TTDateTime {
        TTDateTime(date(d), hour: hh, minute: mm)
    }

    static func date(_ d: Int) -> TTDate { TTDate(year: 2026, month: 11, day: d)! }
    static func hm(_ hh: Int, _ mm: Int) -> Int { hh * 3600 + mm * 60 }
    static let de = TimeTrackingTexts.de

    static func tracker(_ days: [TTDay] = [], _ settings: TTSettings = TTSettings()) -> TTTracker {
        TTTracker(days: days, settings: settings, texts: de)
    }

    /// Frame around the clock.
    static var allDay: TTSettings {
        TTSettings().withRules(TTWorkRules(frameFrom: 0, frameTo: TTLimits.dayEnd))
    }

    /// "Only on workdays" switched off.
    static var everyDay: TTSettings {
        var s = TTSettings()
        s.autoWorkdaysOnly = false
        return s
    }

    private static func workAndPause(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        t.stop(dt(16, 12, 0), reason: .locked)
        t.start(dt(16, 12, 30))
        let info = t.today(dt(16, 13, 0))
        suite.expect(info.workSecs == 4 * 3600 + 30 * 60, "work_and_pause: work")
        suite.expect(info.pauseSecs == 30 * 60, "work_and_pause: pause")
        suite.expect(info.firstStart == hm(8, 0), "work_and_pause: first start")
    }

    private static func manualBreakUntilResumed(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        suite.expect(t.status(dt(16, 9, 0)) == .running, "manual_break: running")
        suite.expect(t.takeBreak(dt(16, 12, 0)), "manual_break: break taken")
        suite.expect(t.onBreak, "manual_break: on break")
        suite.expect(t.status(dt(16, 12, 30)) == .onBreak(since: dt(16, 12, 0)), "manual_break: status break")
        // Nothing counts during the break.
        suite.expect(t.today(dt(16, 12, 30)).workSecs == hm(4, 0), "manual_break: nothing counts during it")
        // App quit: the reason stays "break".
        t.stop(dt(16, 12, 31), reason: .manual)
        suite.expect(t.onBreak, "manual_break: quitting keeps the break")
        suite.expect(t.start(dt(16, 12, 45)), "manual_break: resumed")
        suite.expect(!t.onBreak, "manual_break: no longer on break")
        let info = t.today(dt(16, 13, 0))
        suite.expect(info.workSecs == hm(4, 15), "manual_break: work")
        suite.expect(info.pauseSecs == hm(0, 45), "manual_break: pause")
        // Shorter than the minimum break: counts as working time.
        t.takeBreak(dt(16, 14, 0))
        t.start(dt(16, 14, 10))
        suite.expect(t.today(dt(16, 15, 0)).workSecs == hm(6, 15), "manual_break: short break counts as work")
    }

    private static func lockDuringBreakEndsItOnUnlock(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        t.takeBreak(dt(16, 12, 0))
        t.stop(dt(16, 12, 5), reason: .locked)
        suite.expect(!t.onBreak, "lock_during_break: the lock replaces the break")
        suite.expect(t.status(dt(16, 12, 10)) == .paused, "lock_during_break: paused")
        // Unlocking resumes recording; the break counts from 12:00.
        suite.expect(t.start(dt(16, 12, 40)), "lock_during_break: unlock starts")
        suite.expect(t.today(dt(16, 13, 0)).pauseSecs == hm(0, 40), "lock_during_break: break from 12:00")
        // Restart of the app during a break.
        var t2 = tracker(t.snapshot(dt(16, 13, 0)))
        t2.restoreBreak(since: dt(16, 13, 0))
        suite.expect(t2.status(dt(16, 13, 5)) == .onBreak(since: dt(16, 13, 0)), "lock_during_break: restored break")
    }

    private static func awayCountsWhileLockedUntilUnlock(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        suite.expect(t.goAway(dt(16, 12, 0), activity: .meeting), "away: started")
        suite.expect(t.onAway, "away: on away")
        suite.expect(!t.goAway(dt(16, 12, 1), activity: .call), "away: already running")
        suite.expect(t.status(dt(16, 12, 5)) == .away(since: dt(16, 12, 0), activity: .meeting), "away: status")
        // Locking changes nothing, the time keeps counting.
        suite.expect(!t.stop(dt(16, 12, 5), reason: .locked), "away: lock changes nothing")
        suite.expect(t.onAway, "away: still away after the lock")
        let info = t.today(dt(16, 13, 0))
        suite.expect((info.workSecs, info.pauseSecs) == (hm(5, 0), 0), "away: counts while locked")
        // Quitting the app: stays.
        t.stop(dt(16, 13, 0), reason: .manual)
        suite.expect(t.onAway, "away: survives quitting")
        // Unlocking ends it; the time is entered as work away from the Mac.
        suite.expect(t.start(dt(16, 13, 30)), "away: unlock starts")
        suite.expect(!t.onAway, "away: ended by the unlock")
        suite.expect(t.status(dt(16, 13, 31)) == .running, "away: running again")
        let d = t.days[0]
        suite.expect(d.work.count == 1, "away: one block")
        suite.expect(d.work.first.map { ($0.from, $0.to, $0.note) } ?? (0, 0, "") == (hm(12, 0), hm(13, 30), "Meeting"),
                     "away: the block with its note")
        suite.expect(t.today(dt(16, 14, 0)).workSecs == hm(6, 0), "away: work after")
        // Restart of the app during work away from the Mac.
        var t2 = tracker(t.snapshot(dt(16, 14, 0)))
        t2.restoreAway(since: dt(16, 14, 0), activity: .call)
        suite.expect(t2.today(dt(16, 14, 30)).workSecs == hm(6, 30), "away: restored")
        // End of work during work away from the Mac: it ends with the end of work.
        suite.expect((try? t2.closeDay(dt(16, 15, 0), at: hm(14, 45)).get()) != nil, "away: end of work taken")
        suite.expect(!t2.onAway, "away: ended by the end of work")
        suite.expect(t2.today(dt(16, 16, 0)).workSecs == hm(6, 45), "away: work until the end of work")
        suite.expect(!t2.goAway(dt(16, 16, 0), activity: .other), "away: not after the end of work")
    }

    private static func awayOverMidnightAndFromBreak(_ suite: TestSuite) {
        let allDay = allDay
        var t = tracker([], allDay)
        t.start(dt(16, 22, 0))
        t.takeBreak(dt(16, 22, 30))
        suite.expect(t.goAway(dt(16, 23, 0), activity: .other), "away_over_midnight: from a break")
        // Midnight ends the work away from the Mac (also with the weekend between).
        suite.expect(t.rollOver(dt(18, 0, 10)), "away_over_midnight: rolled over")
        suite.expect(!t.onAway, "away_over_midnight: ended")
        suite.expect(t.days.count == 1, "away_over_midnight: one day")
        suite.expect(t.days.first?.work.first?.to == TTLimits.dayEnd, "away_over_midnight: until midnight")
        suite.expect(t.days.first?.record(allDay)?.pauseSecs == hm(0, 30), "away_over_midnight: the break stays")
        suite.expect(t.start(dt(18, 8, 0)), "away_over_midnight: unlock starts")
        suite.expect(t.today(dt(18, 9, 0)).workSecs == hm(1, 0), "away_over_midnight: the new day")
        // An end of work from outside (records window) ends it as well.
        var t2 = tracker()
        t2.start(dt(16, 8, 0))
        t2.goAway(dt(16, 16, 0), activity: .meeting)
        var days = t2.snapshot(dt(16, 17, 0))
        days[0].end = hm(16, 30)
        t2.replaceDays(days, settings: TTSettings(), now: dt(16, 17, 0))
        suite.expect(!t2.onAway, "away_over_midnight: end of work from outside")
        suite.expect(t2.today(dt(16, 17, 0)).workSecs == hm(8, 30), "away_over_midnight: work until the end")
    }

    private static func deletedDayRestartsRunningCapture(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        // Saved, then all entries of today deleted in the records window.
        var dbDays = t.snapshot(dt(16, 13, 0))
        t.replaceDays(dbDays, settings: TTSettings(), now: dt(16, 13, 0))
        dbDays.removeAll { $0.date == date(16) }
        t.replaceDays(dbDays, settings: TTSettings(), now: dt(16, 13, 30))
        suite.expect(t.isRunning, "deleted_day: recording goes on")
        suite.expect(t.today(dt(16, 14, 0)).workSecs == hm(0, 30), "deleted_day: only from the deletion")
        // Without deleting, the running period stays as it was.
        var t2 = tracker()
        t2.start(dt(16, 8, 0))
        let days = t2.snapshot(dt(16, 13, 0))
        t2.replaceDays(days, settings: TTSettings(), now: dt(16, 13, 0))
        suite.expect(t2.today(dt(16, 14, 0)).workSecs == hm(6, 0), "deleted_day: kept without deleting")
        // Running work away from the Mac also counts only from now after the deletion.
        var t3 = tracker()
        t3.start(dt(16, 8, 0))
        suite.expect(t3.goAway(dt(16, 12, 0), activity: .meeting), "deleted_day: away")
        let days3 = t3.snapshot(dt(16, 13, 0))
        t3.replaceDays(days3, settings: TTSettings(), now: dt(16, 13, 0))
        t3.replaceDays([], settings: TTSettings(), now: dt(16, 13, 30))
        suite.expect(t3.onAway, "deleted_day: still away")
        suite.expect(t3.today(dt(16, 14, 0)).workSecs == hm(0, 30), "deleted_day: away only from now")
    }

    private static func fullDayAbsenceStopsCapture(_ suite: TestSuite) {
        let vacation = TTAbsence(.vacation, half: false)
        var off = TTDay(date: date(17))
        off.absence = vacation
        // Vacation on Tuesday entered ahead; on Monday recording runs into the night.
        var t = tracker([off], TTSettings().withRules(TTWorkRules(frameTo: TTLimits.dayEnd)))
        suite.expect(t.start(dt(16, 22, 0)), "absence: Monday starts")
        // At midnight recording ends: the vacation day takes no time.
        suite.expect(t.rollOver(dt(17, 0, 5)), "absence: rolled over")
        suite.expect(!t.isRunning, "absence: stopped at midnight")
        suite.expect(t.status(dt(17, 9, 0)) == .absent, "absence: status")
        suite.expect(t.absent(date(17)) == vacation, "absence: the absence")
        // Unlocking, commands and entries do nothing.
        suite.expect(!t.start(dt(17, 9, 0)), "absence: unlock does nothing")
        suite.expect(!t.goAway(dt(17, 9, 0), activity: .meeting), "absence: no away")
        suite.expect(t.setStart(dt(17, 9, 0), at: hm(8, 0)) == .success([]), "absence: no start")
        suite.expect(t.closeDay(dt(17, 9, 0), at: hm(9, 0)) == .success([]), "absence: no end")
        t.addWork(date(17), from: hm(10, 0), to: hm(11, 0), note: "Meeting")
        let tue = t.snapshot(dt(17, 12, 0)).first { $0.date == date(17) }
        suite.expect(tue == off, "absence: only the absence")
        // Half a day: recording runs.
        var half = off
        half.absence = TTAbsence(.vacation, half: true)
        var t2 = tracker([half])
        suite.expect(t2.start(dt(17, 9, 0)), "absence: half day starts")
        suite.expect(t2.status(dt(17, 10, 0)) != .absent, "absence: half day is not absent")
        // Entered for the whole day in the records window while recording ran: it ends.
        var t3 = tracker()
        suite.expect(t3.start(dt(17, 9, 0)), "absence: started")
        t3.replaceDays([off], settings: TTSettings(), now: dt(17, 9, 30))
        suite.expect(!t3.isRunning, "absence: stopped by the records window")
        suite.expect(t3.today(dt(17, 10, 0)).workSecs == 0, "absence: nothing counted")
    }

    private static func pauseCountedAsWork(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        t.stop(dt(16, 12, 0), reason: .locked)
        t.start(dt(16, 12, 45))
        let pauses = t.pausesToday(dt(16, 13, 0))
        suite.expect(pauses == [TTSpan(hm(12, 0), hm(12, 45))], "pause_counted: the break")
        guard let pause = pauses.first else { return }
        t.addWork(date(16), from: pause.from, to: pause.to, note: "Telefonat")
        suite.expect(t.pausesToday(dt(16, 13, 0)).isEmpty, "pause_counted: no break left")
        suite.expect(t.today(dt(16, 13, 0)).workSecs == hm(5, 0), "pause_counted: counted as work")
        // Deleted again: the break is back.
        suite.expect(!t.removeWork(date(16), from: pause.from, to: pause.to, now: dt(16, 13, 0)),
                     "pause_counted: nothing running removed")
        suite.expect(t.days[0].work.isEmpty, "pause_counted: block removed")
        suite.expect(t.pausesToday(dt(16, 13, 0)) == pauses, "pause_counted: the break is back")
        suite.expect(t.today(dt(16, 13, 0)).workSecs == hm(4, 15), "pause_counted: work as before")
    }

    private static func removeRunningAwayWork(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        t.stop(dt(16, 12, 0), reason: .locked)
        t.start(dt(16, 12, 30))
        suite.expect(t.goAway(dt(16, 13, 0), activity: .meeting), "remove_running_away: away")
        // Saved in between and read again from outside (as after the records window).
        let days = t.snapshot(dt(16, 13, 20))
        t.replaceDays(days, settings: TTSettings(), now: dt(16, 13, 20))
        suite.expect(t.onAway, "remove_running_away: still away")
        // Deleted in the week view (state of 13:10): ends without an entry.
        suite.expect(t.removeWork(date(16), from: hm(13, 0), to: hm(13, 10), now: dt(16, 13, 30)),
                     "remove_running_away: the running block")
        suite.expect(!t.onAway, "remove_running_away: ended")
        suite.expect(t.days[0].work.isEmpty, "remove_running_away: no entry")
        suite.expect(t.start(dt(16, 13, 30)), "remove_running_away: recording again")
        suite.expect(t.pausesToday(dt(16, 14, 0)) == [TTSpan(hm(12, 0), hm(12, 30)), TTSpan(hm(13, 0), hm(13, 30))],
                     "remove_running_away: both breaks")
        // Another block leaves running work away from the Mac untouched.
        t.addWork(date(16), from: hm(12, 0), to: hm(12, 30), note: "Telefonat")
        t.goAway(dt(16, 14, 0), activity: .call)
        suite.expect(!t.removeWork(date(16), from: hm(12, 0), to: hm(12, 30), now: dt(16, 14, 10)),
                     "remove_running_away: another block")
        suite.expect(t.onAway, "remove_running_away: still away after another block")
    }

    private static func idleEndsAtTheLastInput(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        // At 10:12 it shows: no input since 10:00.
        suite.expect(t.goIdle(lastInput: dt(16, 10, 0)), "idle: went idle")
        suite.expect(t.onIdle && !t.isRunning, "idle: on idle")
        suite.expect(t.status(dt(16, 10, 12)) == .paused, "idle: paused")
        suite.expect(t.lockedSince == nil, "idle: no lock, no question")
        suite.expect(!t.goIdle(lastInput: dt(16, 10, 5)), "idle: not running any more")
        // Back after 40 min: a break from the last input.
        suite.expect(t.start(dt(16, 10, 40)), "idle: back")
        suite.expect(!t.onIdle, "idle: no longer idle")
        let info = t.today(dt(16, 11, 0))
        suite.expect((info.workSecs, info.pauseSecs) == (hm(2, 20), hm(0, 40)), "idle: break from the last input")
        // Only briefly away (under the minimum break): keeps counting as work.
        t.goIdle(lastInput: dt(16, 11, 0))
        t.start(dt(16, 11, 10))
        suite.expect(t.today(dt(16, 11, 30)).workSecs == hm(2, 50), "idle: short idle counts")
        // Locked meanwhile: a lock since the last input.
        t.goIdle(lastInput: dt(16, 12, 0))
        t.stop(dt(16, 12, 20), reason: .locked)
        suite.expect(!t.onIdle, "idle: the lock replaces idle")
        suite.expect(t.lockedSince == dt(16, 12, 0), "idle: locked since the last input")
        // The last input never lies before the start of the running period.
        var t2 = tracker()
        t2.start(dt(16, 8, 0))
        t2.goIdle(lastInput: dt(16, 7, 30))
        suite.expect(t2.pausedSince == dt(16, 8, 0), "idle: not before the period")
    }

    private static func todayReportsStretchAndAccount(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        t.stop(dt(16, 10, 0), reason: .locked)
        t.start(dt(16, 10, 5)) // 5 min: no break, the stretch goes on
        suite.expect(t.today(dt(16, 11, 0)).stretchSecs == hm(3, 0), "stretch: goes on")
        t.stop(dt(16, 12, 0), reason: .locked)
        t.start(dt(16, 12, 30)) // 30 min break: new
        let info = t.today(dt(16, 13, 0))
        suite.expect(info.stretchSecs == hm(0, 30), "stretch: new after a break")
        // Time account: the running day stays at zero until the target is
        // reached; what is missing only counts with the end of work. Plus the carry.
        suite.expect(info.account == 0, "account: zero")
        t.settings.accountCarry = hm(10, 0)
        suite.expect(t.today(dt(16, 13, 0)).account == hm(10, 0), "account: the carry")
        suite.expect((try? t.closeDay(dt(16, 13, 0), at: hm(13, 0)).get()) != nil, "account: end of work")
        suite.expect(t.today(dt(16, 13, 0)).account == hm(10, 0) + hm(4, 30) - hm(7, 48), "account: after the end")
    }

    private static func midnightSplit(_ suite: TestSuite) {
        let allDay = allDay
        var t = tracker([], allDay)
        t.start(dt(16, 23, 0))
        t.rollOver(dt(17, 0, 30))
        t.stop(dt(17, 1, 0), reason: .manual)
        suite.expect(t.days.count == 2, "midnight_split: two days")
        suite.expect(t.days.first?.record(allDay)?.workSecs == 3600, "midnight_split: first day")
        suite.expect(t.days.last?.record(allDay)?.workSecs == 3600, "midnight_split: second day")
        // Within the default frame (07:00–22:00) none of it counts.
        suite.expect(t.days.first?.record(TTSettings())?.workSecs == 0, "midnight_split: outside the frame")
    }

    private static func shortLockCountsAsWorkLongLockAsPause(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        t.stop(dt(16, 10, 0), reason: .locked)
        t.start(dt(16, 10, 10)) // locked 10 min
        t.stop(dt(16, 12, 0), reason: .locked)
        t.start(dt(16, 12, 40)) // locked 40 min
        let info = t.today(dt(16, 13, 0))
        suite.expect(info.workSecs == hm(4, 20), "short_lock: work")
        suite.expect(info.pauseSecs == hm(0, 40), "short_lock: pause")
        suite.expect(info.targetSecs == hm(7, 48), "short_lock: target")
        // Today the target only counts as far as it is worked: no minus on the running day.
        suite.expect(info.weekBalance == 0, "short_lock: no minus today")
        // The day after, the rest is missing.
        t.stop(dt(16, 13, 0), reason: .locked)
        suite.expect(t.today(dt(17, 6, 0)).weekBalance == hm(4, 20) - hm(7, 48), "short_lock: missing the day after")
    }

    private static func nothingCountedOutsideFrame(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 6, 30))
        suite.expect(!t.inFrame(dt(16, 6, 59)), "outside_frame: before")
        suite.expect(t.inFrame(dt(16, 7, 0)), "outside_frame: from 07:00")
        let early = t.today(dt(16, 6, 50))
        suite.expect(early.workSecs == 0 && early.firstStart == nil, "outside_frame: nothing before the frame")
        let info = t.today(dt(16, 8, 0))
        suite.expect(info.workSecs == hm(1, 0) && info.firstStart == hm(7, 0), "outside_frame: from the frame")
        if info.warnings.count == 1, case let .outsideFrame(spans, _) = info.warnings[0] {
            suite.expect(spans.count == 1, "outside_frame: one span")
        } else {
            suite.expect(false, "outside_frame: exactly one warning about it, got \(info.warnings)")
        }
        suite.expect(info.autoFirst == hm(7, 0), "outside_frame: first unlock in the frame")
    }

    private static func closedDayCountsNothingUntilReopened(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        suite.expect((try? t.closeDay(dt(16, 17, 20), at: hm(17, 0)).get()) != nil, "closed_day: end of work")
        // Recording goes on, also after a lock, but nothing counts.
        suite.expect(t.isRunning, "closed_day: still recording")
        suite.expect(t.status(dt(16, 17, 30)) == .closed, "closed_day: status")
        t.stop(dt(16, 17, 40), reason: .locked)
        suite.expect(t.start(dt(16, 18, 0)), "closed_day: unlock records")
        suite.expect(t.today(dt(16, 20, 0)).workSecs == hm(9, 0), "closed_day: nothing after the end counts")
        // End taken back: the time between is back (the 20 min lock is a break).
        t.reopenDay(dt(16, 20, 0))
        let info = t.today(dt(16, 20, 0))
        suite.expect((info.workSecs, info.pauseSecs) == (hm(11, 40), hm(0, 20)), "closed_day: reopened")
        // Next day: automatic again.
        var t2 = tracker()
        t2.start(dt(16, 8, 0))
        _ = t2.closeDay(dt(16, 17, 0), at: hm(17, 0))
        t2.stop(dt(16, 18, 0), reason: .locked)
        suite.expect(t2.start(dt(17, 8, 0)), "closed_day: next day starts")
        suite.expect(t2.today(dt(17, 9, 0)).workSecs == hm(1, 0), "closed_day: next day counts")
    }

    private static func closeDayRefusesWhatWouldCountNothing(_ suite: TestSuite) {
        // Shortly after midnight the evening before is meant: the new day stays open.
        var t = tracker()
        t.start(dt(16, 21, 0))
        t.rollOver(dt(17, 0, 10))
        suite.expect(t.closeDay(dt(17, 0, 10), at: hm(0, 10)) == .failure(.endBeforeFrame(hm(7, 0))),
                     "close_day_refuses: before the frame")
        suite.expect(t.mode(dt(17, 0, 10)) == .auto, "close_day_refuses: still automatic")
        t.stop(dt(17, 0, 20), reason: .locked)
        t.start(dt(17, 8, 0))
        suite.expect(t.today(dt(17, 9, 0)).workSecs == hm(1, 0), "close_day_refuses: the day counts")
        // End not after the manual start, and the other way round.
        suite.expect((try? t.setStart(dt(17, 9, 0), at: hm(8, 30)).get()) != nil, "close_day_refuses: start set")
        suite.expect(t.closeDay(dt(17, 9, 0), at: hm(8, 30)) == .failure(.endNotAfterStart(hm(8, 30))),
                     "close_day_refuses: not after the start")
        suite.expect(t.mode(dt(17, 9, 0)) == .auto, "close_day_refuses: still automatic after refusing")
        t.addWork(date(17), from: hm(10, 0), to: hm(11, 0), note: "Meeting")
        suite.expect((try? t.closeDay(dt(17, 12, 0), at: hm(12, 0)).get()) != nil, "close_day_refuses: end set")
        suite.expect(t.setStart(dt(17, 13, 0), at: hm(12, 30)) == .failure(.startNotBeforeEnd(hm(12, 0))),
                     "close_day_refuses: start not before the end")
        // Nothing changed: start, work away from the Mac and working time stand.
        let d = t.days.first { $0.date == date(17) }
        suite.expect(d?.start == hm(8, 30) && d?.end == hm(12, 0) && d?.work.count == 1,
                     "close_day_refuses: nothing changed")
        suite.expect(t.today(dt(17, 13, 0)).workSecs == hm(3, 30), "close_day_refuses: work stands")
        suite.expect(TTRefused.startNotBeforeEnd(hm(12, 0)).text(de).contains("12:00"), "close_day_refuses: text")
    }

    private static func closeDayDuringABreakEndsWithTheBreak(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        t.takeBreak(dt(16, 16, 0))
        // "End of work → Now" half an hour later: the break does not become work.
        _ = t.closeDay(dt(16, 16, 30), at: hm(16, 30))
        suite.expect(t.mode(dt(16, 16, 30)) == .closed(hm(16, 0)), "close_during_break: ends with the break")
        suite.expect(t.today(dt(16, 17, 0)).workSecs == hm(8, 0), "close_during_break: work")
        // An earlier end stays as chosen.
        var t2 = tracker()
        t2.start(dt(16, 8, 0))
        t2.takeBreak(dt(16, 16, 0))
        _ = t2.closeDay(dt(16, 16, 30), at: hm(15, 0))
        suite.expect(t2.today(dt(16, 17, 0)).workSecs == hm(7, 0), "close_during_break: earlier end")
    }

    private static func forgottenAwayEndsWithTheFrame(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 0))
        t.goAway(dt(16, 17, 0), activity: .meeting)
        // Saved in between: up to "now".
        let snap = t.snapshot(dt(16, 23, 0))
        suite.expect(snap.first?.work.first?.to == hm(23, 0), "forgotten_away: saved up to now")
        suite.expect(t.rollOver(dt(17, 7, 30)), "forgotten_away: rolled over")
        suite.expect(!t.onAway, "forgotten_away: ended")
        let d = t.days[0]
        suite.expect(d.work.first.map { ($0.from, $0.to) } ?? (0, 0) == (hm(17, 0), hm(22, 0)),
                     "forgotten_away: until the end of the frame")
        suite.expect(t.forgotten?.date == date(16), "forgotten_away: the day")
        suite.expect(t.forgotten?.block.describe(de) == "Meeting 17:00–22:00", "forgotten_away: the block")
        let warnings = TTWarning.dayWarnings(t.days, date: date(16), settings: t.settings)
        suite.expect(warnings.allSatisfy { if case .outsideFrame = $0 { return false } else { return true } },
                     "forgotten_away: nothing outside the frame")
        // Begun only after the frame: it counted nothing anyway; no entry, no message.
        var t2 = tracker()
        t2.start(dt(16, 8, 0))
        t2.goAway(dt(16, 22, 30), activity: .meeting)
        t2.rollOver(dt(17, 7, 30))
        suite.expect(t2.days[0].work.isEmpty && t2.forgotten == nil, "forgotten_away: after the frame")
        suite.expect(t2.start(dt(17, 8, 0)), "forgotten_away: unlock starts")
    }

    private static func manualStartEarlierAndReset(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(16, 8, 12))
        _ = t.setStart(dt(16, 9, 0), at: hm(7, 30))
        let info = t.today(dt(16, 9, 0))
        suite.expect(info.workSecs == hm(1, 30), "manual_start: earlier")
        suite.expect(info.startManual, "manual_start: manual")
        suite.expect(info.autoFirst == hm(8, 12), "manual_start: first unlock")
        _ = t.setStart(dt(16, 9, 0), at: nil)
        suite.expect(t.today(dt(16, 9, 0)).workSecs == hm(0, 48), "manual_start: reset")
    }

    private static func startAfterAnAppointmentDropsIt(_ suite: TestSuite) {
        // An appointment away from the Mac in the morning; later the day should only start at 09:20.
        var t = tracker()
        t.start(dt(16, 8, 0))
        t.goAway(dt(16, 8, 5), activity: .meeting)
        t.start(dt(16, 9, 0))
        suite.expect(t.today(dt(16, 10, 0)).firstStart == hm(8, 0), "start_after_appointment: first start")
        let cut = (try? t.setStart(dt(16, 10, 0), at: hm(9, 20)).get()) ?? []
        suite.expect(cut.map { $0.describe(de) } == ["Meeting 08:05–09:00"], "start_after_appointment: cut")
        let info = t.today(dt(16, 10, 0))
        suite.expect(info.firstStart == hm(9, 20) && info.workSecs == hm(0, 40), "start_after_appointment: from 09:20")
        // End of work before an entered appointment: the appointment goes.
        t.addWork(date(16), from: hm(9, 40), to: hm(9, 55), note: "Telefonat")
        let cut2 = (try? t.closeDay(dt(16, 10, 0), at: hm(9, 30)).get()) ?? []
        suite.expect(cut2.count == 1, "start_after_appointment: cut by the end")
        suite.expect(t.today(dt(16, 10, 0)).workSecs == hm(0, 10), "start_after_appointment: until the end")
        // Running work away from the Mac only counts from the new start.
        var t2 = tracker()
        t2.goAway(dt(16, 8, 0), activity: .call)
        suite.expect(t2.setStart(dt(16, 9, 0), at: hm(8, 30)) == .success([]), "start_after_appointment: running away")
        suite.expect(t2.today(dt(16, 9, 0)).workSecs == hm(0, 30), "start_after_appointment: from the start")
    }

    private static func saveWritesOnlyChangedDays(_ suite: TestSuite) {
        var old = TTDay(date: date(10))
        old.addPeriod(from: hm(8, 0), to: hm(9, 0))
        var t = tracker([old])
        t.start(dt(16, 8, 0))
        let snap = t.snapshot(dt(16, 9, 0))
        let (changed, removed) = TTTracker.diff(t.saved, snap)
        suite.expect(changed.count == 1, "save_writes_only_changed: one day")
        suite.expect(changed.first?.date == date(16), "save_writes_only_changed: today")
        suite.expect(removed.isEmpty, "save_writes_only_changed: nothing removed")
        let (changed2, removed2) = TTTracker.diff(snap, Array(snap[1...]))
        suite.expect(changed2.isEmpty, "save_writes_only_changed: nothing changed")
        suite.expect(removed2 == [old.date], "save_writes_only_changed: removed")
        // `save` hands the diff over and remembers the state only when writing worked.
        struct Failed: Error {}
        var written: [[TTDate]] = []
        try? t.save(dt(16, 9, 0)) { _, _ in throw Failed() }
        t.save(dt(16, 9, 0)) { changed, _ in written.append(changed.map(\.date)) }
        t.save(dt(16, 9, 0)) { changed, _ in written.append(changed.map(\.date)) }
        suite.expect(written == [[date(16)], []], "save_writes_only_changed: retried after a failure, then nothing")
    }

    private static func freeDayIsRecordedButNotCounted(_ suite: TestSuite) {
        // Saturday, 21 November 2026
        var t = tracker()
        t.start(dt(21, 10, 0))
        suite.expect(t.counting(date(21)) == false, "free_day: not counted")
        suite.expect(t.status(dt(21, 11, 0)) == .freeDay, "free_day: status")
        suite.expect(t.today(dt(21, 11, 0)).workSecs == 0, "free_day: no work")
        // Recorded anyway: counted afterwards from the first unlock.
        suite.expect(t.setCounting(date(21), on: true), "free_day: record today")
        suite.expect(t.status(dt(21, 11, 0)) == .running, "free_day: running")
        suite.expect(t.today(dt(21, 11, 0)).workSecs == hm(1, 0), "free_day: counted from the first unlock")
        // After unlocking again it stays so.
        t.stop(dt(21, 12, 0), reason: .locked)
        t.start(dt(21, 13, 0))
        suite.expect(t.counting(date(21)) == true, "free_day: still counted")
        // And off again.
        suite.expect(t.setCounting(date(21), on: false), "free_day: off again")
        suite.expect(t.today(dt(21, 14, 0)).workSecs == 0, "free_day: not counted again")
    }

    private static func workdaysAndSettingOffCountAsBefore(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(20, 8, 0)) // Friday
        suite.expect(t.counting(date(20)) == nil, "workdays: Friday is a workday")
        suite.expect(t.status(dt(20, 9, 0)) == .running, "workdays: running")
        // Friday deselected: a free day.
        var t2 = tracker([], TTSettings().withRules(TTWorkRules(workdays: 0b0_1111)))
        t2.start(dt(20, 8, 0))
        suite.expect(t2.status(dt(20, 9, 0)) == .freeDay, "workdays: deselected Friday")
        // Setting off: everything counts, also on Saturday.
        var t3 = tracker([], everyDay)
        t3.start(dt(21, 8, 0))
        suite.expect(t3.counting(date(21)) == nil, "workdays: setting off")
        suite.expect(t3.today(dt(21, 9, 0)).workSecs == hm(1, 0), "workdays: Saturday counts")
    }

    private static func midnightIntoFreeDayAndSettingsChange(_ suite: TestSuite) {
        // Friday 23:00 to Saturday 01:00: not counted from midnight on.
        var t = tracker()
        t.start(dt(20, 23, 0))
        suite.expect(t.rollOver(dt(21, 0, 30)), "midnight_free_day: rolled over")
        suite.expect(t.counting(date(21)) == false, "midnight_free_day: Saturday not counted")
        suite.expect(t.counting(date(20)) == nil, "midnight_free_day: Friday as always")
        // Setting switched off: today counts again.
        let days = t.snapshot(dt(21, 1, 0))
        t.replaceDays(days, settings: everyDay, now: dt(21, 1, 0))
        suite.expect(t.counting(date(21)) == nil, "midnight_free_day: counts again")
        // And on again: what is recorded right now only counts after "Record today".
        t.replaceDays(t.snapshot(dt(21, 1, 0)), settings: TTSettings(), now: dt(21, 1, 0))
        suite.expect(t.counting(date(21)) == false, "midnight_free_day: not counted again")
    }

    private static func clearingAnUncountedFreeDayStopsRecording(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(21, 1, 0))
        suite.expect(t.freeDay(date(21)) == .uncounted, "clearing_free_day: uncounted")
        // "Delete all entries" in the records window: only the decision stays.
        var cleared = TTDay(date: date(21))
        cleared.freeDay = .stopped
        t.replaceDays([cleared], settings: TTSettings(), now: dt(21, 1, 23))
        suite.expect(!t.isRunning, "clearing_free_day: stopped")
        suite.expect(t.snapshot(dt(21, 1, 30)) == [cleared], "clearing_free_day: no new period from now")
        suite.expect(t.status(dt(21, 1, 30)) == .freeDay, "clearing_free_day: status")
        // Unlocking starts nothing …
        suite.expect(!t.start(dt(21, 9, 0)), "clearing_free_day: unlock starts nothing")
        // … until "Record today": then it counts from now.
        suite.expect(t.setCounting(date(21), on: true), "clearing_free_day: record today")
        suite.expect(t.start(dt(21, 9, 0)), "clearing_free_day: starts")
        suite.expect(t.today(dt(21, 10, 0)).workSecs == hm(1, 0), "clearing_free_day: counts from now")

        // Also with "Record today": after deleting, the tick is gone and recording off.
        var t2 = tracker()
        t2.start(dt(22, 9, 0))
        t2.setCounting(date(22), on: true)
        // Saved as in the app (in between, with the running period).
        t2.saved = t2.snapshot(dt(22, 9, 59))
        var cleared2 = TTDay(date: date(22))
        cleared2.freeDay = .stopped
        t2.replaceDays([cleared2], settings: TTSettings(), now: dt(22, 10, 0))
        suite.expect(!t2.isRunning, "clearing_free_day: stopped after record today")
        suite.expect(t2.counting(date(22)) == false, "clearing_free_day: not counting")
        suite.expect(t2.snapshot(dt(22, 11, 0)) == [cleared2], "clearing_free_day: nothing new")
    }
}
