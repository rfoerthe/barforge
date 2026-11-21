// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

// Settings and rules of time tracking (port of Tagwerk's `rules.rs`).
//
// Adjustable are the working-time frame, the regular weekly hours, the workdays
// and the minimum break (`TTWorkRules`), each from a date on, so a change does
// not recompute earlier days (`TTSettings.rules(_:)` gives a day's rules). Fixed
// are the rules of the German Working Hours Act (ArbZG):
//
// - Frame: work only within the set frame (default 07:00–22:00); outside it
//   counts as neither work nor break, but there is a warning.
// - Free days: weekend and deselected workdays have no target. Work there does
//   not change balance and account unless the rules say so (`freeDaysCount`).
// - Target: the weekly hours spread over the workdays in whole minutes
//   (`TTWorkRules.dailyTarget(on:)`); the balance follows from it.
// - Breaks (§ 4): more than 6 h of work need 30 min, more than 9 h 45 min, in
//   parts of at least 15 min. More than 6 h in one stretch is a violation too.
// - Rest (§ 5): at least 11 h between two working days.
// - Maximum hours (§ 3): more than 10 h a day.

/// Fixed limits and bounds (`rules.rs` constants).
enum TTLimits {
    /// Midnight at the end of the day (24:00:00).
    static let dayEnd = 86_400
    /// Only breaks of at least 15 minutes count under the Act.
    static let legalBreakSegment = 15 * 60
    /// Nobody may work more than 6 hours in a row without a break.
    static let maxStretch = 6 * 3600
    /// More than 10 hours of work a day are a violation.
    static let maxDailyWork = 10 * 3600
    /// Minimum rest between two working days.
    static let minRest = 11 * 3600
    /// All workdays: Monday to Friday (bit 0 = Monday … bit 4 = Friday).
    static let allWorkdays = 0b1_1111
    /// Bounds of the idle time after which recording pauses (0 = off).
    static let idleRange = 60...(120 * 60)
    /// Largest amount carried over into the time account.
    static let carryMax = 10_000 * 3600
    /// From this long a lock on, unlocking asks what the time was (when on);
    /// never shorter than the minimum break.
    static let askAfterLock = 30 * 60
    static let minPauseRange = 60...(120 * 60)
    static let weeklyRange = 3600...(60 * 3600)
    /// Bounds for the minimum length of work away from the Mac when entered by
    /// hand. It has nothing to do with the minimum break and only guards
    /// against accidental entries.
    static let minWorkRange = 60...(240 * 60)
    /// Advance notice before the maximum working time.
    static let maxDailyWorkNotice = 15 * 60
    /// Advance notice before 6 hours in one stretch.
    static let maxStretchNotice = 15 * 60
}

extension Int {
    func ttClamped(to range: ClosedRange<Int>) -> Int {
        ttClamped(range.lowerBound, range.upperBound)
    }
}

/// Icon set for the menu bar (ids as stored by Tagwerk).
enum TTIconSet: Int, CaseIterable, Sendable {
    /// The working day as a sun arc above the horizon.
    case tagbogen = 0
    /// Padlock with a clock: unlocked = working time.
    case schlossuhr = 1
    /// Progress ring towards the day's target.
    case tagesring = 2
    /// Builder with helmet and hammer.
    case bauarbeiter = 3
    /// Craftswoman with bun, bow and spanner.
    case handwerkerin = 4
    /// Coffee cup with a face.
    case kaffeetasse = 5
    /// Hamster in a wheel.
    case hamsterrad = 6
    /// Robot.
    case roboter = 7
    /// Rabbit with long ears.
    case kaninchen = 8

    static let `default`: TTIconSet = .tagbogen

    /// Value in the database.
    var id: Int { rawValue }

    /// Unknown values give the default.
    static func from(id: Int) -> TTIconSet {
        TTIconSet(rawValue: id) ?? .default
    }

    func name(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case .tagbogen: return texts.iconSetDayArc
        case .schlossuhr: return texts.iconSetLockClock
        case .tagesring: return texts.iconSetDayRing
        case .bauarbeiter: return texts.iconSetBuilder
        case .handwerkerin: return texts.iconSetCraftswoman
        case .kaffeetasse: return texts.iconSetCoffeeCup
        case .hamsterrad: return texts.iconSetHamsterWheel
        case .roboter: return texts.iconSetRobot
        case .kaninchen: return texts.iconSetRabbit
        }
    }
}

/// Working-time rules: what counts as work, break and target on a day (all
/// times in seconds). They apply from a day until the next set of rules (see
/// `TTSettings.work`), so a change does not recompute earlier days.
struct TTWorkRules: Hashable, Sendable {
    /// Minimum break: shorter locks count as working time.
    var minPause: Int
    /// Regular weekly working hours.
    var weeklyTarget: Int
    /// Start of the working-time frame (seconds since midnight).
    var frameFrom: Int
    /// End of the working-time frame (seconds since midnight).
    var frameTo: Int
    /// Workdays as bits (bit 0 = Monday … bit 4 = Friday); the weekly target
    /// spreads evenly over them.
    var workdays: Int
    /// Work on free days (weekend, deselected workdays) counts as overtime in
    /// balance and account. Default: no, it is shown but changes no balance.
    var freeDaysCount: Bool

    init(minPause: Int = 15 * 60, weeklyTarget: Int = 39 * 3600, frameFrom: Int = 7 * 3600,
         frameTo: Int = 22 * 3600, workdays: Int = TTLimits.allWorkdays, freeDaysCount: Bool = false) {
        self.minPause = minPause
        self.weeklyTarget = weeklyTarget
        self.frameFrom = frameFrom
        self.frameTo = frameTo
        self.workdays = workdays
        self.freeDaysCount = freeDaysCount
    }

    static let `default` = TTWorkRules()

    /// Brings the values within valid bounds.
    var sanitized: TTWorkRules {
        let d = TTWorkRules.default
        let days = workdays & TTLimits.allWorkdays
        var r = TTWorkRules(
            minPause: minPause.ttClamped(to: TTLimits.minPauseRange),
            // In whole minutes, as it can be entered and as all balances compute.
            weeklyTarget: weeklyTarget.ttClamped(to: TTLimits.weeklyRange) / 60 * 60,
            frameFrom: frameFrom.ttClamped(0, TTLimits.dayEnd),
            frameTo: frameTo.ttClamped(0, TTLimits.dayEnd),
            // Without a workday there would be no target: Monday to Friday again.
            workdays: days == 0 ? TTLimits.allWorkdays : days,
            freeDaysCount: freeDaysCount)
        if r.frameTo <= r.frameFrom {
            r.frameFrom = d.frameFrom
            r.frameTo = d.frameTo
        }
        return r
    }

    /// Is `date` one of the set workdays (does it have a target)?
    func isWorkday(_ date: TTDate) -> Bool {
        let day = date.weekday
        return day < 5 && workdays & (1 << day) != 0
    }

    /// Number of workdays per week (1 to 5).
    var workdayCount: Int {
        Swift.max((workdays & TTLimits.allWorkdays).nonzeroBitCount, 1)
    }

    /// Target of the day `date` in whole minutes (0 on free days). If the weekly
    /// hours do not divide into whole minutes (38.5 h on four days = 9:37:30),
    /// the workdays of the week get 9:37, 9:38, 9:37 and 9:38 h in turn, exactly
    /// the weekly hours together. So every day's balance is a whole number of
    /// minutes and days add up to the week without rounding remainders.
    func dailyTarget(on date: TTDate) -> Int {
        guard isWorkday(date) else { return 0 }
        let weekday = date.weekday
        // Workdays of the week before this day.
        let before = (workdays & ((1 << weekday) - 1)).nonzeroBitCount
        let (week, n) = (weeklyTarget / 60, workdayCount)
        return ((before + 1) * week / n - before * week / n) * 60
    }

    /// Shortest and longest target of a workday (see `dailyTarget(on:)`),
    /// mostly equal, otherwise a minute apart.
    var dailyTargetRange: (low: Int, high: Int) {
        let (week, n) = (weeklyTarget / 60, workdayCount)
        let low = week / n * 60
        return (low, week % n == 0 ? low : low + 60)
    }

    /// `7:48 Std.` or `9:37 bis 9:38 Std.`: the target of a workday to show.
    func dailyTargetText(_ texts: TimeTrackingTexts) -> String {
        let (low, high) = dailyTargetRange
        if low == high { return String(format: texts.dailyTargetFormat, TTFormat.hoursMinutes(low)) }
        return String(format: texts.dailyTargetRangeFormat, TTFormat.hoursMinutes(low), TTFormat.hoursMinutes(high))
    }

    /// `Mo–Fr` or `Mo, Di, Do`: the set workdays.
    func workdaysText(_ texts: TimeTrackingTexts) -> String {
        if workdays & TTLimits.allWorkdays == TTLimits.allWorkdays { return texts.mondayToFriday }
        let names = texts.weekdayShortNames.prefix(5)
        return names.enumerated()
            .filter { workdays & (1 << $0.offset) != 0 }
            .map(\.element)
            .joined(separator: texts.listSeparator)
    }

    /// `5-Tage-Woche`
    func weekText(_ texts: TimeTrackingTexts) -> String {
        String(format: texts.weekFormat, workdayCount)
    }

    /// Does the time `secs` lie within the working-time frame?
    func inFrame(_ secs: Int) -> Bool {
        (frameFrom..<frameTo).contains(secs)
    }

    /// `07:00–22:00 Uhr`
    func frameText(_ texts: TimeTrackingTexts) -> String {
        String(format: texts.frameFormat, TTFormat.clock(frameFrom), TTFormat.clock(frameTo))
    }

    /// Summary for footers and the export.
    func summary(_ texts: TimeTrackingTexts) -> String {
        String(format: texts.rulesSummaryFormat, frameText(texts), TTFormat.hours(weeklyTarget, texts),
               workdaysText(texts), minPause / 60, freeDaysCount ? texts.rulesSummaryFreeDays : "")
    }
}

/// A set of working-time rules: applies from `from` (`nil`: since always) until the next.
struct TTRulesPeriod: Hashable, Sendable {
    var from: TTDate?
    var rules: TTWorkRules

    init(from: TTDate?, rules: TTWorkRules) {
        self.from = from
        self.rules = rules
    }
}

/// Values the user can set (all times in seconds).
struct TTSettings: Hashable, Sendable {
    /// Working-time rules with their validity: sorted by date, never empty, the
    /// first applies since always (`from: nil`), two in a row differ (see
    /// `sanitized`). Query through `rules(_:)`.
    var work: [TTRulesPeriod] = [TTRulesPeriod(from: nil, rules: .default)]
    /// Minimum length of work away from the Mac entered by hand (independent of
    /// the minimum break; only checks input and so applies without a date).
    var minWork = 15 * 60
    /// Icon set of the menu bar.
    var iconSet = TTIconSet.default
    /// Show today's working time next to the menu bar icon.
    var showTime = false
    /// Global shortcuts.
    var hotkeys = false
    /// Recording counts only on workdays: on Saturday, Sunday and free weekdays
    /// it is recorded but only counts after "Record today" (see `TTDay.freeDay`).
    var autoWorkdaysOnly = true
    /// After this long without input (seconds) the Mac counts as left and
    /// recording pauses (0 = off).
    var idleSecs = 0
    /// On unlocking after a long lock, ask whether it was a break, work or the end of work.
    var askAfterLock = false
    /// Notifications about the maximum working time (9:45 and 10 h).
    var notifyLimit = true
    /// Notifications about breaks (5:45 and 6 h of work in a row).
    var notifyBreak = true
    /// The time account counts from this day (`nil`: all recorded days).
    var accountFrom: TTDate?
    /// Carried over into the time account: balance from before (seconds, also negative).
    var accountCarry = 0

    init() {}

    /// Brings the values within valid bounds (after loading, for example).
    var sanitized: TTSettings {
        var s = self
        s.work = TTSettings.normalized(work)
        s.minWork = minWork.ttClamped(to: TTLimits.minWorkRange)
        s.idleSecs = idleSecs <= 0 ? 0 : idleSecs.ttClamped(to: TTLimits.idleRange)
        s.accountCarry = accountCarry.ttClamped(-TTLimits.carryMax, TTLimits.carryMax)
        return s
    }

    /// The same settings with a single set of rules that applies since always.
    func withRules(_ rules: TTWorkRules) -> TTSettings {
        var s = self
        s.work = [TTRulesPeriod(from: nil, rules: rules)]
        return s.sanitized
    }

    /// The working-time rules that apply on the day `date`.
    func rules(_ date: TTDate) -> TTWorkRules {
        work.last { period in period.from.map { $0 <= date } ?? true }?.rules ?? .default
    }

    /// Sets the rules from `from` (`nil`: since always). Rules with the same
    /// date are replaced, and so are the rules from `replaces` (when moving a
    /// set to another date, in one step so nothing merges in between). Rules
    /// equal to the ones before them go.
    mutating func setRules(from: TTDate?, _ rules: TTWorkRules, replaces: TTDate? = nil) {
        work.removeAll { $0.from == from || (replaces != nil && $0.from == replaces) }
        work.append(TTRulesPeriod(from: from, rules: rules.sanitized))
        work = TTSettings.normalized(work)
    }

    /// Deletes the rules from `from`; from then on the rules before apply
    /// again. The first set (since always) always stays.
    mutating func removeRules(from: TTDate) {
        work.removeAll { $0.from == from }
        work = TTSettings.normalized(work)
    }

    /// The sets that apply between `from` and `to`: each with the first day in
    /// the range it applies on.
    func rulesBetween(_ from: TTDate, _ to: TTDate) -> [(from: TTDate, rules: TTWorkRules)] {
        var out: [(from: TTDate, rules: TTWorkRules)] = [(from, rules(from))]
        for period in work {
            if let start = period.from, start > from, start <= to {
                out.append((start, period.rules))
            }
        }
        return out
    }

    /// Summary of the rules from `from` to `to` for footers and the export, one
    /// paragraph per set when they change in the range.
    func summaryBetween(_ from: TTDate, _ to: TTDate, _ texts: TimeTrackingTexts) -> [String] {
        let parts = rulesBetween(from, to)
        if parts.count == 1 { return [parts[0].rules.summary(texts)] }
        return parts.enumerated().map { i, part in
            let summary = part.rules.summary(texts)
            if i + 1 == parts.count {
                return String(format: texts.rulesFromFormat, TTFormat.day(part.from, texts), summary)
            }
            let until = TTFormat.day(parts[i + 1].from.adding(days: -1), texts)
            if i == 0 { return String(format: texts.rulesUntilFormat, until, summary) }
            return String(format: texts.rulesRangeFormat, TTFormat.day(part.from, texts), until, summary)
        }
    }

    /// Basis of the target from `from` to `to` for footers: `39 Std./Woche,
    /// Mo–Fr`; when the rules change in the range, a pointer to the rules per day.
    func targetBasis(_ from: TTDate, _ to: TTDate, _ texts: TimeTrackingTexts) -> String {
        let parts = rulesBetween(from, to)
        guard parts.count == 1 else { return texts.targetBasisMixed }
        let r = parts[0].rules
        return String(format: texts.targetBasisFormat, TTFormat.hours(r.weeklyTarget, texts), r.workdaysText(texts))
    }

    /// Saturday or Sunday?
    static func isWeekend(_ date: TTDate) -> Bool { date.isWeekend }

    /// Is `date` a workday by the rules that apply on it (does it have a target)?
    func isWorkday(_ date: TTDate) -> Bool {
        rules(date).isWorkday(date)
    }

    /// Does automatic recording count on `date` by itself? Otherwise recording
    /// marks the day as uncounted at the first unlock, until "Record today".
    func autoCountsOn(_ date: TTDate) -> Bool {
        !autoWorkdaysOnly || isWorkday(date)
    }

    /// Does the working time on `date` go into balance and account? On workdays
    /// always, on free days only when the rules applying on it say so.
    func workCountsOn(_ date: TTDate) -> Bool {
        let r = rules(date)
        return r.freeDaysCount || r.isWorkday(date)
    }

    /// Working time `work` on `date` as far as it goes into the balance (else 0).
    func countedWork(_ date: TTDate, _ work: Int) -> Int {
        workCountsOn(date) ? work : 0
    }

    /// Balance of the day `day` with its figures `rec` (`today`: today): shown
    /// working time as far as it counts, minus the target (see
    /// `countedTarget`). `nil` when there is none: neither counted working time
    /// nor a target (work on a free day that does not count, for example).
    func dayBalance(_ day: TTDay, _ rec: TTDayRecord, today: TTDate) -> Int? {
        let target = countedTarget(day, rec, today: today)
        guard countedWork(day.date, rec.workSecs) > 0 || target > 0 else { return nil }
        return countedWork(day.date, rec.shownWorkSecs) - target
    }

    /// Target of a day (0 on free days) by the rules that apply on it.
    func dailyTarget(_ date: TTDate) -> Int {
        rules(date).dailyTarget(on: date)
    }

    /// Target of the day `date` with the absence `absence`: vacation, special
    /// leave, sickness and holiday lower it to zero or (half day) to half,
    /// rounded down to whole minutes; time off does not.
    func dayTarget(_ date: TTDate, absence: TTAbsence?) -> Int {
        let full = dailyTarget(date)
        guard let absence else { return full }
        if !absence.kind.reducesTarget { return full }
        return absence.half ? full / 120 * 60 : 0
    }

    /// Target of `day` with its figures `rec` that goes into the balance
    /// (`today`: today). Until yesterday every workday counts, also without
    /// working time; with an absence what it says applies. Future days (a
    /// planned absence) do not count yet. Today the target counts only as far
    /// as it is worked: the running day stays at zero until the target is
    /// reached and is in the plus after. What is missing only counts with the
    /// end of work or from tomorrow. Time off counts at once.
    func countedTarget(_ day: TTDay, _ rec: TTDayRecord, today: TTDate) -> Int {
        let target = dayTarget(day.date, absence: day.absence)
        if day.date > today { return 0 }
        if day.date < today || day.end != nil || day.absence.map({ !$0.kind.reducesTarget }) == true {
            return target
        }
        return Swift.min(target, countedWork(day.date, rec.shownWorkSecs))
    }

    /// From this long a lock on the day `date`, unlocking asks (never under the
    /// minimum break).
    func askAfter(_ date: TTDate) -> Int {
        Swift.max(TTLimits.askAfterLock, rules(date).minPause)
    }

    /// Workdays from `from` to `to` without any entry (`days`: all days, sorted
    /// by date). They still count into the target, from the first recorded day
    /// (there is no data before) until yesterday (today only counts with working
    /// time). An entry is what gives a row (`TTDay.record`): recorded time, a
    /// correction or an absence. The mere decision about recording on a free
    /// day is none, otherwise the day would drop out of the target if it later
    /// becomes a workday.
    func missingWorkdays(_ days: [TTDay], from: TTDate, to: TTDate, today: TTDate) -> [TTDate] {
        func entry(_ d: TTDay) -> Bool { d.hasEntries || d.absence != nil }
        guard let first = days.first(where: entry)?.date, let yesterday = today.predecessor else { return [] }
        let (from, to) = (Swift.max(from, first), Swift.min(to, yesterday))
        guard from <= to else { return [] }
        let recorded = Set(days.filter { $0.date >= from && $0.date <= to && entry($0) }.map(\.date))
        return (from.ordinal...to.ordinal)
            .map(TTDate.init(ordinal:))
            .filter { isWorkday($0) && !recorded.contains($0) }
    }

    /// Working time that goes into the balance (as shown, in whole minutes) and
    /// target of the days from `from` to `to` (`days`: all days, `today`: today);
    /// the balance is the difference. Work on free days only counts when the
    /// rules say so. The target counts by `countedTarget`, also for workdays
    /// without any entry (`missingWorkdays`).
    func balance(_ days: [TTDay], from: TTDate, to: TTDate, today: TTDate) -> (work: Int, target: Int) {
        var (work, target) = (0, 0)
        for day in days where day.date >= from && day.date <= to {
            guard let rec = day.record(self) else { continue }
            work += countedWork(day.date, rec.shownWorkSecs)
            target += countedTarget(day, rec, today: today)
        }
        let missing = missingWorkdays(days, from: from, to: to, today: today).reduce(0) { $0 + dailyTarget($1) }
        return (work, target + missing)
    }

    /// Time account on the day `today`: carry plus the balance of all days since
    /// the set start (without a start: since the first recorded day), see `balance`.
    func account(_ days: [TTDay], today: TTDate) -> Int {
        let (work, target) = balance(days, from: accountFrom ?? .min, to: today, today: today)
        return accountCarry + work - target
    }

    /// Sorts, cleans and merges sets of rules: the first applies since always,
    /// there is at most one per date, and a set equal to the one before goes.
    static func normalized(_ work: [TTRulesPeriod]) -> [TTRulesPeriod] {
        // Stable: with the same date the last one entered wins.
        let sorted = work.ttStableSorted { lhs, rhs in
            switch (lhs.from, rhs.from) {
            case (nil, nil): return false
            case (nil, _): return true
            case (_, nil): return false
            case let (a?, b?): return a < b
            }
        }
        var out: [TTRulesPeriod] = []
        for period in sorted {
            let p = TTRulesPeriod(from: period.from, rules: period.rules.sanitized)
            if let last = out.last, last.from == p.from {
                out[out.count - 1] = p
            } else if let last = out.last, last.rules == p.rules {
                continue
            } else {
                out.append(p)
            }
        }
        if out.isEmpty {
            out.append(TTRulesPeriod(from: nil, rules: .default))
        } else {
            out[0].from = nil
        }
        return out
    }
}
