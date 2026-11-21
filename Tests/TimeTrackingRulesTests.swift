// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// The tests of Tagwerk's `rules.rs`, one function per `#[test]`, plus the
/// English texts of the logic.
enum TimeTrackingRulesTests {
    static func run(_ suite: TestSuite) {
        defaultsAndTarget(suite)
        rulesApplyFromTheirDate(suite)
        earlierDaysKeepTheirRules(suite)
        iconSetIds(suite)
        hoursText(suite)
        warnings(suite)
        longStretchWithoutBreak(suite)
        outsideFrameTextListsTimes(suite)
        limitAlertsAt945And10Hours(suite)
        carryInput(suite)
        workdaysSpreadTheWeeklyTarget(suite)
        absencesChangeTheTarget(suite)
        specialLeaveIsAlwaysAFullDay(suite)
        freeDayWorkCountsOnlyIfTheRulesSaySo(suite)
        accountAddsCarryAndCountsFromStart(suite)
        breakRemindersAt545And6Hours(suite)
        balanceCountsWorkdaysWithoutEntries(suite)
        balanceAddsUpShownMinutes(suite)
        dailyTargetsAreWholeMinutesAndAddUp(suite)
        todaysTargetCountsOnlyAsFarAsWorked(suite)
        legalChecksSeeWorkOutsideTheFrame(suite)
        aDayWithOnlyTheFreeDayMarkIsNoEntry(suite)
        englishTexts(suite)
    }

    static func h(_ hh: Int, _ mm: Int) -> Int { hh * 3600 + mm * 60 }
    /// A day in November 2026 (the 16th is a Monday).
    static func date(_ day: Int) -> TTDate { TTDate(year: 2026, month: 11, day: day)! }
    static let de = TimeTrackingTexts.de

    static func dayWith(_ d: Int, _ periods: [(Int, Int)]) -> TTDay {
        var day = TTDay(date: date(d))
        for (from, to) in periods { day.addPeriod(from: from, to: to) }
        return day
    }

    static func isMaxHours(_ warning: TTWarning) -> Bool {
        if case .maxHours = warning { return true }
        return false
    }

    static func isOutsideFrame(_ warning: TTWarning) -> Bool {
        if case .outsideFrame = warning { return true }
        return false
    }

    // MARK: rules.rs

    private static func defaultsAndTarget(_ suite: TestSuite) {
        let s = TTSettings()
        suite.expect(s.dailyTarget(date(16)) == h(7, 48), "Monday: 7:48 h")
        suite.expect(s.dailyTarget(date(15)) == 0, "Sunday: no target")
        suite.expect(s.rules(date(16)).frameText(de) == "07:00–22:00 Uhr", "frame text")
        let bad = TTWorkRules(minPause: 0, weeklyTarget: 0, frameFrom: h(22, 0), frameTo: h(7, 0), workdays: 0,
                              freeDaysCount: true)
        let fixed = s.withRules(bad)
        let r = fixed.rules(date(16))
        suite.expect((r.frameFrom, r.frameTo) == (h(7, 0), h(22, 0)), "a reversed frame falls back to the default")
        suite.expect(r.minPause == 60, "minimum break at least a minute")
        suite.expect(r.weeklyTarget == 3600, "weekly target at least an hour")
        suite.expect(r.workdays == TTLimits.allWorkdays, "no workday means Monday to Friday")
        suite.expect(fixed.minWork == s.minWork, "the minimum work stays")
        // The minimum length of work away from the Mac does not depend on the minimum break.
        var shortWork = s
        shortWork.minWork = 5 * 60
        let s20 = shortWork.withRules(TTWorkRules(minPause: 20 * 60))
        suite.expect((s20.rules(date(16)).minPause, s20.minWork) == (20 * 60, 5 * 60), "independent minimums")
        var none = s
        none.minWork = 0
        suite.expect(none.sanitized.minWork == TTLimits.minWorkRange.lowerBound, "minimum work has a floor")
        var huge = s
        huge.minWork = 999 * 60
        suite.expect(huge.sanitized.minWork == TTLimits.minWorkRange.upperBound, "minimum work has a ceiling")
    }

    private static func rulesApplyFromTheirDate(_ suite: TestSuite) {
        var s = TTSettings()
        let part = TTWorkRules(weeklyTarget: h(32, 0), workdays: 0b0_1111)
        // From Thursday 32 h on Mon–Thu: before it the rules from the start apply.
        s.setRules(from: date(19), part)
        suite.expect(s.work.count == 2, "two sets")
        suite.expect(s.rules(date(18)) == .default, "before: the default")
        suite.expect(s.rules(date(19)) == part, "from Thursday: the new set")
        suite.expect(s.rules(TTDate.min) == .default, "since always: the default")
        suite.expect(s.dailyTarget(date(18)) == h(7, 48), "Wednesday, old rules")
        suite.expect(s.dailyTarget(date(19)) == h(8, 0), "Thursday, new rules")
        suite.expect(s.dailyTarget(date(20)) == 0, "Friday is no workday any more")
        suite.expect(s.autoCountsOn(date(18)) && !s.autoCountsOn(date(20)), "recording counts on workdays only")

        // The same day replaces the set; a set like the one before goes.
        let part30 = { var r = part; r.weeklyTarget = h(30, 0); return r }()
        s.setRules(from: date(19), part30)
        suite.expect(s.work.count == 2, "the same day replaces")
        suite.expect(s.rules(date(25)) == part30, "the replaced set applies")
        s.setRules(from: date(23), part30)
        suite.expect(s.work.count == 2, "equal to the set before")

        // Moving: the set from Thursday moves to Tuesday without losing a later
        // set with the rules from the start.
        s.setRules(from: date(26), .default)
        suite.expect(s.work.count == 3, "a later default set")
        s.setRules(from: date(17), part30, replaces: date(19))
        suite.expect(s.work.map(\.from) == [nil, date(17), date(26)], "the set moved to Tuesday")

        // Deleting: from then on the set before applies; here it equals the one after, both merge.
        s.removeRules(from: date(17))
        suite.expect(s.work == [TTRulesPeriod(from: nil, rules: .default)], "deleting merges equal sets")
        // The first set always stays and applies since always.
        s.setRules(from: nil, part)
        suite.expect(s.work == [TTRulesPeriod(from: nil, rules: part)], "the first set is replaced")
        var odd = TTSettings()
        odd.work = []
        suite.expect(odd.sanitized.work == TTSettings().work, "no set gives the default")
        var late = TTSettings()
        late.work = [TTRulesPeriod(from: date(5), rules: part)]
        suite.expect(late.sanitized.work == [TTRulesPeriod(from: nil, rules: part)], "the first set applies since always")
    }

    private static func earlierDaysKeepTheirRules(_ suite: TestSuite) {
        // Mon–Wed 39 h/5 days, from Thursday 32 h/4 days (Mon–Thu), frame from 8:00,
        // minimum break 30 min.
        var s = TTSettings()
        let part = TTWorkRules(minPause: 30 * 60, weeklyTarget: h(32, 0), frameFrom: h(8, 0), workdays: 0b0_1111)
        s.setRules(from: date(19), part)
        // 7:30 to 16:00 with 20 min lock at lunch.
        let days = (16...20).map { dayWith($0, [(h(7, 30), h(12, 0)), (h(12, 20), h(16, 0))]) }
        func rec(_ d: Int) -> TTDayRecord { days.first { $0.date == date(d) }!.record(s)! }
        // Wednesday: old frame (from 7:00) and old minimum break (20 min are a break).
        suite.expect((rec(18).workSecs, rec(18).pauseSecs) == (h(8, 10), h(0, 20)), "Wednesday keeps the old rules")
        // Thursday: from 8:00, the 20 min count as working time.
        suite.expect((rec(19).workSecs, rec(19).pauseSecs) == (h(8, 0), 0), "Thursday has the new rules")
        // Target of the week: 3 × 7:48 + 8:00 (Friday free, its work does not count).
        let (work, target) = s.balance(days, from: date(16), to: date(22), today: date(23))
        suite.expect(target == 3 * h(7, 48) + h(8, 0), "target by the rules of each day")
        suite.expect(work == 3 * h(8, 10) + h(8, 0), "work by the rules of each day")
        // A missing workday counts with the target that applied on it.
        let missing = days.filter { $0.date != date(17) && $0.date != date(19) }
        suite.expect(s.balance(missing, from: date(16), to: date(22), today: date(23)).target == 3 * h(7, 48) + h(8, 0),
                     "missing workdays count with their own target")
        // Warning "outside the frame" only where the frame says so.
        suite.expect(!TTWarning.dayWarnings(days, date: date(18), settings: s).contains(where: isOutsideFrame),
                     "Wednesday: 7:30 is within the frame")
        let thursday = TTWarning.dayWarnings(days, date: date(19), settings: s)
        let outside = TTWarning.outsideFrame(spans: [TTSpan(h(7, 30), h(8, 0))], frame: TTSpan(h(8, 0), h(22, 0)))
        suite.expect(thursday.contains(outside), "Thursday: 7:30 is outside the frame")
        suite.expect(outside.text(de).contains("(08:00–22:00 Uhr)"), "the warning names the frame that applied")
        // Footers: one paragraph per set, otherwise one.
        suite.expect(s.summaryBetween(date(16), date(18), de) == [TTWorkRules.default.summary(de)], "one set, one paragraph")
        suite.expect(s.targetBasis(date(19), date(22), de) == "32 Std./Woche, Mo, Di, Mi, Do", "target basis")
        let parts = s.summaryBetween(date(16), date(22), de)
        suite.expect(parts.count == 2, "two sets, two paragraphs")
        suite.expect(parts.first?.hasPrefix("Bis 18.11.2026: Arbeitszeitrahmen 07:00") == true, parts.first ?? "")
        suite.expect(parts.last?.hasPrefix("Ab 19.11.2026: Arbeitszeitrahmen 08:00") == true, parts.last ?? "")
        s.setRules(from: date(21), .default)
        let three = s.summaryBetween(date(16), date(22), de)
        suite.expect(three.count == 3 && three[1].hasPrefix("19.11.2026 bis 20.11.2026: "), three.joined(separator: "\n"))
        suite.expect(s.targetBasis(date(16), date(22), de) == "nach den Regeln, die am jeweiligen Tag galten",
                     "mixed rules point to the rules of each day")
    }

    private static func iconSetIds(_ suite: TestSuite) {
        suite.expect(TTIconSet.default == .tagbogen, "the day arc is the default")
        for set in TTIconSet.allCases {
            suite.expect(TTIconSet.from(id: set.id) == set, "\(set) round-trips")
        }
        suite.expect(TTIconSet.allCases.map(\.id) == Array(0...8), "ids 0 to 8 as stored by Tagwerk")
        suite.expect(TTIconSet.from(id: 99) == .tagbogen, "unknown ids give the default")
        suite.expect(TTIconSet.allCases.map { $0.name(de) } == ["Tagbogen", "Schlossuhr", "Tagesring", "Bauarbeiter",
                                                                "Handwerkerin", "Kaffeetasse", "Hamsterrad",
                                                                "Roboter", "Kaninchen"],
                     "Tagwerk's names")
    }

    private static func hoursText(_ suite: TestSuite) {
        suite.expect(TTFormat.hours(h(39, 0), de) == "39", "whole hours")
        suite.expect(TTFormat.hours(h(38, 30), de) == "38,5", "half hours with a comma")
        suite.expect(TTFormat.parseHours("38,5") == h(38, 30), "38,5")
        suite.expect(TTFormat.parseHours(" 40 ") == h(40, 0), "40")
        suite.expect(TTFormat.parseHours("x") == nil, "x")
        suite.expect(TTFormat.balance(-h(0, 30)) == "\u{2212}0:30 h", "negative balance with a minus sign")
        suite.expect(TTFormat.balance(h(1, 5)) == "+1:05 h", "positive balance")
        suite.expect(TTFormat.balance(-20) == "+0:00 h", "under a minute is no minus")
    }

    private static func warnings(_ suite: TestSuite) {
        let s = TTSettings()
        // Monday until 22:00, Tuesday from 07:00: only 9 h of rest.
        let mon = dayWith(16, [(h(12, 0), h(22, 0))])
        let tue = dayWith(17, [(h(6, 30), h(12, 0))])
        let sat = dayWith(21, [(h(10, 0), h(11, 0))])
        let days = [mon, tue, sat]

        var w = TTWarning.dayWarnings(days, date: date(16), settings: s)
        suite.expect(w.contains(.breaks(required: 45 * 60, outside: false)), "\(w)")
        suite.expect(!w.contains(where: isMaxHours), "exactly 10 h are allowed")

        w = TTWarning.dayWarnings(days, date: date(17), settings: s)
        suite.expect(w.contains(.rest(rest: h(9, 0), outside: false)), "\(w)")
        let r = s.rules(date(17))
        let outside = TTWarning.outsideFrame(spans: [TTSpan(h(6, 30), h(7, 0))], frame: TTSpan(r.frameFrom, r.frameTo))
        suite.expect(w.contains(outside), "\(w)")
        suite.expect(outside.text(de) == "06:30–07:00 Uhr außerhalb des Arbeitszeitrahmens (07:00–22:00 Uhr) – nicht gezählt",
                     outside.text(de))

        suite.expect(TTWarning.dayWarnings(days, date: date(21), settings: s) == [.weekend(counted: false)],
                     "work on Saturday")

        let long = dayWith(18, [(h(7, 0), h(12, 0)), (h(13, 0), h(19, 0))])
        suite.expect(TTWarning.dayWarnings([long], date: date(18), settings: s) == [.maxHours(work: h(11, 0), outside: false)],
                     "11 h are too many")
    }

    private static func longStretchWithoutBreak(_ suite: TestSuite) {
        let s = TTSettings()
        func day(_ periods: [(Int, Int)]) -> TTDay { dayWith(18, periods) }
        // 7 h in one stretch, the break only after: enough break, but too late.
        let late = day([(h(7, 0), h(14, 0)), (h(14, 30), h(15, 30))])
        let w = TTWarning.dayWarnings([late], date: date(18), settings: s)
        suite.expect(w == [.longStretch(work: h(7, 0), outside: false)], "\(w)")
        suite.expect(w.first?.text(de) == "7:00 Std. ohne Pause – erlaubt sind höchstens 6 Std. am Stück (§ 4 ArbZG)",
                     w.first?.text(de) ?? "")
        // Exactly 6 h in one stretch are allowed.
        let ok = day([(h(7, 0), h(13, 0)), (h(13, 30), h(15, 0))])
        suite.expect(TTWarning.dayWarnings([ok], date: date(18), settings: s).isEmpty, "6 h are allowed")
        // Without any break the warning about the missing break is enough.
        let none = day([(h(7, 0), h(14, 0))])
        suite.expect(TTWarning.dayWarnings([none], date: date(18), settings: s) == [.breaks(required: 30 * 60, outside: false)],
                     "no break at all")
        // Too little break and too late: both warnings.
        let both = day([(h(7, 0), h(13, 10)), (h(13, 30), h(14, 30))])
        suite.expect(TTWarning.dayWarnings([both], date: date(18), settings: s)
                     == [.breaks(required: 30 * 60, outside: false), .longStretch(work: h(6, 10), outside: false)],
                     "too little and too late")
        // Minimum break 5 min: an interruption of 10 min is no break under the Act;
        // the work before and after counts together (without the interruption).
        var shortSettings = s
        shortSettings.minWork = 5 * 60
        let short = shortSettings.withRules(TTWorkRules(minPause: 5 * 60))
        let split = day([(h(7, 0), h(10, 0)), (h(10, 10), h(13, 30)), (h(14, 0), h(15, 0))])
        suite.expect(TTWarning.dayWarnings([split], date: date(18), settings: short)
                     == [.longStretch(work: h(6, 20), outside: false)], "10 min are no legal break")
    }

    private static func outsideFrameTextListsTimes(_ suite: TestSuite) {
        let s = TTSettings()
        // As at night: unlocked 00:00–00:02 and 00:15–00:24 (13 min lock counts), 30
        // seconds at 02:03 go unmentioned, then work within the frame.
        let d = dayWith(17, [(0, 2 * 60 + 39), (h(0, 15) + 50, h(0, 24) + 26), (h(2, 3), h(2, 3) + 30),
                             (h(12, 8), h(12, 23))])
        let w = TTWarning.dayWarnings([d], date: date(17), settings: s)
        suite.expect(w.count == 1, "\(w)")
        suite.expect(w.first?.text(de) == "00:00–00:24 Uhr außerhalb des Arbeitszeitrahmens (07:00–22:00 Uhr) – nicht gezählt",
                     w.first?.text(de) ?? "")
        let frame = TTSpan(TTWorkRules.default.frameFrom, TTWorkRules.default.frameTo)
        let two = TTWarning.outsideFrame(spans: [TTSpan(h(6, 30), h(7, 0)), TTSpan(h(22, 0), TTLimits.dayEnd)], frame: frame)
        suite.expect(two.text(de).hasPrefix("06:30–07:00 und 22:00–24:00 Uhr außerhalb"), two.text(de))
        let many = TTWarning.outsideFrame(spans: Array(repeating: TTSpan(0, 600), count: 4), frame: frame)
        suite.expect(many.text(de).hasPrefix("4 Zeiträume (0:40 Std.) außerhalb"), many.text(de))
        let late = TTWarning.outsideFrame(spans: [TTSpan(h(23, 22) + 34, TTLimits.dayEnd - 1)], frame: frame)
        suite.expect(late.text(de).hasPrefix("23:23–24:00 Uhr außerhalb"), late.text(de))
    }

    private static func limitAlertsAt945And10Hours(_ suite: TestSuite) {
        suite.expect(TTLimitAlert.level(h(9, 44)) == nil, "9:44: nothing")
        suite.expect(TTLimitAlert.level(h(9, 45)) == .soon, "9:45: soon")
        suite.expect(TTLimitAlert.level(h(10, 0)) == .reached, "10:00: reached")
        suite.expect(TTLimitAlert.soon.title(de) == "Noch 15 Min. bis 10 Std. Arbeitszeit", TTLimitAlert.soon.title(de))
        suite.expect(TTLimitAlert.soon.body(de).hasPrefix("Heute 9:45 Std. gearbeitet"), TTLimitAlert.soon.body(de))
        suite.expect(TTLimitAlert.soon.id == "max-hours-soon" && TTLimitAlert.reached.id == "max-hours-reached",
                     "notification ids")

        var w = TTLimitWatch(date: date(16), work: h(9, 0))
        suite.expect(w.update(date: date(16), work: h(9, 44), working: true) == nil, "below 9:45")
        suite.expect(w.update(date: date(16), work: h(9, 45), working: true) == .soon, "9:45")
        suite.expect(w.update(date: date(16), work: h(9, 50), working: true) == nil, "only once")
        suite.expect(w.update(date: date(16), work: h(10, 0), working: true) == .reached, "10:00")
        suite.expect(w.update(date: date(16), work: h(10, 30), working: true) == nil, "only once")
        // Corrected down, then reached again.
        suite.expect(w.update(date: date(16), work: h(9, 30), working: false) == nil, "corrected down")
        suite.expect(w.update(date: date(16), work: h(10, 0), working: true) == .reached, "a jump only reports reached")
        // A new day.
        suite.expect(w.update(date: date(17), work: h(9, 45), working: true) == .soon, "a new day starts over")
        // Entered while not working: no notification, not later either.
        suite.expect(w.update(date: date(17), work: h(10, 5), working: false) == nil, "entered while not working")
        suite.expect(w.update(date: date(17), work: h(10, 6), working: true) == nil, "and not later")
        // Already over 9:45 h at start: only "reached".
        w = TTLimitWatch(date: date(18), work: h(9, 50))
        suite.expect(w.update(date: date(18), work: h(9, 55), working: true) == nil, "already reported at start")
        suite.expect(w.update(date: date(18), work: h(10, 0), working: true) == .reached, "then reached")
    }

    private static func carryInput(_ suite: TestSuite) {
        suite.expect(TTFormat.parseBalance("+12:30") == h(12, 30), "+12:30")
        suite.expect(TTFormat.parseBalance("-3:15") == -h(3, 15), "-3:15")
        suite.expect(TTFormat.parseBalance(" \u{2212}3:15 h ") == -h(3, 15), "−3:15 h")
        suite.expect(TTFormat.parseBalance("0:05") == h(0, 5), "0:05")
        suite.expect(TTFormat.parseBalance("12,5") == h(12, 30), "12,5")
        suite.expect(TTFormat.parseBalance("-0.25") == -h(0, 15), "-0.25")
        suite.expect(TTFormat.parseBalance("0") == 0, "0")
        for bad in ["", "abc", "1:60", "1:-5", "--2", "99999999:00"] {
            suite.expect(TTFormat.parseBalance(bad) == nil, "rejects \(bad)")
        }
        suite.expect(TTFormat.signedHoursMinutes(h(12, 30)) == "+12:30", "+12:30 formats")
        suite.expect(TTFormat.signedHoursMinutes(-h(3, 15)) == "\u{2212}3:15", "−3:15 formats")
        suite.expect(TTFormat.parseBalance(TTFormat.signedHoursMinutes(-h(3, 15))) == -h(3, 15), "round-trip")
    }

    private static func workdaysSpreadTheWeeklyTarget(_ suite: TestSuite) {
        let s = TTSettings()
        let d = TTWorkRules.default
        suite.expect(d.workdayCount == 5 && d.workdaysText(de) == "Mo–Fr" && d.weekText(de) == "5-Tage-Woche",
                     "the default week")
        // 4-day week without Friday: 32 h are 8 h on Mon–Thu, no target on Friday.
        let r4 = TTWorkRules(weeklyTarget: h(32, 0), workdays: 0b0_1111)
        let four = s.withRules(r4)
        suite.expect(r4.workdayCount == 4 && r4.workdaysText(de) == "Mo, Di, Mi, Do" && r4.weekText(de) == "4-Tage-Woche",
                     "a 4-day week")
        suite.expect(four.dailyTarget(date(16)) == h(8, 0), "Monday")
        suite.expect(four.dailyTarget(date(20)) == 0, "Friday")
        suite.expect(four.isWorkday(date(19)) && !four.isWorkday(date(20)) && !four.isWorkday(date(21)), "workdays")
        suite.expect(r4.summary(de)
                     == "Arbeitszeitrahmen 07:00–22:00 Uhr  ·  Regelarbeitszeit 32 Std./Woche (Mo, Di, Mi, Do)  ·  Pausen ab 15 Min.",
                     r4.summary(de))
        // Work on the free Friday does not count in the balance; a warning says so as
        // on the weekend; with the switch in the rules it is overtime.
        let fri = dayWith(20, [(h(9, 0), h(11, 0))])
        let hint = TTWarning.dayWarnings([fri], date: date(20), settings: four)
        suite.expect(hint == [.freeWeekday(counted: false)], "\(hint)")
        suite.expect(hint.first?.text(de) == "Arbeit an einem freien Tag – zählt nicht im Saldo", hint.first?.text(de) ?? "")
        suite.expect(four.balance([fri], from: date(16), to: date(22), today: date(23)) == (0, 0), "not in the balance")
        let fourCounted = s.withRules({ var r = r4; r.freeDaysCount = true; return r }())
        suite.expect(TTWarning.dayWarnings([fri], date: date(20), settings: fourCounted) == [.freeWeekday(counted: true)],
                     "counted as overtime")
        suite.expect(fourCounted.balance([fri], from: date(16), to: date(22), today: date(23)) == (h(2, 0), 0),
                     "overtime in the balance")
        // Invalid input: without a workday Mon–Fri again, Saturday and Sunday do not exist.
        suite.expect(TTWorkRules(workdays: 0).sanitized.workdays == TTLimits.allWorkdays, "no workday")
        suite.expect(TTWorkRules(workdays: 0b110_0001).sanitized.workdays == 0b0_0001, "weekend bits drop")
        suite.expect(s.withRules(TTWorkRules(weeklyTarget: h(8, 0), workdays: 0b0_0100)).dailyTarget(date(18)) == h(8, 0),
                     "a single workday takes the whole week")
        // Idle time: off or within bounds.
        var idle = s
        idle.idleSecs = -5
        suite.expect(idle.sanitized.idleSecs == 0, "negative idle time is off")
        idle.idleSecs = 10
        suite.expect(idle.sanitized.idleSecs == TTLimits.idleRange.lowerBound, "idle time has a floor")
        suite.expect(s.withRules(TTWorkRules(minPause: h(0, 45))).askAfter(date(16)) == h(0, 45),
                     "asking never comes before the minimum break")
        suite.expect(s.askAfter(date(16)) == TTLimits.askAfterLock, "asking after 30 min by default")
    }

    private static func absencesChangeTheTarget(_ suite: TestSuite) {
        let s = TTSettings()
        func day(_ d: Int, _ hours: Int, _ absence: TTAbsence?) -> TTDay {
            var x = hours > 0 ? dayWith(d, [(h(8, 0), h(8 + hours, 0))]) : TTDay(date: date(d))
            x.absence = absence
            return x
        }
        let full = h(7, 48)
        suite.expect(s.dayTarget(date(16), absence: nil) == full, "no absence")
        suite.expect(s.dayTarget(date(16), absence: TTAbsence(.vacation, half: true)) == full / 2, "half vacation")
        suite.expect(s.dayTarget(date(16), absence: TTAbsence(.sick, half: false)) == 0, "sick")
        suite.expect(s.dayTarget(date(16), absence: TTAbsence(.timeOff, half: false)) == full, "time off keeps the target")
        suite.expect(s.dayTarget(date(21), absence: TTAbsence(.timeOff, half: false)) == 0, "Saturday: no target")
        suite.expect(!TTAbsence(.timeOff, half: true).half, "there is no half time off")

        // Half vacation day with 4 h of work: +0:06 instead of −3:48.
        let half = day(16, 4, TTAbsence(.vacation, half: true))
        suite.expect(s.countedTarget(half, half.record(s)!, today: date(23)) == full / 2, "half target")
        // Whole vacation day, worked an hour anyway: overtime.
        let vacation = day(17, 1, TTAbsence(.vacation, half: false))
        // Time off without working time: the full target counts.
        let off = day(18, 0, TTAbsence(.timeOff, half: false))
        // Holiday without working time: no target.
        let holiday = day(19, 0, TTAbsence(.holiday, half: false))
        let days = [half, vacation, off, holiday]
        // As of Friday: Friday without an entry does not count yet …
        let friday = s.balance(days, from: date(16), to: date(22), today: date(20))
        suite.expect(friday == (h(5, 0), full / 2 + full), "\(friday)")
        suite.expect(TTFormat.balance(s.account(days, today: date(20))) == "\u{2212}6:42 h", "account on Friday")
        // … from Saturday it does: a workday without an absence, the full target is missing.
        suite.expect(s.balance(days, from: date(16), to: date(22), today: date(21)) == (h(5, 0), full / 2 + 2 * full),
                     "Friday counts from Saturday")
        suite.expect(TTFormat.balance(s.account(days, today: date(22))) == "\u{2212}14:30 h", "account on Sunday")
        // Planned time off only counts on its day.
        suite.expect(s.countedTarget(days[2], days[2].record(s)!, today: date(17)) == 0, "planned time off")
        suite.expect(s.countedTarget(days[2], days[2].record(s)!, today: date(18)) == full, "time off on its day")
        // The absence alone makes the day an entry.
        suite.expect(!days[2].isEmpty && days[2].hasCorrections, "an absence is a correction")
        // Texts for export and table, and back.
        let a = TTAbsence(.vacation, half: true)
        suite.expect(a.label(de) == "Urlaub (halber Tag)" && a.short(de) == "½ Urlaub" && a.code(de) == "½ U",
                     "half vacation texts")
        suite.expect(TTAbsence(.timeOff, half: false).code(de) == "ZA", "time off code")
        suite.expect(TTAbsence.parse("Urlaub (halber Tag)", de) == a, "parse half vacation")
        suite.expect(TTAbsence.parse(" zeitausgleich ", de) == TTAbsence(.timeOff, half: false), "parse time off")
        suite.expect(TTAbsence.parse("Dienstreise", de) == nil, "no business trips")
    }

    private static func specialLeaveIsAlwaysAFullDay(_ suite: TestSuite) {
        let s = TTSettings()
        let a = TTAbsence(.specialLeave, half: true)
        suite.expect(!a.half, "there is no half special leave")
        suite.expect(TTAbsenceKind.specialLeave.reducesTarget && !TTAbsenceKind.specialLeave.allowsHalf,
                     "special leave lowers the target, whole days only")
        suite.expect(TTAbsenceKind.vacation.allowsHalf && !TTAbsenceKind.timeOff.allowsHalf, "half days")
        // Lowers the target completely, like a whole vacation day.
        suite.expect(s.dayTarget(date(16), absence: a) == 0, "no target")
        var day = TTDay(date: date(16))
        day.absence = a
        suite.expect(s.balance([day], from: date(16), to: date(16), today: date(23)) == (0, 0), "no balance")
        // Texts, id and back; "Sonderurlaub" is no "Urlaub".
        suite.expect(a.label(de) == "Sonderurlaub" && a.short(de) == "Sonderurlaub" && a.code(de) == "SU",
                     "special leave texts")
        suite.expect(TTAbsence.parse("Sonderurlaub", de) == a, "parse special leave")
        suite.expect(TTAbsence.parse("Sonderurlaub (halber Tag)", de) == a, "parse special leave as a whole day")
        suite.expect(TTAbsence.parse("Urlaub", de) == TTAbsence(.vacation, half: false), "parse vacation")
        suite.expect(TTAbsenceKind.from(id: TTAbsenceKind.specialLeave.id) == .specialLeave, "id round-trips")
        suite.expect(TTAbsenceKind.all.map(\.id) == [1, 5, 2, 3, 4], "ids as stored by Tagwerk")
        // Whole day: not next to other entries.
        let busy = dayWith(17, [(h(8, 0), h(9, 0))])
        suite.expect(!busy.acceptsAbsence(a, today: false), "not next to other entries")
    }

    private static func freeDayWorkCountsOnlyIfTheRulesSaySo(_ suite: TestSuite) {
        // Until Wednesday the default (does not count), from Thursday work on free days counts.
        var s = TTSettings()
        s.setRules(from: date(19), TTWorkRules(freeDaysCount: true))
        suite.expect(s.work.count == 2, "only the switch tells the sets apart")
        func day(_ d: Int) -> TTDay { dayWith(d, [(h(10, 0), h(12, 0))]) }
        // The Sunday before does not count, the Saturday after does; workdays always count.
        let (sun, mon, sat) = (day(15), day(16), day(21))
        suite.expect(!s.workCountsOn(date(15)) && s.workCountsOn(date(16)) && s.workCountsOn(date(21)),
                     "where work counts")
        func rec(_ d: TTDay) -> TTDayRecord { d.record(s)! }
        suite.expect(s.dayBalance(sun, rec(sun), today: date(23)) == nil, "no balance")
        suite.expect(s.dayBalance(sat, rec(sat), today: date(23)) == h(2, 0), "Saturday is overtime")
        suite.expect(s.dayBalance(mon, rec(mon), today: date(23)) == h(2, 0) - h(7, 48), "Monday")
        let days = [sun, mon, sat]
        suite.expect(s.balance(days, from: date(15), to: date(15), today: date(23)) == (0, 0), "Sunday")
        suite.expect(s.balance(days, from: date(21), to: date(21), today: date(23)) == (h(2, 0), 0), "Saturday")
        // A warning on the weekend, depending on whether it counts.
        suite.expect(TTWarning.dayWarnings(days, date: date(15), settings: s) == [.weekend(counted: false)], "Sunday")
        suite.expect(TTWarning.dayWarnings(days, date: date(21), settings: s) == [.weekend(counted: true)], "Saturday")
        suite.expect(TTWarning.weekend(counted: false).text(de) == "Arbeit am Wochenende – zählt nicht im Saldo",
                     "weekend text")
        // A holiday on a workday is no free day: work counts as overtime.
        var holiday = day(17)
        holiday.absence = TTAbsence(.holiday, half: false)
        suite.expect(s.dayBalance(holiday, rec(holiday), today: date(23)) == h(2, 0), "holiday work is overtime")
        // The summary names the switch only when it is on.
        suite.expect(!s.rules(date(16)).summary(de).contains("freien Tagen"), "off: not named")
        suite.expect(s.rules(date(19)).summary(de).hasSuffix("Arbeit an freien Tagen im Saldo"), "on: named")
        // The default does not count.
        suite.expect(!TTWorkRules.default.freeDaysCount && !TTSettings().workCountsOn(date(15)), "default")
        // `sanitized` keeps the switch.
        suite.expect(TTWorkRules(freeDaysCount: true).sanitized.freeDaysCount, "sanitized keeps the switch")
    }

    private static func accountAddsCarryAndCountsFromStart(_ suite: TestSuite) {
        var s = TTSettings()
        // Mon 9 h (+1:12), Tue 7 h (−0:48), Wed to Fri exactly the target, Sat 1 h
        // (does not count, only with the switch in the rules as overtime).
        var days = [dayWith(16, [(h(8, 0), h(17, 0))]), dayWith(17, [(h(8, 0), h(15, 0))])]
        days += (18...20).map { dayWith($0, [(h(8, 0), h(15, 48))]) }
        days.append(dayWith(21, [(h(10, 0), h(11, 0))]))
        suite.expect(s.account(days, today: date(22)) == h(0, 24), "account without free days")
        s = s.withRules(TTWorkRules(freeDaysCount: true))
        suite.expect(s.account(days, today: date(22)) == h(1, 24), "account with free days")
        // As of an earlier day: later days do not count yet.
        suite.expect(s.account(days, today: date(16)) == h(1, 12), "account on Monday")
        // From Tuesday, with 5 h carried over from before.
        var fromTue = s
        fromTue.accountFrom = date(17)
        fromTue.accountCarry = h(5, 0)
        suite.expect(fromTue.account(days, today: date(22)) == h(5, 0) - h(0, 48) + h(1, 0), "start and carry")
        var minus = s
        minus.accountCarry = -h(2, 0)
        suite.expect(TTFormat.balance(minus.account(days, today: date(22))) == "\u{2212}0:36 h", "negative carry")
    }

    private static func breakRemindersAt545And6Hours(_ suite: TestSuite) {
        suite.expect(TTBreakAlert.level(h(5, 44)) == nil, "5:44: nothing")
        suite.expect(TTBreakAlert.level(h(5, 45)) == .soon, "5:45: soon")
        suite.expect(TTBreakAlert.level(h(6, 0)) == .reached, "6:00: reached")
        suite.expect(TTBreakAlert.soon.title(de) == "Noch 15 Min. bis 6 Std. ohne Pause", TTBreakAlert.soon.title(de))
        suite.expect(TTBreakAlert.soon.body(de).hasPrefix("Seit 5:45 Std. ohne Pause"), TTBreakAlert.soon.body(de))
        suite.expect(TTBreakAlert.soon.id == "break-soon" && TTBreakAlert.reached.id == "break-reached",
                     "notification ids")

        var w = TTBreakWatch(date: date(16), stretch: h(2, 0))
        suite.expect(w.update(date: date(16), stretch: h(5, 45), working: true) == .soon, "5:45")
        suite.expect(w.update(date: date(16), stretch: h(5, 50), working: true) == nil, "only once")
        suite.expect(w.update(date: date(16), stretch: h(6, 0), working: true) == .reached, "6:00")
        // After the break the stretch starts anew, and the reminder comes again.
        suite.expect(w.update(date: date(16), stretch: h(0, 10), working: true) == nil, "after a break")
        suite.expect(w.update(date: date(16), stretch: h(5, 45), working: true) == .soon, "the reminder comes again")
        // Already over 6 h in one stretch at start: no reminder any more.
        w = TTBreakWatch(date: date(17), stretch: h(6, 30))
        suite.expect(w.update(date: date(17), stretch: h(6, 31), working: true) == nil, "already reached at start")
    }

    private static func balanceCountsWorkdaysWithoutEntries(_ suite: TestSuite) {
        let s = TTSettings()
        let mon = dayWith(16, [(h(8, 0), h(17, 0))]) // 9 h
        let sat = dayWith(21, [(h(10, 0), h(11, 0))]) // weekend: no target, does not count
        let days = [mon, sat]
        // As of Tuesday: today only counts with working time.
        suite.expect(s.balance(days, from: date(16), to: date(22), today: date(17)) == (h(9, 0), h(7, 48)), "Tuesday")
        suite.expect(s.missingWorkdays(days, from: date(16), to: date(22), today: date(17)).isEmpty, "none missing yet")
        // As of the Monday after: Tue to Fri without an entry count with their target.
        suite.expect(s.missingWorkdays(days, from: date(16), to: date(22), today: date(23)) == (17...20).map(date),
                     "Tue to Fri are missing")
        suite.expect(s.balance(days, from: date(16), to: date(22), today: date(23)) == (h(9, 0), 5 * h(7, 48)),
                     "they count with their target")
        // Before the first recorded day nothing counts; without entries nothing at all.
        suite.expect(s.missingWorkdays(days, from: date(2), to: date(13), today: date(23)).isEmpty, "before the first day")
        suite.expect(s.missingWorkdays([], from: date(16), to: date(22), today: date(23)).isEmpty, "no days")
        // A day with only a break or the like, but no working time, counts its target as well.
        var tue = TTDay(date: date(17))
        tue.addBreak(from: h(12, 0), to: h(12, 30))
        suite.expect(s.countedTarget(tue, tue.record(s)!, today: date(23)) == h(7, 48), "a day with only a break")
        suite.expect(s.countedTarget(tue, tue.record(s)!, today: date(17)) == 0, "not yet today")
    }

    private static func balanceAddsUpShownMinutes(_ suite: TestSuite) {
        // Two days of 7:34:40 h each: shown 7:34 h and −0:14 h each, so the week is
        // 15:08 h and −0:28 h, not 15:09 h and −0:26 h from the seconds.
        let s = TTSettings()
        let days = [16, 17].map { dayWith($0, [(h(8, 0) + 10, h(15, 34) + 50)]) }
        let rec = days[0].record(s)!
        suite.expect(TTFormat.balance(rec.shownWorkSecs - s.dailyTarget(rec.date)) == "\u{2212}0:14 h", "a day")
        let (work, target) = s.balance(days, from: date(16), to: date(22), today: date(18))
        suite.expect(work == h(15, 8), "the week's shown work")
        suite.expect(TTFormat.balance(work - target) == "\u{2212}0:28 h", "the week's balance")
    }

    private static func dailyTargetsAreWholeMinutesAndAddUp(_ suite: TestSuite) {
        // 38.5 h on four days: 9:37:30 per day would not divide into minutes.
        let r = TTWorkRules(weeklyTarget: h(38, 30), workdays: 0b0_1111)
        let s = TTSettings().withRules(r)
        let targets = (16...22).map { s.dailyTarget(date($0)) }
        suite.expect(targets == [h(9, 37), h(9, 38), h(9, 37), h(9, 38), 0, 0, 0], "\(targets)")
        suite.expect(targets.reduce(0, +) == h(38, 30), "they add up to the week")
        suite.expect(r.dailyTargetRange == (h(9, 37), h(9, 38)), "range")
        suite.expect(r.dailyTargetText(de) == "9:37 bis 9:38 Std.", r.dailyTargetText(de))
        suite.expect(TTWorkRules.default.dailyTargetText(de) == "7:48 Std.", TTWorkRules.default.dailyTargetText(de))
        suite.expect((16...20).allSatisfy { TTSettings().dailyTarget(date($0)) == h(7, 48) }, "7:48 every workday")
        // Tue and Thu as workdays: the second gets the extra minute.
        let two = TTWorkRules(weeklyTarget: h(19, 15), workdays: 0b0_1010)
        suite.expect((two.dailyTarget(on: date(17)), two.dailyTarget(on: date(19))) == (h(9, 37), h(9, 38)),
                     "the second day gets the minute")
        suite.expect(two.dailyTarget(on: date(16)) == 0, "Monday is free")
        // Four days of 9:37:30 work each: every day's balance is a whole number of
        // minutes, and together they make exactly the week's balance.
        let days = (16...19).map { dayWith($0, [(h(8, 0), h(17, 37) + 30)]) }
        let perDay = days.map { s.dayBalance($0, $0.record(s)!, today: date(23))! }
        suite.expect(perDay == [0, -60, 0, -60], "\(perDay)")
        let (work, target) = s.balance(days, from: date(16), to: date(22), today: date(23))
        suite.expect(work - target == perDay.reduce(0, +), "days add up to the week")
        suite.expect(TTFormat.balance(work - target) == "\u{2212}0:02 h", "the week's balance")
        // Half day: half, rounded down to whole minutes.
        let half = TTAbsence(.vacation, half: true)
        suite.expect(s.dayTarget(date(16), absence: half) == h(4, 48), "half of 9:37")
        suite.expect(TTSettings().dayTarget(date(16), absence: half) == h(3, 54), "half of 7:48")
        // A weekly target with seconds (only from a foreign database) is rounded down.
        suite.expect(TTWorkRules(weeklyTarget: h(39, 0) + 59).sanitized.weeklyTarget == h(39, 0), "seconds drop")
    }

    private static func todaysTargetCountsOnlyAsFarAsWorked(_ suite: TestSuite) {
        let s = TTSettings()
        let mon = dayWith(16, [(h(8, 0), h(16, 0))]) // 8:00 h: +0:12
        var tue = dayWith(17, [(h(8, 0), h(8, 1))])
        func week(_ days: [TTDay], _ today: Int) -> Int {
            let (work, target) = s.balance(days, from: date(16), to: date(22), today: date(today))
            return work - target
        }
        func dayBalance(_ d: TTDay, _ today: Int) -> Int? { s.dayBalance(d, d.record(s)!, today: date(today)) }
        // Tuesday before the first unlock and at 08:01: the week's balance stays.
        suite.expect(week([mon], 17) == h(0, 12), "before the first unlock")
        suite.expect(week([mon, tue], 17) == h(0, 12), "at 08:01")
        suite.expect(dayBalance(tue, 17) == 0, "today stands at zero")
        // At noon as well; above the target it grows.
        tue.addPeriod(from: h(8, 0), to: h(12, 0))
        suite.expect(week([mon, tue], 17) == h(0, 12), "at noon")
        var long = tue
        long.addPeriod(from: h(12, 0), to: h(16, 30))
        suite.expect(dayBalance(long, 17) == h(0, 42), "above the target")
        // End of work at 12:00: the day is over, the rest is missing.
        var closed = tue
        closed.end = h(12, 0)
        suite.expect(dayBalance(closed, 17) == h(4, 0) - h(7, 48), "closed day")
        // Without an end it is missing from tomorrow.
        suite.expect(dayBalance(tue, 18) == h(4, 0) - h(7, 48), "tomorrow")
        suite.expect(week([mon, tue], 18) == h(0, 12) + h(4, 0) - h(7, 48), "the week tomorrow")
        // Half vacation today: half the target, also only as far as worked.
        var half = tue
        half.absence = TTAbsence(.vacation, half: true)
        suite.expect(dayBalance(half, 17) == h(0, 6), "half vacation today")
        var halfOnly = TTDay(date: date(17))
        halfOnly.absence = half.absence
        suite.expect(dayBalance(halfOnly, 17) == nil, "half vacation without work today")
        suite.expect(dayBalance(halfOnly, 18) == -h(3, 54), "half vacation without work tomorrow")
        // Time off counts at once: there the time account is meant to go down.
        var off = TTDay(date: date(17))
        off.absence = TTAbsence(.timeOff, half: false)
        suite.expect(dayBalance(off, 17) == -h(7, 48), "time off counts at once")
    }

    private static func legalChecksSeeWorkOutsideTheFrame(_ suite: TestSuite) {
        let s = TTSettings()
        // Monday at the Mac until 23:30 (counted until 22:00), Tuesday from 09:15.
        let mon = dayWith(16, [(h(8, 0), h(12, 0)), (h(13, 0), h(23, 30))])
        let tue = dayWith(17, [(h(9, 15), h(12, 0))])
        var w = TTWarning.dayWarnings([mon, tue], date: date(17), settings: s)
        suite.expect(w == [.rest(rest: h(9, 45), outside: true)], "\(w)")
        suite.expect(w.first?.text(de) == "Ruhezeit nur 9:45 Std. – vorgeschrieben sind 11 Std. (§ 5 ArbZG), "
                     + "mit der Zeit außerhalb des Arbeitszeitrahmens", w.first?.text(de) ?? "")
        // Wednesday 05:00–11:00 and 11:45–16:00: counted 8:15, actually 10:15 h.
        let wed = dayWith(18, [(h(5, 0), h(11, 0)), (h(11, 45), h(16, 0))])
        w = TTWarning.dayWarnings([wed], date: date(18), settings: s)
        suite.expect(w.count == 2, "\(w)")
        suite.expect(w.first == .maxHours(work: h(10, 15), outside: true), "\(w)")
        suite.expect(w.count == 2 && isOutsideFrame(w[1]), "\(w)")
        // A violation already in the counted time is not reported twice.
        let long = dayWith(18, [(h(5, 0), h(11, 0)), (h(11, 45), h(19, 0))])
        w = TTWarning.dayWarnings([long], date: date(18), settings: s)
        suite.expect(w.filter(isMaxHours) == [.maxHours(work: h(11, 15), outside: false)], "\(w)")
        // A short glance at the Mac at night (under a minute) shortens no rest.
        let thu = dayWith(19, [(h(2, 0), h(2, 0) + 30), (h(8, 0), h(12, 0))])
        suite.expect(TTWarning.dayWarnings([wed, thu], date: date(19), settings: s).isEmpty, "a glance at night")
        // Sunday evening recorded but not counted: no work, so no rest either.
        var sun = dayWith(22, [(h(20, 0), h(23, 0))])
        sun.freeDay = .uncounted
        let next = dayWith(23, [(h(7, 0), h(12, 0))])
        suite.expect(TTWarning.dayWarnings([sun, next], date: date(23), settings: s).isEmpty, "uncounted Sunday")
    }

    private static func aDayWithOnlyTheFreeDayMarkIsNoEntry(_ suite: TestSuite) {
        let s = TTSettings()
        let first = dayWith(16, [(h(8, 0), h(16, 0))])
        // Only the decision about recording, on a day that is (by now) a workday.
        var marked = TTDay(date: date(17))
        marked.freeDay = .stopped
        let days = [first, marked]
        suite.expect(s.missingWorkdays(days, from: date(16), to: date(22), today: date(19)) == [date(17), date(18)],
                     "the marked day is missing")
        suite.expect(s.balance(days, from: date(16), to: date(22), today: date(19)) == (h(8, 0), 3 * h(7, 48)),
                     "it counts its target")
        // Such a day alone is no first recorded day either.
        suite.expect(s.missingWorkdays([marked], from: date(16), to: date(22), today: date(19)).isEmpty,
                     "no first recorded day")
    }

    // MARK: English

    private static func englishTexts(_ suite: TestSuite) {
        let en = FeatureStrings.timeTrackingTexts(.enUS)
        suite.expect(FeatureStrings.timeTrackingTexts(.de).absenceVacation == "Urlaub"
                     && FeatureStrings.timeTrackingTexts(.fr).absenceVacation == en.absenceVacation,
                     "German is Tagwerk's, the others are English for now")
        let r4 = TTWorkRules(weeklyTarget: h(38, 30), workdays: 0b0_1011)
        suite.expect(r4.summary(en) == "Working hours 07:00–22:00  ·  Regular hours 38.5 h/week (Mon, Tue, Thu)  ·  Breaks from 15 min",
                     r4.summary(en))
        suite.expect(TTWorkRules.default.dailyTargetText(en) == "7:48 h" && TTWorkRules.default.workdaysText(en) == "Mon–Fri",
                     "English target and workdays")
        suite.expect(TTFormat.day(date(30), en) == "2026-11-30" && TTFormat.day(date(30), de) == "30.11.2026",
                     "dates")
        suite.expect(TTWarning.rest(rest: h(9, 45), outside: true).text(en)
                     == "Rest period only 9:45 h – 11 h are required (§ 5 ArbZG), including the time outside working hours",
                     TTWarning.rest(rest: h(9, 45), outside: true).text(en))
        let frame = TTSpan(h(7, 0), h(22, 0))
        suite.expect(TTWarning.outsideFrame(spans: [TTSpan(h(6, 30), h(7, 0)), TTSpan(h(22, 0), h(23, 0))], frame: frame).text(en)
                     == "06:30–07:00 and 22:00–23:00 outside working hours (07:00–22:00) – not counted",
                     "outside the frame in English")
        let a = TTAbsence(.sick, half: true)
        suite.expect(a.label(en) == "Sick (half day)" && TTAbsence.parse(a.label(en), en) == a && a.code(en) == "½ S",
                     "English absences round-trip")
        var d = TTDay(date: date(16))
        d.addPeriod(from: h(11, 10), to: h(12, 42))
        d.addPeriod(from: h(13, 27), to: h(15, 55))
        suite.expect(d.joinWorkGaps(from: h(12, 42), to: h(13, 18), minPause: 15 * 60).note(minPause: 15 * 60, en)
                     == "A gap from 13:18 to 13:27 (9 min) would have been left next to the working time. That is "
                     + "shorter than the minimum break of 15 min, so the time was added to the new block. "
                     + "It now runs from 12:42 to 13:27.",
                     "English note")
        suite.expect(TTLimitAlert.soon.body(en).hasPrefix("9:45 h worked today") && TTBreakAlert.soon.title(en)
                     == "15 min left until 6 h without a break", "English notifications")
    }
}
