// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import CoreGraphics
import Foundation

/// The tests of Tagwerk's `week_view.rs`, one function per `#[test]`, plus
/// the English texts of the week view.
enum TimeTrackingWeekTests {
    static func run(_ suite: TestSuite) {
        titles(suite)
        hoursCoverFrameAndOutsideWork(suite)
        freeDayShowsUncountedTime(suite)
        compactHoursFollowTheWork(suite)
        blocksIncludeCorrections(suite)
        workWithoutMacJoinsBlocks(suite)
        freeAreaPresets(suite)
        workLabelsAvoidTheTimes(suite)
        durationsFollowShownMinutes(suite)
        contextMenuOffersWhatIsPossible(suite)
        edgesOfADay(suite)
        draggingSnapsAndStaysInLimits(suite)
        dragResultAndLabel(suite)
        dragPreviewMovesTheEdgeAndShowsWhatIsCut(suite)
        draggingAtDetachedWorkWithoutMacShowsTheRealChange(suite)
        magnetLeavesTheNeighbouringValuesReachable(suite)
        boundDialogFollowsTheDragLimits(suite)
        workDialogAcceptsItsOwnPresets(suite)
        freeAreasLeaveRoomForTheEdges(suite)
        voiceoverReadsDaysBlocksAndPauses(suite)
        workdaysWithoutEntriesShowTheMissingTarget(suite)
        fullDayAbsenceLocksTheColumn(suite)
        ruleWarningsPerDay(suite)
        runningBlockToday(suite)

        englishTexts(suite)
    }

    static let t = TTWeekTexts.de

    static func h(_ hh: Int, _ mm: Int) -> Int { hh * 3600 + mm * 60 }
    static func date(_ y: Int, _ m: Int, _ d: Int) -> TTDate { TTDate(year: y, month: m, day: d)! }
    static func at(_ d: TTDate, _ hh: Int, _ mm: Int, _ ss: Int = 0) -> TTDateTime {
        TTDateTime(d, hour: hh, minute: mm, second: ss)
    }

    static func snap(_ days: [TTDay], _ now: TTDateTime, _ running: Bool,
                     settings: TTSettings = TTSettings()) -> TTWeekSnapshot {
        TTWeekSnapshot(days: days, settings: settings, now: now, running: running)
    }

    static let week47 = TTDate(year: 2026, month: 11, day: 16)!

    static func columns(_ days: [TTDay], _ now: TTDateTime, _ running: Bool = false) -> [TTWeekColumn] {
        TTWeekLayout.columns(snap(days, now, running), monday: week47)
    }

    static func same(_ a: (from: Int, to: Int), _ b: (Int, Int)) -> Bool { a.from == b.0 && a.to == b.1 }
    static func same(_ a: (lo: Int, hi: Int)?, _ b: (Int, Int)?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x.lo == y.0 && x.hi == y.1
        default: return false
        }
    }

    static func edges(_ start: Int, _ end: Int) -> TTWeekEdges {
        TTWeekEdges(start: start, end: end, autoStart: start, autoEnd: end, manualStart: false, manualEnd: false,
                    running: false)
    }

    static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: week_view.rs

    private static func titles(_ suite: TestSuite) {
        suite.expect(TTWeekLayout.title(monday: date(2026, 11, 16), t) == "KW 47  ·  16. – 22. November 2026",
                     "week: title within a month")
        suite.expect(TTWeekLayout.title(monday: date(2026, 11, 30), t) == "KW 49  ·  30. November – 6. Dezember 2026",
                     "week: title across months")
        suite.expect(TTWeekLayout.title(monday: date(2025, 12, 29), t) == "KW 1  ·  29. Dezember 2025 – 4. Januar 2026",
                     "week: title across years")
        suite.expect(TTWeekLayout.monday(date(2026, 11, 22)) == date(2026, 11, 16), "week: Monday of a Sunday")
    }

    private static func hoursCoverFrameAndOutsideWork(_ suite: TestSuite) {
        suite.expect(same(TTWeekLayout.hourRange(TTSettings(), [], now: nil, compact: false), (7, 22)),
                     "week hours: the default frame")
        let s = TTSettings().withRules(TTWorkRules(frameFrom: h(6, 30), frameTo: h(18, 15)))
        suite.expect(same(TTWeekLayout.hourRange(s, [], now: nil, compact: false), (6, 19)), "week hours: a frame of its own")
        // Without work the compact grid shows the whole frame too.
        suite.expect(same(TTWeekLayout.hourRange(s, [], now: h(10, 0), compact: true), (6, 19)),
                     "week hours: compact without work")
        // Work outside the frame widens the grid.
        var d = TTDay(date: date(2026, 11, 17))
        d.addPeriod(from: h(5, 40), to: h(9, 0))
        d.addPeriod(from: h(21, 0), to: h(22, 30))
        let cols = columns([d], at(date(2026, 11, 18), 9, 0))
        suite.expect(same(TTWeekLayout.hourRange(TTSettings(), cols, now: nil, compact: false), (5, 23)),
                     "week hours: outside work widens the frame")
        // Compact reaches just as far: the work outside belongs to it.
        suite.expect(same(TTWeekLayout.hourRange(TTSettings(), cols, now: nil, compact: true), (5, 23)),
                     "week hours: compact with outside work")
        let outside = cols[1].blocks.filter { $0.kind == .outside }.map(\.span)
        suite.expect(outside == [TTSpan(h(5, 40), h(7, 0)), TTSpan(h(22, 0), h(22, 30))], "week: outside blocks \(outside)")
        suite.expect(cols[1].warnings.count == 1
                     && cols[1].warnings[0].text(t.texts).contains("außerhalb des Arbeitszeitrahmens"),
                     "week: one warning about the work outside")
    }

    private static func freeDayShowsUncountedTime(_ suite: TestSuite) {
        // Saturday without "Record today": the recorded time as a block of its own, not counted.
        var d = TTDay(date: date(2026, 11, 21))
        d.addPeriod(from: h(10, 0), to: h(12, 0))
        d.freeDay = .uncounted
        let now = at(date(2026, 11, 22), 9, 0)
        var cols = columns([d], now)
        let kinds = cols[5].blocks.map { "\($0.kind) \($0.from) \($0.to)" }
        suite.expect(kinds == ["freeDay \(h(10, 0)) \(h(12, 0))"], "free day: an uncounted block \(kinds)")
        suite.expect(cols[5].workSecs == 0, "free day: no working time")
        // Full width, as there is something to see.
        suite.expect(TTWeekLayout.columnWeights(TTSettings(), cols)[5] == 1.0, "free day: full width with a block")
        // Counted: a normal block.
        d.freeDay = .counted
        cols = columns([d], now)
        suite.expect(cols[5].blocks.map(\.kind) == [.work], "free day counted: a work block")
        suite.expect(cols[5].workSecs == h(2, 0), "free day counted: its working time")
        suite.expect(cols[5].edges != nil, "free day counted: start and end can move")
        // Not counted, but with work away from the Mac: that counts, start and
        // end only after "Count recorded time" (as in the panel and the inspector).
        d.freeDay = .uncounted
        d.addWork(from: h(13, 0), to: h(14, 0), note: "Telefonat")
        cols = columns([d], now)
        suite.expect(cols[5].workSecs == h(1, 0), "free day: work away from the Mac counts")
        suite.expect(cols[5].edges == nil, "free day uncounted: no edges")
    }

    private static func compactHoursFollowTheWork(_ suite: TestSuite) {
        let s = TTSettings()
        func week(_ periods: [(Int, Int)]) -> [TTWeekColumn] {
            var d = TTDay(date: date(2026, 11, 17))
            for (from, to) in periods { d.addPeriod(from: from, to: to) }
            return columns([d], at(date(2026, 11, 22), 9, 0))
        }
        // 08:27–17:04: an hour of room before (but not before the frame) and after.
        let cols = week([(h(8, 27), h(12, 0)), (h(12, 45), h(17, 4))])
        suite.expect(same(TTWeekLayout.hourRange(s, cols, now: nil, compact: true), (7, 19)), "compact: room around the work")
        suite.expect(same(TTWeekLayout.hourRange(s, cols, now: nil, compact: false), (7, 22)), "compact: whole frame")
        // In the running week "now" belongs to it.
        suite.expect(same(TTWeekLayout.hourRange(s, cols, now: h(20, 10), compact: true), (7, 22)), "compact: up to now")
        // A short day: filled up to the minimum height, within the frame.
        let short = week([(h(10, 0), h(12, 0))])
        let (h0, h1) = TTWeekLayout.hourRange(s, short, now: nil, compact: true)
        suite.expect(h1 - h0 == TTWeekLayout.minHours, "compact: at least \(TTWeekLayout.minHours) hours")
        suite.expect(h0 >= 7 && h0 <= 9 && h1 >= 13 && h1 <= 22, "compact: \(h0)–\(h1) within the frame")
        // Free days without an entry are narrow, workdays and a Saturday with work are not.
        let n = TTWeekLayout.narrow
        suite.expect(TTWeekLayout.columnWeights(s, cols) == [1, 1, 1, 1, 1, n, n], "weights: the weekend narrow")
        var sat = TTDay(date: date(2026, 11, 21))
        sat.addPeriod(from: h(10, 0), to: h(11, 0))
        let withSat = columns([sat], at(date(2026, 11, 22), 9, 0))
        suite.expect(TTWeekLayout.columnWeights(s, withSat) == [1, 1, 1, 1, 1, 1, n], "weights: a Saturday with work")
        // A four-day week: the free Friday is narrow as well.
        let four = s.withRules(TTWorkRules(workdays: 0b0_1111))
        suite.expect(TTWeekLayout.columnWeights(four, withSat)[4] == n, "weights: a free Friday")
    }

    private static func blocksIncludeCorrections(_ suite: TestSuite) {
        var d = TTDay(date: date(2026, 11, 17))
        d.addPeriod(from: h(8, 12), to: h(11, 58))
        d.addPeriod(from: h(12, 41), to: h(17, 30))
        d.start = h(7, 30)
        d.end = h(17, 0)
        d.breaks.append(TTBreak(from: h(10, 0), to: h(10, 30)))
        let cols = columns([d], at(date(2026, 11, 17), 20, 0))
        suite.expect(cols.count == 7 && cols[0].blocks.isEmpty, "corrections: seven columns, Monday empty")
        suite.expect(cols[1].blocks.map(\.span) == [TTSpan(h(7, 30), h(10, 0)), TTSpan(h(10, 30), h(11, 58)),
                                                    TTSpan(h(12, 41), h(17, 0))], "corrections: the blocks")
        suite.expect(cols[1].workSecs == h(2, 30) + h(1, 28) + h(4, 19), "corrections: working time")
        // 7:30 – 17:00 minus working time: manual break and lunch gap.
        suite.expect(cols[1].pauseSecs == h(0, 30) + h(0, 43), "corrections: breaks")
        suite.expect(cols[1].blocks[0].notes.map { $0.text(t) }
                        == ["Arbeitsbeginn manuell festgelegt", "endet mit einer manuellen Pause"],
                     "corrections: notes of the first block")
        suite.expect(cols[1].gaps == [TTSpan(h(10, 0), h(10, 30)), TTSpan(h(11, 58), h(12, 41))], "corrections: gaps")
        suite.expect(cols[1].manual.isEmpty, "corrections: no work away from the Mac")
        suite.expect(cols[1].blocks[2].notes.map { $0.text(t) } == ["Feierabend manuell festgelegt"],
                     "corrections: notes of the last block")
        suite.expect(cols[1].warnings.isEmpty, "corrections: no warnings")
    }

    private static func workWithoutMacJoinsBlocks(_ suite: TestSuite) {
        var d = TTDay(date: date(2026, 11, 17))
        d.addPeriod(from: h(8, 0), to: h(12, 0))
        d.addPeriod(from: h(14, 0), to: h(17, 0))
        d.addWork(from: h(12, 5), to: h(13, 30), note: "Meeting")
        let cols = columns([d], at(date(2026, 11, 17), 20, 0))
        // 12:00–12:05 is shorter than the minimum break and counts.
        suite.expect(cols[1].blocks.map(\.span) == [TTSpan(h(8, 0), h(13, 30)), TTSpan(h(14, 0), h(17, 0))],
                     "away: joins the block")
        let block = TTSpan(h(12, 5), h(13, 30))
        suite.expect(cols[1].manual == [TTWeekManual(span: block, block: block, note: "Meeting")], "away: manual")
        suite.expect(cols[1].gaps == [TTSpan(h(13, 30), h(14, 0))], "away: gaps")
        suite.expect(cols[1].blocks[0].notes.map { $0.text(t) } == ["ohne Mac gearbeitet 12:05 – 13:30 (Meeting)"],
                     "away: note")
        suite.expect(TTWeekLayout.spanText(cols[1].gaps[0], t) == "13:30 – 14:00 Uhr (30 Min.)", "away: span text")
    }

    private static func freeAreaPresets(_ suite: TestSuite) {
        let m = 15 * 60
        var d = TTDay(date: date(2026, 11, 17))
        d.addPeriod(from: h(8, 0), to: h(12, 0))
        d.addPeriod(from: h(12, 45), to: h(17, 0))
        func now(_ hh: Int, _ mm: Int) -> TTDateTime { at(date(2026, 11, 17), hh, mm) }
        let cols = columns([d], now(20, 0))
        let c = cols[1]
        func preset(_ col: TTWeekColumn, _ clicked: Int, _ n: TTDateTime, _ minWork: Int = m) -> TTSpan? {
            TTWeekLayout.freePreset(col, at: clicked, now: n, minWork: minWork)
        }
        // In the break: the whole break.
        suite.expect(preset(c, h(12, 20), now(20, 0)) == TTSpan(h(12, 0), h(12, 45)), "preset: the whole break")
        // Before the start and after the end: 30 minutes from the click (5-minute grid).
        suite.expect(preset(c, h(7, 13), now(20, 0)) == TTSpan(h(7, 10), h(7, 40)), "preset: before the start")
        suite.expect(preset(c, h(18, 2), now(20, 0)) == TTSpan(h(18, 0), h(18, 30)), "preset: after the end")
        // Nothing on a block.
        suite.expect(preset(c, h(9, 0), now(20, 0)) == nil, "preset: nothing on a block")
        // Today not in the future; the end at most now. Shortly before now the
        // preset would stay under the minimum: it starts earlier then.
        suite.expect(preset(c, h(17, 50), now(18, 0)) == TTSpan(h(17, 45), h(18, 0)), "preset: earlier before now")
        suite.expect(preset(c, h(17, 2), now(17, 10)) == TTSpan(h(17, 0), h(17, 10)), "preset: not into the block")
        suite.expect(preset(c, h(18, 5), now(18, 0)) == nil, "preset: not after now")
        // Not on future days, on a free day in the past yes.
        suite.expect(preset(cols[2], h(9, 0), now(20, 0)) == nil, "preset: not on a future day")
        suite.expect(preset(cols[0], h(9, 0), now(20, 0)) == TTSpan(h(9, 0), h(9, 30)), "preset: a past free day")
        // Free areas for the hand: before the start, the break, after the end (until now).
        suite.expect(TTWeekLayout.freeSpans(c, now: now(20, 0))
                        == [TTSpan(0, h(8, 0)), TTSpan(h(12, 0), h(12, 45)), TTSpan(h(17, 0), h(20, 0))],
                     "free spans: before, between, after")
        suite.expect(TTWeekLayout.freeSpans(c, now: now(18, 0)).last == TTSpan(h(17, 0), h(18, 0)), "free spans: until now")
        suite.expect(TTWeekLayout.freeSpans(cols[2], now: now(20, 0)).isEmpty, "free spans: none in the future")
        suite.expect(TTWeekLayout.freeSpans(cols[0], now: now(20, 0)) == [TTSpan(0, h(23, 59))], "free spans: a whole day")
        // At most until 23:59 (and earlier for it).
        suite.expect(preset(cols[0], h(23, 50), now(20, 0)) == TTSpan(h(23, 40), h(23, 59)), "preset: until 23:59")
        // A longer minimum: the preset at least that long.
        suite.expect(preset(c, h(18, 2), now(20, 0), 45 * 60) == TTSpan(h(18, 0), h(18, 45)), "preset: longer minimum")
    }

    private static func workLabelsAvoidTheTimes(_ suite: TestSuite) {
        suite.expect(TTWeekLayout.workLabel("", t) == "Sonstiges" && TTWeekLayout.workLabel(" Telefonat ", t) == "Telefonat",
                     "work label: the note or Other")
        // Centred when free; else at the edge; too narrow: nothing.
        let centred = TTWeekLayout.workLabelRect(rect(0, 100, 120, 40), taken: [], width: 50)
        suite.expect(centred?.minY == 114 && centred?.height == 12, "work label: centred")
        let times = [rect(7, 102, 80, 15)]
        suite.expect(TTWeekLayout.workLabelRect(rect(0, 100, 120, 40), taken: times, width: 50)?.minY == 126.5,
                     "work label: below the times")
        suite.expect(TTWeekLayout.workLabelRect(rect(0, 100, 50, 40), taken: [], width: 50) == nil, "work label: too narrow")
        // Too low: right of the time, when there is room.
        let line = [rect(7, 100, 60, 17)]
        let beside = TTWeekLayout.workLabelRect(rect(0, 100, 140, 10), taken: line, width: 40)
        suite.expect(beside?.minX == 95 && beside?.minY == 101, "work label: beside the time")
        suite.expect(TTWeekLayout.workLabelRect(rect(0, 100, 100, 10), taken: line, width: 40) == nil,
                     "work label: no room beside")
    }

    private static func durationsFollowShownMinutes(_ suite: TestSuite) {
        // 17:00:19 – 17:30:00 shows 17:00 – 17:30 and so 30 min.
        suite.expect(TTWeekLayout.spanText(TTSpan(h(17, 0) + 19, h(17, 30)), t) == "17:00 – 17:30 Uhr (30 Min.)",
                     "durations: by the shown minutes")
        suite.expect(TTWeekLayout.spanText(TTSpan(h(14, 45) + 27, h(15, 40)), t) == "14:45 – 15:40 Uhr (55 Min.)",
                     "durations: 55 min")
        suite.expect(TTSpan.shownLen(from: h(9, 0) + 59, to: h(9, 0) + 30) == 0, "durations: within a minute")
    }

    private static func contextMenuOffersWhatIsPossible(_ suite: TestSuite) {
        let d = date(2026, 11, 17)
        func titles(_ ctx: TTWeekContext, _ canOpen: Bool) -> [String] {
            TTWeekLayout.contextEntries(ctx, canOpen: canOpen, t).map { $0.title }
        }
        // On a block next to the time: only the day.
        let plain = TTWeekContext(date: d)
        suite.expect(titles(plain, true) == ["Di, 17.11.2026", "", "Tag bearbeiten"], "menu: only the day")
        // Free day with a mark: count the recorded time (with a check mark).
        var freeDay = plain
        freeDay.counting = false
        suite.expect(titles(freeDay, true) == ["Di, 17.11.2026", "", "Tag bearbeiten", "Erfasste Zeit zählen"],
                     "menu: count recorded time")
        // Without the window or in the future there is nothing to do there.
        suite.expect(TTWeekLayout.contextEntries(plain, canOpen: false, t).isEmpty, "menu: nothing to do")
        // Free area: enter.
        var free = plain
        free.preset = TTSpan(h(12, 0), h(12, 30))
        suite.expect(titles(free, true) == ["Di, 17.11.2026", "", "Tag bearbeiten", "Arbeit ohne Mac eintragen …"],
                     "menu: add work in a free area")
        // Work away from the Mac: with its span, delete.
        var work = plain
        work.work = TTWeekWorkHit(block: TTSpan(h(14, 0), h(14, 45)), note: "Meeting")
        suite.expect(titles(work, true) == ["Di, 17.11.2026", "", "Tag bearbeiten", "",
                                            "Meeting 14:00 – 14:45 Uhr (45 Min.)", "Arbeit ohne Mac löschen"],
                     "menu: work away from the Mac")
        let entries = TTWeekLayout.contextEntries(work, canOpen: false, t)
        suite.expect(entries.count == 4, "menu: without “Edit Day” no second separator")
        suite.expect(entries.count == 4 && entries[2].action == nil && entries[3].action == .removeWork,
                     "menu: the span is display only")
        // The absence as a submenu, also for future days where nothing else goes.
        var off = plain
        off.absenceEditable = true
        suite.expect(titles(off, false) == ["Di, 17.11.2026", "", "Abwesenheit"], "menu: absence without the day")
        suite.expect(titles(off, true) == ["Di, 17.11.2026", "", "Tag bearbeiten", "Abwesenheit"], "menu: absence")
        // A day with entries can be emptied.
        var full = off
        full.busy = true
        full.clearable = true
        suite.expect(titles(full, true) == ["Di, 17.11.2026", "", "Tag bearbeiten", "Abwesenheit",
                                            "Alle Einträge löschen …"], "menu: delete all entries")
        let half = TTAbsence(.vacation, half: true)
        let subs = TTWeekLayout.absenceEntries(current: half, busy: false, noTarget: false, t)
        suite.expect(subs.map { $0.title } == ["Keine", "", "Urlaub", "Urlaub (halber Tag)", "Sonderurlaub", "Krank",
                                           "Krank (halber Tag)", "Feiertag", "Feiertag (halber Tag)", "Zeitausgleich"],
                     "absence menu: the kinds")
        suite.expect(subs.filter(\.checked).map { $0.title } == ["Urlaub (halber Tag)"], "absence menu: the checked one")
        suite.expect(subs.allSatisfy { $0.enabled || $0.title.isEmpty }, "absence menu: an empty day allows everything")
        suite.expect(TTWeekLayout.absenceEntries(current: nil, busy: false, noTarget: false, t)[0].checked,
                     "absence menu: “None” checked")
        // Every item leads to exactly its absence.
        for e in subs where !e.title.isEmpty {
            let choice = TTWeekLayout.absence(ofTag: e.tag)
            suite.expect(choice != nil && (choice?.absence?.label(t.texts) ?? "Keine") == e.title,
                         "absence menu: \(e.title) by its tag")
        }
        // With entries: only "None" and half days, and the note.
        let busy = TTWeekLayout.absenceEntries(current: nil, busy: true, noTarget: false, t)
        suite.expect(busy.filter(\.enabled).map { $0.title }
                        == ["Keine", "Urlaub (halber Tag)", "Krank (halber Tag)", "Feiertag (halber Tag)"],
                     "absence menu: busy day")
        suite.expect(busy.last == TTWeekAbsenceItem(title: "Ganztags erst nach „Alle Einträge löschen“", tag: -1,
                                                    checked: false, enabled: false), "absence menu: busy note")
        // A free day (without target): remove only, "None" and the entered one.
        let freeAbsence = TTWeekLayout.absenceEntries(current: TTAbsence(.holiday, half: false), busy: true,
                                                      noTarget: true, t)
        suite.expect(freeAbsence.map { "\($0.title)|\($0.enabled)" }
                        == ["Keine|true", "|false", "Feiertag|true", "|false", "Freier Tag: nur entfernen|false"],
                     "absence menu: a free day")
        suite.expect(TTWeekLayout.absence(ofTag: freeAbsence[0].tag) == TTWeekAbsenceChoice(absence: nil),
                     "absence tag: none")
        suite.expect(TTWeekLayout.absence(ofTag: freeAbsence[2].tag)
                        == TTWeekAbsenceChoice(absence: TTAbsence(.holiday, half: false)), "absence tag: holiday")
        suite.expect(TTWeekLayout.absence(ofTag: -1) == nil && TTWeekLayout.absence(ofTag: 99) == nil,
                     "absence tag: display only and unknown")
        // On the only block: start (manual, so also reset) and end.
        let e = TTWeekEdges(start: h(7, 30), end: h(17, 0), autoStart: h(8, 12), autoEnd: h(17, 0), manualStart: true,
                            manualEnd: false, running: false)
        var both = plain
        both.edges = e
        both.bounds = [.start, .end]
        suite.expect(titles(both, true) == ["Di, 17.11.2026", "", "Tag bearbeiten", "", "Arbeitsbeginn ändern …",
                                            "Arbeitsbeginn zurücksetzen (08:12 Uhr)", "Feierabend ändern …"],
                     "menu: start and end")
        var end = both
        end.bounds = [.end]
        suite.expect(titles(end, false) == ["Di, 17.11.2026", "", "Feierabend ändern …"], "menu: only the end")
    }

    private static func edgesOfADay(_ suite: TestSuite) {
        var d = TTDay(date: date(2026, 11, 17))
        d.addPeriod(from: h(8, 12), to: h(11, 58))
        d.addPeriod(from: h(12, 41), to: h(17, 30))
        d.start = h(7, 30)
        var cols = columns([d], at(date(2026, 11, 17), 20, 0))
        let e = cols[1].edges
        suite.expect(e?.start == h(7, 30) && e?.autoStart == h(8, 12) && e?.manualStart == true, "edges: the start")
        suite.expect(e?.end == h(17, 30) && e?.autoEnd == h(17, 30) && e?.manualEnd == false && e?.running == false,
                     "edges: the end")
        let start = e?.get(.start)
        suite.expect(start?.value == h(7, 30) && start?.auto == h(8, 12) && start?.manual == true, "edges: get(.start)")
        suite.expect(cols[0].edges == nil, "edges: nothing to move without working time")
        // Only worked outside the frame: nothing that counts, so no edges.
        var early = TTDay(date: date(2026, 11, 18))
        early.addPeriod(from: h(5, 0), to: h(6, 30))
        cols = columns([early], at(date(2026, 11, 18), 20, 0))
        suite.expect(cols[2].edges == nil, "edges: none outside the frame")
        // Still running today: the end is "now".
        var today = TTDay(date: date(2026, 11, 17))
        today.addPeriod(from: h(8, 0), to: h(9, 30))
        cols = columns([today], at(date(2026, 11, 17), 9, 30), true)
        suite.expect(cols[1].edges?.running == true, "edges: running today")
    }

    private static func draggingSnapsAndStaysInLimits(_ suite: TestSuite) {
        let s = TTWorkRules.default // frame 07:00–22:00
        let e = edges(h(8, 12), h(17, 0))
        let grid = (h(7, 0), h(19, 0))
        let past = TTLimits.dayEnd - 60
        suite.expect(same(TTWeekLayout.dragLimits(e, .start, s, limit: past, grid: grid), (h(7, 0), h(16, 55))),
                     "drag limits: start")
        suite.expect(same(TTWeekLayout.dragLimits(e, .end, s, limit: past, grid: grid), (h(8, 17), h(19, 0))),
                     "drag limits: end")
        // Today at most until now (to the minute), in the future not at all.
        suite.expect(same(TTWeekLayout.dragLimits(e, .end, s, limit: h(17, 20) + 42, grid: grid), (h(8, 17), h(17, 20))),
                     "drag limits: until now")
        suite.expect(same(TTWeekLayout.dragLimits(e, .start, s, limit: nil, grid: grid), nil), "drag limits: future")
        // Bounds with seconds: inwards to whole minutes.
        let odd = edges(h(8, 12) + 23, h(17, 0) + 41)
        suite.expect(same(TTWeekLayout.dragLimits(odd, .start, s, limit: past, grid: grid), (h(7, 0), h(16, 55))),
                     "drag limits: seconds at the start")
        suite.expect(same(TTWeekLayout.dragLimits(odd, .end, s, limit: past, grid: grid), (h(8, 18), h(19, 0))),
                     "drag limits: seconds at the end")

        let limits = (lo: h(7, 0), hi: h(16, 55))
        let magnet = 5 * 60
        func value(_ raw: Int, _ auto: Int?, _ fine: Bool) -> (Int, Bool) {
            TTWeekLayout.dragValue(raw, auto: auto, magnet: magnet, fine: fine, limits: limits)
        }
        // 5-minute grid, with ⌥ to the minute.
        suite.expect(value(h(7, 32) + 40, nil, false) == (h(7, 35), false), "drag value: 5 minutes")
        suite.expect(value(h(7, 32) + 40, nil, true) == (h(7, 33), false), "drag value: with ⌥")
        // Close to the recorded value the edge snaps there (also between grid lines).
        suite.expect(value(h(8, 11), h(8, 12) + 23, false) == (h(8, 12) + 23, true), "drag value: magnet before")
        suite.expect(value(h(8, 14), h(8, 12) + 23, false) == (h(8, 12) + 23, true), "drag value: magnet after")
        suite.expect(value(h(8, 30), h(8, 12) + 23, false) == (h(8, 30), false), "drag value: away from the magnet")
        // Not beyond the limits.
        suite.expect(value(h(5, 0), nil, false) == (h(7, 0), false), "drag value: lower limit")
        suite.expect(value(h(18, 0), nil, false) == (h(16, 55), false), "drag value: upper limit")
    }

    private static func dragResultAndLabel(_ suite: TestSuite) {
        let auto = edges(h(8, 12), h(17, 0))
        // Not manual: at the recorded value nothing changes, otherwise the new time.
        suite.expect(TTWeekLayout.dragResult(auto, .start, at: h(8, 12)) == nil, "drag result: unchanged")
        suite.expect(TTWeekLayout.dragResult(auto, .start, at: h(7, 30)) == .at(h(7, 30)), "drag result: new time")
        // Manual: back to the recorded value means automatic again; the same value nothing.
        var manual = auto
        manual.start = h(7, 30)
        manual.manualStart = true
        suite.expect(TTWeekLayout.dragResult(manual, .start, at: h(8, 12)) == .auto, "drag result: automatic again")
        suite.expect(TTWeekLayout.dragResult(manual, .start, at: h(7, 30)) == nil, "drag result: the same manual value")
        suite.expect(TTWeekLayout.dragResult(manual, .start, at: h(7, 45)) == .at(h(7, 45)), "drag result: another start")
        suite.expect(TTWeekLayout.dragResult(manual, .end, at: h(17, 30)) == .at(h(17, 30)), "drag result: another end")

        func label(_ b: TTEditBound, _ at: Int, _ before: Int, _ autoValue: Int?, _ diff: Int) -> String {
            TTWeekLayout.dragLabel(b, at: at, before: before, auto: autoValue, workDiff: diff, t)
        }
        suite.expect(label(.start, h(7, 30), h(7, 5), h(7, 5), -25 * 60) == "Beginn 07:30 · +25 Min.", "drag label: later")
        suite.expect(label(.end, h(15, 55), h(17, 0), nil, -65 * 60) == "Feierabend 15:55 · −1:05 h", "drag label: hours")
        suite.expect(label(.start, h(7, 5) + 12, h(7, 30), h(7, 5) + 12, 25 * 60) == "Beginn 07:05 · automatisch",
                     "drag label: automatic")
        suite.expect(label(.end, h(17, 0), h(17, 0), nil, 0) == "Feierabend 17:00", "drag label: unchanged")
        // When the working time changes differently from the time, the label says so.
        suite.expect(label(.end, h(19, 15), h(19, 30), nil, 105 * 60) == "Feierabend 19:15 · −15 Min. · Arbeitszeit +1:45 h",
                     "drag label: a different working time")
        suite.expect(label(.start, h(9, 0), h(8, 0), nil, 0) == "Beginn 09:00 · +1:00 h · Arbeitszeit unverändert",
                     "drag label: unchanged working time")
    }

    /// The model of the week of 16 November 2026 with `days`, now on Wednesday 9:00.
    static func model(_ days: [TTDay], now: TTDateTime = at(date(2026, 11, 18), 9, 0)) -> TTWeekModel {
        var data = TTWeekModel(snap: snap(days, now, false), monday: week47)
        data.rebuild()
        return data
    }

    private static func dragPreviewMovesTheEdgeAndShowsWhatIsCut(_ suite: TestSuite) {
        let day = date(2026, 11, 17)
        var d = TTDay(date: day)
        d.addPeriod(from: h(8, 0), to: h(12, 0))
        d.addPeriod(from: h(12, 45), to: h(16, 0))
        d.addWork(from: h(16, 0), to: h(17, 0), note: "Meeting")
        var data = model([d])
        guard let e = data.cols[1].edges else {
            suite.expect(false, "drag preview: edges")
            return
        }
        suite.expect(e.start == h(8, 0) && e.end == h(17, 0), "drag preview: work away from the Mac belongs to the end")
        var g = TTWeekDrag(col: 1, date: day, bound: .end, edges: e, active: true, at: h(16, 30), days: [d], day: d)
        TTWeekLayout.preview(&data, &g)
        let c = data.cols[1]
        suite.expect(c.edges?.end == h(16, 30) && c.edges?.manualEnd == true, "drag preview: the end moved")
        suite.expect(c.blocks.last?.to == h(16, 30), "drag preview: the last block ends there")
        suite.expect(g.cut == [TTSpan(h(16, 30), h(17, 0))], "drag preview: the end of the meeting goes")
        // Back to the old value: the saved state again, nothing goes.
        g.at = h(17, 0)
        TTWeekLayout.preview(&data, &g)
        suite.expect(data.cols[1].edges?.end == h(17, 0) && g.cut.isEmpty && g.workDiff == 0, "drag preview: back")
        // The label names only the move when the working time follows it.
        g.at = h(16, 30)
        TTWeekLayout.preview(&data, &g)
        suite.expect(g.workDiff == -30 * 60, "drag preview: work diff")
        suite.expect(TTWeekLayout.dragLabel(g.bound, at: g.at, before: e.end, auto: e.autoEnd, workDiff: g.workDiff, t)
                        == "Feierabend 16:30 · −30 Min.", "drag preview: label")
    }

    /// Shows the day `d` (Tuesday, 17 November 2026, in the past) in the
    /// week and puts `bound` at `at` as while dragging.
    static func dragTo(_ d: TTDay, _ bound: TTEditBound, _ at: Int) -> (TTWeekModel, TTWeekDrag)? {
        var data = model([d])
        guard let edges = data.cols[1].edges else { return nil }
        var g = TTWeekDrag(col: 1, date: d.date, bound: bound, edges: edges, active: true, at: at, days: [d], day: d)
        TTWeekLayout.preview(&data, &g)
        return (data, g)
    }

    private static func draggingAtDetachedWorkWithoutMacShowsTheRealChange(_ suite: TestSuite) {
        // Work away from the Mac apart from the recorded time (Mac locked at
        // 17:00), the end dragged 15 minutes earlier at its end. A manual end
        // counts from the last lock before it: 17:00–19:00 becomes working time.
        var d = TTDay(date: date(2026, 11, 17))
        d.addPeriod(from: h(9, 0), to: h(17, 0))
        d.addWork(from: h(19, 0), to: h(19, 30), note: "Meeting")
        let s = TTSettings()
        suite.expect(d.record(s)?.workSecs == h(8, 30), "detached: working time before")
        guard let (data, g) = dragTo(d, .end, h(19, 15)) else {
            suite.expect(false, "detached: edges")
            return
        }
        suite.expect(g.edges.end == h(19, 30), "detached: the edge at the end of the work away from the Mac")
        // Preview and saving compute the same: +1:45 h instead of −15 min.
        var saved = d
        saved.setEnd(h(19, 15))
        suite.expect(saved.record(s)?.workSecs == h(10, 15), "detached: saved")
        suite.expect(data.cols[1].workSecs == h(10, 15) && g.workDiff == h(1, 45), "detached: preview")
        suite.expect(TTWeekLayout.dragLabel(g.bound, at: g.at, before: g.edges.end, auto: g.edges.autoEnd,
                                            workDiff: g.workDiff, t)
                        == "Feierabend 19:15 · −15 Min. · Arbeitszeit +1:45 h", "detached: label at the end")
        // Likewise before the recorded time: start 07:15 counts until the first unlock at 09:00.
        var early = TTDay(date: date(2026, 11, 17))
        early.addPeriod(from: h(9, 0), to: h(17, 0))
        early.addWork(from: h(7, 0), to: h(7, 30), note: "Telefonat")
        guard let (data2, g2) = dragTo(early, .start, h(7, 15)) else {
            suite.expect(false, "detached: edges at the start")
            return
        }
        suite.expect(data2.cols[1].workSecs == h(9, 45), "detached: preview at the start")
        suite.expect(TTWeekLayout.dragLabel(g2.bound, at: g2.at, before: g2.edges.start, auto: g2.edges.autoStart,
                                            workDiff: g2.workDiff, t)
                        == "Beginn 07:15 · +15 Min. · Arbeitszeit +1:15 h", "detached: label at the start")
    }

    private static func magnetLeavesTheNeighbouringValuesReachable(_ suite: TestSuite) {
        // At 40 points an hour the magnet (6 points) caught 9 minutes around the
        // recorded value: 08:05 to 08:20 next to 08:12 could not be reached.
        let limits = (lo: h(7, 0), hi: h(16, 55))
        let auto = h(8, 12) + 23
        let magnet = Int(TTWeekLayout.magnet / 40 * 3600)
        suite.expect(magnet == 9 * 60, "magnet: 9 minutes at 40 points an hour")
        for (raw, want) in [(h(8, 5), h(8, 5)), (h(8, 9), h(8, 10)), (h(8, 15), h(8, 15)), (h(8, 20), h(8, 20))] {
            suite.expect(TTWeekLayout.dragValue(raw, auto: auto, magnet: magnet, fine: false, limits: limits) == (want, false),
                         "magnet: \(TTFormat.clock(raw)) reachable")
        }
        suite.expect(TTWeekLayout.dragValue(h(8, 12), auto: auto, magnet: magnet, fine: false, limits: limits) == (auto, true),
                     "magnet: the recorded value")
        // With ⌥ every minute next to it, the recorded value itself only very close.
        for m in [10, 11, 13, 14] {
            suite.expect(TTWeekLayout.dragValue(h(8, m), auto: auto, magnet: magnet, fine: true, limits: limits)
                            == (h(8, m), false), "magnet: 08:\(m) with ⌥")
        }
        suite.expect(TTWeekLayout.dragValue(h(8, 12) + 30, auto: auto, magnet: magnet, fine: true, limits: limits)
                        == (auto, true), "magnet: the recorded value with ⌥")
    }

    private static func boundDialogFollowsTheDragLimits(_ suite: TestSuite) {
        let s = TTWorkRules.default // frame 07:00–22:00
        let past = TTLimits.dayEnd - 60
        let auto = edges(h(8, 12) + 23, h(17, 0) + 41)
        func result(_ e: TTWeekEdges, _ b: TTEditBound, _ at: Int, _ limit: Int?) -> Result<TTBoundChange?, TTWeekRefusal> {
            TTWeekLayout.dialogResult(e, b, at: at, s, limit: limit, t)
        }
        // "Apply" without a change: the field shows 08:12, that stays automatic.
        suite.expect(result(auto, .start, h(8, 12), past) == .success(nil), "dialog: unchanged start")
        suite.expect(result(auto, .end, h(17, 0), past) == .success(nil), "dialog: unchanged end")
        suite.expect(result(auto, .start, h(7, 30), past) == .success(.at(h(7, 30))), "dialog: a new start")
        // Manual: the same value changes nothing, the minute of the recorded value resets.
        var manual = auto
        manual.start = h(7, 30)
        manual.manualStart = true
        suite.expect(result(manual, .start, h(7, 30), past) == .success(nil), "dialog: the same manual value")
        suite.expect(result(manual, .start, h(8, 12), past) == .success(.auto), "dialog: back to automatic")
        // Refused with a reason: order, frame, minimum distance, future.
        func error(_ b: TTEditBound, _ at: Int, _ limit: Int?) -> String {
            if case let .failure(refusal) = result(auto, b, at, limit) { return refusal.text }
            return ""
        }
        suite.expect(error(.start, h(17, 30), past) == "Der Arbeitsbeginn muss vor dem Feierabend (17:00 Uhr) liegen.",
                     "dialog: start after end")
        suite.expect(error(.end, h(8, 0), past) == "Der Feierabend muss nach dem Arbeitsbeginn (08:12 Uhr) liegen.",
                     "dialog: end before start")
        suite.expect(error(.start, h(6, 30), past).hasPrefix("Der Arbeitsbeginn muss im Arbeitszeitrahmen von 07:00 bis 22:00 Uhr"),
                     "dialog: start outside the frame")
        suite.expect(error(.end, h(22, 30), past).hasPrefix("Der Feierabend muss im Arbeitszeitrahmen"),
                     "dialog: end outside the frame")
        suite.expect(error(.start, h(16, 57), past) == "Zwischen Arbeitsbeginn und Feierabend müssen mindestens 5 Minuten liegen.",
                     "dialog: minimum distance")
        suite.expect(error(.end, h(17, 30), h(17, 20) + 5) == "Der Feierabend kann nicht in der Zukunft liegen.",
                     "dialog: end in the future")
        suite.expect(error(.start, h(7, 30), nil) == "An künftigen Tagen lassen sich keine Zeiten eintragen.",
                     "dialog: a future day")
        // Exactly the times that can be dragged too (without the grid).
        for bound in [TTEditBound.start, .end] {
            for limit in [past, h(12, 0) + 30] {
                guard let (lo, hi) = TTWeekLayout.dragLimits(auto, bound, s, limit: limit, grid: (0, TTLimits.dayEnd)) else {
                    suite.expect(false, "dialog: limits for \(bound)")
                    continue
                }
                var wrong: [String] = []
                for minute in 0..<(TTLimits.dayEnd / 60) {
                    let at = minute * 60
                    let unchanged = at / 60 == auto.get(bound).value / 60
                    var ok = false
                    if case .success = result(auto, bound, at, limit) { ok = true }
                    if ok != (unchanged || (lo...hi).contains(at)) { wrong.append(TTFormat.clock(at)) }
                }
                suite.expect(wrong.isEmpty, "dialog: \(bound) with limit \(limit) like dragging: \(wrong.prefix(5))")
            }
        }
    }

    private static func workDialogAcceptsItsOwnPresets(_ suite: TestSuite) {
        let minimum = 30 * 60
        let past = TTLimits.dayEnd - 60
        func input(_ f: Int, _ to: Int, _ preset: TTSpan, _ pauses: [TTSpan], _ limit: Int?) -> Result<TTSpan, TTWeekRefusal> {
            TTWeekLayout.workInput(from: f, to: to, preset: preset, pauses: pauses, minWork: minimum, limit: limit, t)
        }
        // Preset: the break 12:00:37–12:20:10 (20 min, shorter than the minimum).
        let gap = TTSpan(h(12, 0) + 37, h(12, 20) + 10)
        suite.expect(input(h(12, 0), h(12, 20), gap, [gap], past) == .success(gap), "work input: the break to the second")
        // Changed and too short: refused; long enough: entered like that.
        suite.expect(input(h(12, 5), h(12, 20), gap, [gap], past)
                        == .failure(TTWeekRefusal(text: TTRecords.minWorkText(minimum, t.records))), "work input: too short")
        suite.expect(input(h(11, 50), h(12, 20), gap, [gap], past) == .success(TTSpan(h(11, 50), h(12, 20))),
                     "work input: long enough")
        // Another break filled exactly: also shorter.
        let other = TTSpan(h(15, 0), h(15, 20))
        let preset = TTSpan(h(18, 0), h(18, 30))
        suite.expect(input(h(15, 0), h(15, 20), preset, [gap, other], past) == .success(other), "work input: another break")
        // End before start, future.
        suite.expect(input(h(12, 20), h(12, 0), gap, [gap], past) == .failure(TTWeekRefusal(text: "Das Ende muss nach dem Beginn liegen.")),
                     "work input: end before start")
        suite.expect(input(h(17, 0), h(17, 40), preset, [], h(17, 30))
                        == .failure(TTWeekRefusal(text: "Das Ende kann nicht in der Zukunft liegen.")), "work input: future end")
        if case .success = input(h(9, 0), h(10, 0), preset, [], nil) {
            suite.expect(false, "work input: a future day is refused")
        }
        // Presets from the column: a break and shortly before now, both taken.
        var d = TTDay(date: date(2026, 11, 17))
        d.addPeriod(from: h(8, 0), to: h(12, 0) + 37)
        d.addPeriod(from: h(12, 20) + 10, to: h(17, 0))
        let now = at(date(2026, 11, 17), 17, 50, 27)
        var settings = TTSettings()
        settings.minWork = minimum
        let cols = TTWeekLayout.columns(snap([d], now, false, settings: settings), monday: week47)
        let limit = TTWeekLayout.freeLimit(cols[1].date, now: now)
        let pauses = cols[1].gaps
        let inPause = TTWeekLayout.freePreset(cols[1], at: h(12, 10), now: now, minWork: minimum)
        suite.expect(inPause == gap, "work input: preset in the break")
        let late = TTWeekLayout.freePreset(cols[1], at: h(17, 40), now: now, minWork: minimum)
        suite.expect(late == TTSpan(h(17, 20), h(17, 50) + 27), "work input: longer towards the front to the minimum")
        for p in [inPause, late].compactMap({ $0 }) {
            let shown = (p.from / 60 * 60, p.to / 60 * 60)
            suite.expect(input(shown.0, shown.1, p, pauses, limit) == .success(p), "work input: takes its preset \(p)")
        }
    }

    private static func freeAreasLeaveRoomForTheEdges(_ suite: TestSuite) {
        func r(_ y: CGFloat, _ height: CGFloat) -> CGRect { rect(10, y, 100, height) }
        // Free area above the start of work (edge at y = 100).
        let zone = r(95, 6.5)
        suite.expect(TTWeekLayout.withoutZones(r(40, 60), [zone]) == r(40, 55), "zones: above the start")
        // Below the end of work.
        let end = r(198.5, 6.5)
        suite.expect(TTWeekLayout.withoutZones(r(200, 50), [end]) == r(205, 45), "zones: below the end")
        // Another column: unchanged.
        let other = rect(200, 95, 100, 6.5)
        suite.expect(TTWeekLayout.withoutZones(r(40, 60), [other]) == r(40, 60), "zones: another column")
    }

    private static func voiceoverReadsDaysBlocksAndPauses(_ suite: TestSuite) {
        // Tuesday: 08:00–12:00, break, 12:45–17:00 with a meeting away from the Mac; Saturday free.
        var d = TTDay(date: date(2026, 11, 17))
        d.addPeriod(from: h(8, 0), to: h(12, 0))
        d.addPeriod(from: h(12, 45), to: h(15, 0))
        d.addWork(from: h(15, 0), to: h(17, 0), note: "Meeting")
        var cols = columns([d], at(date(2026, 11, 22), 9, 0))
        var items = TTWeekLayout.axItems(cols, t)
        func ofDay(_ col: Int) -> [String] { items.filter { $0.col == col }.map { $0.text } }
        suite.expect(ofDay(0) == ["Montag, 16. November: keine Arbeitszeit"], "voiceover: an empty day")
        suite.expect(ofDay(1) == ["Dienstag, 17. November: Arbeitszeit 8 Std. 15 Min., Pausen 45 Min.",
                                  "Arbeit 08:00 bis 12:00 Uhr, 4 Std.",
                                  "Pause 12:00 bis 12:45 Uhr, 45 Min.",
                                  "Arbeit 12:45 bis 17:00 Uhr, 4 Std. 15 Min.",
                                  "Arbeit ohne Mac, Meeting: 15:00 bis 17:00 Uhr"], "voiceover: a day \(ofDay(1))")
        suite.expect(items[1].part == .header && items[2].part == .span(TTSpan(h(8, 0), h(12, 0))),
                     "voiceover: header and span elements")
        // Warnings and manual bounds as sentences of their own.
        var long = TTDay(date: date(2026, 11, 18))
        long.addPeriod(from: h(8, 0), to: h(18, 30))
        long.start = h(7, 30)
        cols = columns([long], at(date(2026, 11, 22), 9, 0))
        items = TTWeekLayout.axItems(cols, t)
        let texts = ofDay(2)
        suite.expect(texts.first?.hasPrefix("Mittwoch, 18. November: Arbeitszeit 11 Std., Pausen 0 Min. Hinweis: Ab 9 Std.") == true,
                     "voiceover: warnings \(texts.first ?? "")")
        suite.expect(texts.count > 1 && texts[1] == "Arbeit 07:30 bis 18:30 Uhr, 11 Std. Arbeitsbeginn manuell festgelegt",
                     "voiceover: manual start")
        // The absence in the day header.
        var off = TTDay(date: date(2026, 11, 19))
        off.absence = TTAbsence(.vacation, half: true)
        cols = columns([off], at(date(2026, 11, 22), 9, 0))
        suite.expect(cols[3].absence?.short(t.texts) == "½ Urlaub" && cols[3].absence?.label(t.texts) == "Urlaub (halber Tag)",
                     "voiceover: absence texts")
        suite.expect(TTWeekLayout.axItems(cols, t)[3].text == "Donnerstag, 19. November: keine Arbeitszeit. Urlaub (halber Tag)",
                     "voiceover: absence in the header")
        suite.expect(TTWeekLayout.spokenDuration(h(0, 5), t) == "5 Min.", "voiceover: minutes")
        suite.expect(TTWeekLayout.spoken("KW 47  ·  16. – 22. November 2026") == "KW 47, 16. – 22. November 2026",
                     "voiceover: spoken title")
    }

    private static func workdaysWithoutEntriesShowTheMissingTarget(_ suite: TestSuite) {
        // Tue worked, Wed only a break, Thu vacation, Fri nothing; state: the Monday after.
        var tue = TTDay(date: date(2026, 11, 17))
        tue.addPeriod(from: h(8, 0), to: h(16, 0))
        var wed = TTDay(date: date(2026, 11, 18))
        wed.addBreak(from: h(12, 0), to: h(12, 30))
        var thu = TTDay(date: date(2026, 11, 19))
        thu.absence = TTAbsence(.vacation, half: false)
        let snapshot = snap([tue, wed, thu], at(date(2026, 11, 23), 9, 0), false)
        var cols = TTWeekLayout.columns(snapshot, monday: week47)
        let full = h(7, 48)
        // Mon lies before the first recorded day, Sat and Sun are free.
        suite.expect(cols.map(\.missing) == [nil, nil, full, nil, full, nil, nil], "missing: \(cols.map(\.missing))")
        suite.expect(TTWeekLayout.axItems(cols, t).first { $0.col == 4 }?.text
                        == "Freitag, 20. November: keine Arbeitszeit. Nichts erfasst, Saldo minus 7 Std. 48 Min.",
                     "missing: read by VoiceOver")
        // The week's balance counts exactly these days: 8:00 − 3 × 7:48.
        suite.expect(TTWeekLayout.weekSummary(snapshot, monday: week47, cols, t)
                        == "Woche: 8:00 h  ·  Pausen: 0:00 h  ·  Saldo \u{2212}15:24 h", "missing: week summary")
        // Today does not count yet.
        cols = TTWeekLayout.columns(snap(snapshot.days, at(date(2026, 11, 20), 9, 0), false), monday: week47)
        suite.expect(cols[4].missing == nil, "missing: not today")
    }

    private static func fullDayAbsenceLocksTheColumn(_ suite: TestSuite) {
        // A whole vacation day (with work away from the Mac from before) and a half one.
        var full = TTDay(date: date(2026, 11, 17))
        full.addWork(from: h(9, 0), to: h(10, 0), note: "Meeting")
        full.absence = TTAbsence(.vacation, half: false)
        var half = TTDay(date: date(2026, 11, 18))
        half.addPeriod(from: h(8, 0), to: h(12, 0))
        half.absence = TTAbsence(.vacation, half: true)
        let now = at(date(2026, 11, 20), 9, 0)
        let cols = columns([full, half], now)
        suite.expect(cols[1].locked && !cols[2].locked && !cols[0].locked, "locked: only the whole day")
        // Locked: no preset for work away from the Mac, no free areas.
        suite.expect(TTWeekLayout.freePreset(cols[1], at: h(14, 0), now: now, minWork: 15 * 60) == nil, "locked: no preset")
        suite.expect(TTWeekLayout.freeSpans(cols[1], now: now).isEmpty, "locked: no free areas")
        suite.expect(TTWeekLayout.freePreset(cols[2], at: h(14, 0), now: now, minWork: 15 * 60) != nil, "half day: a preset")
        suite.expect(!TTWeekLayout.freeSpans(cols[2], now: now).isEmpty, "half day: free areas")
        // Start and end can only be dragged on the half day too.
        var withWork = TTDay(date: date(2026, 11, 17))
        withWork.addPeriod(from: h(8, 0), to: h(12, 0))
        withWork.absence = TTAbsence(.vacation, half: false)
        var halfWithWork = TTDay(date: date(2026, 11, 18))
        halfWithWork.addPeriod(from: h(8, 0), to: h(12, 0))
        halfWithWork.absence = TTAbsence(.vacation, half: true)
        let data = model([withWork, halfWithWork], now: now)
        suite.expect(data.cols[1].locked && data.cols[1].edges != nil, "locked: edges exist")
        let geo = TTWeekGeometry(size: CGSize(width: 900, height: 700), data)
        suite.expect(TTWeekLayout.edgeRects(geo, data).map { $0.col } == [2, 2], "locked: only the half day, start and end")
    }

    private static func ruleWarningsPerDay(_ suite: TestSuite) {
        // 10:30 h without a break: the break is missing and the maximum is exceeded.
        var d = TTDay(date: date(2026, 11, 17))
        d.addPeriod(from: h(8, 0), to: h(18, 30))
        // Worked on Saturday.
        var sat = TTDay(date: date(2026, 11, 21))
        sat.addPeriod(from: h(10, 0), to: h(11, 0))
        let cols = columns([d, sat], at(date(2026, 11, 22), 9, 0))
        let texts = cols[1].warnings.map { $0.text(t.texts) }
        suite.expect(texts.count == 2 && texts[0].contains("45 Min. Pause") && texts[1].contains("mehr als 10 Std."),
                     "warnings: \(texts)")
        suite.expect(cols[5].warnings == [.weekend(counted: false)], "warnings: weekend")
        suite.expect(TTWeekLayout.warningsSummary(cols, t) == "Hinweise an 2 Tagen", "warnings: two days")
        suite.expect(TTWeekLayout.warningsSummary(Array(cols[..<2]), t) == "Hinweise an 1 Tag", "warnings: one day")
        suite.expect(TTWeekLayout.warningsSummary(Array(cols[2..<5]), t) == "", "warnings: none")
    }

    private static func runningBlockToday(_ suite: TestSuite) {
        var d = TTDay(date: date(2026, 11, 17))
        d.addPeriod(from: h(8, 0), to: h(9, 30))
        let s = snap([d], at(date(2026, 11, 17), 9, 30), true)
        let cols = TTWeekLayout.columns(s, monday: week47)
        suite.expect(cols[1].blocks.first?.running == true, "running: the last block runs")
        // The running day stays at zero until the target is reached.
        suite.expect(TTWeekLayout.weekSummary(s, monday: week47, cols, t) == "Woche: 1:30 h  ·  Pausen: 0:00 h  ·  Saldo +0:00 h",
                     "running: week summary")
        let next = date(2026, 11, 23)
        suite.expect(TTWeekLayout.weekSummary(s, monday: next, TTWeekLayout.columns(s, monday: next), t) == "Woche: –",
                     "running: a future week")
    }

    // MARK: English

    private static func englishTexts(_ suite: TestSuite) {
        let en = TTWeekTexts.enUS
        suite.expect(TTWeekLayout.title(monday: date(2026, 11, 16), en) == "Week 47  ·  November 16 – 22, 2026",
                     "week in English: title")
        suite.expect(TTWeekLayout.title(monday: date(2025, 12, 29), en) == "Week 1  ·  December 29, 2025 – January 4, 2026",
                     "week in English: title across years")
        suite.expect(TTWeekLayout.dragLabel(.end, at: h(15, 55), before: h(17, 0), auto: nil, workDiff: -65 * 60, en)
                        == "End 15:55 · −1:05 h", "week in English: drag label")
        suite.expect(TTWeekLayout.spanText(TTSpan(h(13, 30), h(14, 0)), en) == "13:30 – 14:00 (30 min)",
                     "week in English: span")
        suite.expect(TTWeekLayout.spokenDay(date(2026, 11, 17), en) == "Tuesday, November 17", "week in English: spoken day")
        suite.expect(TTWeekLayout.headerTitle(date(2026, 11, 17), en) == "Tue 11-17"
                     && TTWeekLayout.headerTitle(date(2026, 11, 17), t) == "Di 17.11.", "week: header titles")
        let all = [TimeTrackingWeekStrings.enUS, .de].flatMap { strings in
            Mirror(reflecting: strings).children.compactMap { $0.value as? String }
        }
        suite.expect(!all.contains { $0.contains("\u{2014}") || $0.contains("...") || $0.isEmpty },
                     "week texts: no em dash, no three dots, none empty")
        for language in AppLanguage.allCases where language != .enUS {
            suite.expect(FeatureStrings.timeTrackingWeek(language).titleSameMonthFormat != TimeTrackingWeekStrings.enUS.titleSameMonthFormat,
                         "\(language.rawValue): the week view is translated")
        }
    }
}
