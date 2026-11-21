// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// The tests of Tagwerk's `store.rs`, one function per `#[test]`, plus round
/// trips through the database, the preferences in UserDefaults and the
/// takeover from Tagwerk.
enum TimeTrackingStoreTests {
    static func run(_ suite: TestSuite) {
        // store.rs
        statusLineRoundTrip(suite)
        dbRoundtripAndPartialSave(suite)
        editDayAndExternalChange(suite)
        takeOverReplacesTheDataOnce(suite) // adapts imports_legacy_markdown_once
        exportRangeSumAndRoundtrip(suite)
        settingsRoundtripAndSchemaUpgrade(suite)
        workRulesGetTheFreeDaysColumn(suite)
        absencesSurviveDatabaseAndExport(suite)
        csvHasOneRowPerDay(suite)
        exportFormatsByName(suite)
        defaultRangeIs28Days(suite)
        legacyFileBecomesPeriods(suite)
        dailyBackupKeepsLast15(suite)
        freeDayCountingSurvivesDatabaseAndExport(suite)
        markdownAndCsvNameTheSameBalance(suite)
        staleFreeDayMarksAreDroppedOnLoad(suite)
        importSkipsWhatTheWindowWouldRefuse(suite)
        importBacksUpTheStateBefore(suite)
        // Barforge
        databaseFilesAreOwnerOnlyAndWAL(suite)
        newerSchemaIsRefused(suite)
        editDayRollsBackOnError(suite)
        loadRangeAndRemoval(suite)
        preferencesLiveInUserDefaults(suite)
        takeOverRefusesOtherSchemas(suite)
        englishExportReadsBack(suite)
        dateTimeArithmetic(suite)
    }

    static func h(_ hh: Int, _ mm: Int) -> Int { hh * 3600 + mm * 60 }
    /// A day in November 2026 (the 16th is a Monday).
    static func date(_ d: Int) -> TTDate { TTDate(year: 2026, month: 11, day: d)! }
    static func now() -> TTDateTime { TTDateTime(date(17), hour: 10, minute: 0) }
    static func st() -> TTSettings { TTSettings() }
    static let de = TimeTrackingTexts.de
    static let en = TimeTrackingTexts.enUS

    static func markdown(_ days: [TTDay], _ from: TTDate, _ to: TTDate, _ now: TTDateTime,
                         _ settings: TTSettings = TTSettings(), _ texts: TimeTrackingTexts = .de) -> String {
        TTExport.markdown(days, from: from, to: to, now: now, settings: settings, appName: "Tagwerk", texts)
    }

    static func report(_ days: [TTDay], _ from: TTDate, _ to: TTDate, _ today: TTDate,
                       _ settings: TTSettings = TTSettings(), _ texts: TimeTrackingTexts = .de) -> TTReport {
        TTReport(days, from: from, to: to, today: today, settings: settings, texts)
    }

    /// An empty folder of its own, removed afterwards; failures are recorded.
    static func withDirectory(_ suite: TestSuite, _ name: String, _ body: (URL) throws -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("timetracking-test-\(name)-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try body(dir)
        } catch {
            suite.expect(false, "\(name): \(error)")
        }
    }

    /// A UserDefaults suite of its own, removed afterwards.
    static func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suiteName = "com.vorssaint.tests.timetracking.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    static func open(_ dir: URL) throws -> TimeTrackingDatabase {
        try TimeTrackingDatabase(directory: dir, container: dir)
    }

    static func sampleDays() -> [TTDay] {
        var d = TTDay(date: date(16))
        d.addPeriod(from: h(8, 12), to: h(11, 58))
        d.addPeriod(from: h(12, 41), to: h(17, 30))
        d.start = h(8, 0)
        d.breaks.append(TTBreak(from: h(12, 0), to: h(12, 45)))
        d.end = h(17, 15)
        d.addWork(from: h(18, 0), to: h(18, 30), note: "Telefonat")
        var shortLock = TTDay(date: date(17))
        shortLock.addPeriod(from: h(8, 0), to: h(9, 30))
        shortLock.addPeriod(from: h(9, 40), to: h(10, 0)) // locked 10 min: counts as work
        return [d, shortLock]
    }

    // MARK: store.rs

    private static func statusLineRoundTrip(_ suite: TestSuite) {
        let since = TTDateTime(date(17), hour: 12, minute: 3, second: 9)
        for status: TTStatus in [.running, .paused, .onBreak(since: since), .away(since: since, activity: .meeting),
                                 .away(since: since, activity: .other), .outside, .freeDay, .closed, .absent] {
            suite.expect(TTStatus(line: status.line) == status, "status \(status.line) round trip")
        }
        suite.expect(TTStatus.onBreak(since: since).line == "break 2026-11-17T12:03:09", "break line")
        suite.expect(TTStatus.away(since: since, activity: .call).line == "away 2026-11-17T12:03:09 call", "away line")
        suite.expect(TTStatus(line: "away 2026-11-17T12:03:09") == .away(since: since, activity: .other),
                     "away without activity: other")
        suite.expect(TTStatus(line: "break") == nil, "break without time")
        suite.expect(TTStatus(line: "break\n") == nil, "break without time, newline")
        suite.expect(TTStatus(line: "paused\n") == .paused, "trailing newline")
    }

    private static func dbRoundtripAndPartialSave(_ suite: TestSuite) {
        withDirectory(suite, "roundtrip") { dir in
            let db = try open(dir)
            let days = sampleDays()
            try db.saveDays(days, removed: [], now: now())
            suite.expect(try db.load() == days, "days survive the database")
            suite.expect(try db.load(from: date(17), to: date(17)) == [days[1]], "range load")

            // Writing one day leaves the other alone.
            var changed = days[1]
            changed.end = h(9, 45)
            try db.saveDays([changed], removed: [], now: now())
            suite.expect(try db.load() == [days[0], changed], "partial save")

            // Removal and empty days.
            try db.saveDays([TTDay(date: date(17))], removed: [date(16)], now: now())
            suite.expect(try db.load().isEmpty, "removed and empty days are gone")
        }
    }

    private static func editDayAndExternalChange(_ suite: TestSuite) {
        withDirectory(suite, "edit") { dir in
            let a = try open(dir)
            let b = try open(dir)
            try a.saveDays(sampleDays(), removed: [], now: now())
            suite.expect(!a.changedExternally(), "an own change does not count")
            suite.expect(b.changedExternally(), "the other connection sees the change")
            try b.editDay(date(16), now: now()) { $0.breaks.removeAll() }
            suite.expect(a.changedExternally(), "edit_day is seen")
            suite.expect(try a.load()[0].breaks.isEmpty, "the edit is stored")
            suite.expect(!a.changedExternally(), "loading changes nothing")
        }
    }

    /// `imports_legacy_markdown_once` checked that Tagwerk takes over its old
    /// `tagwerk.md` once. Barforge does not import that file (plan §1); its
    /// counterpart is the takeover of Tagwerk's database, checked here: the
    /// days arrive, the preferences move, and a second takeover replaces the
    /// data (after a backup) instead of adding to it.
    private static func takeOverReplacesTheDataOnce(_ suite: TestSuite) {
        withDirectory(suite, "takeover") { dir in
            try withDefaults { defaults in
                let source = dir.appendingPathComponent("tagwerk", isDirectory: true)
                do {
                    let tagwerk = try open(source)
                    try tagwerk.saveDays(sampleDays(), removed: [], now: now())
                    var rules = st()
                    rules.setRules(from: date(2), TTWorkRules(weeklyTarget: h(30, 0)))
                    rules.accountCarry = h(2, 0)
                    try tagwerk.saveSettings(rules, today: date(17))
                    try tagwerk.connection.run("INSERT INTO settings (key, value) VALUES ('icon_set', 2), ('idle_s', 300), ('notify_break', 0)")
                }
                let sourceFile = source.appendingPathComponent(TimeTrackingDatabase.fileName)
                let db = try open(dir.appendingPathComponent("barforge", isDirectory: true))
                let first = try TimeTrackingTagwerkImport.takeOver(from: sourceFile, into: db, defaults: defaults, now: now())
                suite.expect(first.days == 2 && first.backup == nil, "two days, nothing to back up")
                suite.expect(try db.load() == sampleDays(), "the days arrive")
                suite.expect(Set(first.movedPreferences) == ["icon_set", "idle_s", "notify_break"], "preferences move")
                let settings = try db.loadSettings(defaults: defaults)
                suite.expect(settings.iconSet == .tagesring && settings.idleSecs == 300 && !settings.notifyBreak
                             && settings.notifyLimit, "preferences in UserDefaults")
                suite.expect(settings.rules(date(2)).weeklyTarget == h(30, 0) && settings.accountCarry == h(2, 0),
                             "rules and account stay in the database")
                let left = try db.connection.integer("SELECT count(*) FROM settings WHERE key IN ('icon_set', 'idle_s', 'notify_break')")
                suite.expect(left == 0, "moved preferences leave the database")
                suite.expect(try db.connection.integer("PRAGMA application_id") == TimeTrackingDatabase.applicationID,
                             "Barforge's application id")

                // A second takeover replaces, after backing up.
                do {
                    let tagwerk = try open(source)
                    try tagwerk.saveDays([], removed: [date(16)], now: now())
                }
                let second = try TimeTrackingTagwerkImport.takeOver(from: sourceFile, into: db, defaults: defaults,
                                                                     now: now().adding(seconds: 5))
                suite.expect(second.days == 1, "one day left")
                suite.expect(second.backup?.lastPathComponent == "timetracking-2026-11-17-vor-tagwerk-100005.db",
                             "backup before the second takeover: \(String(describing: second.backup))")
                suite.expect(try db.load() == [sampleDays()[1]], "replaced, not merged")
                suite.expect(TimeTrackingTagwerkImport.isRunning(bundleIdentifiers: [nil, "de.foerther.tagwerk"])
                             && !TimeTrackingTagwerkImport.isRunning(bundleIdentifiers: ["com.apple.finder", nil]),
                             "Tagwerk is recognized by its bundle id")
            }
        }
    }

    private static func exportRangeSumAndRoundtrip(_ suite: TestSuite) {
        let days = sampleDays()
        let md = markdown(days, date(16), date(17), now())
        suite.expect(md.contains("# Tagwerk – Arbeitszeiten 16.11.2026 bis 17.11.2026"), md)
        suite.expect(md.contains("| Mo, 16.11.2026 | 08:00:00 | 18:30:00 | 08:58:00 | 01:32:00 | +1:10 h |"), md)
        suite.expect(md.contains("| Mo, 16.11.2026 | Pause | 12:00:00 | 12:45:00 | |"), md)
        suite.expect(md.contains("| Mo, 16.11.2026 | Arbeit ohne Mac | 18:00:00 | 18:30:00 | Telefonat |"), md)
        // Tuesday is today and still open: its target only counts as far as worked.
        suite.expect(md.contains("| Di, 17.11.2026 | 08:00:00 | 10:00:00 | 02:00:00 | 00:00:00 | +0:00 h |"), md)
        suite.expect(md.contains("| **Summe: 2 Arbeitstage** | | | **10:58:00** | **01:32:00** | **+1:10 h** |"), md)
        suite.expect(md.contains("Soll: 9:48 h (39 Std./Woche, Mo–Fr; Arbeitstage bis gestern auch ohne Eintrag, heute nur das schon Erarbeitete)."), md)
        suite.expect(md.contains("Keine Verstöße"), md)
        suite.expect(TTImport.parseFile(md) == days, "the export reads back")

        let only16 = markdown(days, date(10), date(16), now())
        suite.expect(!only16.contains("17.11.2026 |"), "the 17th is outside")
        suite.expect(only16.contains("**Summe: 1 Arbeitstag**"), "one workday")
        suite.expect(TTImport.parseFile(only16) == [days[0]], "the range reads back")
    }

    private static func settingsRoundtripAndSchemaUpgrade(_ suite: TestSuite) {
        withDirectory(suite, "settings") { dir in
            // A database in schema 1 (without settings) with an open lunch break.
            do {
                let conn = try TimeTrackingSQLite(url: dir.appendingPathComponent(TimeTrackingDatabase.fileName))
                try conn.execute(TimeTrackingDatabase.schemaVersion1Tables)
                try conn.execute("PRAGMA user_version = 1")
                try conn.execute("INSERT INTO periods VALUES ('2026-11-16', 0, 28800, 36000)")
                try conn.execute("INSERT INTO breaks VALUES ('2026-11-16', 0, 36000, NULL)")
            }
            let db = try open(dir)
            suite.expect(try db.loadSettings() == TTSettings(), "defaults after the upgrade")
            let days = try db.load()
            suite.expect(days.count == 1, "one day")
            suite.expect(days.first?.breaks.isEmpty == true, "an open break is skipped")
            suite.expect(try db.connection.integer("PRAGMA user_version") == TimeTrackingDatabase.schemaVersion,
                         "schema 3 after the upgrade")

            let old = TTWorkRules(minPause: 20 * 60, weeklyTarget: h(38, 30), frameFrom: h(6, 0), frameTo: h(20, 0),
                                  workdays: 0b0_1111, freeDaysCount: false)
            var new = old
            new.weeklyTarget = h(30, 0)
            new.freeDaysCount = true
            var custom = TTSettings()
            custom.work = [TTRulesPeriod(from: nil, rules: old), TTRulesPeriod(from: date(16), rules: new)]
            custom.minWork = 30 * 60
            custom.iconSet = .schlossuhr
            custom.showTime = true
            custom.hotkeys = true
            custom.autoWorkdaysOnly = false
            custom.idleSecs = 10 * 60
            custom.askAfterLock = true
            custom.notifyLimit = false
            custom.notifyBreak = false
            custom.accountFrom = date(2)
            custom.accountCarry = -h(3, 30)
            try withDefaults { defaults in
                let other = try open(dir)
                try other.saveSettings(custom, today: date(20), defaults: defaults)
                suite.expect(db.changedExternally(), "settings change the database")
                suite.expect(try db.loadSettings(defaults: defaults) == custom, "settings round trip")
            }
            // For older Tagwerk versions `settings` holds the rules that applied when saving.
            let weekly = try db.connection.integer("SELECT value FROM settings WHERE key = ?1",
                                                   [.text(TimeTrackingDatabase.SettingsKey.weekly)])
            suite.expect(weekly == h(30, 0), "today's rules in settings")
            let keys = try db.connection.query("SELECT key FROM settings ORDER BY key") { $0.text(0) }
            suite.expect(keys == ["account_carry_s", "account_from_day", "frame_from_s", "frame_to_s", "min_pause_s",
                                  "weekly_target_s", "workdays"], "only rules and account in the database: \(keys)")
            // A database of an older version (without sets): the rules in `settings` apply since always.
            try db.connection.run("DELETE FROM work_rules")
            let legacy = try db.loadSettings()
            // Older versions do not know whether work on free days counts: the default.
            var newLegacy = new
            newLegacy.freeDaysCount = false
            suite.expect(legacy.work == [TTRulesPeriod(from: nil, rules: newLegacy)], "legacy rules since always")
        }
    }

    private static func workRulesGetTheFreeDaysColumn(_ suite: TestSuite) {
        withDirectory(suite, "free-days-column") { dir in
            // `work_rules` in its first version (without `free_days_count`), as an
            // older Tagwerk created and filled it.
            do {
                let conn = try TimeTrackingSQLite(url: dir.appendingPathComponent(TimeTrackingDatabase.fileName))
                try conn.execute(TimeTrackingDatabase.schemaVersion1Tables)
                try conn.execute(TimeTrackingDatabase.schemaSettings)
                try conn.execute(TimeTrackingDatabase.schemaWork)
                try conn.execute("PRAGMA user_version = \(TimeTrackingDatabase.schemaVersion)")
                try conn.execute("""
                    CREATE TABLE work_rules (
                        valid_from TEXT PRIMARY KEY,
                        min_pause_s INTEGER NOT NULL,
                        weekly_target_s INTEGER NOT NULL,
                        frame_from_s INTEGER NOT NULL,
                        frame_to_s INTEGER NOT NULL,
                        workdays INTEGER NOT NULL
                    ) WITHOUT ROWID;
                    INSERT INTO work_rules VALUES ('', 900, 140400, 25200, 79200, 31);
                    INSERT INTO work_rules VALUES ('2026-11-16', 900, 115200, 25200, 79200, 15);
                    """)
            }
            let db = try open(dir)
            let s = try db.loadSettings()
            suite.expect(s.work.count == 2, "two sets")
            suite.expect(s.work.allSatisfy { !$0.rules.freeDaysCount }, "default: does not count")
            // Saving and loading keeps the switch per set.
            var changed = s
            var rules = s.work[1].rules
            rules.freeDaysCount = true
            changed.setRules(from: date(16), rules)
            try db.saveSettings(changed, today: date(20))
            let again = try open(dir).loadSettings()
            suite.expect(again == changed, "the switch survives")
            suite.expect(!again.rules(date(13)).freeDaysCount && again.rules(date(16)).freeDaysCount, "per set")
            // An older version saves without the column: then the default applies.
            try db.connection.run("""
                INSERT OR REPLACE INTO work_rules (valid_from, min_pause_s, weekly_target_s, frame_from_s, frame_to_s, workdays)
                VALUES ('2026-11-16', 900, 115200, 25200, 79200, 15)
                """)
            suite.expect(!(try db.loadSettings().rules(date(16)).freeDaysCount), "missing value: the default")
        }
    }

    private static func absencesSurviveDatabaseAndExport(_ suite: TestSuite) {
        withDirectory(suite, "absences") { dir in
            var half = TTDay(date: date(16))
            half.addPeriod(from: h(8, 0), to: h(12, 0))
            half.absence = TTAbsence(.vacation, half: true)
            // A day with only the absence, without any recorded time.
            var off = TTDay(date: date(18))
            off.absence = TTAbsence(.timeOff, half: false)
            let days = [half, off]
            let db = try open(dir)
            try db.saveDays(days, removed: [], now: now())
            suite.expect(try db.load() == days, "absences survive the database")
            // Taking the absence back: the day without times goes.
            try db.editDay(date(18), now: now()) { $0.absence = nil }
            suite.expect(try db.load() == [days[0]], "the empty day goes")
            suite.expect(try db.connection.integer("PRAGMA user_version") == TimeTrackingDatabase.schemaVersion,
                         "the schema version stays")

            // Markdown: the absence is a correction and reads back.
            let evening = TTDateTime(date(18), hour: 18, minute: 0)
            let md = markdown(days, date(16), date(22), evening)
            suite.expect(md.contains("| Mo, 16.11.2026 | Abwesenheit | – | – | Urlaub (halber Tag) |"), md)
            suite.expect(md.contains("| Mi, 18.11.2026 | Abwesenheit | – | – | Zeitausgleich |"), md)
            suite.expect(TTImport.parseFile(md) == days, "absences read back")
            // Half the target on Monday, the full one on Tuesday without an entry
            // and on Wednesday: 4:00 − (3:54 + 7:48 + 7:48).
            suite.expect(md.contains("| Di, 17.11.2026 | – | – | 00:00:00 | 00:00:00 | −7:48 h |"), md)
            suite.expect(md.contains("| **Summe: 1 Arbeitstag** | | | **04:00:00** | **00:00:00** | **−15:30 h** |"), md)
        }
    }

    private static func csvHasOneRowPerDay(_ suite: TestSuite) {
        // Mon 16.11.: 08:00–12:00 and 12:45–17:30 with a manual break; Sat 21.11.: 1 h.
        var mon = TTDay(date: date(16))
        mon.addPeriod(from: h(8, 0), to: h(12, 0))
        mon.addPeriod(from: h(12, 45), to: h(17, 30))
        mon.addBreak(from: h(15, 0), to: h(15, 15))
        var sat = TTDay(date: date(21))
        sat.addPeriod(from: h(10, 0), to: h(11, 0))
        let days = [mon, sat]
        // As of Tuesday: Tuesday only counts with working time.
        let r = report(days, date(16), date(22), date(17))
        let t = r.totals
        suite.expect((t.work, t.pause, t.target, t.days) == (h(8, 30) + h(1, 0), h(1, 0), h(7, 48), 2), "totals")
        let csv = TTExport.csv(r, de)
        suite.expect(csv.hasPrefix("\u{FEFF}"), "BOM for Excel")
        let lines = String(csv.dropFirst()).components(separatedBy: "\r\n")
        suite.expect(lines[0] == "Datum;Wochentag;Beginn;Ende;Arbeitszeit;Arbeitszeit (Std.);Pausen;Soll;Saldo;Abwesenheit;Korrigiert;Hinweise",
                     lines[0])
        suite.expect(lines[1] == "16.11.2026;Mo;08:00;17:30;8:30;8,50;1:00;7:48;+0:42;;ja;", lines[1])
        // Work on the weekend does not count in the balance: the field stays empty.
        suite.expect(lines[2] == "21.11.2026;Sa;10:00;11:00;1:00;1,00;0:00;0:00;;;nein;Arbeit am Wochenende – zählt nicht im Saldo",
                     lines[2])
        suite.expect(r.balance == h(0, 42), "balance")
        // With the switch in the rules: overtime.
        let counted = st().withRules(TTWorkRules(freeDaysCount: true))
        let reportCounted = report(days, date(16), date(22), date(17), counted)
        suite.expect(reportCounted.balance == h(1, 42), "balance with free days counted")
        let csvCounted = TTExport.csv(reportCounted, de)
        suite.expect(csvCounted.contains("21.11.2026;Sa;10:00;11:00;1:00;1,00;0:00;0:00;+1:00;;nein;Arbeit am Wochenende – zählt ohne Soll als Mehrarbeit"),
                     csvCounted)
        suite.expect(lines.count == 4, "a line end after the last row")
        // A week later: Tue to Fri without an entry come with their target.
        let later = report(days, date(16), date(22), date(30))
        let lt = later.totals
        suite.expect((lt.work, lt.pause, lt.target, lt.days) == (h(9, 30), h(1, 0), 5 * h(7, 48), 2), "totals later")
        let laterLines = TTExport.csv(later, de).components(separatedBy: "\r\n")
        suite.expect(laterLines.count == 8, "eight lines")
        suite.expect(laterLines[2] == "17.11.2026;Di;;;0:00;0,00;0:00;7:48;-7:48;;nein;", laterLines[2])
        suite.expect(laterLines[6].hasPrefix("21.11.2026;Sa;10:00"), laterLines[6])
        // Time off without working time: no times, the full target as minus.
        var off = TTDay(date: date(18))
        off.absence = TTAbsence(.timeOff, half: false)
        let offCSV = TTExport.csv(report([off], date(16), date(22), date(18)), de)
        suite.expect(offCSV.contains("18.11.2026;Mi;;;0:00;0,00;0:00;7:48;-7:48;Zeitausgleich;ja;\r\n"), offCSV)
        // A warning with a semicolon goes in quotes.
        var quotedDay = r.days[0]
        quotedDay.warnings = ["a; b \"c\""]
        let quoted = TTReport(from: r.from, to: r.to, days: [quotedDay])
        suite.expect(TTExport.csv(quoted, de).contains(";ja;\"a; b \"\"c\"\"\"\r\n"), TTExport.csv(quoted, de))
    }

    private static func exportFormatsByName(_ suite: TestSuite) {
        suite.expect(TTExportFormat.from(name: "CSV") == .csv, "CSV")
        suite.expect(TTExportFormat.from(name: "markdown") == .markdown, "markdown")
        suite.expect(TTExportFormat.from(path: "/tmp/zeiten.PDF") == .pdf, "PDF by extension")
        suite.expect(TTExportFormat.from(path: "zeiten") == nil, "no extension")
        // Tagwerk names it `tagwerk-…`.
        suite.expect(TTExport.fileName(from: date(1), to: date(30), format: .csv) == "timetracking-2026-11-01_2026-11-30.csv",
                     "file name")
        for format in TTExportFormat.allCases {
            suite.expect(TTExportFormat.from(name: format.fileExtension) == format, "\(format) by its extension")
        }
        suite.expect(TTExportFormat.markdown.label(de) == "Markdown (vollständig, wieder einlesbar)", "label")
    }

    private static func defaultRangeIs28Days(_ suite: TestSuite) {
        let (from, to) = TTExport.defaultRange(today: date(17))
        suite.expect(from == TTDate(year: 2026, month: 10, day: 21)! && to == date(17), "28 days")
        suite.expect(TTExport.fileName(from: from, to: to, format: .markdown) == "timetracking-2026-10-21_2026-11-17.md",
                     "file name")
    }

    private static func legacyFileBecomesPeriods(_ suite: TestSuite) {
        let md = """
            | Datum | Erster Login | Letzter Logout | Arbeitszeit | Pausenzeit |
            |---|---|---|---|---|
            | Mo, 09.11.2026 | 08:00:00 | 17:00:00 | 08:00:00 | 01:00:00 |
            | Di, 10.11.2026 | 08:00:00 | 12:00:00 | 04:00:00 | 00:00:00 |

            """
        let days = TTImport.parseFile(md)
        suite.expect(days.count == 2, "two days")
        suite.expect(days.first?.periods == [TTSpan(h(8, 0), h(12, 0)), TTSpan(h(13, 0), h(17, 0))], "break in the middle")
        suite.expect(days.last?.periods == [TTSpan(h(8, 0), h(12, 0))], "without break")
        if let r = days.first?.record(st()) {
            suite.expect((r.workSecs, r.pauseSecs) == (h(8, 0), h(1, 0)), "working time and break")
        } else {
            suite.expect(false, "a record")
        }
        // Export and import keep the values.
        suite.expect(TTImport.parseFile(markdown(days, date(1), date(30), now())) == days, "round trip")
    }

    private static func dailyBackupKeepsLast15(_ suite: TestSuite) {
        withDirectory(suite, "backup") { dir in
            let db = try open(dir)
            let start = TTDate(year: 2026, month: 10, day: 1)!
            for i in 0..<20 {
                let day = start.adding(days: i)
                var d = TTDay(date: day)
                d.addPeriod(from: h(8, 0), to: h(9, 0))
                let t = TTDateTime(day, hour: 12, minute: 0)
                try db.saveDays([d], removed: [], now: t)
                try db.saveDays([d], removed: [], now: t) // a second save the same day: no new backup
            }
            let names = try FileManager.default.contentsOfDirectory(atPath: db.backupDirectory.path)
            // The first save (empty database) makes no backup: 19 days, 15 of them left.
            suite.expect(names.count == TimeTrackingDatabase.maxBackups, "15 backups: \(names)")
            suite.expect(names.contains("timetracking-2026-10-20.db"), "the newest stays")
            suite.expect(!names.contains("timetracking-2026-10-05.db"), "the oldest go")
            // A backup is a complete database with the state before the change.
            let backupURL = db.backupDirectory.appendingPathComponent("timetracking-2026-10-20.db")
            let backup = try TimeTrackingSQLite(url: backupURL, readOnly: true)
            suite.expect(try backup.integer("SELECT count(*) FROM periods") == 19, "the state before the change")
            let mode = try FileManager.default.attributesOfItem(atPath: backupURL.path)[.posixPermissions] as? NSNumber
            suite.expect(mode?.intValue == 0o600, "backups are owner-only")
            let dirMode = try FileManager.default.attributesOfItem(atPath: db.backupDirectory.path)[.posixPermissions] as? NSNumber
            suite.expect(dirMode?.intValue == 0o700, "the backup folder is owner-only")
        }
    }

    private static func freeDayCountingSurvivesDatabaseAndExport(_ suite: TestSuite) {
        withDirectory(suite, "counting") { dir in
            // Saturday not counted, Sunday counted.
            var sat = TTDay(date: date(21))
            sat.addPeriod(from: h(10, 0), to: h(12, 0))
            sat.freeDay = .uncounted
            var sun = TTDay(date: date(22))
            sun.addPeriod(from: h(9, 0), to: h(10, 0))
            sun.freeDay = .counted
            let days = [sat, sun]
            let db = try open(dir)
            try db.saveDays(days, removed: [], now: now())
            suite.expect(try db.load() == days, "free days survive the database")
            suite.expect(try db.connection.integer("PRAGMA user_version") == TimeTrackingDatabase.schemaVersion,
                         "the schema version stays")
            // Deleting the entries deletes the decision too.
            try db.editDay(date(22), now: now()) { $0 = TTDay(date: date(22)) }
            suite.expect(try db.load() == [days[0]], "the decision goes with the entries")

            let evening = TTDateTime(date(22), hour: 18, minute: 0)
            let md = markdown(days, date(16), date(22), evening)
            suite.expect(md.contains("| Sa, 21.11.2026 | Erfassung | – | – | freier Tag, nicht gezählt |"), md)
            suite.expect(md.contains("| So, 22.11.2026 | Erfassung | – | – | freier Tag, gezählt |"), md)
            suite.expect(TTImport.parseFile(md) == days, "free days read back")
            // Only Sunday counts.
            suite.expect(md.contains("| So, 22.11.2026 | 09:00:00 | 10:00:00 | 01:00:00 |"), md)
        }
    }

    private static func markdownAndCsvNameTheSameBalance(_ suite: TestSuite) {
        // 08:00:10–16:48:00: 8:47:50 to the second, shown 8:48 h, balance +1:00.
        var mon = TTDay(date: date(16))
        mon.addPeriod(from: h(8, 0) + 10, to: h(16, 48))
        var tue = TTDay(date: date(17))
        tue.addPeriod(from: h(8, 0) + 20, to: h(15, 0))
        let days = [mon, tue]
        let later = TTDateTime(date(23), hour: 10, minute: 0)
        let md = markdown(days, date(16), date(17), later)
        suite.expect(md.contains("| Mo, 16.11.2026 | 08:00:10 | 16:48:00 | 08:47:50 | 00:00:00 | +1:00 h |"), md)
        suite.expect(md.contains("| Di, 17.11.2026 | 08:00:20 | 15:00:00 | 06:59:40 | 00:00:00 | −0:48 h |"), md)
        // The total is the sum of the rows.
        suite.expect(md.contains("| **Summe: 2 Arbeitstage** | | | **15:47:30** | **00:00:00** | **+0:12 h** |"), md)
        let r = report(days, date(16), date(17), date(23))
        let csv = TTExport.csv(r, de)
        suite.expect(csv.contains("16.11.2026;Mo;08:00;16:48;8:48;8,80;0:00;7:48;+1:00;"), csv)
        suite.expect(csv.contains("17.11.2026;Di;08:00;15:00;7:00;7,00;0:00;7:48;-0:48;"), csv)
        suite.expect(r.balance == h(0, 12), "the same balance")
        // The note on the target: with the running day in the range it says how it counts.
        suite.expect(TTExport.targetNote(st(), from: date(16), to: date(22), today: date(23), de)
                     == "39 Std./Woche, Mo–Fr; Arbeitstage bis gestern auch ohne Eintrag", "note without today")
        suite.expect(TTExport.targetNote(st(), from: date(16), to: date(22), today: date(17), de)
                        .hasSuffix("heute nur das schon Erarbeitete"), "note with today")
    }

    private static func staleFreeDayMarksAreDroppedOnLoad(_ suite: TestSuite) {
        withDirectory(suite, "stale-marks") { dir in
            let db = try open(dir)
            // Four-day week without Friday: on Friday the time was recorded but not
            // counted; the Friday before only has the decision.
            let four = st().withRules(TTWorkRules(workdays: 0b0_1111))
            try db.saveSettings(four, today: date(23))
            var fri = TTDay(date: date(20))
            fri.addPeriod(from: h(8, 0), to: h(16, 0))
            fri.freeDay = .uncounted
            var markOnly = TTDay(date: date(13))
            markOnly.freeDay = .stopped
            var sat = TTDay(date: date(21))
            sat.addPeriod(from: h(10, 0), to: h(11, 0))
            sat.freeDay = .uncounted
            let days = [markOnly, fri, sat]
            try db.saveDays(days, removed: [], now: now())
            suite.expect(try db.load() == days, "marks stay while the rules say free")
            suite.expect(days[1].record(four)?.workSecs == 0, "Friday does not count")
            // The rules become Mon–Fr backwards: Friday has a target, and its time counts.
            try db.saveSettings(st(), today: date(23))
            let loaded = try db.load()
            fri.freeDay = nil
            suite.expect(loaded == [fri, sat], "Saturday stays, the empty Friday goes")
            suite.expect(loaded.first?.record(st())?.workSecs == h(8, 0), "Friday counts")
            suite.expect(try db.load(from: date(20), to: date(20)) == [fri], "range load drops too")
            // Back to the four-day week: the mark is still there.
            try db.saveSettings(four, today: date(23))
            suite.expect(try db.load() == days, "the marks come back")
        }
    }

    private static func importSkipsWhatTheWindowWouldRefuse(_ suite: TestSuite) {
        let noon = TTDateTime(date(18), hour: 12, minute: 0)
        var fine = TTDay(date: date(16))
        fine.addPeriod(from: h(8, 0), to: h(16, 0))
        fine.breaks.append(TTBreak(from: h(12, 0), to: h(12, 0))) // without length: goes
        var reversed = TTDay(date: date(17))
        reversed.addPeriod(from: h(8, 0), to: h(16, 0))
        reversed.start = h(18, 0)
        reversed.end = h(12, 0)
        var laterToday = TTDay(date: date(18))
        laterToday.addPeriod(from: h(8, 0), to: h(13, 0))
        var future = TTDay(date: date(19))
        future.addWork(from: h(9, 0), to: h(10, 0), note: "Meeting")
        var planned = TTDay(date: date(20))
        planned.absence = TTAbsence(.vacation, half: false)
        var locked = TTDay(date: date(13))
        locked.absence = TTAbsence(.sick, half: false)
        locked.addPeriod(from: h(8, 0), to: h(9, 0))
        let result = TTImport.check([locked, fine, reversed, laterToday, future, planned], now: noon)
        fine.breaks.removeAll()
        suite.expect(result.days == [fine, planned], "a planned absence goes in, times in the future do not")
        let why = result.skipped.map { ($0.date.day, $0.problem.text(de)) }
        let expected = [(13, "ganztägige Abwesenheit neben anderen Einträgen"),
                        (17, "Arbeitsbeginn nicht vor dem Feierabend"),
                        (18, "Zeiten nach der jetzigen Uhrzeit"),
                        (19, "Zeiten in der Zukunft")]
        suite.expect(why.map(\.0) == expected.map(\.0) && why.map(\.1) == expected.map(\.1), "\(why)")
        suite.expect(result.skippedText(de) == "Übersprungen: 13.11.2026 (ganztägige Abwesenheit neben anderen Einträgen), "
                     + "17.11.2026 (Arbeitsbeginn nicht vor dem Feierabend), 18.11.2026 (Zeiten nach der jetzigen "
                     + "Uhrzeit), und 1 weitere.", result.skippedText(de))
        // An own export comes through unchanged.
        let days = sampleDays()
        let md = markdown(days, date(16), date(17), now())
        suite.expect(TTImport.check(TTImport.parseFile(md), now: now()) == TTImport(days: days, skipped: []),
                     "an own export passes")
    }

    private static func importBacksUpTheStateBefore(_ suite: TestSuite) {
        withDirectory(suite, "import-backup") { dir in
            let db = try open(dir)
            // An empty database: nothing to back up.
            suite.expect(try db.importDays(Array(sampleDays()[..<1]), now: now()) == nil, "nothing to back up")
            let later = now().adding(seconds: 90)
            let backup = try db.importDays(Array(sampleDays()[1...]), now: later)
            suite.expect(backup?.lastPathComponent == "timetracking-2026-11-17-vor-import-100130.db",
                         "backup name: \(String(describing: backup))")
            suite.expect(backup.map { FileManager.default.fileExists(atPath: $0.path) } == true, "the backup exists")
            suite.expect(try db.load() == sampleDays(), "both imports are in")
        }
    }

    // MARK: Barforge

    private static func databaseFilesAreOwnerOnlyAndWAL(_ suite: TestSuite) {
        withDirectory(suite, "permissions") { root in
            let dir = root.appendingPathComponent("TimeTracking", isDirectory: true)
            let db = try TimeTrackingDatabase(directory: dir, container: root)
            try db.saveDays(sampleDays(), removed: [], now: now())
            func mode(_ url: URL) throws -> Int? {
                (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue
            }
            suite.expect(try mode(dir) == 0o700, "the data folder is owner-only")
            suite.expect(try mode(db.fileURL) == 0o600, "the database is owner-only")
            let wal = URL(fileURLWithPath: db.fileURL.path + "-wal")
            if FileManager.default.fileExists(atPath: wal.path) {
                suite.expect(try mode(wal) == 0o600, "the WAL is owner-only")
            }
            suite.expect(try db.connection.text("PRAGMA journal_mode") == "wal", "WAL")
            suite.expect(try db.connection.integer("PRAGMA synchronous") == 1, "synchronous NORMAL")
            suite.expect(try db.connection.integer("PRAGMA application_id") == TimeTrackingDatabase.applicationID,
                         "application id")
            for table in ["periods", "breaks", "day_marks", "settings", "work_blocks", "absences", "auto_counting",
                          "work_rules"] {
                let sql = try db.connection.text("SELECT sql FROM sqlite_master WHERE name = ?1", [.text(table)]) ?? ""
                suite.expect(sql.contains("WITHOUT ROWID"), "\(table) is WITHOUT ROWID")
            }
        }
    }

    private static func newerSchemaIsRefused(_ suite: TestSuite) {
        withDirectory(suite, "newer") { dir in
            do {
                let conn = try TimeTrackingSQLite(url: dir.appendingPathComponent(TimeTrackingDatabase.fileName))
                try conn.execute("PRAGMA user_version = 4")
            }
            do {
                _ = try open(dir)
                suite.expect(false, "a newer schema is refused")
            } catch let error as TimeTrackingDatabaseError {
                suite.expect(error == .newerSchema(4), "\(error)")
            }
        }
    }

    private static func editDayRollsBackOnError(_ suite: TestSuite) {
        struct Refused: Error {}
        withDirectory(suite, "rollback") { dir in
            let db = try open(dir)
            try db.saveDays(sampleDays(), removed: [], now: now())
            do {
                try db.editDay(date(16), now: now()) { day in
                    day.breaks.removeAll()
                    throw Refused()
                }
                suite.expect(false, "the error is passed on")
            } catch is Refused {}
            suite.expect(try db.load() == sampleDays(), "nothing written")
            // A day that does not exist yet is created.
            try db.editDay(date(19), now: now()) { $0.absence = TTAbsence(.holiday, half: false) }
            suite.expect(try db.load().last?.absence == TTAbsence(.holiday, half: false), "a new day")
        }
    }

    private static func loadRangeAndRemoval(_ suite: TestSuite) {
        withDirectory(suite, "range") { dir in
            let db = try open(dir)
            var days: [TTDay] = []
            for d in 2...27 {
                var day = TTDay(date: date(d))
                day.addPeriod(from: h(8, 0), to: h(8, 0) + d * 60)
                day.addWork(from: h(18, 0), to: h(18, 30), note: "Note | \(d)")
                days.append(day)
            }
            try db.saveDays(days, removed: [], now: now())
            suite.expect(try db.load() == days, "26 days")
            suite.expect(try db.load(from: date(10), to: date(12)) == Array(days[8...10]), "range")
            try db.saveDays([], removed: (2...26).map(date), now: now())
            suite.expect(try db.load() == [days[25]], "removed in one go")
        }
    }

    private static func preferencesLiveInUserDefaults(_ suite: TestSuite) {
        withDefaults { defaults in
            suite.expect(TTPreferences.read(from: defaults) == TTSettings(), "an empty suite reads like a new install")
            var s = TTSettings()
            s.minWork = 20 * 60
            s.iconSet = .kaninchen
            s.showTime = true
            s.hotkeys = true
            s.autoWorkdaysOnly = false
            s.idleSecs = 5 * 60
            s.askAfterLock = true
            s.notifyLimit = false
            s.notifyBreak = false
            TTPreferences.write(s, to: defaults)
            suite.expect(TTPreferences.read(from: defaults) == s, "preferences round trip")
            defaults.set(99_999, forKey: DefaultsKey.timeTrackingIdleSeconds)
            defaults.set(77, forKey: DefaultsKey.timeTrackingIconSet)
            let read = TTPreferences.read(from: defaults)
            suite.expect(read.idleSecs == TTLimits.idleRange.upperBound && read.iconSet == .default,
                         "values out of range are sanitized")
        }
        // The registered defaults are Tagwerk's.
        withDefaults { defaults in
            for key in TTPreferences.keys {
                defaults.set(Defaults.registeredDefaults[key], forKey: key)
            }
            suite.expect(TTPreferences.read(from: defaults) == TTSettings(), "registered defaults are Tagwerk's")
        }
        let exported = SettingsBackupSupport.exportKeys()
        suite.expect(TTPreferences.keys.allSatisfy(exported.contains), "all preferences travel with backups")
        suite.expect(TTPreferences.keys.allSatisfy { Defaults.registeredDefaults[$0] != nil }, "all are registered")
    }

    private static func takeOverRefusesOtherSchemas(_ suite: TestSuite) {
        withDirectory(suite, "takeover-schema") { dir in
            try withDefaults { defaults in
                let db = try open(dir.appendingPathComponent("barforge", isDirectory: true))
                let old = dir.appendingPathComponent("old.db")
                do {
                    let conn = try TimeTrackingSQLite(url: old)
                    try conn.execute(TimeTrackingDatabase.schemaVersion1Tables)
                    try conn.execute("PRAGMA user_version = 2")
                }
                do {
                    _ = try TimeTrackingTagwerkImport.takeOver(from: old, into: db, defaults: defaults, now: now())
                    suite.expect(false, "schema 2 is refused")
                } catch let failure as TimeTrackingTagwerkImport.Failure {
                    suite.expect(failure == .unsupportedSchema(2), "\(failure)")
                }
                let missing = dir.appendingPathComponent("missing.db")
                do {
                    _ = try TimeTrackingTagwerkImport.takeOver(from: missing, into: db, defaults: defaults, now: now())
                    suite.expect(false, "a missing file is refused")
                } catch let failure as TimeTrackingTagwerkImport.Failure {
                    suite.expect(failure == .missing(missing.path), "\(failure)")
                }
                suite.expect(try db.load().isEmpty, "nothing changed")
            }
        }
    }

    private static func englishExportReadsBack(_ suite: TestSuite) {
        var days = sampleDays()
        var half = TTDay(date: date(18))
        half.addPeriod(from: h(8, 0), to: h(12, 0))
        half.absence = TTAbsence(.vacation, half: true)
        var sat = TTDay(date: date(21))
        sat.addPeriod(from: h(10, 0), to: h(11, 0))
        sat.freeDay = .uncounted
        var sun = TTDay(date: date(22))
        sun.freeDay = .stopped
        var mon = TTDay(date: date(23))
        mon.absence = TTAbsence(.specialLeave, half: false)
        days += [half, sat, sun, mon]
        let evening = TTDateTime(date(23), hour: 18, minute: 5)
        let md = markdown(days, date(16), date(23), evening, st(), en)
        suite.expect(md.hasPrefix("# Tagwerk – Working time 2026-11-16 to 2026-11-23\n\nExported on 2026-11-23 at 18:05."), md)
        suite.expect(md.contains("| Mon, 2026-11-16 | Start of work | 08:00:00 | – | |"), md)
        suite.expect(md.contains("| Wed, 2026-11-18 | Absence | – | – | Vacation (half day) |"), md)
        suite.expect(md.contains("| Sat, 2026-11-21 | Recording | – | – | free day, not counted |"), md)
        suite.expect(md.contains("| **Total: 3 workdays** |"), md)
        suite.expect(TTImport.parseFile(md) == days, "the English export reads back")
        // German and English files read the same days.
        suite.expect(TTImport.parseFile(markdown(days, date(16), date(23), evening)) == days, "the German one too")
        let csv = TTExport.csv(report(days, date(16), date(23), date(23), st(), en), en)
        suite.expect(csv.contains("2026-11-16;Mon;08:00;18:30;8:58;8.97;1:32;7:48;+1:10;;yes;\r\n"), csv)
        suite.expect(csv.hasPrefix("\u{FEFF}Date;Weekday;Start;End;"), csv)
    }

    private static func dateTimeArithmetic(_ suite: TestSuite) {
        let t = TTDateTime(date(17), hour: 23, minute: 59, second: 30)
        suite.expect(t.adding(seconds: 45) == TTDateTime(date(18), hour: 0, minute: 0, second: 15), "over midnight")
        suite.expect(TTDateTime(date(17), 10).adding(seconds: -20) == TTDateTime(date(16), TTLimits.dayEnd - 10),
                     "back over midnight")
        suite.expect(TTDateTime(date(17), 0).adding(seconds: -TTLimits.dayEnd) == TTDateTime(date(16), 0), "a day back")
        suite.expect(TTDateTime(iso: "2026-11-17T23:59:30") == t && TTDateTime(iso: "2026-11-17 23:59:30") == nil,
                     "iso")
        suite.expect(TTImport.parseDate("Mo, 16.11.2026") == date(16) && TTImport.parseDate("2026-11-16") == date(16)
                     && TTImport.parseDate("Mon, 2026-11-16") == date(16) && TTImport.parseDate("Datum") == nil,
                     "dates in either language")
    }
}
