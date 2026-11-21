// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import CoreGraphics
import Foundation
import IOKit.pwr_mgt

/// The menu bar of Time Tracking: the tests of Tagwerk's `menubar.rs` and
/// `glyphs.rs` (without the `#[ignore]`d rendering ones), the rules for which
/// action shows, the status lines, the question after a long lock, the
/// notifications and the shortcut roles.
enum TimeTrackingMenuTests {
    static func run(_ suite: TestSuite) {
        // menubar.rs
        pauseTitlesFollowShownMinutes(suite)
        idleQueriesAnswer(suite)
        idleStatusNamesTheLastInput(suite)
        barTimeIsCompact(suite)
        countPauseTagsRoundTrip(suite)
        dbErrorTextFitsOneMenuLine(suite)
        awayOutsideFrameShowsOutside(suite)
        // glyphs.rs
        boundsAreFiniteAndShapesFitTheirHeight(suite)
        widthsStayModerate(suite)
        // Barforge
        glyphInksFollowTheState(suite)
        statusLines(suite)
        actionsOnAWorkday(suite)
        actionsOnAFreeDay(suite)
        actionsAfterTheEndOfWorkAndWhenAbsent(suite)
        timeChoicesAreClamped(suite)
        lockQuestionConditions(suite)
        lockAnswersAndCategory(suite)
        notices(suite)
        remindersComeOncePerThreshold(suite)
        snapshotCarriesTheMenu(suite)
        shortcutsAndPreferences(suite)
    }

    static func dt(_ d: Int, _ hh: Int, _ mm: Int) -> TTDateTime { TimeTrackingTrackerTests.dt(d, hh, mm) }
    static func date(_ d: Int) -> TTDate { TimeTrackingTrackerTests.date(d) }
    static func hm(_ hh: Int, _ mm: Int) -> Int { hh * 3600 + mm * 60 }
    static let de = TimeTrackingTexts.de
    static let menuDE = TimeTrackingMenuTexts.de

    static func tracker(_ settings: TTSettings = TTSettings()) -> TTTracker {
        TTTracker(days: [], settings: settings, texts: de)
    }

    static func status(_ t: TTTracker, _ now: TTDateTime) -> TTStatusLine {
        TTMenu.statusLine(t, now: now, texts: de, menu: menuDE)
    }

    static func actions(_ t: TTTracker, _ now: TTDateTime) -> TTMenuActions {
        TTMenu.model(t, now: now, texts: de, menu: menuDE).actions
    }

    // MARK: menubar.rs

    private static func pauseTitlesFollowShownMinutes(_ suite: TestSuite) {
        let hms = { (h: Int, m: Int, s: Int) in h * 3600 + m * 60 + s }
        // 15:25:40 – 15:45:10 shows 15:25 – 15:45 and so 20 min (not 19).
        suite.expect(TTMenu.pauseTitle(TTSpan(hms(15, 25, 40), hms(15, 45, 10)), texts: de, menu: menuDE)
                        == "15:25 – 15:45 Uhr  (20 Min.)", "menu: a break's length follows the shown minutes")
        suite.expect(TTMenu.pauseTitle(TTSpan(hms(12, 0, 0), hms(13, 5, 0)), texts: de, menu: menuDE)
                        == "12:00 – 13:05 Uhr  (1:05 h)", "menu: an hour or more shows hours")
        suite.expect(TTMenu.pauseTitle(TTSpan(hms(12, 0, 0), hms(12, 20, 0)), texts: .enUS, menu: .enUS)
                        == "12:00 – 12:20  (20 min)", "menu: the English break title")
    }

    private static func idleQueriesAnswer(_ suite: TestSuite) {
        // Only that the queries to macOS answer (the values depend on the Mac).
        let raw = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        suite.expect(TimeTrackingSystemState.seconds(sinceInput: raw) >= 0, "menu: the idle query answers")
        var status: Unmanaged<CFDictionary>?
        let answered = IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess
        let assertions = status?.takeRetainedValue() as? [String: Any]
        _ = TimeTrackingSystemState.displayKeptAwake(assertions: assertions)
        suite.expect(answered, "menu: the power assertion query answers")
    }

    private static func idleStatusNamesTheLastInput(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(18, 8, 0))
        t.goIdle(lastInput: dt(18, 10, 0))
        let line = status(t, dt(18, 10, 12))
        suite.expect(line.kind == .paused, "menu: idle shows as paused")
        suite.expect(line.text == "Keine Eingabe seit 10:00 Uhr – pausiert", "menu: idle names the last input")
    }

    private static func barTimeIsCompact(_ suite: TestSuite) {
        suite.expect(TTMenu.barTime(0) == "0:00", "bar time: zero")
        suite.expect(TTMenu.barTime(6 * 3600 + 12 * 60 + 59) == "6:12", "bar time: minutes cut, not rounded")
        suite.expect(TTMenu.barTime(10 * 3600 + 5 * 60) == "10:05", "bar time: two-digit hours")
    }

    private static func countPauseTagsRoundTrip(_ suite: TestSuite) {
        for activity in TTActivity.all {
            for from in [0, 12 * 3600 + 3 * 60 + 17, TTLimits.dayEnd - 1] {
                let back = TTMenu.countPause(fromTag: TTMenu.countPauseTag(from: from, activity: activity))
                suite.expect(back.from == from && back.activity == activity,
                             "menu: the count-pause tag keeps \(from) and \(activity)")
            }
        }
    }

    private static func dbErrorTextFitsOneMenuLine(_ suite: TestSuite) {
        suite.expect(TTMenu.dbErrorText(what: "Speichern fehlgeschlagen", detail: "database is locked")
                        == "Speichern fehlgeschlagen: database is locked", "db error: short text as is")
        let long = TTMenu.dbErrorText(what: "Speichern fehlgeschlagen",
                                      detail: String(repeating: "disk I/O error\n ", count: 20))
        suite.expect(long.count == TTMenu.dbErrorMax, "db error: cut to one menu line (\(long.count))")
        suite.expect(long.hasSuffix("…") && !long.contains("\n"), "db error: one line ending in … (\(long))")
    }

    private static func awayOutsideFrameShowsOutside(_ suite: TestSuite) {
        var t = tracker()
        suite.expect(t.goAway(dt(18, 6, 9), activity: .other), "away: before the frame")
        var line = status(t, dt(18, 6, 30))
        suite.expect(line.kind == .outside, "away: outside the frame shows as outside")
        suite.expect(line.text == "Ohne Mac seit 06:09 Uhr – außerhalb des Arbeitszeitrahmens",
                     "away: outside the frame (\(line.text))")
        // From the start of the frame it counts: green like running.
        line = status(t, dt(18, 7, 5))
        suite.expect(line.kind == .away, "away: within the frame")
        suite.expect(line.text == "Ohne Mac seit 06:09 Uhr", "away: within the frame (\(line.text))")
        suite.expect(line.kind.glyph == .running && TTIconKind.outside.glyph == .outside,
                     "away: the glyph counts like running")
    }

    // MARK: glyphs.rs

    private static func boundsAreFiniteAndShapesFitTheirHeight(_ suite: TestSuite) {
        for set in TTIconSet.allCases {
            let (lo, hi) = TTGlyphs.bounds(set)
            let (w, h) = (hi.x - lo.x, hi.y - lo.y)
            suite.expect(w > 0 && h > 0 && w.isFinite && h.isFinite, "glyphs: \(set) has an extent")
            // Aspect ratios as designed: the arc wide, the lock high, the ring round.
            let ratio = w / h
            switch set {
            case .tagbogen: suite.expect((1.8..<2.4).contains(ratio), "glyphs: the arc is wide (\(ratio))")
            case .schlossuhr: suite.expect((0.5..<0.8).contains(ratio), "glyphs: the lock is high (\(ratio))")
            case .tagesring: suite.expect(abs(ratio - 1) < 1e-6, "glyphs: the ring is round (\(ratio))")
            default: suite.expect((0.6..<1.6).contains(ratio), "glyphs: \(set) is compact (\(ratio))")
            }
        }
    }

    private static func widthsStayModerate(_ suite: TestSuite) {
        // At 18 pt no set is wider than a typical wide system symbol.
        for set in TTIconSet.allCases {
            suite.expect(TTGlyphs.width(set, size: 18) <= 28, "glyphs: \(set) at 18 pt is \(TTGlyphs.width(set, size: 18))")
        }
    }

    // MARK: Barforge

    private static func glyphInksFollowTheState(_ suite: TestSuite) {
        for set in TTIconSet.allCases {
            for state in TTGlyphState.allCases {
                let inks = TTGlyphs.ops(set, state).map(\.ink)
                let accent = inks.contains { if case .accent = $0 { return true } else { return false } }
                suite.expect(!inks.isEmpty, "glyphs: \(set) draws \(state)")
                suite.expect(accent == state.hasAccent && (inks.contains(.white) ? state.hasAccent : true),
                             "glyphs: \(set) \(state) is \(state.hasAccent ? "coloured" : "a template")")
            }
            let layout = TTGlyphs.layout(set, size: 18)
            suite.expect(layout.height == (18 * max(TTGlyphs.optical(set), 1)).rounded(.up),
                         "glyphs: \(set) is as high as the symbol, higher only when it must be")
        }
        suite.expect(TTIconKind.allCases.map(\.glyph)
                        == [.running, .running, .onBreak, .onBreak, .outside, .closed, .closed],
                     "glyphs: every state maps to Tagwerk's glyph")
    }

    private static func statusLines(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(18, 8, 0))
        suite.expect(status(t, dt(18, 9, 0)) == TTStatusLine(text: "Zeiterfassung läuft", kind: .running),
                     "status: running")
        suite.expect(TTMenu.statusLine(t, now: dt(18, 9, 0), texts: .enUS, menu: .enUS).text == "Recording",
                     "status: running in English")
        t.takeBreak(dt(18, 12, 3))
        suite.expect(status(t, dt(18, 12, 10)) == TTStatusLine(text: "Pause seit 12:03 Uhr (zählt ab 15 Min.)",
                                                               kind: .onBreak), "status: a break not yet counted")
        suite.expect(status(t, dt(18, 12, 30)).text == "Pause seit 12:03 Uhr", "status: a break")
        suite.expect(TTMenu.statusLine(t, now: dt(18, 12, 30), texts: .enUS, menu: .enUS).text
                        == "On a break since 12:03", "status: a break in English")
        t.start(dt(18, 13, 0))
        t.stop(dt(18, 14, 0), reason: .locked)
        suite.expect(status(t, dt(18, 14, 5)) == TTStatusLine(text: "Zeiterfassung pausiert seit 14:00 Uhr",
                                                              kind: .paused), "status: paused since")
        t.goAway(dt(18, 14, 10), activity: .meeting)
        suite.expect(status(t, dt(18, 15, 0)) == TTStatusLine(text: "Ohne Mac seit 14:10 Uhr – Meeting",
                                                              kind: .away), "status: away with its note")
        suite.expect(status(t, dt(18, 23, 0)).kind == .outside, "status: away after the frame")
        _ = t.closeDay(dt(18, 17, 30), at: hm(17, 30))
        suite.expect(status(t, dt(18, 17, 40)) == TTStatusLine(text: "Feierabend um 17:30 Uhr", kind: .closed),
                     "status: end of work")

        // A break from yesterday names the day.
        var b = tracker()
        b.restoreBreak(since: dt(17, 21, 0))
        suite.expect(TTMenu.breakText(since: dt(17, 21, 0), now: dt(18, 7, 30), minPause: 15 * 60, menu: menuDE)
                        == "Pause seit 17.11. 21:00 Uhr", "status: a break since yesterday")
        suite.expect(TTMenu.breakText(since: dt(17, 21, 0), now: dt(18, 7, 30), minPause: 15 * 60, menu: .enUS)
                        == "On a break since 11/17 21:00", "status: a break since yesterday in English")

        var outside = tracker()
        outside.start(dt(18, 22, 30))
        suite.expect(status(outside, dt(18, 23, 0)) == TTStatusLine(
                        text: "Außerhalb des Arbeitszeitrahmens (07:00–22:00 Uhr)", kind: .outside),
                     "status: outside the frame")

        var free = tracker()
        free.start(dt(21, 10, 0))
        suite.expect(status(free, dt(21, 11, 0)) == TTStatusLine(text: "Freier Tag – Erfassung zählt nicht",
                                                                 kind: .outside), "status: a free day")
        var day = TTDay(date: date(19))
        day.absence = TTAbsence(.vacation, half: false)
        let absent = TTTracker(days: [day], settings: TTSettings(), texts: de)
        suite.expect(status(absent, dt(19, 9, 0)) == TTStatusLine(text: "Heute abwesend: Urlaub", kind: .absent),
                     "status: absent today")
        suite.expect(TTStatusTone(.away) == .running && TTStatusTone(.paused) == .onBreak
                        && TTStatusTone(.outside) == .neutral && TTStatusTone(.absent) == .absent,
                     "status: colours as in Tagwerk")
        suite.expect(TTMenu.isMinus(-60) && !TTMenu.isMinus(-59) && !TTMenu.isMinus(0),
                     "balance: under a minute counts as even")
    }

    private static func actionsOnAWorkday(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(18, 6, 30))
        var a = actions(t, dt(18, 6, 45))
        suite.expect(!a.countDay && a.pause && a.pauseAction == .pause && a.away && !a.countPause && a.start
                        && !a.close && !a.reopen, "actions: before the frame there is no end of work")
        a = actions(t, dt(18, 9, 0))
        suite.expect(a.close && !a.startReset, "actions: within the frame the day can end")
        t.stop(dt(18, 12, 0), reason: .locked)
        t.start(dt(18, 12, 40))
        a = actions(t, dt(18, 13, 0))
        suite.expect(a.countPause, "actions: a break today can count as work")
        t.takeBreak(dt(18, 14, 0))
        a = actions(t, dt(18, 14, 5))
        suite.expect(a.pause && a.pauseAction == .resume && a.away, "actions: on a break, resume")
        t.goAway(dt(18, 14, 10), activity: .call)
        a = actions(t, dt(18, 14, 20))
        suite.expect(a.pause && a.pauseAction == .backAtMac && !a.away, "actions: away, back at the Mac")
        t.start(dt(18, 15, 0))
        _ = t.setStart(dt(18, 15, 0), at: hm(6, 0))
        a = actions(t, dt(18, 15, 5))
        suite.expect(a.startReset && a.startResetUnlock == hm(7, 0),
                     "actions: a manual start offers the first unlock in the frame")
        suite.expect(TTMenu.startResetTitle(unlock: a.startResetUnlock, menu: menuDE)
                        == "Erstes Entsperren verwenden  (07:00 Uhr)"
                        && TTMenu.startResetTitle(unlock: nil, menu: menuDE) == "Manuellen Beginn entfernen",
                     "actions: the title of the start reset")
        suite.expect(TTMenu.relativeTitle(minutes: 0, now: hm(9, 12), menu: menuDE) == "Jetzt  (09:12 Uhr)"
                        && TTMenu.relativeTitle(minutes: 15, now: hm(9, 12), menu: menuDE)
                        == "Vor 15 Min.  (08:57 Uhr)"
                        && TTMenu.relativeTitle(minutes: 30, now: hm(9, 12), menu: .enUS) == "30 min ago  (08:42)",
                     "actions: the relative times")
        suite.expect(TTMenu.relativeTime(minutes: 30, now: hm(0, 10)) == 0, "actions: never before midnight")
    }

    private static func actionsOnAFreeDay(_ suite: TestSuite) {
        // Saturday: recorded, but only counted after "Record today".
        var t = tracker()
        t.start(dt(21, 10, 0))
        var a = actions(t, dt(21, 11, 0))
        suite.expect(a.countDay && !a.countDayChecked && !a.pause && !a.away && !a.countPause && !a.start
                        && !a.close && !a.reopen, "free day: only \"Record today\" until it counts")
        t.setCounting(date(21), on: true)
        a = actions(t, dt(21, 11, 0))
        suite.expect(a.countDay && a.countDayChecked && a.pause && a.away && a.start && a.close,
                     "free day: everything once it counts")
        // What runs can always be ended, even when the day stopped counting.
        t.takeBreak(dt(21, 12, 0))
        t.setCounting(date(21), on: false)
        a = actions(t, dt(21, 12, 5))
        suite.expect(a.pause && a.pauseAction == .resume && !a.away && !a.start,
                     "free day: a running break can still be ended")
        // A workday has no "Record today".
        var w = tracker()
        w.start(dt(18, 9, 0))
        suite.expect(!actions(w, dt(18, 10, 0)).countDay, "workday: no \"Record today\"")
    }

    private static func actionsAfterTheEndOfWorkAndWhenAbsent(_ suite: TestSuite) {
        var t = tracker()
        t.start(dt(18, 8, 0))
        _ = t.closeDay(dt(18, 17, 0), at: hm(17, 0))
        let a = actions(t, dt(18, 17, 5))
        suite.expect(!a.pause && !a.away && !a.close && a.reopen && a.start && !a.countDay,
                     "closed: only the start and taking the end back")
        var day = TTDay(date: date(19))
        day.absence = TTAbsence(.sick, half: false)
        let absent = TTTracker(days: [day], settings: TTSettings(), texts: de)
        let b = actions(absent, dt(19, 10, 0))
        suite.expect(b == TTMenuActions(pauseAction: .resume), "absent: nothing to control")
    }

    private static func timeChoicesAreClamped(_ suite: TestSuite) {
        // Midnight to now by default; the initial time within.
        var c = TTTimeChoice(now: hm(10, 0), initial: nil, earliest: nil, latest: nil)
        suite.expect(c.earliest == 0 && c.latest == hm(10, 0) && c.initial == hm(10, 0), "time: midnight to now")
        // The start before an end of work at 17:00 (latest 16:59), opened on the first start.
        c = TTTimeChoice(now: hm(18, 0), initial: hm(8, 0), earliest: nil, latest: hm(17, 0) - 60)
        suite.expect(c.latest == hm(16, 59) && c.initial == hm(8, 0), "time: the start before the end")
        // The end after a manual start at 9:00.
        c = TTTimeChoice(now: hm(18, 0), initial: nil, earliest: hm(9, 0) + 60, latest: nil)
        suite.expect(c.earliest == hm(9, 1) && c.initial == hm(18, 0), "time: the end after the start")
        // A limit that leaves nothing falls back to midnight to now.
        c = TTTimeChoice(now: hm(6, 0), initial: nil, earliest: hm(7, 1), latest: nil)
        suite.expect(c.earliest == 6 * 3600 && c.latest == hm(6, 0),
                     "time: an earliest time after now is now")
        c = TTTimeChoice(now: hm(6, 0), initial: hm(5, 0), earliest: hm(5, 30), latest: hm(5, 0))
        suite.expect(c.earliest == 0 && c.latest == hm(6, 0) && c.initial == hm(5, 0),
                     "time: crossed limits fall back to midnight to now")
        suite.expect(c.clamp(hm(23, 0), now: hm(6, 0)) == hm(6, 0), "time: never in the future")

        let model = TTMenu.model({
            var t = tracker()
            t.start(dt(18, 8, 0))
            _ = t.closeDay(dt(18, 17, 30), at: hm(17, 0))
            return t
        }(), now: dt(18, 17, 30), texts: de, menu: menuDE)
        suite.expect(model.startChoice.latest == hm(16, 59) && model.startChoice.initial == hm(8, 0),
                     "time: the start choice follows the day")
        suite.expect(model.endChoice.earliest == hm(7, 1), "time: the end of work lies after the frame begins")
    }

    private static func lockQuestionConditions(_ suite: TestSuite) {
        func locked(_ settings: TTSettings, from: TTDateTime, to: TTDateTime, start: TTDateTime? = nil,
                    prepare: (inout TTTracker) -> Void = { _ in }) -> TTLockQuestion? {
            var t = TTTracker(days: [], settings: settings, texts: de)
            t.start(start ?? from.adding(seconds: -3600))
            prepare(&t)
            t.stop(from, reason: .locked)
            t.start(to)
            return TTLockQuestion.ask(t, from: from, to: to)
        }
        var on = TTSettings()
        on.askAfterLock = true
        suite.expect(locked(TTSettings(), from: dt(18, 12, 0), to: dt(18, 12, 40)) == nil,
                     "lock question: off by default")
        suite.expect(locked(on, from: dt(18, 12, 0), to: dt(18, 12, 40))
                        == TTLockQuestion(date: date(18), from: hm(12, 0), to: hm(12, 40)),
                     "lock question: a lock of 40 min asks")
        suite.expect(locked(on, from: dt(18, 12, 0), to: dt(18, 12, 30)) != nil, "lock question: from 30 min on")
        suite.expect(locked(on, from: dt(18, 12, 0), to: dt(18, 12, 29)) == nil, "lock question: not under 30 min")
        let longBreak = on.withRules(TTWorkRules(minPause: 45 * 60))
        suite.expect(locked(longBreak, from: dt(18, 12, 0), to: dt(18, 12, 40)) == nil
                        && locked(longBreak, from: dt(18, 12, 0), to: dt(18, 12, 45)) != nil,
                     "lock question: never shorter than the minimum break")
        suite.expect(locked(on, from: dt(17, 21, 30), to: dt(18, 8, 0)) == nil, "lock question: not over night")
        suite.expect(locked(on, from: dt(18, 6, 0), to: dt(18, 7, 30), start: dt(18, 5, 0)) == nil,
                     "lock question: not for a lock that began before the frame")
        suite.expect(locked(on, from: dt(21, 12, 0), to: dt(21, 12, 40)) == nil,
                     "lock question: not on a free day that does not count")
        suite.expect(locked(on, from: dt(21, 12, 0), to: dt(21, 12, 40)) { $0.setCounting(date(21), on: true) }
                        != nil, "lock question: on a free day that counts")
        // After the end of work nothing counts: no question.
        var t = TTTracker(days: [], settings: on, texts: de)
        t.start(dt(18, 8, 0))
        t.stop(dt(18, 16, 0), reason: .locked)
        _ = t.closeDay(dt(18, 16, 0), at: hm(16, 0))
        t.start(dt(18, 17, 0))
        suite.expect(TTLockQuestion.ask(t, from: dt(18, 16, 0), to: dt(18, 17, 0)) == nil,
                     "lock question: not after the end of work")
    }

    private static func lockAnswersAndCategory(_ suite: TestSuite) {
        let ids = TTLockAnswer.all.map(\.actionIdentifier)
        suite.expect(ids == ["timeTracking.work-meeting", "timeTracking.work-call", "timeTracking.work-networking",
                             "timeTracking.work-other", "timeTracking.close-day"],
                     "lock answers: Tagwerk's five buttons, prefixed")
        suite.expect(TTLockAnswer.all.allSatisfy { TTLockAnswer(actionIdentifier: $0.actionIdentifier) == $0 }
                        && TTLockAnswer(actionIdentifier: "com.apple.UNNotificationDefaultActionIdentifier") == nil,
                     "lock answers: read back, a click on the notification is no answer")
        suite.expect(TTLockAnswer.all.map { $0.title(de, menuDE) }
                        == ["Meeting", "Telefonat", "Networking", "Sonstige Arbeit", "Feierabend"],
                     "lock answers: German titles")
        suite.expect(TTLockQuestion.categoryIdentifier == "timeTracking.lock-ask", "lock question: the category")
        let question = TTLockQuestion(date: date(18), from: hm(12, 0), to: hm(12, 40))
        let notice = question.notice(texts: de, menu: menuDE)
        suite.expect(notice.id == "timeTracking.lock-ask" && notice.title == "Gesperrt von 12:00 – 12:40 Uhr  (40 Min.)"
                        && notice.body == "Das zählt als Pause. War es Arbeit ohne Mac oder schon Feierabend?",
                     "lock question: Tagwerk's text (\(notice.title))")
        let info = question.userInfo as [AnyHashable: Any]
        suite.expect(TTLockQuestion(userInfo: info) == question, "lock question: survives in the notification")
        suite.expect(TTLockQuestion(userInfo: [:]) == nil
                        && TTLockQuestion(userInfo: ["timeTracking.lockDate": "2026-11-18", "timeTracking.lockFrom": 5,
                                                     "timeTracking.lockTo": 4]) == nil,
                     "lock question: nothing or nonsense is no question")
    }

    private static func notices(_ suite: TestSuite) {
        suite.expect(TTNotice.limit(.soon, de).id == "timeTracking.max-hours-soon"
                        && TTNotice.limit(.reached, de).id == "timeTracking.max-hours-reached"
                        && TTNotice.breakReminder(.soon, de).id == "timeTracking.break-soon"
                        && TTNotice.breakReminder(.reached, de).id == "timeTracking.break-reached",
                     "notices: Tagwerk's reminder ids, prefixed")
        suite.expect(TTNotice.limit(.soon, de).title == "Noch 15 Min. bis 10 Std. Arbeitszeit",
                     "notices: the reminder texts come from the rules")
        let refused = TTNotice.entryRefused(start: false, .endBeforeFrame(hm(7, 0)), texts: de, menu: menuDE)
        suite.expect(refused.id == "timeTracking.entry-refused" && refused.title == "Kein Feierabend eingetragen"
                        && refused.body.hasPrefix("Vor 07:00 Uhr zählt heute noch nichts"),
                     "notices: a refused end of work")
        suite.expect(TTNotice.entryRefused(start: true, .startNotBeforeEnd(hm(17, 0)), texts: de, menu: menuDE).title
                        == "Arbeitsbeginn nicht geändert", "notices: a refused start")
        let blocks = [TTWorkBlock(from: hm(6, 0), to: hm(7, 0), note: "Meeting"),
                      TTWorkBlock(from: hm(7, 30), to: hm(8, 0), note: "")]
        let cut = TTNotice.workCut(blocks, beforeStart: true, texts: de, menu: menuDE)
        suite.expect(cut?.id == "timeTracking.work-cut" && cut?.title == "Arbeit ohne Mac entfällt"
                        && cut?.body == "Meeting 06:00–07:00, Arbeit ohne Mac 07:30–08:00 lag vor dem Arbeitsbeginn "
                        + "und zählt nicht mehr – die letzte Angabe gilt.",
                     "notices: cut work names what went (\(cut?.body ?? ""))")
        suite.expect(TTNotice.workCut([], beforeStart: false, texts: de, menu: menuDE) == nil,
                     "notices: nothing cut, nothing said")
        let forgotten = TTNotice.forgottenAway(
            TTForgottenAway(date: date(17), block: TTWorkBlock(from: hm(16, 0), to: hm(22, 0), note: "Networking")),
            texts: de, menu: menuDE)
        suite.expect(forgotten.id == "timeTracking.away-forgotten" && forgotten.title == "„Zurück am Mac“ vergessen?"
                        && forgotten.body.hasPrefix("Am 17.11.2026 lief „Ohne Mac weiterarbeiten“ bis zum Ende des "
                                                    + "Arbeitszeitrahmens weiter: Networking 16:00–22:00."),
                     "notices: a forgotten Back at the Mac (\(forgotten.body))")
        let db = TTNotice.databaseError(.write, detail: "disk full", title: "Arbeitszeiterfassung", menu: menuDE)
        suite.expect(db.id == "timeTracking.db-error" && db.title == "Arbeitszeiterfassung: Speichern fehlgeschlagen"
                        && db.body == "disk full. Die Arbeitszeit wird weiter gezählt, aber erst gesichert, "
                        + "wenn das Speichern wieder gelingt.", "notices: a database error")
        suite.expect(TTNotice.isTimeTracking(db.id) && !TTNotice.isTimeTracking("3F2504E0-4F89-11D3-9A0C-0305E82C3301"),
                     "notices: Time Tracking's notifications are told apart")
        suite.expect(TTMenu.tooltip(kind: .outside, status: .freeDay, workSecs: hm(1, 5), pauseSecs: 0, error: nil,
                                    title: "Arbeitszeiterfassung", menu: menuDE)
                        == "Arbeitszeiterfassung – freier Tag, Erfassung zählt nicht\nHeute gearbeitet: 1:05 h\nPausen: 0:00 h",
                     "tooltip: state, working time and breaks")
        suite.expect(TTMenu.tooltip(kind: .running, status: .running, workSecs: 0, pauseSecs: 0, error: "Fehler",
                                    title: "T", menu: menuDE).hasSuffix("\nFehler"), "tooltip: with the error")
    }

    private static func remindersComeOncePerThreshold(_ suite: TestSuite) {
        let s = TTSettings()
        // At startup already past 9:45: not reported.
        var r = TTReminders(date: date(18), work: hm(9, 50), stretch: 0)
        suite.expect(r.update(date: date(18), work: hm(9, 55), stretch: 0, working: true, settings: s, texts: de)
                        .isEmpty, "reminders: what was reached at the start stays quiet")
        suite.expect(r.update(date: date(18), work: hm(10, 0), stretch: 0, working: true, settings: s, texts: de)
                        .map(\.id) == ["timeTracking.max-hours-reached"], "reminders: 10 h reached")
        suite.expect(r.update(date: date(18), work: hm(10, 5), stretch: 0, working: true, settings: s, texts: de)
                        .isEmpty, "reminders: once per threshold")
        // Switched off: nothing comes, but the watch follows.
        var quiet = s
        quiet.notifyBreak = false
        r = TTReminders(date: date(18), work: 0, stretch: 0)
        suite.expect(r.update(date: date(18), work: hm(5, 50), stretch: hm(5, 50), working: true, settings: quiet,
                              texts: de).isEmpty, "reminders: a break reminder switched off")
        suite.expect(r.update(date: date(18), work: hm(6, 0), stretch: hm(6, 0), working: true, settings: s,
                              texts: de).map(\.id) == ["timeTracking.break-reached"],
                     "reminders: switched on later, only the next threshold comes")
        // Entered afterwards (not while working): no reminder.
        r = TTReminders(date: date(18), work: 0, stretch: 0)
        suite.expect(r.update(date: date(18), work: hm(9, 50), stretch: 0, working: false, settings: s, texts: de)
                        .isEmpty, "reminders: none for time entered afterwards")
    }

    private static func snapshotCarriesTheMenu(_ suite: TestSuite) {
        TimeTrackingEngineTests.withRig(dt(18, 8, 0)) { rig in
            rig.clock.set(dt(18, 9, 0))
            let snapshot = rig.engine.snapshot()
            suite.expect(snapshot.date == date(18) && snapshot.menu.status.kind == .running
                            && snapshot.menu.status.text == "Recording" && snapshot.menu.actions.pause,
                         "snapshot: the menu of the moment")
            suite.expect(rig.engine.lockQuestion(from: dt(18, 8, 0), to: dt(18, 9, 0)) == nil,
                         "snapshot: no question while the setting is off")
        }
    }

    private static func shortcutsAndPreferences(_ suite: TestSuite) {
        let pause = GlobalShortcutRole.timeTrackingPause
        let records = GlobalShortcutRole.timeTrackingRecords
        suite.expect(pause.feature == .timeTracking && records.feature == .timeTracking,
                     "shortcuts: both belong to Time Tracking")
        suite.expect(pause.requiredEnableKeys == [DefaultsKey.timeTrackingEnabled, DefaultsKey.timeTrackingHotkeys]
                        && records.requiredEnableKeys == pause.requiredEnableKeys,
                     "shortcuts: Tagwerk's one switch, while recording is on")
        suite.expect(records.defaultShortcut == GlobalShortcut(keyCode: 0x00, modifiers: [.control, .option, .command]),
                     "shortcuts: ⌃⌥⌘A opens the records, as in Tagwerk")
        suite.expect(pause.defaultShortcut == .timeTrackingPauseDefault
                        && pause.defaultShortcut != .screenshotClipboardDefault,
                     "shortcuts: pausing keeps clear of the screenshot's ⌃⌥⌘P")
        let registered = Defaults.registeredDefaults
        suite.expect(registered[pause.storageKey] as? String == pause.defaultShortcut.storageValue
                        && registered[records.storageKey] as? String == records.defaultShortcut.storageValue
                        && registered[DefaultsKey.timeTrackingHotkeys] as? Bool == false,
                     "shortcuts: registered, off by default")
        suite.expect(registered[DefaultsKey.timeTrackingStatusItem] as? Bool == true
                        && registered[DefaultsKey.panelShowTimeTracking] as? Bool == true,
                     "menu bar: the own icon and the panel section are on by default")
        let exported = SettingsBackupSupport.exportKeys()
        suite.expect([DefaultsKey.timeTrackingStatusItem, pause.storageKey, records.storageKey].allSatisfy(exported.contains),
                     "menu bar: the new settings travel with backups")
        for language in AppLanguage.allCases {
            suite.expect(!FeatureStrings.timeTracking(language).panelDescription.isEmpty,
                         "\(language.rawValue): the panel section is described")
        }
    }
}
