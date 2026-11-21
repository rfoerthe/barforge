// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// The tests of Tagwerk's `settings_window.rs`, one function per `#[test]`,
/// plus the switch for the hints of the German Working Hours Act, "Restore
/// defaults", the notification permission and the English texts.
enum TimeTrackingSettingsTests {
    static func run(_ suite: TestSuite) {
        sheetExplainsWhatAChangeDoes(suite)
        sheetHintComparesBeforeAndAfter(suite)
        changedDaysMergeAndSplit(suite)
        frameEndMayBeMidnight(suite)
        askNoteFollowsTodaysRules(suite)
        resetNamesWhatChangesAndWhatStays(suite)
        dailyTargetShowsUnevenWeeks(suite)
        ruleRowsMarkTodayAndPlanned(suite)
        workStepperMovesOverRoundValues(suite)
        legalHintsSwitchSkipsTheWorkingHoursAct(suite)
        restoreDefaultsResetsEveryPreference(suite)
        deleteNamesTheRulesThatApplyAgain(suite)
        notificationPermission(suite)
        englishTexts(suite)
    }

    static func h(_ hh: Int, _ mm: Int) -> Int { hh * 3600 + mm * 60 }
    /// A day in November 2026 (the 16th is a Monday, the 21st a Saturday).
    static func date(_ day: Int) -> TTDate { TTDate(year: 2026, month: 11, day: day)! }
    static let de = TimeTrackingSettingsStrings.de
    static let texts = TimeTrackingTexts.de

    static func rules(weekly: Int? = nil, pause: Int? = nil, workdays: Int? = nil,
                      freeDaysCount: Bool = false) -> TTWorkRules {
        var r = TTWorkRules.default
        if let weekly { r.weeklyTarget = weekly }
        if let pause { r.minPause = pause }
        if let workdays { r.workdays = workdays }
        r.freeDaysCount = freeDaysCount
        return r
    }

    static func hint(_ s: TTSettings, _ editing: TTRulesEditing, _ from: TTDate?, _ draft: TTWorkRules,
                     today: TTDate = date(21)) -> (String, Bool) {
        let h = TTSettingsModel.sheetHint(s, editing: editing, from: from, draft: draft, today: today, de, texts)
        return (h.text, h.warn)
    }

    // MARK: settings_window.rs

    private static func sheetExplainsWhatAChangeDoes(_ suite: TestSuite) {
        var s = TTSettings()
        let d = TTWorkRules.default
        let part = rules(weekly: 32 * 3600)
        // New rules from today: no warning.
        suite.expect(hint(s, .new, date(21), part) == ("Gilt ab 21.11.2026.", false), "sheet: new rules from today")
        // Without a change.
        suite.expect(hint(s, .new, date(21), d) == ("Gleicht dem Stand davor – es ändert sich nichts.", false),
                     "sheet: nothing changes")
        // Retroactive: orange.
        let (text, warn) = hint(s, .new, date(2), part)
        suite.expect(warn && text.hasSuffix("Rückwirkend: Saldo und Aufzeichnungen ab dem 02.11.2026 ändern sich."),
                     "sheet: retroactive \(text)")
        // With later rules the new ones apply only until before them; the same day replaces them.
        s.setRules(from: date(30), part)
        suite.expect(hint(s, .new, date(23), rules(weekly: 35 * 3600)).0 == "Gilt vom 23.11.2026 bis 29.11.2026.",
                     "sheet: until before the next rules")
        let (replaced, replacedWarn) = hint(s, .new, date(30), d)
        suite.expect(replacedWarn, "sheet: replacing is orange")
        suite.expect(replaced == "Ersetzt den vorhandenen Stand ab 30.11.2026. Gleicht dem Stand davor und entfällt deshalb. "
                        + "Andere Regeln als bisher gelten ab dem 30.11.2026.", "sheet: replaces \(replaced)")
        // Editing the set itself replaces nothing.
        suite.expect(hint(s, .existing(date(30)), date(30), part).0 == "Gilt ab 30.11.2026.", "sheet: edit itself")
        // The first set applies until the next; unchanged it changes nothing, changed retroactively.
        suite.expect(hint(s, .existing(nil), nil, d) == ("Gilt für alle Tage vor dem 30.11.2026.", false),
                     "sheet: the first set")
        suite.expect(hint(s, .existing(nil), nil, rules(pause: 20 * 60))
                        == ("Gilt für alle Tage vor dem 30.11.2026. Rückwirkend: Saldo und Aufzeichnungen bis zum "
                            + "29.11.2026 ändern sich.", true),
                     "sheet: the first set changed")
    }

    private static func sheetHintComparesBeforeAndAfter(_ suite: TestSuite) {
        let d = TTWorkRules.default
        let part = rules(weekly: 32 * 3600)
        var s = TTSettings()
        s.setRules(from: date(2), part)
        // Moving past rules into the future: retroactive for the days between.
        let (text, warn) = hint(s, .existing(date(2)), date(25), part)
        suite.expect(text == "Gilt ab 25.11.2026. Rückwirkend: Saldo und Aufzeichnungen vom 02.11.2026 bis 24.11.2026 "
                        + "ändern sich.", "hint: moved later \(text)")
        suite.expect(warn, "hint: moved later is orange")
        // Moving back into the past: the days before.
        suite.expect(hint(s, .existing(date(2)), date(1), part).0
                        == "Gilt ab 01.11.2026. Rückwirkend: Saldo und Aufzeichnungen am 01.11.2026 ändern sich.",
                     "hint: moved earlier")
        // Planned rules move later: only future days change, no warning, but the days between are named.
        s = TTSettings()
        s.setRules(from: date(25), part)
        suite.expect(hint(s, .existing(date(25)), date(28), part)
                        == ("Gilt ab 28.11.2026. Andere Regeln als bisher gelten vom 25.11.2026 bis 27.11.2026.", false),
                     "hint: planned rules move later")
        // Past rules equal the ones before after the change and go: retroactive.
        s = TTSettings()
        s.setRules(from: date(2), part)
        suite.expect(hint(s, .existing(date(2)), date(2), d)
                        == ("Gleicht dem Stand davor und entfällt deshalb. Rückwirkend: Saldo und Aufzeichnungen ab dem "
                            + "02.11.2026 ändern sich.", true),
                     "hint: past rules dropped")
        // A draft equal to the rules after drops those: the set then applies without end,
        // but only the days until before them changed (no addition, they belong to the set).
        s.setRules(from: date(30), d)
        suite.expect(hint(s, .new, date(21), d) == ("Gilt ab 21.11.2026.", false), "hint: equal to the next")
        s = TTSettings()
        s.setRules(from: date(30), part)
        suite.expect(hint(s, .new, date(23), part).0 == "Gilt ab 23.11.2026.", "hint: the next merges")
    }

    private static func changedDaysMergeAndSplit(_ suite: TestSuite) {
        let part = rules(weekly: 32 * 3600)
        var before = TTSettings()
        before.setRules(from: date(2), part)
        before.setRules(from: date(10), rules(pause: 20 * 60))
        // Moving the set of 2 Nov to 20 Nov: 2–9 Nov default again, from 20 Nov "part".
        var after = before
        after.setRules(from: date(20), part, replaces: date(2))
        let changed = TTSettingsModel.changedDays(before, after)
        suite.expect(changed == [TTDaySpan(date(2), date(9)), TTDaySpan(date(20), nil)], "changed days: \(changed)")
        suite.expect(TTSettingsModel.spansText(changed, de, texts) == "vom 02.11.2026 bis 09.11.2026 und ab dem 20.11.2026",
                     "changed days: text")
        suite.expect(TTSettingsModel.changedDays(before, before).isEmpty, "changed days: none")
        var all = TTSettings()
        all.setRules(from: nil, part)
        suite.expect(TTSettingsModel.changedDays(TTSettings(), all) == [TTDaySpan(nil, nil)], "changed days: all")
        suite.expect(TTSettingsModel.spansText([TTDaySpan(nil, nil)], de, texts) == "aller Tage", "changed days: all text")
    }

    private static func frameEndMayBeMidnight(_ suite: TestSuite) {
        func frame(_ from: String, _ to: String) -> [Int]? {
            (try? TTSettingsModel.parseFrame(from, to).get()).map { [$0.from, $0.to] }
        }
        suite.expect(frame("07:00", "24:00") == [h(7, 0), TTLimits.dayEnd], "frame: until 24:00")
        suite.expect(frame("7.30", "22:00 Uhr") == [h(7, 30), h(22, 0)], "frame: dot and Uhr")
        // Seconds go.
        suite.expect(frame("07:00:30", "22:00") == [h(7, 0), h(22, 0)], "frame: seconds go")
        if case let .failure(error) = TTSettingsModel.parseFrame("07:00", "00:00") {
            suite.expect(error == .midnight && error.text(de).contains("24:00"), "frame: midnight as end is 24:00")
        } else {
            suite.expect(false, "frame: 00:00 as end is refused")
        }
        for (from, to) in [("22:00", "07:00"), ("24:00", "24:00"), ("7", "22:00"), ("07:00", "24:01")] {
            suite.expect(frame(from, to) == nil, "frame: \(from)–\(to) is refused")
        }
        // 24:00 shows as 24:00 again (a frame until midnight survives saving).
        var r = TTWorkRules.default
        r.frameTo = TTLimits.dayEnd
        r = r.sanitized
        suite.expect(r.frameTo == TTLimits.dayEnd && TTFormat.clock(r.frameTo) == "24:00", "frame: 24:00 stays")
    }

    private static func askNoteFollowsTodaysRules(_ suite: TestSuite) {
        let today = date(21)
        var s = TTSettings()
        let note = TTSettingsModel.askNote(s, today: today, de)
        suite.expect(note.hasPrefix("Ab 30 Min. Sperre fragt"), "ask note: \(note)")
        s.setRules(from: today, rules(pause: 45 * 60))
        suite.expect(TTSettingsModel.askNote(s, today: today, de)
                        .hasPrefix("Ab 45 Min. Sperre (so lang wie die Mindestpause) fragt"), "ask note: minimum break")
        suite.expect(TTSettingsModel.askNote(s, today: date(20), de).hasPrefix("Ab 30 Min. Sperre fragt"),
                     "ask note: the rules of the day")
        suite.expect(TTSettingsModel.askNote(s, today: today, de)
                        .contains("im Arbeitszeitrahmen begonnen hat und am selben Tag endet"), "ask note: conditions")
    }

    private static func resetNamesWhatChangesAndWhatStays(_ suite: TestSuite) {
        let today = date(21)
        let part = rules(weekly: 32 * 3600)
        var s = TTSettings()
        s.accountCarry = 12 * 3600 + 1800
        s.accountFrom = date(1)
        s.setRules(from: date(2), part)
        s.setRules(from: date(30), rules(weekly: 32 * 3600, pause: 20 * 60))
        let info = TTSettingsModel.resetInfo(s, today: today, de, texts)
        for part in [
            "Das Zeitkonto zählt danach alle erfassten Tage ohne Übertrag (bisher ab 01.11.2026, Übertrag +12:30).",
            "Ab heute (21.11.2026) gelten wieder die Standardregeln: 39 Std./Woche (Mo–Fr, 7:48 Std. pro Arbeitstag)",
            "Der geplante Stand ab 30.11.2026 entfällt.",
        ] {
            suite.expect(info.contains(part), "reset: \(part) in \(info)")
        }
        // Barforge: the recording switch stays instead of Tagwerk's "start at login".
        suite.expect(info.hasSuffix("Es bleiben „Arbeitszeit erfassen“, die Arbeitszeitregeln bis gestern und alle "
                                    + "Aufzeichnungen."), "reset: what stays \(info)")
        // What the text says, `withDefaults` does.
        let fresh = TTSettingsModel.withDefaults(s, today: today)
        suite.expect(fresh.accountFrom == nil && fresh.accountCarry == 0, "reset: the time account")
        suite.expect(fresh.rules(date(20)) == part, "reset: earlier days keep their rules")
        suite.expect(fresh.rules(today) == .default && fresh.rules(date(30)) == .default,
                     "reset: default rules from today, planned ones dropped")
        // Already the defaults: no sentence about the account, no planned rules.
        let plain = TTSettingsModel.resetInfo(TTSettings(), today: today, de, texts)
        suite.expect(plain.contains("Die Arbeitszeitregeln von heute sind schon die Standardwerte."), "reset: \(plain)")
        suite.expect(!plain.contains("Zeitkonto zählt danach") && !plain.contains("geplant"), "reset: \(plain)")
        // Two planned sets are named together.
        var two = s
        two.setRules(from: date(28), rules(weekly: 30 * 3600))
        suite.expect(TTSettingsModel.resetInfo(two, today: today, de, texts)
                        .contains("Die geplanten Stände ab 28.11.2026 und 30.11.2026 entfallen."), "reset: two planned")
    }

    private static func dailyTargetShowsUnevenWeeks(_ suite: TestSuite) {
        let r = rules(weekly: 38 * 3600 + 1800, workdays: 0b0_1111)
        let line = TTSettingsModel.rulesLine(r, de, texts)
        suite.expect(line.hasPrefix("38,5 Std./Woche (Mo, Di, Mi, Do, 9:37 bis 9:38 Std. pro Arbeitstag)"),
                     "rules line: \(line)")
        suite.expect(TTSettingsModel.dailyNote(r, de, texts) == "4-Tage-Woche  ·  9:37 bis 9:38 Std. pro Arbeitstag",
                     "daily note: uneven")
    }

    private static func ruleRowsMarkTodayAndPlanned(_ suite: TestSuite) {
        var s = TTSettings()
        s.setRules(from: date(2), rules(weekly: 38 * 3600))
        s.setRules(from: date(30), rules(workdays: 0b0_1111))
        let rows = TTSettingsModel.ruleRows(s, today: date(21), de, texts)
        let flags = rows.map { "\($0.cells[0])|\($0.current)|\($0.planned)" }
        suite.expect(flags == ["Beginn|false|false", "02.11.2026|true|false", "30.11.2026|false|true"],
                     "rule rows: \(flags)")
        suite.expect(Array(rows[1].cells.dropFirst()) == ["38 Std.", "Mo–Fr", "07:00–22:00", "15 Min.", "–"],
                     "rule rows: cells \(rows[1].cells)")
        suite.expect(TTSettingsModel.rulesNowText(s, today: date(21), de, texts)
                        == "Heute gilt der Stand ab 02.11.2026: 7:36 Std. pro Arbeitstag (5-Tage-Woche).\n"
                        + "Geplant ab 30.11.2026: 9:45 Std. pro Arbeitstag (4-Tage-Woche).", "rules now")
        // When work on days off counts, the column "Days off" says so.
        s.setRules(from: date(16), rules(freeDaysCount: true))
        suite.expect(TTSettingsModel.ruleRows(s, today: date(21), de, texts)[2].cells[5] == "im Saldo",
                     "rule rows: in balance")
        suite.expect(TTSettingsModel.rowTip(rows[0], de) == "Galt früher"
                        && TTSettingsModel.rowTip(rows[1], de) == "Gilt heute"
                        && TTSettingsModel.rowTip(rows[2], de) == "Geplant – gilt ab diesem Tag", "rule rows: tips")
        suite.expect(Set(rows.map(\.id)).count == rows.count, "rule rows: ids are unique")
    }

    private static func workStepperMovesOverRoundValues(_ suite: TestSuite) {
        let cases: [(old: Int, stepped: Int, expected: Int)] = [
            // down: 15 → 10 → 5 → 1 (the stepper stops at the lower bound)
            (15, 10, 10), (10, 5, 5), (5, 1, 1), (3, 1, 1), (1, 1, 1),
            // up: 1 → 5 → 10
            (1, 6, 5), (5, 10, 10),
            // from an odd value to the next round one
            (12, 17, 15), (12, 7, 10), (240, 240, 240),
        ]
        for c in cases {
            suite.expect(TTSettingsModel.stepMinutes(old: c.old, stepped: c.stepped) == c.expected,
                         "stepper: \(c.old) → \(c.stepped) gives \(c.expected)")
        }
    }

    // MARK: Barforge

    /// Plan E2: without the hints of the Working Hours Act there are no
    /// warnings about breaks, stretch, maximum hours and rest, and no
    /// reminders; the hints about days off and the frame stay.
    private static func legalHintsSwitchSkipsTheWorkingHoursAct(_ suite: TestSuite) {
        func day(_ d: Int, _ periods: [(Int, Int)]) -> TTDay {
            var day = TTDay(date: date(d))
            for (from, to) in periods { day.addPeriod(from: from, to: to) }
            return day
        }
        // Monday 11 h without a break and an hour outside the frame; Tuesday
        // starts 9 h after that hour; Saturday some work.
        let days = [day(16, [(h(7, 0), h(18, 0)), (h(22, 0), h(23, 0))]), day(17, [(h(8, 0), h(9, 0))]),
                    day(21, [(h(10, 0), h(11, 0))])]
        var s = TTSettings()
        func isLegal(_ w: TTWarning) -> Bool {
            switch w {
            case .breaks, .longStretch, .maxHours, .rest: return true
            case .outsideFrame, .weekend, .freeWeekday: return false
            }
        }
        let on = TTWarning.dayWarnings(days, date: date(16), settings: s)
        suite.expect(on.contains(where: isLegal) && on.contains { if case .outsideFrame = $0 { return true }; return false },
                     "legal hints on: \(on)")
        suite.expect(TTWarning.dayWarnings(days, date: date(17), settings: s).contains(where: isLegal),
                     "legal hints on: rest \(TTWarning.dayWarnings(days, date: date(17), settings: s))")
        s.legalHints = false
        let off = TTWarning.dayWarnings(days, date: date(16), settings: s)
        suite.expect(!off.contains(where: isLegal), "legal hints off: no Working Hours Act \(off)")
        suite.expect(off.contains { if case .outsideFrame = $0 { return true }; return false },
                     "legal hints off: outside the frame stays")
        suite.expect(TTWarning.dayWarnings(days, date: date(17), settings: s).isEmpty, "legal hints off: no rest")
        suite.expect(TTWarning.dayWarnings(days, date: date(21), settings: s) == [.weekend(counted: false)],
                     "legal hints off: the weekend stays")

        // Reminders: quiet without the hints, though switched on.
        var r = TTReminders(date: date(18), work: 0, stretch: 0)
        suite.expect(r.update(date: date(18), work: h(10, 0), stretch: h(6, 0), working: true, settings: s,
                              texts: .de).isEmpty, "legal hints off: no reminders")
        s.legalHints = true
        r = TTReminders(date: date(18), work: 0, stretch: 0)
        suite.expect(r.update(date: date(18), work: h(10, 0), stretch: h(6, 0), working: true, settings: s,
                              texts: .de).count == 2, "legal hints on: both reminders")

        // Notifications are only needed for the reminders while the hints are on.
        func notifies(_ values: [String: Bool]) -> Bool {
            AppFeature.activeFeatures(using: .notifications, isAvailable: { $0 == .timeTracking },
                                      boolFor: { values[$0] ?? false }, stringFor: { _ in nil })
                .contains(.timeTracking)
        }
        let recording = [DefaultsKey.timeTrackingEnabled: true, DefaultsKey.timeTrackingNotifyLimit: true,
                         DefaultsKey.timeTrackingNotifyBreak: true]
        suite.expect(!notifies(recording), "reminders without the legal hints need no notifications")
        suite.expect(notifies(recording.merging([DefaultsKey.timeTrackingLegalHints: true]) { $1 }),
                     "reminders with the legal hints need notifications")
        suite.expect(notifies([DefaultsKey.timeTrackingEnabled: true, DefaultsKey.timeTrackingAskAfterLock: true]),
                     "the lock question needs notifications without the legal hints too")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.timeTrackingLegalHints] as? Bool == true
                        && TTSettings().legalHints, "the legal hints are on by default")
    }

    private static func restoreDefaultsResetsEveryPreference(_ suite: TestSuite) {
        var s = TTSettings()
        s.minWork = 30 * 60
        s.iconSet = .roboter
        s.showTime = true
        s.hotkeys = true
        s.autoWorkdaysOnly = false
        s.idleSecs = 5 * 60
        s.askAfterLock = true
        s.notifyLimit = false
        s.notifyBreak = false
        s.legalHints = false
        s.accountCarry = -3 * 3600
        s.setRules(from: date(2), rules(weekly: 30 * 3600))
        let fresh = TTSettingsModel.withDefaults(s, today: date(21))
        var expected = TTSettings()
        expected.work = fresh.work
        suite.expect(fresh == expected, "restore defaults: every preference as at the beginning")
        suite.expect(fresh.work.map(\.from) == [nil, date(2), date(21)], "restore defaults: \(fresh.work)")
        // Default rules already today: nothing new is added.
        let plain = TTSettingsModel.withDefaults(TTSettings(), today: date(21))
        suite.expect(plain == TTSettings(), "restore defaults: defaults stay defaults")
        let info = TTSettingsModel.resetInfo(s, today: date(21), de, texts)
        suite.expect(info.contains("(bisher Übertrag \u{2212}3:00)"), "reset: a negative carry \(info)")
    }

    private static func deleteNamesTheRulesThatApplyAgain(_ suite: TestSuite) {
        var s = TTSettings()
        s.setRules(from: date(2), rules(weekly: 32 * 3600))
        s.setRules(from: date(30), rules(weekly: 30 * 3600))
        let past = TTSettingsModel.deleteInfo(s, from: date(2), today: date(21), de, texts)
        suite.expect(past.title == "Stand ab 02.11.2026 löschen?", "delete: \(past.title)")
        suite.expect(past.info == "Ab dem 02.11.2026 gilt dann wieder der Stand davor: 39 Std./Woche (Mo–Fr, 7:48 Std. "
                        + "pro Arbeitstag)  ·  Rahmen 07:00–22:00 Uhr  ·  Pausen ab 15 Min. Saldo und "
                        + "Aufzeichnungen ab dem 02.11.2026 ändern sich.", "delete: \(past.info)")
        let planned = TTSettingsModel.deleteInfo(s, from: date(30), today: date(21), de, texts)
        suite.expect(planned.info.hasPrefix("Ab dem 30.11.2026 gilt dann wieder der Stand davor: 32 Std./Woche")
                        && !planned.info.contains("ändern sich"), "delete planned: \(planned.info)")
    }

    private static func notificationPermission(_ suite: TestSuite) {
        typealias P = TTNotificationPermission
        suite.expect(P(authorized: nil, visible: true) == .notDetermined, "permission: not determined")
        suite.expect(P(authorized: false, visible: true) == .denied, "permission: denied")
        suite.expect(P(authorized: true, visible: false) == .hidden, "permission: hidden")
        suite.expect(P(authorized: true, visible: true) == .allowed, "permission: allowed")
        suite.expect([P.notDetermined, .denied, .hidden].allSatisfy(\.needsSettings)
                        && !P.allowed.needsSettings && !P.unavailable.needsSettings,
                     "permission: System Settings only when something is to change there")
        suite.expect(P.hidden.text(de) == "Ausgeblendet" && P.denied.note(de) == P.notDetermined.note(de),
                     "permission: Tagwerk's texts")
    }

    private static func englishTexts(_ suite: TestSuite) {
        let en = TimeTrackingSettingsStrings.enUS
        let texts = TimeTrackingTexts.enUS
        let part = rules(weekly: 32 * 3600)
        let h = TTSettingsModel.sheetHint(TTSettings(), editing: .new, from: date(2), draft: part, today: date(21),
                                          en, texts)
        suite.expect(h.text == "Applies from 2026-11-02. Retroactive: the balance and records change for the days "
                        + "from 2026-11-02.", "English hint: \(h.text)")
        suite.expect(TTSettingsModel.rulesLine(.default, en, texts)
                        == "39 h/week (Mon–Fri, 7:48 h per workday)  ·  working hours 07:00–22:00  ·  breaks from 15 min",
                     "English rules line: \(TTSettingsModel.rulesLine(.default, en, texts))")
        let spans = [TTDaySpan(nil, date(1)), TTDaySpan(date(5), date(5)), TTDaySpan(date(9), date(12))]
        suite.expect(TTSettingsModel.spansText(spans, en, texts)
                        == "the days until 2026-11-01, 2026-11-05 and 2026-11-09 to 2026-11-12", "English spans")
        suite.expect(FeatureStrings.timeTrackingSettings(.fr).statusItem == en.statusItem,
                     "other languages show English until they are translated")
    }
}
