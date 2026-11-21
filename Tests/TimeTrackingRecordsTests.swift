// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import CoreGraphics
import Foundation

/// The tests of Tagwerk's `records.rs`, one function per `#[test]`, plus the
/// edits applied to a day, the rows of the table, the cards, the English texts
/// and the PDF writer.
enum TimeTrackingRecordsTests {
    static func run(_ suite: TestSuite) {
        footerNamesTheRulesOfTheSelectedDay(suite)
        undoTakesBackOnlyWhatTheStepChanged(suite)
        undoKeepsWhatChangedSince(suite)
        undoNeverLeavesAnInvalidDay(suite)
        wholeDayRestoresRecordedPeriods(suite)
        refusesFutureTimesAndBoundsOutOfOrder(suite)
        noNewAbsenceOnDaysWithoutTarget(suite)
        asksBeforeAnEntryLongBeforeTheFirstDay(suite)
        exportSummaryCountsDaysWithWorkLikeTheFile(suite)
        absenceTodayOffersHalfDay(suite)
        recordedSummaryNamesCountAndSpan(suite)
        clearDayTextListsEntries(suite)
        uncountedFreeDayAllowsOnlyWhatMenuAndWeekAllow(suite)
        historyMergesFollowUpsAndForgetsRedo(suite)
        accountCardNamesStartAndCarry(suite)
        filterByPeriodAndMarks(suite)

        editsChangeTheDay(suite)
        rowsGroupWeeksAndMissingDays(suite)
        cardsAndFooterCountWorkdays(suite)
        englishTexts(suite)
        pdfLinesAndPages(suite)
    }

    static let texts = TimeTrackingTexts.de
    static let de = TimeTrackingRecordsStrings.de

    /// A day in November 2026 (the 16th is a Monday, the 21st a Saturday).
    static func date(_ d: Int) -> TTDate { TTDate(year: 2026, month: 11, day: d)! }
    static func hm(_ h: Int, _ m: Int) -> Int { h * 3600 + m * 60 }
    static func at(_ d: Int, _ h: Int, _ m: Int) -> TTDateTime { TTDateTime(date(d), hour: h, minute: m) }

    static func step(_ name: TTEditName, _ d: Int, _ start: Int?) -> TTEditStep {
        let before = TTCorrections(start: start)
        return TTEditStep(name: name, date: date(d), before: before, after: before)
    }

    static func refusal(_ d: TTDay, _ edit: TTEdit, _ s: TTSettings, _ now: TTDateTime) -> String? {
        TTEdits.refusal(d, edit, settings: s, now: now, texts, de)
    }

    // MARK: records.rs

    private static func footerNamesTheRulesOfTheSelectedDay(_ suite: TestSuite) {
        var s = TTSettings()
        s.setRules(from: date(16), TTWorkRules(weeklyTarget: 32 * 3600))
        let today = date(21)
        let now = s.rules(today).summary(texts)
        suite.expect(now.contains("32 Std./Woche"), "footer: today's rules: \(now)")
        suite.expect(TTRecords.rulesFooter(s, selected: nil, today: today, texts, de) == now, "footer: no selection")
        suite.expect(TTRecords.rulesFooter(s, selected: today, today: today, texts, de) == now, "footer: today")
        let before = TTRecords.rulesFooter(s, selected: date(13), today: today, texts, de)
        suite.expect(before == "Regeln am 13.11.2026: " + TTWorkRules.default.summary(texts),
                     "footer: another day names its date: \(before)")
        suite.expect(before.contains("39 Std./Woche"), "footer: the rules before")
    }

    private static func undoTakesBackOnlyWhatTheStepChanged(_ suite: TestSuite) {
        var day = TTDay(date: date(17))
        day.addPeriod(from: hm(8, 0), to: hm(12, 0))
        day.addWork(from: hm(7, 0), to: hm(8, 0), note: "Meeting")
        let before = TTCorrections.of(day)
        // The step: start of work 8:00 - the work away from the Mac before it goes.
        day.setStart(hm(8, 0))
        let after = TTCorrections.of(day)
        // Meanwhile the Mac keeps recording, and the menu ends the day.
        day.addPeriod(from: hm(13, 0), to: hm(17, 0))
        day.end = hm(17, 0)
        suite.expect(TTCorrections.rewind(&day, done: after, target: before) == .done, "undo: done")
        suite.expect(day.start == nil && day.work.count == 1, "undo: start and work away from the Mac back")
        suite.expect(day.end == hm(17, 0), "undo: the end of work from the menu stays")
        suite.expect(day.periods.count == 2, "undo: recorded time stays")
        // Redo: the start again, the work away from the Mac goes again.
        suite.expect(TTCorrections.rewind(&day, done: before, target: after) == .done, "redo: done")
        suite.expect(day.start == hm(8, 0) && day.work.isEmpty && day.end == hm(17, 0), "redo: the step again")
    }

    private static func undoKeepsWhatChangedSince(_ suite: TestSuite) {
        var day = TTDay(date: date(17))
        day.addPeriod(from: hm(8, 0), to: hm(12, 0))
        day.addWork(from: hm(7, 0), to: hm(8, 0), note: "Meeting")
        var before = TTCorrections.of(day)
        day.setStart(hm(8, 0))
        var after = TTCorrections.of(day)
        // Meanwhile new work away from the Mac ("Keep working away from the Mac").
        day.addWork(from: hm(12, 0), to: hm(13, 0), note: "Telefonat")
        var changed = day
        var rewind = TTCorrections.rewind(&day, done: after, target: before)
        suite.expect(rewind == .partial([.work]), "undo: only partly: \(rewind)")
        suite.expect(day.start == nil, "undo: the start goes")
        suite.expect(day.work == changed.work, "undo: the new work away from the Mac stays")
        let name = TTEditName.setStart.title(de)
        let note = TTEdits.rewindNote(redo: false, name: name, date: date(17), rewind, texts, de)
        suite.expect(note?.title == "Nur zum Teil widerrufen", "undo note: title")
        suite.expect(note?.text == "„Arbeitsbeginn ändern“ vom 17.11.2026 ist nur zum Teil widerrufen. Inzwischen "
                        + "anders geändert und deshalb so geblieben: Arbeit ohne Mac.",
                     "undo note: text: \(note?.text ?? "nil")")

        // Everything the step changed has changed differently since: not at all.
        day = TTDay(date: date(17))
        day.addPeriod(from: hm(8, 0), to: hm(12, 0))
        before = TTCorrections.of(day)
        day.setStart(hm(8, 0))
        after = TTCorrections.of(day)
        day.start = hm(7, 30)
        changed = day
        rewind = TTCorrections.rewind(&day, done: after, target: before)
        suite.expect(rewind == .refused(.changed([.start])), "undo: refused: \(rewind)")
        suite.expect(day == changed, "undo: refused leaves the day")
        let redo = TTEdits.rewindNote(redo: true, name: name, date: date(17), rewind, texts, de)
        suite.expect(redo?.text == "„Arbeitsbeginn ändern“ vom 17.11.2026 lässt sich nicht mehr wiederholen – "
                        + "inzwischen anders geändert: Arbeitsbeginn. Der Tag bleibt, wie er ist.",
                     "redo note: \(redo?.text ?? "nil")")
        suite.expect(TTEdits.rewindNote(redo: false, name: "x", date: date(17), .done, texts, de) == nil,
                     "no note when it worked")
    }

    private static func undoNeverLeavesAnInvalidDay(_ suite: TestSuite) {
        // Full-day absence removed, then recorded: undo would give vacation next to recorded time.
        var day = TTDay(date: date(17))
        day.absence = TTAbsence(.vacation, half: false)
        var before = TTCorrections.of(day)
        day.absence = nil
        var after = TTCorrections.of(day)
        day.addPeriod(from: hm(9, 0), to: hm(10, 0))
        let changed = day
        let rewind = TTCorrections.rewind(&day, done: after, target: before)
        suite.expect(rewind == .refused(.absenceBesideEntries), "undo: no absence next to entries")
        suite.expect(day == changed, "undo: the day stays")
        let note = TTEdits.rewindNote(redo: false, name: TTEditName.setAbsence.title(de), date: date(17), rewind,
                                      texts, de)
        suite.expect(note?.text.contains("neben inzwischen") == true, "undo note names the absence")

        // End of work removed, meanwhile a later start: the old end would lie before it.
        day = TTDay(date: date(17))
        day.addPeriod(from: hm(8, 0), to: hm(15, 0))
        day.end = hm(12, 0)
        before = TTCorrections.of(day)
        day.end = nil
        after = TTCorrections.of(day)
        day.start = hm(13, 0)
        suite.expect(TTCorrections.rewind(&day, done: after, target: before) == .refused(.order),
                     "undo: start not before the end")
        suite.expect(day.end == nil, "undo: the end stays removed")
    }

    private static func wholeDayRestoresRecordedPeriods(_ suite: TestSuite) {
        var day = TTDay(date: date(17))
        day.addPeriod(from: hm(8, 0), to: hm(12, 0))
        day.addBreak(from: hm(10, 0), to: hm(10, 30))
        day.absence = TTAbsence(.vacation, half: true)
        let before = TTCorrections.whole(day)
        let original = day
        var cleared = TTDay(date: date(17))
        let after = TTCorrections.whole(cleared)
        suite.expect(TTCorrections.rewind(&cleared, done: after, target: before) == .done, "undo clear: done")
        suite.expect(cleared == original, "undo brings the whole day back")
        // Redo deletes everything again, the recorded times too.
        suite.expect(TTCorrections.rewind(&cleared, done: before, target: after) == .done, "redo clear: done")
        suite.expect(cleared.isEmpty, "redo empties the day")

        // Today: after deleting, the Mac keeps recording; that stays on undo.
        var today = TTDay(date: date(17))
        today.addPeriod(from: hm(13, 0), to: hm(14, 0))
        suite.expect(TTCorrections.rewind(&today, done: after, target: before) == .done, "undo today: done")
        suite.expect(today.periods == [TTSpan(hm(8, 0), hm(12, 0)), TTSpan(hm(13, 0), hm(14, 0))],
                     "undo today keeps what was recorded since")
        suite.expect(today.breaks == original.breaks, "undo today: the breaks are back")
        // Redo deletes only what deleting had deleted.
        suite.expect(TTCorrections.rewind(&today, done: before, target: after) == .done, "redo today: done")
        suite.expect(today.periods == [TTSpan(hm(13, 0), hm(14, 0))], "redo today keeps the new time")
        suite.expect(today.breaks.isEmpty && today.absence == nil, "redo today removes the rest")
    }

    private static func refusesFutureTimesAndBoundsOutOfOrder(_ suite: TestSuite) {
        let s = TTSettings()
        let now = at(18, 10, 0)
        var day = TTDay(date: date(18))
        day.addPeriod(from: hm(8, 0), to: hm(10, 0))
        // Today nothing after now.
        suite.expect(refusal(day, .setEnd(hm(10, 1)), s, now)?.contains("nach jetzt (10:00 Uhr)") == true,
                     "refusal: nothing after now")
        suite.expect(refusal(day, .addWork(hm(9, 0), hm(11, 0), ""), s, now) != nil, "refusal: work after now")
        suite.expect(refusal(day, .setEnd(hm(10, 0)), s, now) == nil, "refusal: an end now is fine")
        // Future days: only the absence (and removing).
        let tomorrow = TTDay(date: date(19))
        for edit in [TTEdit.setStart(hm(8, 0)), .setEnd(hm(17, 0)), .addBreak(hm(12, 0), hm(12, 30)),
                     .addWork(hm(9, 0), hm(10, 0), "")] {
            suite.expect(refusal(tomorrow, edit, s, now) == de.futureText, "refusal: future \(edit.name)")
        }
        for edit in [TTEdit.setAbsence(TTAbsence(.vacation, half: false)), .setStart(nil), .clearDay] {
            suite.expect(refusal(tomorrow, edit, s, now) == nil, "refusal: future allows \(edit.name)")
        }
        // Start of work before the end.
        var past = TTDay(date: date(17))
        past.addPeriod(from: hm(8, 0), to: hm(16, 0))
        past.end = hm(12, 0)
        suite.expect(refusal(past, .setStart(hm(12, 0)), s, now)
                        == "Der Arbeitsbeginn muss vor dem Feierabend um 12:00 Uhr liegen.", "refusal: start at the end")
        suite.expect(refusal(past, .setStart(hm(11, 59)), s, now) == nil, "refusal: start before the end")
        past.start = hm(9, 0)
        suite.expect(refusal(past, .setEnd(hm(8, 30)), s, now)
                        == "Der Feierabend muss nach dem Arbeitsbeginn um 09:00 Uhr liegen.", "refusal: end before start")
        suite.expect(refusal(past, .setEnd(nil), s, now) == nil && refusal(past, .setStart(nil), s, now) == nil,
                     "refusal: removing always works")
    }

    private static func noNewAbsenceOnDaysWithoutTarget(_ suite: TestSuite) {
        let s = TTSettings()
        let now = at(23, 12, 0)
        let vacation = TTAbsence(.vacation, half: false)
        var sat = TTDay(date: date(21))
        suite.expect(refusal(sat, .setAbsence(vacation), s, now) == de.freeDayAbsence, "absence: none on a free day")
        // An existing one stays and can be removed, but not changed.
        sat.absence = vacation
        suite.expect(refusal(sat, .setAbsence(vacation), s, now) == nil, "absence: the same one stays")
        suite.expect(refusal(sat, .setAbsence(nil), s, now) == nil, "absence: removing works")
        suite.expect(refusal(sat, .setAbsence(TTAbsence(.sick, half: false)), s, now) != nil, "absence: no change")
        // On a workday it works.
        suite.expect(refusal(TTDay(date: date(20)), .setAbsence(vacation), s, now) == nil, "absence: on a workday")
    }

    private static func asksBeforeAnEntryLongBeforeTheFirstDay(_ suite: TestSuite) {
        let s = TTSettings()
        let today = date(23)
        var first = TTDay(date: date(16))
        first.addPeriod(from: hm(8, 0), to: hm(16, 0))
        let days = [first]
        func text(_ days: [TTDay], _ d: Int) -> String? {
            TTEdits.beforeFirstText(days, date: date(d), settings: s, today: today, texts, de)
        }
        suite.expect(text([], 2) == nil, "before first: nothing recorded yet")
        suite.expect(text(days, 16) == nil, "before first: the first day itself")
        suite.expect(text(days, 20) == nil, "before first: after the first day")
        // The Friday before: only the weekend lies in between.
        suite.expect(text(days, 13) == nil, "before first: only the weekend between")
        // Monday 2.11.: workdays from the 3rd to the 13th (9 days of 7:48 h).
        suite.expect(text(days, 2) == "Bisher beginnen die Aufzeichnungen am 16.11.2026. Mit einem Eintrag am "
                        + "02.11.2026 zählen auch die 9 Arbeitstage dazwischen mit ihrem Soll – zusammen etwa 70 Std. "
                        + "Minus in Saldo und Zeitkonto, bis dort Zeiten oder Abwesenheiten eingetragen sind.",
                     "before first: \(text(days, 2) ?? "nil")")
        suite.expect(text(days, 12)?.contains("zählt auch der Arbeitstag dazwischen") == true, "before first: one day")
        suite.expect(TTEdit.addBreak(0, 1).addsEntry && !TTEdit.setStart(nil).addsEntry
                     && !TTEdit.setCounting(true).addsEntry, "which edits add an entry")
    }

    private static func exportSummaryCountsDaysWithWorkLikeTheFile(_ suite: TestSuite) {
        let s = TTSettings()
        let today = date(23)
        var worked = TTDay(date: date(16))
        worked.addPeriod(from: hm(8, 0) + 20, to: hm(16, 0) + 40)
        var vacation = TTDay(date: date(17))
        vacation.absence = TTAbsence(.vacation, half: false)
        let report = TTReport([worked, vacation], from: date(16), to: date(17), today: today, settings: s, texts)
        let totals = report.totals
        suite.expect(totals.work == hm(8, 0) && totals.days == 1, "export summary: without seconds, without vacation")
        let balance = TTFormat.balance(report.balance)
        suite.expect(TTRecords.exportSummary(report, de) == "1 Arbeitstag · 8:00 h Arbeitszeit · Saldo \(balance)",
                     "export summary: \(TTRecords.exportSummary(report, de))")
    }

    private static func absenceTodayOffersHalfDay(_ suite: TestSuite) {
        suite.expect(!TTEdits.absenceTodayText(recorded: 3600, half: false, texts, de).contains("halber Tag"),
                     "absence today: no half day")
        suite.expect(TTEdits.absenceTodayText(recorded: 3600, half: true, texts, de)
                        .hasSuffix("Ein halber Tag geht auch neben der erfassten Zeit – sie bleibt dann."),
                     "absence today offers a half day")
        suite.expect(TTEdits.absenceTodayText(recorded: 3600, half: false, texts, de).contains("(1:00 h)"),
                     "absence today names the recorded time")
    }

    private static func recordedSummaryNamesCountAndSpan(_ suite: TestSuite) {
        suite.expect(TTRecords.recordedSummary([], de) == "Keine – der Mac war nicht entsperrt.", "recorded: none")
        var day = TTDay(date: date(17))
        day.addPeriod(from: 8 * 3600 + 120, to: 12 * 3600)
        suite.expect(TTRecords.recordedSummary(day.periods, de) == "1 Zeit, 08:02 – 12:00", "recorded: one")
        day.addPeriod(from: 13 * 3600, to: 17 * 3600 + 31 * 60)
        suite.expect(TTRecords.recordedSummary(day.periods, de) == "2 Zeiten, 08:02 – 17:31", "recorded: two")
    }

    private static func clearDayTextListsEntries(_ suite: TestSuite) {
        func text(_ d: TTDay, _ today: Bool) -> String { TTEdits.clearDayText(d, isToday: today, texts, de) }
        var day = TTDay(date: date(17))
        day.addPeriod(from: 8 * 3600, to: 12 * 3600)
        day.addPeriod(from: 13 * 3600, to: 17 * 3600)
        suite.expect(text(day, false) == "Das betrifft 2 automatisch erfasste Zeiten. ⌘Z nimmt das zurück.",
                     "clear: periods: \(text(day, false))")
        day.start = 7 * 3600
        day.addBreak(from: 10 * 3600, to: 10 * 3600 + 1800)
        day.addWork(from: 12 * 3600, to: 13 * 3600, note: "Meeting")
        day.absence = TTAbsence(.vacation, half: true)
        suite.expect(text(day, true) == "Das betrifft 2 automatisch erfasste Zeiten, den festgelegten Arbeitsbeginn, "
                        + "1 eingetragene Pause, 1 Eintrag Arbeit ohne Mac und die Abwesenheit „Urlaub (halber Tag)“. "
                        + "Die automatische Erfassung läuft danach ab jetzt weiter. ⌘Z nimmt das zurück.",
                     "clear: everything: \(text(day, true))")
        // Today on a free day that does not count: recording stays off.
        var sat = TTDay(date: date(21))
        sat.addPeriod(from: 10 * 3600, to: 12 * 3600)
        sat.freeDay = .uncounted
        suite.expect(text(sat, true) == "Das betrifft 1 automatisch erfasste Zeit. Die automatische Erfassung bleibt "
                        + "heute aus, bis im Panel „Heute erfassen“ gewählt ist. ⌘Z nimmt das zurück.",
                     "clear: free day today: \(text(sat, true))")
        // With "Record today" too: the mark goes with it.
        sat.freeDay = .counted
        suite.expect(text(sat, true).contains("bleibt heute aus"), "clear: counted free day today")
        suite.expect(text(sat, false).hasSuffix("Das betrifft 1 automatisch erfasste Zeit. ⌘Z nimmt das zurück."),
                     "clear: free day in the past")
    }

    private static func uncountedFreeDayAllowsOnlyWhatMenuAndWeekAllow(_ suite: TestSuite) {
        let s = TTSettings()
        var sat = TTDay(date: date(21))
        sat.addPeriod(from: 9 * 3600 + 42 * 60, to: 15 * 3600)
        sat.freeDay = .uncounted
        // Start, end and breaks only after "Count recorded time" …
        for edit in [TTEdit.setStart(9 * 3600), .setEnd(14 * 3600), .addBreak(12 * 3600, 12 * 3600 + 1800)] {
            suite.expect(TTEdits.refuses(sat, edit), "uncounted refuses \(edit.name)")
        }
        // … removing, work away from the Mac, counting and clearing work.
        for edit in [TTEdit.setStart(nil), .setEnd(nil), .removeBreak(0), .addWork(16 * 3600, 17 * 3600, ""),
                     .setCounting(true), .clearDay] {
            suite.expect(!TTEdits.refuses(sat, edit), "uncounted allows \(edit.name)")
        }
        // Figures: not "no working time in the frame" but why nothing counts.
        let stats = TTRecords.dayStats(date(21), day: sat, days: [sat], settings: s, today: date(23))
        suite.expect(stats == .note(.freeDayUncounted), "uncounted: why nothing counts: \(stats)")
        suite.expect(TTDayNote.freeDayUncounted.text(de) == "Freier Tag – die erfasste Zeit zählt nicht.",
                     "uncounted: Tagwerk's text")
        // Counted: everything as on any day.
        sat.freeDay = .counted
        suite.expect(!TTEdits.refuses(sat, .setStart(9 * 3600)), "counted allows a start")
        if case .numbers = TTRecords.dayStats(date(21), day: sat, days: [sat], settings: s, today: date(23)) {
            suite.expect(true, "counted: figures")
        } else {
            suite.expect(false, "counted: figures")
        }
    }

    private static func historyMergesFollowUpsAndForgetsRedo(_ suite: TestSuite) {
        var h = TTEditHistory()
        h.record(step(.setStart, 17, nil), followUp: false)
        // Arrow keys in the time field: the same step.
        h.record(step(.setStart, 17, 7 * 3600), followUp: true)
        h.record(step(.setStart, 17, 7 * 3600 + 600), followUp: true)
        suite.expect(h.undo.count == 1, "history: follow-ups merge")
        suite.expect(h.undo[0].before.start == nil, "history: the state before the whole input")
        suite.expect(h.undo[0].after.start == 7 * 3600 + 600, "history: the state after the last input")
        // Another day or another entry is a new step, also as a follow-up.
        h.record(step(.setStart, 18, nil), followUp: true)
        h.record(step(.setEnd, 18, nil), followUp: true)
        suite.expect(h.undo.count == 3, "history: other day or entry is a new step")
        // A new change forgets what could be redone.
        h.redo.append(step(.removeBreak, 17, nil))
        h.record(step(.addBreak, 17, nil), followUp: false)
        suite.expect(h.redo.isEmpty, "history: a new change forgets redo")
        for _ in 0..<(TTEditHistory.max + 10) {
            h.record(step(.addBreak, 17, nil), followUp: false)
        }
        suite.expect(h.undo.count == TTEditHistory.max, "history: at most 50 steps")
        suite.expect(TTEdits.historyTitle(redo: false, name: "Pause entfernen", de) == "Widerrufen: Pause entfernen",
                     "history title")
        suite.expect(TTEdits.historyTitle(redo: true, name: nil, de) == "Wiederholen", "history title without step")
    }

    private static func accountCardNamesStartAndCarry(_ suite: TestSuite) {
        var s = TTSettings()
        suite.expect(TTRecords.accountDetail(s, first: date(2), texts, de) == "seit 02.11.2026", "account: since")
        suite.expect(TTRecords.accountDetail(s, first: nil, texts, de) == "noch nichts erfasst", "account: nothing")
        s.accountFrom = date(9)
        s.accountCarry = -90 * 60
        suite.expect(TTRecords.accountDetail(s, first: date(2), texts, de) == "ab 09.11.2026 · Übertrag −1:30 h",
                     "account: from and carry: \(TTRecords.accountDetail(s, first: date(2), texts, de))")
    }

    private static func filterByPeriodAndMarks(_ suite: TestSuite) {
        let today = date(19)
        func on(_ y: Int, _ m: Int, _ d: Int) -> TTDate { TTDate(year: y, month: m, day: d)! }
        suite.expect(TTRecordsPeriod.thisMonth.contains(date(1), today: today)
                     && !TTRecordsPeriod.thisMonth.contains(on(2026, 10, 31), today: today), "filter: this month")
        suite.expect(TTRecordsPeriod.lastMonth.contains(on(2026, 10, 31), today: today)
                     && !TTRecordsPeriod.lastMonth.contains(date(1), today: today), "filter: last month")
        suite.expect(TTRecordsPeriod.thisYear.contains(on(2026, 1, 1), today: today)
                     && !TTRecordsPeriod.thisYear.contains(on(2025, 12, 31), today: today), "filter: this year")
        suite.expect(TTRecordsPeriod.lastYear.contains(on(2025, 12, 31), today: today), "filter: last year")
        // January: "Last month" is December of the year before.
        suite.expect(TTRecordsPeriod.lastMonth.contains(on(2026, 12, 15), today: on(2027, 1, 10)),
                     "filter: last month across the year")

        let plain = TTDay(date: date(17))
        var corrected = TTDay(date: date(18))
        corrected.start = 7 * 3600
        let warning = [TTWarning.weekend(counted: false)]
        suite.expect(!TTRecordsFilter().isActive && TTRecordsFilter().shows(plain, warnings: [], today: today),
                     "filter: off shows everything")
        let warnings = TTRecordsFilter(warnings: true)
        suite.expect(warnings.isActive && !warnings.shows(plain, warnings: [], today: today)
                     && warnings.shows(plain, warnings: warning, today: today), "filter: warnings")
        let both = TTRecordsFilter(period: .thisMonth, warnings: true, corrected: true)
        suite.expect(both.shows(corrected, warnings: warning, today: today)
                     && !both.shows(plain, warnings: warning, today: today), "filter: both marks")
        suite.expect(!both.shows(corrected, warnings: warning, today: on(2026, 12, 1)), "filter: another month")
    }

    // MARK: Beyond records.rs

    private static func editsChangeTheDay(_ suite: TestSuite) {
        let s = TTSettings()
        let now = at(18, 14, 0)
        func apply(_ edit: TTEdit, _ day: inout TTDay) -> TTEditOutcome {
            TTEdits.apply(edit, to: &day, settings: s, now: now, texts, de)
        }
        // A start cuts work away from the Mac before it, and says so.
        var day = TTDay(date: date(17))
        day.addPeriod(from: hm(8, 0), to: hm(12, 0))
        day.addWork(from: hm(7, 0), to: hm(8, 0), note: "Meeting")
        var outcome = apply(.setStart(hm(8, 0)), &day)
        suite.expect(outcome.refusal == nil && day.start == hm(8, 0) && day.work.isEmpty, "edit: start set")
        suite.expect(outcome.cut(.setStart(hm(8, 0))) == .start && outcome.before.periods == nil,
                     "edit: the cut is reported, periods are not part of the step")
        // A refused edit leaves the day and says why.
        let unchanged = day
        outcome = apply(.setEnd(hm(7, 0)), &day)
        suite.expect(outcome.refusal != nil && day == unchanged && outcome.before == outcome.after,
                     "edit: refused leaves the day")
        // A whole-day absence locks the other entries.
        var vacation = TTDay(date: date(16))
        _ = apply(.setAbsence(TTAbsence(.vacation, half: false)), &vacation)
        suite.expect(vacation.absence == TTAbsence(.vacation, half: false), "edit: absence on an empty day")
        outcome = apply(.addBreak(hm(12, 0), hm(12, 30)), &vacation)
        suite.expect(vacation.breaks.isEmpty && outcome.refusal == nil, "edit: absence locks silently")
        // Today a whole-day absence deletes the recorded time, as part of the step.
        var today = TTDay(date: date(18))
        today.addPeriod(from: hm(8, 0), to: hm(10, 0))
        outcome = apply(.setAbsence(TTAbsence(.sick, half: false)), &today)
        suite.expect(today.periods.isEmpty && today.absence?.kind == .sick && outcome.before.periods?.count == 1,
                     "edit: absence today deletes the recorded time and remembers it")
        // Clearing today on a free day stops recording.
        var sat = TTDay(date: date(18))
        sat.addPeriod(from: hm(9, 0), to: hm(10, 0))
        sat.freeDay = .counted
        outcome = apply(.clearDay, &sat)
        suite.expect(sat.periods.isEmpty && sat.freeDay == .stopped && outcome.before.periods != nil,
                     "edit: clearing a free day today stops recording")
        // Removing by index.
        var breaks = TTDay(date: date(17))
        breaks.addBreak(from: hm(10, 0), to: hm(10, 30))
        _ = apply(.removeBreak(3), &breaks)
        suite.expect(breaks.breaks.count == 1, "edit: an index out of range changes nothing")
        _ = apply(.removeBreak(0), &breaks)
        suite.expect(breaks.breaks.isEmpty, "edit: the break goes")
    }

    private static func rowsGroupWeeksAndMissingDays(_ suite: TestSuite) {
        let s = TTSettings()
        let today = date(20)
        var mon = TTDay(date: date(9))
        mon.addPeriod(from: hm(8, 0), to: hm(16, 0))
        var tue = TTDay(date: date(17))
        tue.addPeriod(from: hm(8, 0), to: hm(17, 0))
        tue.start = hm(7, 30)
        let days = [mon, tue]
        let rows = TTRecords.rows(days, settings: s, filter: TTRecordsFilter(), today: today)
        // Week 47: Thu 19, Wed 18, Tue 17, Mon 16 (missing except the 17th); week 46: Fri 13 … Mon 9.
        let dates = rows.compactMap(\.date)
        suite.expect(dates == [date(19), date(18), date(17), date(16), date(13), date(12), date(11), date(10), date(9)],
                     "rows: newest first with missing workdays: \(dates)")
        suite.expect(rows.filter(\.isWeek).count == 2 && rows.first?.isWeek == true, "rows: one row per week")
        if case let .week(monday, week, workdays, total, balance) = rows[0] {
            let target = 4 * TTWorkRules.default.dailyTarget(on: date(16))
            suite.expect(monday == date(16) && week == 47 && workdays == 1 && total == hm(9, 30)
                         && balance == hm(9, 30) - target, "rows: the week row counts the week: \(balance)")
            suite.expect(TTRecords.weekTitle(monday: monday, week: week, texts, de) == "KW 47  ·  16.11. – 22.11.2026",
                         "rows: week title")
            suite.expect(TTRecords.weekTotal(workdays: workdays, total: total, de) == "1 Arbeitstag  ·  9:30 h  ·  Saldo ",
                         "rows: week total")
        } else {
            suite.expect(false, "rows: a week row first")
        }
        if case let .missing(d, target) = rows[1] {
            suite.expect(d == date(19) && target == TTWorkRules.default.dailyTarget(on: d), "rows: missing day")
        } else {
            suite.expect(false, "rows: the 19th is missing")
        }
        // The filter hides days, and weeks without a visible day.
        let corrected = TTRecords.rows(days, settings: s, filter: TTRecordsFilter(corrected: true), today: today)
        suite.expect(corrected.count == 2 && corrected[1].date == date(17), "rows: only corrected days")
        let footer = TTRecords.footer(rows: corrected, days: days, settings: s,
                                      filter: TTRecordsFilter(corrected: true), selected: nil, today: today, texts, de)
        suite.expect(footer.hasPrefix("Filter: 1 von 9 Tagen  ·  "), "rows: filter footer: \(footer)")
    }

    private static func cardsAndFooterCountWorkdays(_ suite: TestSuite) {
        let s = TTSettings()
        let today = date(18)
        var mon = TTDay(date: date(16))
        mon.addPeriod(from: hm(8, 0), to: hm(16, 0))
        var wed = TTDay(date: date(18))
        wed.addPeriod(from: hm(8, 15), to: hm(10, 15))
        wed.start = hm(8, 0)
        let days = [mon, wed]
        let cards = TTRecords.cards(days, settings: s, today: today, texts, de)
        suite.expect(cards.map(\.title) == ["Heute", "Diese Woche", "Dieser Monat", "Ø pro Arbeitstag", "Zeitkonto"],
                     "cards: five")
        suite.expect(cards[0].value == "2:15 h" && cards[0].detail == "Beginn 08:00 Uhr (manuell) · Soll 7:48 h",
                     "cards: today: \(cards[0].detail)")
        suite.expect(cards[1].detail == "2 Arbeitstage · Saldo " && cards[1].detailBalance != nil, "cards: week")
        suite.expect(cards[3].detail.hasSuffix("· November"), "cards: average names the month")
        suite.expect(cards[4].valueBalance == s.account(days, today: today), "cards: account")
        let footer = TTRecords.footer(rows: [], days: days, settings: s, filter: TTRecordsFilter(), selected: nil,
                                      today: today, texts, de)
        suite.expect(footer == "2 Arbeitstage erfasst  ·  " + TTWorkRules.default.summary(texts), "footer: \(footer)")
        suite.expect(TTRecords.longDate(date(17), de) == "Dienstag, 17. November 2026", "long date")
        suite.expect(TTRecords.longDate(date(17), .enUS) == "Tuesday, November 17, 2026", "long date in English")
        suite.expect(TTRecords.shortDuration(40 * 60, texts) == "40 Min." && TTRecords.shortDuration(hm(1, 5), texts)
                        == "1:05 h", "short durations")
        let lastMonth = TTExportPreset.lastMonth.range(today: TTDate(year: 2027, month: 1, day: 10)!)
        suite.expect(lastMonth?.from == TTDate(year: 2026, month: 12, day: 1)
                     && lastMonth?.to == TTDate(year: 2026, month: 12, day: 31), "export preset: last month")
    }

    private static func englishTexts(_ suite: TestSuite) {
        let en = TimeTrackingRecordsStrings.enUS
        suite.expect(TTEdits.historyTitle(redo: false, name: TTEditName.removeBreak.title(en), en)
                        == "Undo Remove Break", "English undo title")
        suite.expect(FeatureStrings.timeTrackingRecords(.fr).windowTitle == en.windowTitle,
                     "other languages show English until they are translated")
        let all = Mirror(reflecting: en).children.compactMap { $0.value as? String }
            + Mirror(reflecting: de).children.compactMap { $0.value as? String }
        suite.expect(!all.contains { $0.contains("\u{2014}") || $0.contains("...") }, "no em dash and no three dots")
    }

    private static func pdfLinesAndPages(_ suite: TestSuite) {
        let path = TimeTrackingParityTests.directory + "testdata-2026-11-17.md"
        guard let data = FileManager.default.contents(atPath: path) else {
            suite.expect(false, "PDF: fixture reads")
            return
        }
        let days = TTImport.parseFile(String(decoding: data, as: UTF8.self))
        let s = TTSettings()
        let now = TTDateTime(TTDate(year: 2026, month: 11, day: 17)!, hour: 9, minute: 30)
        let from = TTDate(year: 2026, month: 1, day: 1)!, to = TTDate(year: 2026, month: 11, day: 16)!
        let report = TTReport(days, from: from, to: to, today: now.date, settings: s, texts)
        let lines = TimeTrackingPDF.lines(report, settings: s, now: now, appName: "Barforge", texts, de)
        suite.expect(lines.first?.cells == ["Barforge – Arbeitszeiten 01.01.2026 bis 16.11.2026"], "PDF: title")
        suite.expect(lines[1].cells[0].hasPrefix("Exportiert am 17.11.2026 um 09:30 Uhr  ·  Arbeitszeitrahmen"),
                     "PDF: export time and rules: \(lines[1].cells[0])")
        suite.expect(lines.contains { $0.style == .header && $0.cells == ["Datum", "Beginn", "Ende", "Arbeitszeit",
                                                                         "Pausen", "Saldo"] }, "PDF: header")
        let dayLines = lines.filter { $0.style == .day }
        suite.expect(dayLines.count == report.days.count, "PDF: a line per day")
        suite.expect(lines.filter { $0.style == .week }.first?.cells.first == "KW 1", "PDF: week totals")
        let total = lines.first { $0.style == .total }
        suite.expect(total?.cells.first == "Summe: \(report.totals.days) Arbeitstage"
                     && total?.cells.last == TTFormat.balance(report.balance), "PDF: total")
        suite.expect(lines.contains { $0.style == .note && $0.cells[0].contains("✎ manuell korrigiert") },
                     "PDF: target line with legend")
        let warnings = report.days.reduce(0) { $0 + $1.warnings.count }
        suite.expect(lines.filter { $0.style == .warning }.count == warnings, "PDF: the warnings listed")
        suite.expect(dayLines.contains { $0.cells[0].contains("⚠") } == (warnings > 0), "PDF: days with warnings marked")

        let pdf = TimeTrackingPDF.data(report, settings: s, now: now, appName: "Barforge", texts, de)
        let document = CGDataProvider(data: pdf as CFData).flatMap(CGPDFDocument.init)
        let pages = document?.numberOfPages ?? 0
        suite.expect(pages >= 2, "PDF: a valid document over several pages (\(pages))")
        if let page = document?.page(at: 1) {
            let box = page.getBoxRect(.mediaBox)
            suite.expect(box.width == 595 && box.height == 842, "PDF: A4")
        }
        // Without any day: one page with "no violations".
        let empty = TTReport(from: from, to: from, days: [])
        let emptyLines = TimeTrackingPDF.lines(empty, settings: s, now: now, appName: "Barforge", texts, de)
        suite.expect(emptyLines.last?.cells == [texts.exportNoWarnings], "PDF: no violations")
        let one = CGDataProvider(data: TimeTrackingPDF.render(emptyLines) as CFData).flatMap(CGPDFDocument.init)
        suite.expect(one?.numberOfPages == 1, "PDF: a short export is one page")
    }
}
