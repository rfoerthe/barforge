// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

// What the Records window shows, as pure functions (the model part of
// Tagwerk's `records.rs`): the rows of the table with week rows and missing
// workdays, the filter, the summary cards, the footer, the figures and notes
// of the inspector and the summary of the export dialog.

/// The period the table is limited to (`records.rs` `Period`).
enum TTRecordsPeriod: CaseIterable, Hashable, Sendable {
    case all, thisMonth, lastMonth, thisYear, lastYear

    func label(_ s: TimeTrackingRecordsStrings) -> String {
        switch self {
        case .all: return s.periodAll
        case .thisMonth: return s.periodThisMonth
        case .lastMonth: return s.periodLastMonth
        case .thisYear: return s.periodThisYear
        case .lastYear: return s.periodLastYear
        }
    }

    /// Does `date` lie in the period (seen from `today`)?
    func contains(_ date: TTDate, today: TTDate) -> Bool {
        switch self {
        case .all: return true
        case .thisMonth: return (date.year, date.month) == (today.year, today.month)
        case .lastMonth:
            let last = TTRecords.monthStart(today).adding(days: -1)
            return (date.year, date.month) == (last.year, last.month)
        case .thisYear: return date.year == today.year
        case .lastYear: return date.year == today.year - 1
        }
    }
}

/// Filter of the table: period and marks of the days. It only applies to
/// the rows; the cards and the week totals always count everything
/// (`records.rs` `Filter`).
struct TTRecordsFilter: Hashable, Sendable {
    var period = TTRecordsPeriod.all
    /// Only days with warnings about rule violations.
    var warnings = false
    /// Only days with manual corrections.
    var corrected = false

    init(period: TTRecordsPeriod = .all, warnings: Bool = false, corrected: Bool = false) {
        self.period = period
        self.warnings = warnings
        self.corrected = corrected
    }

    var isActive: Bool { self != TTRecordsFilter() }

    func shows(_ day: TTDay, warnings: [TTWarning], today: TTDate) -> Bool {
        period.contains(day.date, today: today)
            && (!self.warnings || !warnings.isEmpty)
            && (!corrected || day.hasCorrections)
    }
}

/// A row of the table: a week, a day, or a past workday without any entry
/// (`records.rs` `Row`).
enum TTRecordsRow: Hashable, Sendable {
    /// Week row: Monday, ISO week, days with working time, total and balance of the week.
    case week(monday: TTDate, week: Int, workdays: Int, total: Int, balance: Int)
    case day(TTDay, TTDayRecord, [TTWarning])
    /// Past workday without any entry: counts with its target until times or
    /// an absence are entered (see `TTSettings.missingWorkdays`).
    case missing(TTDate, target: Int)

    /// The day of a day row (`nil` for a week row).
    var date: TTDate? {
        switch self {
        case .week: return nil
        case let .day(day, _, _): return day.date
        case let .missing(date, _): return date
        }
    }

    /// The day for the week view: a week row gives its Monday.
    var weekDate: TTDate {
        switch self {
        case let .week(monday, _, _, _, _): return monday
        case let .day(day, _, _): return day.date
        case let .missing(date, _): return date
        }
    }

    var isWeek: Bool {
        if case .week = self { return true }
        return false
    }
}

/// Figures in the head of the inspector (`records.rs` `DayStats`).
enum TTDayStats: Hashable, Sendable {
    /// Working time, breaks and balance (`nil`: the working time does not go into the balance).
    case numbers(work: Int, pause: Int, balance: Int?)
    case note(TTDayNote)
}

/// The sentence in the head of the inspector when there are no figures.
enum TTDayNote: Hashable, Sendable {
    case futureWorkday, futureFreeDay, noWorkNoTarget, freeDayUncounted, noWorkInFrame, nothingYet

    func text(_ s: TimeTrackingRecordsStrings) -> String {
        switch self {
        case .futureWorkday: return s.noteFutureWorkday
        case .futureFreeDay: return s.noteFutureFreeDay
        case .noWorkNoTarget: return s.noteNoWorkNoTarget
        case .freeDayUncounted: return s.noteFreeDayUncounted
        case .noWorkInFrame: return s.noteNoWorkInFrame
        case .nothingYet: return s.noteNothingYet
        }
    }
}

/// A card of the overview: value, detail line and, where there is one, the
/// coloured balance (as the value for the time account, otherwise at the end
/// of the detail line) (`records.rs` `Card`).
struct TTRecordsCard: Hashable, Sendable {
    var title: String
    var value: String
    var detail: String
    var valueBalance: Int?
    var detailBalance: Int?
}

/// Ranges offered by the export dialog.
enum TTExportPreset: CaseIterable, Hashable, Sendable {
    case lastFourWeeks, thisMonth, lastMonth, thisYear, custom

    func label(_ s: TimeTrackingRecordsStrings) -> String {
        switch self {
        case .lastFourWeeks: return s.presetLastFourWeeks
        case .thisMonth: return s.periodThisMonth
        case .lastMonth: return s.periodLastMonth
        case .thisYear: return s.periodThisYear
        case .custom: return s.presetCustom
        }
    }

    /// The range from `today` on (`nil` for a custom range) (`preset_range`).
    func range(today: TTDate) -> (from: TTDate, to: TTDate)? {
        switch self {
        case .lastFourWeeks: return TTExport.defaultRange(today: today)
        case .thisMonth: return (TTRecords.monthStart(today), today)
        case .lastMonth:
            let last = TTRecords.monthStart(today).adding(days: -1)
            return (TTRecords.monthStart(last), last)
        case .thisYear: return (TTDate(year: today.year, month: 1, day: 1) ?? today, today)
        case .custom: return nil
        }
    }
}

enum TTRecords {
    static func monthStart(_ d: TTDate) -> TTDate {
        TTDate(year: d.year, month: d.month, day: 1) ?? d
    }

    static func monthEnd(_ d: TTDate) -> TTDate {
        TTDate(year: d.year, month: d.month, day: TTDate.daysInMonth(year: d.year, month: d.month)) ?? d
    }

    /// Monday of the week of `d`.
    static func monday(_ d: TTDate) -> TTDate { d.adding(days: -d.weekday) }

    /// `40 min` or `1:05 h` (`records.rs` `fmt_dur`).
    static func shortDuration(_ secs: Int, _ texts: TimeTrackingTexts) -> String {
        secs < 3600 ? String(format: texts.minutesFormat, Swift.max(secs, 0) / 60) : TTExport.hoursMinutesUnit(secs)
    }

    /// `Tuesday, November 17, 2026` / `Dienstag, 17. November 2026`.
    static func longDate(_ d: TTDate, _ s: TimeTrackingRecordsStrings) -> String {
        String(format: s.longDateFormat, s.weekdayNames[d.weekday], d.day, s.monthNames[d.month - 1], d.year)
    }

    /// `3 workdays` (days with working time).
    static func workdays(_ n: Int, _ s: TimeTrackingRecordsStrings) -> String {
        String(format: n == 1 ? s.workdaysOneFormat : s.workdaysManyFormat, n)
    }

    /// The error when work away from the Mac is shorter than `minWork`.
    static func minWorkText(_ minWork: Int, _ s: TimeTrackingRecordsStrings) -> String {
        String(format: s.minWorkFormat, minWork / 60)
    }

    // MARK: Table

    /// The rows of the table: recorded days and workdays without an entry,
    /// newest first, each week under a week row. The week row counts the
    /// whole week even when the filter hides days; weeks without a visible
    /// day go (`records.rs` `build_rows`).
    static func rows(_ days: [TTDay], settings s: TTSettings, filter: TTRecordsFilter,
                     today: TTDate) -> [TTRecordsRow] {
        // Recorded days and workdays without an entry, newest first.
        var recs: [(date: TTDate, entry: (day: TTDay, rec: TTDayRecord)?)] = days.compactMap { d in
            d.record(s).map { (d.date, (d, $0)) }
        }
        recs += s.missingWorkdays(days, from: .min, to: today, today: today).map { ($0, nil) }
        recs.sort { $0.date > $1.date }
        // The balance of a week only needs its days and the first day with an
        // entry (where missing workdays start); everything else is skipped.
        let first = days.first { $0.hasEntries || $0.absence != nil }
        var byWeek: [TTDate: [TTDay]] = [:]
        for d in days { byWeek[monday(d.date), default: []].append(d) }

        var rows: [TTRecordsRow] = []
        var i = 0
        while i < recs.count {
            let weekStart = monday(recs[i].date)
            var j = i
            while j < recs.count && monday(recs[j].date) == weekStart { j += 1 }
            let week = recs[i..<j]
            let sunday = weekStart.adding(days: 6)
            let total = week.reduce(0) { $0 + ($1.entry?.rec.shownWorkSecs ?? 0) }
            var weekDays = byWeek[weekStart] ?? []
            if let first, first.date < weekStart { weekDays.insert(first, at: 0) }
            let balance = s.balance(weekDays, from: weekStart, to: sunday, today: today)
            let count = week.filter { ($0.entry?.rec.workSecs ?? 0) > 0 }.count
            let shown: [TTRecordsRow] = week.compactMap { item in
                if let entry = item.entry {
                    let warnings = TTWarning.dayWarnings(days, date: item.date, settings: s)
                    guard filter.shows(entry.day, warnings: warnings, today: today) else { return nil }
                    return .day(entry.day, entry.rec, warnings)
                }
                // Without an entry there are neither warnings nor corrections.
                guard filter.period.contains(item.date, today: today) && !filter.warnings && !filter.corrected else {
                    return nil
                }
                return .missing(item.date, target: s.dailyTarget(item.date))
            }
            if !shown.isEmpty {
                rows.append(.week(monday: weekStart, week: weekStart.isoWeek.week, workdays: count, total: total,
                                  balance: balance.work - balance.target))
                rows.append(contentsOf: shown)
            }
            i = j
        }
        return rows
    }

    /// `CW 47  ·  16.11. – 22.11.2026`
    static func weekTitle(monday: TTDate, week: Int, _ texts: TimeTrackingTexts,
                          _ s: TimeTrackingRecordsStrings) -> String {
        String(format: s.weekTitleFormat, week, String(format: s.weekStartFormat, monday.day, monday.month),
               TTFormat.day(monday.adding(days: 6), texts))
    }

    /// `4 workdays  ·  33:40 h  ·  Balance ` (the balance follows in colour).
    static func weekTotal(workdays n: Int, total: Int, _ s: TimeTrackingRecordsStrings) -> String {
        String(format: s.weekTotalFormat, workdays(n, s), TTExport.hoursMinutesUnit(total))
    }

    /// Every day the table can show without a filter: recorded days and
    /// workdays without an entry.
    static func dayCount(_ days: [TTDay], settings: TTSettings, today: TTDate) -> Int {
        days.filter { $0.record(settings) != nil }.count
            + settings.missingWorkdays(days, from: .min, to: today, today: today).count
    }

    /// Footer: how many workdays (days with working time) are recorded, with a
    /// filter how many of all days the table shows, and the rules of the
    /// selected day, without a selection today's (`footer_text`).
    static func footer(rows: [TTRecordsRow], days: [TTDay], settings: TTSettings, filter: TTRecordsFilter,
                       selected: TTDate?, today: TTDate, _ texts: TimeTrackingTexts,
                       _ s: TimeTrackingRecordsStrings) -> String {
        let count: String
        if filter.isActive {
            let shown = rows.filter { !$0.isWeek }.count
            let all = dayCount(days, settings: settings, today: today)
            count = String(format: s.footerFilterFormat, shown,
                           String(format: all == 1 ? s.footerDaysOneFormat : s.footerDaysManyFormat, all))
        } else {
            let worked = days.filter { ($0.record(settings)?.workSecs ?? 0) > 0 }.count
            count = String(format: s.footerRecordedFormat, workdays(worked, s))
        }
        return count + s.footerSeparator + rulesFooter(settings, selected: selected, today: today, texts, s)
    }

    /// The working-time rules for the footer: those of the day `selected`,
    /// with its date when it is not today (without a selection today's).
    static func rulesFooter(_ settings: TTSettings, selected: TTDate?, today: TTDate, _ texts: TimeTrackingTexts,
                            _ s: TimeTrackingRecordsStrings) -> String {
        guard let day = selected, day != today else { return settings.rules(today).summary(texts) }
        return String(format: s.rulesOnFormat, TTFormat.day(day, texts), settings.rules(day).summary(texts))
    }

    // MARK: Cards

    /// Detail line of the card "Time account": since when it counts and the
    /// carry, if there is one (`first`: the first recorded day) (`account_detail`).
    static func accountDetail(_ settings: TTSettings, first: TTDate?, _ texts: TimeTrackingTexts,
                              _ s: TimeTrackingRecordsStrings) -> String {
        let since: String
        if let from = settings.accountFrom {
            since = String(format: s.accountFromFormat, TTFormat.day(from, texts))
        } else if let first {
            since = String(format: s.accountSinceFormat, TTFormat.day(first, texts))
        } else {
            since = s.accountNothingYet
        }
        if settings.accountCarry == 0 { return since }
        return String(format: s.accountCarryFormat, since, TTFormat.balance(settings.accountCarry))
    }

    /// The five cards of the overview (`refresh_summary`).
    static func cards(_ days: [TTDay], settings st: TTSettings, today: TTDate, _ texts: TimeTrackingTexts,
                      _ s: TimeTrackingRecordsStrings) -> [TTRecordsCard] {
        let recs = days.compactMap { d -> (day: TTDay, rec: TTDayRecord)? in
            guard let r = d.record(st), r.workSecs > 0 else { return nil }
            return (d, r)
        }
        func sum(_ include: (TTDate) -> Bool) -> (work: Int, pause: Int, count: Int) {
            recs.filter { include($0.rec.date) }.reduce((0, 0, 0)) { t, x in
                (t.0 + x.rec.shownWorkSecs, t.1 + x.rec.shownPauseSecs, t.2 + 1)
            }
        }
        let todaySum = sum { $0 == today }
        let weekStart = monday(today)
        let weekSum = sum { $0 >= weekStart && $0 <= today }
        let monthSum = sum { $0.year == today.year && $0.month == today.month }
        // The target with absences (half a vacation day, time off) as everywhere.
        let week = st.balance(days, from: weekStart, to: today, today: today)
        let month = st.balance(days, from: monthStart(today), to: monthEnd(today), today: today)
        let todayDay = days.first { $0.date == today }
        let begin = recs.first { $0.rec.date == today }.map { x in
            String(format: x.day.start != nil ? s.startManualFormat : s.startFormat, TTFormat.clock(x.rec.firstStart))
        }
        let todayTarget = st.dayTarget(today, absence: todayDay?.absence)
        let target = String(format: s.targetFormat, TTExport.hoursMinutesUnit(todayTarget))
        let todayDetail: String
        if let begin, todaySum.count > 0 {
            todayDetail = todayTarget > 0 ? begin + s.detailSeparator + target : begin
        } else {
            todayDetail = todayTarget > 0 ? target : s.notAWorkday
        }
        func avg(_ x: Int) -> Int { monthSum.count > 0 ? x / monthSum.count : 0 }
        let account = st.account(days, today: today)
        return [
            TTRecordsCard(title: s.cardToday, value: TTExport.hoursMinutesUnit(todaySum.work), detail: todayDetail),
            TTRecordsCard(title: s.cardWeek, value: TTExport.hoursMinutesUnit(weekSum.work),
                          detail: String(format: s.balanceDetailFormat, workdays(weekSum.count, s)),
                          detailBalance: week.work - week.target),
            TTRecordsCard(title: s.cardMonth, value: TTExport.hoursMinutesUnit(monthSum.work),
                          detail: String(format: s.balanceDetailFormat, workdays(monthSum.count, s)),
                          detailBalance: month.work - month.target),
            TTRecordsCard(title: s.cardAverage, value: TTExport.hoursMinutesUnit(avg(monthSum.work)),
                          detail: String(format: s.averageDetailFormat, TTExport.hoursMinutesUnit(avg(monthSum.pause)),
                                         s.monthNames[today.month - 1])),
            TTRecordsCard(title: s.cardAccount, value: TTFormat.balance(account),
                          detail: accountDetail(st, first: days.first?.date, texts, s), valueBalance: account),
        ]
    }

    // MARK: Inspector

    /// Figures of the day `date` (`day`: its entries, `days`: all days) (`day_stats`).
    static func dayStats(_ date: TTDate, day: TTDay?, days: [TTDay], settings: TTSettings,
                         today: TTDate) -> TTDayStats {
        let entry = day.flatMap { d in d.record(settings).map { (day: d, rec: $0) } }
        // The target that counts, also for a past workday without any entry.
        let target: Int
        if let entry {
            target = settings.countedTarget(entry.day, entry.rec, today: today)
        } else if !settings.missingWorkdays(days, from: date, to: date, today: today).isEmpty {
            target = settings.dailyTarget(date)
        } else {
            target = 0
        }
        // Future days: no times yet, at most a planned absence.
        if date > today && (entry?.rec.workSecs ?? 0) == 0 {
            return .note(settings.isWorkday(date) ? .futureWorkday : .futureFreeDay)
        }
        if let entry, entry.rec.workSecs > 0 {
            // Work on a free day that does not count: no balance.
            return .numbers(work: entry.rec.shownWorkSecs, pause: entry.rec.shownPauseSecs,
                            balance: settings.dayBalance(entry.day, entry.rec, today: today))
        }
        // Without working time but with a target (workday without an entry, time off, half a day).
        if target > 0 { return .numbers(work: 0, pause: 0, balance: -target) }
        guard let entry else { return .note(.nothingYet) }
        if entry.day.absence != nil && entry.day.periods.isEmpty { return .note(.noWorkNoTarget) }
        if entry.day.uncounted { return .note(.freeDayUncounted) }
        return .note(.noWorkInFrame)
    }

    /// `3 periods, 08:02 – 17:31`: the recorded periods in short (`recorded_summary`).
    static func recordedSummary(_ periods: [TTSpan], _ s: TimeTrackingRecordsStrings) -> String {
        guard let from = periods.map(\.from).min(), let to = periods.map(\.to).max() else {
            return s.recordedNone
        }
        let count = String(format: periods.count == 1 ? s.recordedOneFormat : s.recordedManyFormat, periods.count)
        return String(format: s.recordedSummaryFormat, count, TTFormat.clock(from), TTFormat.clock(to))
    }

    /// What the absence means on this day, below the choice (`nil`: nothing to
    /// say), with why the rest is locked or why "Whole Day" is not offered.
    static func absenceEffect(_ date: TTDate, day: TTDay?, settings: TTSettings, today: TTDate,
                              _ s: TimeTrackingRecordsStrings) -> String? {
        let absence = day?.absence
        let workday = settings.isWorkday(date)
        let full = settings.dailyTarget(date)
        let busy = day?.blocksFullAbsence(today: date == today) ?? false
        let locked = day?.locksEntries ?? false
        let effect: String?
        switch absence {
        case .some where !workday || full == 0: effect = s.effectNoTarget
        case .none where !workday: effect = s.effectFreeDay
        case let .some(a) where !a.kind.reducesTarget:
            effect = String(format: s.effectKeepsTargetFormat, TTExport.hoursMinutesUnit(full))
        case let .some(a):
            effect = String(format: s.effectLowersFormat, TTExport.hoursMinutesUnit(full),
                            TTExport.hoursMinutesUnit(settings.dayTarget(date, absence: a)))
        case .none: effect = nil
        }
        guard let effect else { return nil }
        if busy && absence?.half == true { return effect + " " + s.wholeDayBlocked }
        if locked { return effect + " " + s.lockedByAbsence }
        return effect
    }

    /// Note below the start of work (`auto`: first unlock and last lock
    /// within the frame; `inFrame`: the first unlock lies outside the frame).
    static func startNote(future: Bool, uncounted: Bool, auto: (from: Int, to: Int)?, inFrame: Bool,
                          _ s: TimeTrackingRecordsStrings) -> String {
        if future { return s.futureText }
        if uncounted { return s.uncountedNote }
        guard let auto else { return s.startNoteNone }
        return String(format: s.startNoteFormat, inFrame ? s.inFrameSuffix : "", TTFormat.clock(auto.from))
    }

    /// Note below the end of work (`manualToday`: today without a manual end).
    static func endNote(future: Bool, uncounted: Bool, auto: (from: Int, to: Int)?, inFrame: Bool,
                        openToday: Bool, _ s: TimeTrackingRecordsStrings) -> String {
        if future { return s.futureText }
        if uncounted { return s.uncountedNote }
        guard let auto else { return s.endNoteNone }
        if openToday { return s.endNoteToday }
        return String(format: s.endNoteFormat, inFrame ? s.inFrameSuffix : "", TTFormat.clock(auto.to))
    }

    // MARK: Export

    /// Summary in the export dialog: days with working time, working time and
    /// balance of the range, as in the total row of the file (`export_summary`).
    static func exportSummary(_ report: TTReport, _ s: TimeTrackingRecordsStrings) -> String {
        let totals = report.totals
        return String(format: s.exportSummaryFormat, workdays(totals.days, s), TTExport.hoursMinutesUnit(totals.work),
                      TTFormat.balance(report.balance))
    }
}
