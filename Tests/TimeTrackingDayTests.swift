// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// The tests of Tagwerk's `day.rs`, one function per `#[test]`, plus the
/// calendar maths that replaces chrono.
enum TimeTrackingDayTests {
    static func run(_ suite: TestSuite) {
        calendar(suite)
        fullDayAbsenceNeedsAnEmptyDay(suite)
        automaticOnly(suite)
        laterStartAndEarlierEndCutWorkWithoutMac(suite)
        shownPausesFollowShownMinutes(suite)
        shownWorkFollowsShownMinutes(suite)
        shortLocksCountAsWork(suite)
        frameClipsWorkAndPause(suite)
        earlierStartAddsTime(suite)
        laterStartCutsTime(suite)
        startCountsUntilFirstUnlockAfterIt(suite)
        endCountsFromLastLockBeforeIt(suite)
        breakOverlappingLockIsNotCountedTwice(suite)
        endClipsAndExtends(suite)
        manualDayWithoutPeriods(suite)
        workWithoutMacFillsLockGap(suite)
        shortWorkWithoutMacCountsLikeAnyOther(suite)
        workWithoutMacOutsideStartAndEnd(suite)
        workBlocksStaySeparateAndLatestEntryWins(suite)
        shortGapsToWorkWithoutMacJoinTheNewBlock(suite)
        shortGapsToRecordedWorkJoinTheNewBlock(suite)
        gapsUnderAMinuteJoinWithoutANote(suite)
        restsOfAManualBreakJoinTheNewBlock(suite)
        manualEndCountsFromLastLockEvenWithWorkAfterIt(suite)
        activityIdsRoundTrip(suite)
        legalPauseCountsSegmentsFrom15Minutes(suite)
        periodsMerge(suite)
        clockParsing(suite)
        freeDayCountsOnlyAfterChoosingTo(suite)
        freeDayMarkAloneIsKeptButNoRecord(suite)
        uncountedOnlyWithoutCounting(suite)
        freeDayLabelsRoundTrip(suite)
        uncountedFreeDayIgnoresStartAndEnd(suite)
        startMustPrecedeEnd(suite)
        actualSpansIncludeTimeOutsideTheFrame(suite)
    }

    static func h(_ hh: Int, _ mm: Int) -> Int { hh * 3600 + mm * 60 }
    static func st() -> TTSettings { TTSettings() }
    static func date(_ year: Int, _ month: Int, _ day: Int) -> TTDate { TTDate(year: year, month: month, day: day)! }
    static let de = TimeTrackingTexts.de

    /// 08:12–11:58 and 12:41–17:30 on Monday, 16 November 2026.
    static func day() -> TTDay {
        var d = TTDay(date: date(2026, 11, 16))
        d.addPeriod(from: h(8, 12), to: h(11, 58))
        d.addPeriod(from: h(12, 41), to: h(17, 30))
        return d
    }

    static func work(_ d: TTDay) -> Int? { d.record(st())?.workSecs }

    // MARK: TTDate (replaces chrono)

    private static func calendar(_ suite: TestSuite) {
        suite.expect(date(1, 1, 1).ordinal == 1 && TTDate(ordinal: 1) == date(1, 1, 1),
                     "the ordinal is chrono's num_days_from_ce")
        suite.expect(date(1970, 1, 1).ordinal == 719_163 && date(2026, 11, 16).ordinal == 739_936,
                     "ordinals match chrono for the epoch and a Tagwerk test day")
        var roundTrips = true
        for ordinal in stride(from: -800_000, through: 800_000, by: 997) where TTDate(ordinal: ordinal).ordinal != ordinal {
            roundTrips = false
        }
        suite.expect(roundTrips, "ordinals round-trip, also before the common era")
        suite.expect(date(2026, 11, 16).weekday == 0 && date(2026, 11, 21).weekday == 5
                     && date(2026, 11, 22).weekday == 6 && date(1970, 1, 1).weekday == 3,
                     "weekdays count from Monday = 0")
        suite.expect(date(2026, 11, 21).isWeekend && !date(2026, 11, 20).isWeekend, "Saturday is a weekend day")
        suite.expect(TTDate(year: 2026, month: 2, day: 29) == nil && TTDate(year: 2024, month: 2, day: 29) != nil
                     && TTDate(year: 2000, month: 2, day: 29) != nil && TTDate(year: 1900, month: 2, day: 29) == nil
                     && TTDate(year: 2026, month: 4, day: 31) == nil && TTDate(year: 2026, month: 13, day: 1) == nil,
                     "impossible days do not exist")
        suite.expect(date(2026, 12, 31).adding(days: 1) == date(2027, 1, 1)
                     && date(2024, 3, 1).adding(days: -1) == date(2024, 2, 29)
                     && date(2026, 11, 30).days(since: date(2026, 11, 16)) == 14,
                     "adding and counting days crosses months and years")
        suite.expect(date(2026, 1, 1).isoWeek == (2026, 1) && date(2027, 1, 1).isoWeek == (2026, 53)
                     && date(2024, 12, 30).isoWeek == (2025, 1) && date(2026, 11, 16).isoWeek == (2026, 47),
                     "ISO week numbers")
        suite.expect(date(2026, 3, 5).iso == "2026-03-05" && TTDate(iso: "2026-03-05") == date(2026, 3, 5)
                     && TTDate(iso: " 2026-3-5 ") == date(2026, 3, 5) && TTDate(iso: "2026-02-30") == nil
                     && TTDate(iso: "2026/03/05") == nil && TTDate(iso: "2026-03-") == nil,
                     "dates read and write as YYYY-MM-DD")
        suite.expect(TTDate.min < date(1, 1, 1) && TTDate.min.predecessor == nil && TTDate.max.successor == nil
                     && date(2026, 11, 16).predecessor == date(2026, 11, 15),
                     "the earliest day has no day before it")
    }

    // MARK: day.rs

    private static func fullDayAbsenceNeedsAnEmptyDay(_ suite: TestSuite) {
        let vacation: TTAbsence? = TTAbsence(.vacation, half: false)
        let half: TTAbsence? = TTAbsence(.vacation, half: true)
        let timeOff: TTAbsence? = TTAbsence(.timeOff, half: false)
        func empty() -> TTDay { TTDay(date: date(2026, 11, 16)) }
        var d = empty()
        suite.expect(!d.hasEntries && d.acceptsAbsence(vacation, today: false) && d.acceptsAbsence(timeOff, today: false),
                     "an empty day takes any absence")
        // An absence alone is no entry: it can be changed.
        d.absence = half
        suite.expect(!d.hasEntries && d.acceptsAbsence(vacation, today: false), "an absence alone is no entry")
        // With recorded time or a correction only half days (or none).
        let changes: [(String, (inout TTDay) -> Void)] = [
            ("period", { $0.addPeriod(from: h(8, 0), to: h(12, 0)) }),
            ("start", { $0.start = h(8, 0) }),
            ("end", { $0.end = h(17, 0) }),
            ("break", { $0.addBreak(from: h(12, 0), to: h(12, 30)) }),
            ("work", { $0.addWork(from: h(13, 0), to: h(14, 0), note: "Meeting") }),
        ]
        for (name, change) in changes {
            var busy = empty()
            change(&busy)
            suite.expect(busy.hasEntries, "\(name) is an entry")
            suite.expect(!busy.acceptsAbsence(vacation, today: false) && !busy.acceptsAbsence(timeOff, today: false),
                         "\(name) blocks a whole-day absence")
            suite.expect(busy.acceptsAbsence(half, today: false) && busy.acceptsAbsence(nil, today: false),
                         "\(name) still allows a half day or none")
        }
        // Today only entries by hand count: recorded time goes with the absence.
        var today = empty()
        today.addPeriod(from: h(8, 0), to: h(9, 30))
        suite.expect(!today.acceptsAbsence(vacation, today: false) && today.acceptsAbsence(vacation, today: true),
                     "today recorded time does not block a whole-day absence")
        suite.expect(today.clearsForAbsence(vacation, today: true) && !today.clearsForAbsence(half, today: true),
                     "a whole-day absence today clears the recorded time")
        suite.expect(!today.clearsForAbsence(vacation, today: false), "only today")
        today.addBreak(from: h(9, 0), to: h(9, 15))
        suite.expect(!today.acceptsAbsence(vacation, today: true) && !today.clearsForAbsence(vacation, today: true),
                     "a break by hand blocks it today too")
        // Conversely only a whole-day absence locks the other entries.
        var off = empty()
        suite.expect(!off.locksEntries, "no absence locks nothing")
        off.absence = half
        suite.expect(!off.locksEntries, "half day: working time is possible")
        off.absence = vacation
        suite.expect(off.locksEntries, "a whole vacation day locks the entries")
        off.absence = timeOff
        suite.expect(off.locksEntries, "time off locks the entries")
    }

    private static func automaticOnly(_ suite: TestSuite) {
        let d = day()
        suite.expect(work(d) == h(3, 46) + h(4, 49), "recorded periods are the working time")
        let r = d.record(st())!
        suite.expect((r.firstStart, r.lastEnd) == (h(8, 12), h(17, 30)), "first unlock and last lock")
        suite.expect(r.pauseSecs == h(0, 43), "the lunch lock is a break")
    }

    private static func laterStartAndEarlierEndCutWorkWithoutMac(_ suite: TestSuite) {
        // Unlocked from 09:10; before it a meeting 08:00–09:00, in the evening one 17:00–18:00.
        var d = TTDay(date: date(2026, 11, 16))
        d.addPeriod(from: h(9, 10), to: h(16, 0))
        d.addWork(from: h(8, 0), to: h(9, 0), note: "Meeting")
        d.addWork(from: h(17, 0), to: h(18, 0), note: "Telefonat")
        suite.expect(d.record(st())?.firstStart == h(8, 0), "work away from the Mac starts the day")
        // Start 09:20: the meeting before goes, the day starts at 09:20.
        var cut = d.setStart(h(9, 20))
        suite.expect(cut.map { $0.describe(de) } == ["Meeting 08:00–09:00"], "the cut meeting is returned")
        suite.expect(d.work.count == 1, "one block is left")
        let r = d.record(st())!
        suite.expect((r.firstStart, r.lastEnd) == (h(9, 20), h(18, 0)), "the day runs 09:20–18:00")
        // End 17:30: the call after it ends there.
        cut = d.setEnd(h(17, 30))
        suite.expect(cut == [TTWorkBlock(from: h(17, 30), to: h(18, 0), note: "Telefonat")], "the cut part of the call")
        suite.expect(d.record(st())?.lastEnd == h(17, 30), "the day ends at 17:30")
        // A meeting reaching over the start only starts there.
        d = TTDay(date: date(2026, 11, 17))
        d.addWork(from: h(8, 0), to: h(10, 0), note: "")
        cut = d.setStart(h(9, 20))
        suite.expect(cut.first?.describe(de) == "Arbeit ohne Mac 08:00–09:20", "the part before the start is cut")
        suite.expect(d.work.first?.span == TTSpan(h(9, 20), h(10, 0)), "the rest starts at the start")
        // The latest entry wins: work entered afterwards also counts before the start.
        d.addWork(from: h(7, 30), to: h(8, 0), note: "Telefonat")
        suite.expect(d.record(st())?.firstStart == h(7, 30), "later work counts before the start")
        // Taking start or end back cuts nothing.
        suite.expect(d.setStart(nil).isEmpty && d.setEnd(nil).isEmpty, "clearing start and end cuts nothing")
        suite.expect(d.work.count == 2, "both blocks stay")
    }

    private static func shownPausesFollowShownMinutes(_ suite: TestSuite) {
        // Locked 15:25:40 – 15:45:10: shown 15:25 – 15:45, so 20 min break (not 19).
        var d = TTDay(date: date(2026, 11, 18))
        d.addPeriod(from: h(8, 0), to: h(15, 25) + 40)
        d.addPeriod(from: h(15, 45) + 10, to: h(17, 0))
        let r = d.record(st())!
        suite.expect(r.pauseSecs == h(0, 19) + 30, "the break to the second")
        suite.expect(r.shownPauseSecs == h(0, 20), "the break as shown")
        suite.expect(TTSpan.shownLen(from: h(17, 0) + 19, to: h(17, 30)) == h(0, 30), "shown length ignores seconds")
    }

    private static func shownWorkFollowsShownMinutes(_ suite: TestSuite) {
        // 08:18:50 – 12:00:30 and 12:59:10 – 18:05:20: shown 08:18 – 18:05 with 59 min
        // break, so 8:48 h of work; to the second it would only be 8:47:50.
        var d = TTDay(date: date(2026, 10, 30))
        d.addPeriod(from: h(8, 18) + 50, to: h(12, 0) + 30)
        d.addPeriod(from: h(12, 59) + 10, to: h(18, 5) + 20)
        let r = d.record(st())!
        suite.expect(r.workSecs == h(8, 47) + 50, "work to the second")
        suite.expect(r.shownPauseSecs == h(0, 59), "break as shown")
        suite.expect(r.shownWorkSecs == h(8, 48), "work as shown")
        suite.expect(r.shownWorkSecs + r.shownPauseSecs == TTSpan.shownLen(from: r.firstStart, to: r.lastEnd),
                     "shown work and break add up to the shown day")
    }

    private static func shortLocksCountAsWork(_ suite: TestSuite) {
        var d = day()
        d.periods = [TTSpan(h(8, 0), h(10, 0)), TTSpan(h(10, 14), h(12, 0)), TTSpan(h(12, 15), h(16, 0))]
        // 14 min locked: work; 15 min: break.
        var r = d.record(st())!
        suite.expect((r.workSecs, r.pauseSecs) == (h(7, 45), h(0, 15)), "14 min are work, 15 min a break")
        // With a minimum break of 20 min both gaps count as work.
        let s = st().withRules(TTWorkRules(minPause: 20 * 60))
        r = d.record(s)!
        suite.expect((r.workSecs, r.pauseSecs) == (h(8, 0), 0), "both gaps are work with 20 min")
        // The raw data stays unchanged.
        suite.expect(d.periods.count == 3, "periods stay as recorded")
    }

    private static func frameClipsWorkAndPause(_ suite: TestSuite) {
        var d = TTDay(date: date(2026, 11, 16))
        d.addPeriod(from: h(6, 0), to: h(8, 0))
        d.addPeriod(from: h(21, 0), to: h(23, 30))
        var r = d.record(st())!
        suite.expect((r.firstStart, r.lastEnd) == (h(7, 0), h(22, 0)), "the day is clipped to the frame")
        suite.expect(r.workSecs == h(2, 0), "only work within the frame counts")
        suite.expect(d.outsideFrameSpans(st()) == [TTSpan(h(6, 0), h(7, 0)), TTSpan(h(22, 0), h(23, 30))],
                     "work outside the frame")
        suite.expect(d.autoBoundsInFrame(st()).map { [$0.from, $0.to] } == [h(7, 0), h(22, 0)],
                     "automatic bounds within the frame")
        // Only outside: neither work nor break.
        var late = TTDay(date: d.date)
        late.addPeriod(from: h(22, 30), to: h(23, 30))
        r = late.record(st())!
        suite.expect((r.workSecs, r.pauseSecs) == (0, 0), "only outside the frame: nothing counts")
        suite.expect(late.autoBoundsInFrame(st()) == nil, "no bounds within the frame")
        // A manual start before the frame only counts from the start of the frame.
        var early = day()
        early.start = h(6, 30)
        suite.expect(early.record(st())?.firstStart == h(7, 0), "the start is clipped to the frame")
        suite.expect(early.outsideFrameSpans(st()) == [TTSpan(h(6, 30), h(7, 0))], "the early start lies outside")
    }

    private static func earlierStartAddsTime(_ suite: TestSuite) {
        var d = day()
        d.start = h(7, 30)
        suite.expect(work(d) == h(3, 46) + h(4, 49) + h(0, 42), "an earlier start adds the time before")
        suite.expect(d.record(st())?.firstStart == h(7, 30), "the day starts at the manual start")
    }

    private static func laterStartCutsTime(_ suite: TestSuite) {
        var d = day()
        d.start = h(8, 30)
        suite.expect(work(d) == h(3, 28) + h(4, 49), "a later start cuts the time before")
    }

    private static func startCountsUntilFirstUnlockAfterIt(_ suite: TestSuite) {
        // Start in the lunch gap (locked 11:58–12:41): the time until the unlock
        // counts, the morning goes.
        var d = day()
        d.start = h(12, 30)
        let r = d.record(st())!
        suite.expect((r.firstStart, r.workSecs) == (h(12, 30), h(4, 49) + h(0, 11)), "start in the lunch gap")
        // Unlocked briefly before the start: that does not change the start.
        d = TTDay(date: date(2026, 11, 20))
        d.addPeriod(from: h(8, 30), to: h(12, 0))
        d.start = h(8, 0)
        let before = d.spans(st())
        suite.expect(before == [TTSpan(h(8, 0), h(12, 0))], "start before the first unlock")
        d.addPeriod(from: h(6, 0), to: h(6, 1))
        suite.expect(d.spans(st()) == before, "an early glance changes nothing")
        // Start after the last lock: nothing can count.
        d = day()
        d.start = h(18, 0)
        suite.expect(work(d) == 0, "start after the last lock")
        // Start during a short lock (counts as work): starts exactly there.
        d = TTDay(date: date(2026, 11, 20))
        d.addPeriod(from: h(8, 0), to: h(10, 0))
        d.addPeriod(from: h(10, 10), to: h(12, 0))
        d.start = h(10, 5)
        suite.expect(d.spans(st()) == [TTSpan(h(10, 5), h(12, 0))], "start during a short lock")
        // Start and end in the same gap: only the time between counts.
        d = day()
        d.start = h(12, 5)
        d.end = h(12, 35)
        suite.expect(d.spans(st()) == [TTSpan(h(12, 5), h(12, 35))], "start and end in the same gap")
    }

    private static func endCountsFromLastLockBeforeIt(_ suite: TestSuite) {
        // End in the lunch gap (locked 11:58–12:41): the time since the lock
        // counts, the afternoon goes.
        var d = day()
        d.end = h(12, 20)
        var r = d.record(st())!
        suite.expect((r.lastEnd, r.workSecs) == (h(12, 20), h(3, 46) + h(0, 22)), "end in the lunch gap")
        // Unlocked briefly after the end: that does not change the end.
        d = TTDay(date: date(2026, 11, 20))
        d.addPeriod(from: h(11, 28), to: h(12, 0))
        d.addPeriod(from: h(13, 1), to: h(15, 21))
        d.addWork(from: h(15, 21), to: h(16, 25), note: "Meeting")
        d.end = h(16, 30)
        let before = d.spans(st())
        suite.expect(before.last == TTSpan(h(13, 1), h(16, 30)), "the end counts from the last lock")
        d.addPeriod(from: h(17, 51), to: h(17, 52))
        suite.expect(d.spans(st()) == before, "a late glance changes nothing")
        // End before the first unlock: nothing can count.
        d = day()
        d.end = h(7, 30)
        r = d.record(st())!
        suite.expect((r.firstStart, r.lastEnd, r.workSecs) == (h(8, 12), h(8, 12), 0), "end before the first unlock")
        // End during a short lock (counts as work): ends exactly there.
        d = TTDay(date: date(2026, 11, 20))
        d.addPeriod(from: h(8, 0), to: h(10, 0))
        d.addPeriod(from: h(10, 10), to: h(12, 0))
        d.end = h(10, 5)
        suite.expect(d.spans(st()) == [TTSpan(h(8, 0), h(10, 5))], "end during a short lock")
    }

    private static func breakOverlappingLockIsNotCountedTwice(_ suite: TestSuite) {
        var d = day()
        d.breaks.append(TTBreak(from: h(12, 0), to: h(12, 45)))
        // Locked anyway 11:58–12:41, only 12:41–12:45 goes in addition.
        suite.expect(work(d) == h(3, 46) + h(4, 45), "a break over a lock is not counted twice")
    }

    private static func endClipsAndExtends(_ suite: TestSuite) {
        var d = day()
        d.end = h(17, 0)
        suite.expect(d.mode == .closed(h(17, 0)), "the end closes the day")
        suite.expect(work(d) == h(3, 46) + h(4, 19), "an earlier end cuts")
        d.end = h(18, 0)
        suite.expect(work(d) == h(3, 46) + h(5, 19), "a later end extends")
        suite.expect(d.record(st())?.lastEnd == h(18, 0), "the day ends at the manual end")
    }

    private static func manualDayWithoutPeriods(_ suite: TestSuite) {
        var d = TTDay(date: date(2026, 11, 13))
        d.start = h(8, 0)
        d.end = h(16, 0)
        d.breaks.append(TTBreak(from: h(12, 0), to: h(12, 30)))
        let r = d.record(st())!
        suite.expect(r.workSecs == h(7, 30), "start, end and break make a day")
        suite.expect(r.pauseSecs == h(0, 30), "the manual break")
    }

    private static func workWithoutMacFillsLockGap(_ suite: TestSuite) {
        // Locked at lunch 11:58–12:41, on the phone 12:00–12:35: the rests (2 and
        // 6 min) are shorter than the minimum break and count as work too.
        var d = day()
        d.addWork(from: h(12, 0), to: h(12, 35), note: "Telefonat")
        var r = d.record(st())!
        suite.expect((r.workSecs, r.pauseSecs) == (h(9, 18), 0), "the call fills the lunch gap")
        suite.expect(d.hasCorrections, "work away from the Mac is a correction")
        suite.expect(d.pauses(st()).isEmpty, "no break left")
        // Only part of the lunch time: the rest stays a break.
        d = day()
        d.addWork(from: h(12, 0), to: h(12, 20), note: "")
        r = d.record(st())!
        suite.expect(r.pauseSecs == h(0, 21), "the rest stays a break")
        suite.expect(d.pauses(st()) == [TTSpan(h(12, 20), h(12, 41))], "the break after the work")
        let block = TTWorkBlock(from: h(12, 0), to: h(12, 20), note: "")
        let counted = d.countedWork(st())
        suite.expect(counted.count == 1 && counted.first?.span == TTSpan(h(12, 0), h(12, 20))
                     && counted.first?.block == block, "the counted work with its block")
    }

    private static func shortWorkWithoutMacCountsLikeAnyOther(_ suite: TestSuite) {
        // Ten minutes on the phone in the middle of the lunch lock 11:58–12:41: a
        // break of 16 and 17 min stays before and after; the length does not matter.
        var d = day()
        d.addWork(from: h(12, 14), to: h(12, 24), note: "Telefonat")
        var r = d.record(st())!
        suite.expect((r.workSecs, r.pauseSecs) == (h(3, 46) + h(4, 49) + h(0, 10), h(0, 33)), "ten minutes count")
        suite.expect(d.pauses(st()) == [TTSpan(h(11, 58), h(12, 14)), TTSpan(h(12, 24), h(12, 41))],
                     "breaks before and after")
        // Ten minutes long before the first unlock: count and move the start.
        d = day()
        d.addWork(from: h(7, 30), to: h(7, 40), note: "Telefonat")
        r = d.record(st())!
        suite.expect((r.firstStart, r.workSecs) == (h(7, 30), h(0, 10) + h(3, 46) + h(4, 49)),
                     "early work moves the start")
    }

    private static func workWithoutMacOutsideStartAndEnd(_ suite: TestSuite) {
        var d = day()
        d.start = h(8, 30)
        d.end = h(17, 0)
        d.addWork(from: h(7, 45), to: h(8, 0), note: "Telefonat")
        d.addWork(from: h(19, 0), to: h(19, 30), note: "Meeting")
        var r = d.record(st())!
        suite.expect((r.firstStart, r.lastEnd) == (h(7, 45), h(19, 30)), "work away from the Mac extends the day")
        suite.expect(r.workSecs == h(0, 15) + h(3, 28) + h(4, 19) + h(0, 30), "and counts")
        // Without any unlock.
        d = TTDay(date: date(2026, 11, 14))
        d.addWork(from: h(10, 0), to: h(11, 0), note: "")
        suite.expect(!d.isEmpty, "work alone is something to store")
        r = d.record(st())!
        suite.expect((r.firstStart, r.workSecs) == (h(10, 0), h(1, 0)), "work alone makes a day")
        // Outside the frame: not counted.
        d.addWork(from: h(22, 0), to: h(23, 0), note: "")
        suite.expect(work(d) == h(1, 0), "work outside the frame does not count")
        suite.expect(d.outsideFrameSpans(st()) == [TTSpan(h(22, 0), h(23, 0))], "it lies outside")
    }

    private static func workBlocksStaySeparateAndLatestEntryWins(_ suite: TestSuite) {
        var d = day()
        d.addWork(from: h(12, 0), to: h(12, 20), note: "Meeting")
        d.addWork(from: h(12, 20), to: h(12, 30), note: "Telefonat")
        // Adjoining: two blocks.
        suite.expect(d.work == [TTWorkBlock(from: h(12, 0), to: h(12, 20), note: "Meeting"),
                                TTWorkBlock(from: h(12, 20), to: h(12, 30), note: "Telefonat")],
                     "adjoining blocks stay separate")
        // Overlapping: the latest entry wins, the older ones are cut.
        d.addWork(from: h(12, 10), to: h(12, 25), note: "Networking")
        suite.expect(d.work == [TTWorkBlock(from: h(12, 0), to: h(12, 10), note: "Meeting"),
                                TTWorkBlock(from: h(12, 10), to: h(12, 25), note: "Networking"),
                                TTWorkBlock(from: h(12, 25), to: h(12, 30), note: "Telefonat")],
                     "the latest block wins")
        d = day()
        d.addWork(from: h(12, 0), to: h(12, 30), note: "Meeting")
        // A break over it: the work splits.
        d.addBreak(from: h(12, 10), to: h(12, 15))
        suite.expect(d.work.map { [$0.from, $0.to] } == [[h(12, 0), h(12, 10)], [h(12, 15), h(12, 30)]],
                     "a break splits the work")
        suite.expect(d.work[1].note == "Meeting", "both parts keep the note")
        suite.expect(d.breaks == [TTBreak(from: h(12, 10), to: h(12, 15))], "the break is entered")
        // Work over it: the break goes.
        d.addWork(from: h(12, 5), to: h(12, 20), note: "")
        suite.expect(d.breaks.isEmpty, "work over a break removes it")
        suite.expect(d.work.map { [$0.from, $0.to] } == [[h(12, 0), h(12, 5)], [h(12, 5), h(12, 20)],
                                                         [h(12, 20), h(12, 30)]],
                     "the new work cuts the older")
        // Manual break partly covered.
        d = day()
        d.addBreak(from: h(10, 0), to: h(11, 0))
        d.addWork(from: h(10, 30), to: h(11, 30), note: "")
        suite.expect(d.breaks == [TTBreak(from: h(10, 0), to: h(10, 30))], "a partly covered break is cut")
        // Empty or reversed times are ignored.
        let before = d
        d.addWork(from: h(9, 0), to: h(9, 0), note: "x")
        d.addBreak(from: h(9, 0), to: h(8, 0))
        suite.expect(d == before, "empty or reversed times change nothing")
    }

    private static func shortGapsToWorkWithoutMacJoinTheNewBlock(_ suite: TestSuite) {
        var d = day()
        d.addWork(from: h(18, 0), to: h(18, 30), note: "Meeting")
        d.addWork(from: h(19, 0), to: h(19, 30), note: "Telefonat")
        // 5 min gap before, 10 min after: both shorter than 15 min.
        var j = d.joinWorkGaps(from: h(18, 35), to: h(18, 50), minPause: 15 * 60)
        suite.expect(j.span == TTSpan(h(18, 30), h(19, 0)), "both gaps join")
        suite.expect(j.gaps == [TTSpan(h(18, 30), h(18, 35)), TTSpan(h(18, 50), h(19, 0))], "the gaps")
        suite.expect(j.rests.isEmpty, "no rests")
        suite.expect(j.note(minPause: 15 * 60, de)
                     == "Zur Arbeitszeit daneben blieben Lücken von 18:30 bis 18:35 (5 Min.) und von 18:50 "
                     + "bis 19:00 (10 Min.). Das ist jeweils kürzer als die Mindestpause von 15 Min.; die Zeit "
                     + "wurde dem neuen Abschnitt dazugerechnet. Er reicht jetzt von 18:30 bis 19:00 Uhr.",
                     "note about two gaps")
        d.addWork(from: j.span.from, to: j.span.to, note: "Networking")
        suite.expect(d.work.count == 3, "the blocks stay separate")
        // A gap from the minimum break on stays; adjoining directly there is nothing to add.
        j = d.joinWorkGaps(from: h(19, 45), to: h(20, 0), minPause: 15 * 60)
        suite.expect(j.span == TTSpan(h(19, 45), h(20, 0)), "a 15 min gap stays")
        suite.expect(j.note(minPause: 15 * 60, de) == nil, "no note")
        suite.expect(d.joinWorkGaps(from: h(19, 30), to: h(19, 40), minPause: 15 * 60).gaps.isEmpty,
                     "adjoining: no gap")
        // If the new block overlaps one, it adjoins directly after the cut.
        j = d.joinWorkGaps(from: h(19, 20), to: h(19, 40), minPause: 15 * 60)
        suite.expect(j.span == TTSpan(h(19, 20), h(19, 40)) && j.gaps.isEmpty, "overlapping: no gap")
        // A whole manual break in the gap stays.
        d.addBreak(from: h(20, 30), to: h(20, 45))
        d.addWork(from: h(20, 45), to: h(21, 0), note: "")
        j = d.joinWorkGaps(from: h(20, 0), to: h(20, 30), minPause: 15 * 60)
        suite.expect(j.span == TTSpan(h(20, 0), h(20, 30)) && j.gaps.isEmpty && j.rests.isEmpty,
                     "a whole manual break in the gap stays")
    }

    private static func shortGapsToRecordedWorkJoinTheNewBlock(_ suite: TestSuite) {
        // Break 12:42–13:27, a call in it 12:42–13:18: the 9 min until the unlock
        // belong to the new block.
        var d = TTDay(date: date(2026, 11, 16))
        d.addPeriod(from: h(11, 10), to: h(12, 42))
        d.addPeriod(from: h(13, 27), to: h(15, 55))
        var j = d.joinWorkGaps(from: h(12, 42), to: h(13, 18), minPause: 15 * 60)
        suite.expect(j.span == TTSpan(h(12, 42), h(13, 27)), "the gap to the unlock joins")
        suite.expect(j.gaps == [TTSpan(h(13, 18), h(13, 27))], "the gap")
        suite.expect(j.note(minPause: 15 * 60, de)
                     == "Zur Arbeitszeit daneben bliebe eine Lücke von 13:18 bis 13:27 (9 Min.). Das ist kürzer "
                     + "als die Mindestpause von 15 Min.; die Zeit wurde dem neuen Abschnitt dazugerechnet. Er "
                     + "reicht jetzt von 12:42 bis 13:27 Uhr.",
                     "note about one gap")
        // Also before the block; from the minimum break on the gap stays a break.
        j = d.joinWorkGaps(from: h(12, 50), to: h(13, 5), minPause: 15 * 60)
        suite.expect(j.span == TTSpan(h(12, 42), h(13, 5)) && j.gaps.count == 1, "the gap before joins")
    }

    private static func gapsUnderAMinuteJoinWithoutANote(_ suite: TestSuite) {
        // Break 15:29:10–15:50:40, entered by the minute 15:29–15:50: the 40 s until
        // the unlock belong to it, but a note "from 15:50 to 15:50" would confuse.
        var d = TTDay(date: date(2026, 11, 17))
        d.addPeriod(from: h(13, 13), to: h(15, 29) + 10)
        d.addPeriod(from: h(15, 50) + 40, to: h(17, 16))
        var j = d.joinWorkGaps(from: h(15, 29), to: h(15, 50), minPause: 15 * 60)
        suite.expect(j.span == TTSpan(h(15, 29), h(15, 50) + 40), "seconds join")
        suite.expect(j.gaps == [TTSpan(h(15, 50), h(15, 50) + 40)], "the gap of 40 s")
        suite.expect(j.note(minPause: 15 * 60, de) == nil, "no note for seconds")
        // Next to a real gap only that one is named.
        j = d.joinWorkGaps(from: h(15, 35), to: h(15, 50), minPause: 15 * 60)
        suite.expect(j.gaps.count == 2, "two gaps")
        suite.expect(j.note(minPause: 15 * 60, de)
                     == "Zur Arbeitszeit daneben bliebe eine Lücke von 15:29 bis 15:35 (5 Min.). Das ist kürzer "
                     + "als die Mindestpause von 15 Min.; die Zeit wurde dem neuen Abschnitt dazugerechnet. Er "
                     + "reicht jetzt von 15:29 bis 15:50 Uhr.",
                     "only the real gap is named")
    }

    private static func restsOfAManualBreakJoinTheNewBlock(_ suite: TestSuite) {
        // Start moved to 8:00, first unlock 11:31, break 9:00–11:00, a call in it
        // 9:10–10:50: no breaks of 10 min may be left.
        var d = TTDay(date: date(2026, 11, 18))
        d.addPeriod(from: h(11, 31), to: h(11, 38))
        d.start = h(8, 0)
        d.addBreak(from: h(9, 0), to: h(11, 0))
        suite.expect(d.spans(st()) == [TTSpan(h(8, 0), h(9, 0)), TTSpan(h(11, 0), h(11, 38))], "before the call")
        var j = d.joinWorkGaps(from: h(9, 10), to: h(10, 50), minPause: 15 * 60)
        suite.expect(j.span == TTSpan(h(9, 0), h(11, 0)), "the rests join")
        suite.expect(j.rests == [TTSpan(h(9, 0), h(9, 10)), TTSpan(h(10, 50), h(11, 0))], "the rests")
        suite.expect(j.note(minPause: 15 * 60, de)
                     == "Von den manuellen Pausen blieben nur von 09:00 bis 09:10 (10 Min.) und von 10:50 bis "
                     + "11:00 (10 Min.) übrig. Das ist jeweils kürzer als die Mindestpause von 15 Min.; die Zeit "
                     + "wurde dem neuen Abschnitt dazugerechnet. Er reicht jetzt von 09:00 bis 11:00 Uhr.",
                     "note about two rests")
        d.addWork(from: j.span.from, to: j.span.to, note: "Telefonat")
        suite.expect(d.breaks.isEmpty, "the break is gone")
        // The time until the first unlock still counts: no break 11:00–11:31.
        suite.expect(d.spans(st()) == [TTSpan(h(8, 0), h(11, 38))], "one block from the start")
        // A rest from the minimum break on stays a break.
        d = TTDay(date: date(2026, 11, 18))
        d.addBreak(from: h(9, 0), to: h(11, 0))
        j = d.joinWorkGaps(from: h(9, 20), to: h(10, 50), minPause: 15 * 60)
        suite.expect(j.span == TTSpan(h(9, 20), h(11, 0)) && j.rests == [TTSpan(h(10, 50), h(11, 0))],
                     "only the short rest joins")
        d.addWork(from: j.span.from, to: j.span.to, note: "")
        suite.expect(d.breaks == [TTBreak(from: h(9, 0), to: h(9, 20))], "the long rest stays")
    }

    private static func manualEndCountsFromLastLockEvenWithWorkAfterIt(_ suite: TestSuite) {
        // Last lock 17:30, then a call 18:00–18:20, end 19:00: all the time after the
        // last lock counts (no break 17:30–18:00).
        var d = day()
        d.addWork(from: h(18, 0), to: h(18, 20), note: "Telefonat")
        d.end = h(19, 0)
        suite.expect(d.spans(st()).last == TTSpan(h(12, 41), h(19, 0)), "the end counts from the last lock")
    }

    private static func activityIdsRoundTrip(_ suite: TestSuite) {
        for activity in TTActivity.all {
            suite.expect(TTActivity.from(id: activity.id) == activity && TTActivity.from(key: activity.key) == activity,
                         "\(activity) round-trips")
        }
        suite.expect(TTActivity.from(key: "unbekannt") == .other, "unknown keys are Other")
        suite.expect(TTActivity.all.map { $0.label(de) } == ["Meeting", "Telefonat", "Networking", "Sonstiges"],
                     "labels in the order of the choice")
        suite.expect(TTActivity.networking.note(de) == "Networking" && TTActivity.other.note(de) == "",
                     "Other leaves no note")
        suite.expect(TTActivity.all.map(\.id) == [1, 2, 3, 0], "ids as stored by Tagwerk")
    }

    private static func legalPauseCountsSegmentsFrom15Minutes(_ suite: TestSuite) {
        let spans = [TTSpan(h(8, 0), h(10, 0)), TTSpan(h(10, 14), h(12, 0)), TTSpan(h(12, 30), h(15, 0))]
        suite.expect(TTDay.legalPauseSecs(spans) == h(0, 30), "only breaks from 15 min count")
    }

    private static func periodsMerge(_ suite: TestSuite) {
        var d = TTDay(date: date(2026, 11, 16))
        d.addPeriod(from: h(8, 0), to: h(9, 0))
        d.addPeriod(from: h(8, 0), to: h(9, 30)) // the running period saved again
        d.addPeriod(from: h(10, 0), to: h(11, 0))
        suite.expect(d.periods == [TTSpan(h(8, 0), h(9, 30)), TTSpan(h(10, 0), h(11, 0))], "periods merge")
    }

    private static func clockParsing(_ suite: TestSuite) {
        suite.expect(TTFormat.parseClock("8:05") == h(8, 5), "8:05")
        suite.expect(TTFormat.parseClock("08.05 Uhr") == h(8, 5), "08.05 Uhr")
        suite.expect(TTFormat.parseClock("24:00:00") == TTLimits.dayEnd, "24:00:00")
        suite.expect(TTFormat.parseClock("24:01") == nil, "24:01")
        suite.expect(TTFormat.parseClock("abc") == nil, "abc")
        suite.expect(TTFormat.clockSeconds(TTLimits.dayEnd) == "24:00:00", "24:00:00 formats")
        suite.expect(TTFormat.clock(h(8, 5)) == "08:05" && TTFormat.clock(-5) == "00:00", "clock formats")
    }

    private static func freeDayCountsOnlyAfterChoosingTo(_ suite: TestSuite) {
        // Saturday: unlocked 10:00–12:00, a call by hand 14:00–14:30.
        var d = TTDay(date: date(2026, 11, 21))
        d.addPeriod(from: h(10, 0), to: h(12, 0))
        d.addWork(from: h(14, 0), to: h(14, 30), note: "Telefonat")
        // Without a mark (earlier versions, setting off): everything counts.
        suite.expect(d.spans(st()) == [TTSpan(h(10, 0), h(12, 0)), TTSpan(h(14, 0), h(14, 30))],
                     "without a mark everything counts")
        suite.expect(d.uncountedAutoSpans(st()).isEmpty, "nothing uncounted")
        // Uncounted: only the call; the recorded time stands next to it as uncounted.
        d.freeDay = .uncounted
        suite.expect(d.spans(st()) == [TTSpan(h(14, 0), h(14, 30))], "only the call counts")
        suite.expect(d.uncountedAutoSpans(st()) == [TTSpan(h(10, 0), h(12, 0))], "the recorded time is uncounted")
        suite.expect(d.autoBoundsInFrame(st()) == nil, "no automatic bounds")
        suite.expect(work(d) == h(0, 30), "the call is the working time")
        // A call within the recorded time counts, the rest does not.
        d.addWork(from: h(11, 0), to: h(11, 15), note: "Telefonat")
        suite.expect(d.uncountedAutoSpans(st()) == [TTSpan(h(10, 0), h(11, 0)), TTSpan(h(11, 15), h(12, 0))],
                     "the call is cut out of the uncounted time")
        // "Record today": everything again.
        d.freeDay = .counted
        suite.expect(work(d) == h(2, 30), "everything counts after Record today")
        suite.expect(d.uncountedAutoSpans(st()).isEmpty, "nothing uncounted after Record today")
    }

    private static func freeDayMarkAloneIsKeptButNoRecord(_ suite: TestSuite) {
        var d = TTDay(date: date(2026, 11, 21))
        d.freeDay = .uncounted
        suite.expect(!d.isEmpty, "the decision stays stored")
        suite.expect(!d.hasEntries, "it is no entry")
        suite.expect(d.record(st()) == nil, "and gives no row")
    }

    private static func uncountedOnlyWithoutCounting(_ suite: TestSuite) {
        var d = TTDay(date: date(2026, 11, 21))
        suite.expect(!d.uncounted, "without a mark everything counts")
        for (freeDay, uncounted) in [(TTFreeDay.uncounted, true), (.stopped, true), (.counted, false)] {
            d.freeDay = freeDay
            suite.expect(d.uncounted == uncounted, "\(freeDay)")
        }
    }

    private static func freeDayLabelsRoundTrip(_ suite: TestSuite) {
        for freeDay in TTFreeDay.allCases {
            suite.expect(TTFreeDay.parse(freeDay.label(de), de) == freeDay, "\(freeDay) label round-trips")
            suite.expect(TTFreeDay.parse(freeDay.label(.enUS), .enUS) == freeDay, "\(freeDay) English round-trips")
            suite.expect(TTFreeDay.from(id: freeDay.id) == freeDay, "\(freeDay) id round-trips")
        }
        suite.expect(TTFreeDay.from(id: 7) == nil, "unknown ids are none")
        // Nothing recorded, nothing to show, but the decision stays stored.
        var d = TTDay(date: date(2026, 11, 21))
        d.freeDay = .stopped
        suite.expect(!d.isEmpty && d.record(st()) == nil, "a stopped day is kept without a row")
    }

    private static func uncountedFreeDayIgnoresStartAndEnd(_ suite: TestSuite) {
        // Saturday, recorded 09:30–11:00, start 09:00 and end 12:00 by hand.
        var d = TTDay(date: date(2026, 11, 21))
        d.addPeriod(from: h(9, 30), to: h(11, 0))
        d.start = h(9, 0)
        d.end = h(12, 0)
        d.freeDay = .counted
        suite.expect(d.spans(st()) == [TTSpan(h(9, 0), h(12, 0))], "counted: start and end apply")
        // "Count recorded time" off: nothing counts any more, not the whole span
        // between start and end.
        d.freeDay = .uncounted
        suite.expect(d.spans(st()).isEmpty, "uncounted: nothing counts")
        suite.expect(d.uncountedAutoSpans(st()) == [TTSpan(h(9, 30), h(11, 0))], "the recorded time is uncounted")
        // Work away from the Mac counts as always; start and end stay and apply
        // again as soon as the recorded time counts.
        d.addWork(from: h(14, 0), to: h(15, 0), note: "Meeting")
        suite.expect(d.spans(st()) == [TTSpan(h(14, 0), h(15, 0))], "work away from the Mac counts")
        d.freeDay = .counted
        suite.expect(d.spans(st()) == [TTSpan(h(9, 0), h(12, 0)), TTSpan(h(14, 0), h(15, 0))],
                     "start and end apply again")
    }

    private static func startMustPrecedeEnd(_ suite: TestSuite) {
        suite.expect(TTDay.boundsInOrder(start: nil, end: nil) && TTDay.boundsInOrder(start: h(8, 0), end: nil)
                     && TTDay.boundsInOrder(start: nil, end: h(8, 0)), "a missing bound always fits")
        suite.expect(TTDay.boundsInOrder(start: h(8, 0), end: h(8, 1)), "start before end")
        suite.expect(!TTDay.boundsInOrder(start: h(8, 0), end: h(8, 0))
                     && !TTDay.boundsInOrder(start: h(18, 0), end: h(12, 0)), "start not before end")
    }

    private static func actualSpansIncludeTimeOutsideTheFrame(_ suite: TestSuite) {
        var d = TTDay(date: date(2026, 11, 16))
        d.addPeriod(from: h(3, 0), to: h(3, 0) + 30) // a short glance at night stays out
        d.addPeriod(from: h(5, 0), to: h(8, 0))
        d.addPeriod(from: h(21, 0), to: h(23, 0))
        suite.expect(d.spans(st()) == [TTSpan(h(7, 0), h(8, 0)), TTSpan(h(21, 0), h(22, 0))], "counted spans")
        suite.expect(d.actualSpans(st()) == [TTSpan(h(5, 0), h(8, 0)), TTSpan(h(21, 0), h(23, 0))], "actual spans")
        // After the end of work it is over, for the actual working time too.
        d.end = h(21, 30)
        suite.expect(d.actualSpans(st()) == [TTSpan(h(5, 0), h(8, 0)), TTSpan(h(21, 0), h(21, 30))],
                     "the end of work ends the actual time")
    }
}
