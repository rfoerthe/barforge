// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Byte-for-byte comparison with Tagwerk 1.7.0 (plan §6.2 and §6.3).
///
/// The fixtures in Tests/Fixtures/TimeTracking were made with Tagwerk itself:
///
///     python3 testdata/generate_testdata.py --today 2026-11-17 > testdata-2026-11-17.md
///     TAGWERK_DIR=$tw Tagwerk --import testdata-2026-11-17.md
///     TAGWERK_DIR=$tw Tagwerk --export --from 01.05.2025 --to 16.11.2026 --format md  -o tagwerk-export-full.md
///     TAGWERK_DIR=$tw Tagwerk --export --from 01.05.2025 --to 16.11.2026 --format csv -o tagwerk-export-full.csv
///     TAGWERK_DIR=$tw Tagwerk --export --from 01.10.2026 --to 16.11.2026 --format md  -o tagwerk-export-part.md
///
/// `tagwerk-rules.db` is that database with a second set of working-time rules
/// from 01.01.2026 (38.5 h on Mon–Thu, frame 06:30–20:00, minimum break 20 min,
/// work on free days counted) and Tagwerk's preference keys in `settings`;
/// `tagwerk-export-rules.md/.csv` are its exports from 01.05.2025 to
/// 30.11.2026, a range that runs past the day of the export.
///
/// Tagwerk exports with the real clock: the time of the export is in the
/// Markdown ("Exportiert am … um … Uhr") and is read back from there, so the
/// Swift export runs with the same "now". The data ends on 16.11.2026, before
/// that day.
enum TimeTrackingParityTests {
    static let directory = "Tests/Fixtures/TimeTracking/"

    static func run(_ suite: TestSuite) {
        guard let input = read(suite, "testdata-2026-11-17.md"),
              let fullMarkdown = read(suite, "tagwerk-export-full.md"),
              let fullCSV = read(suite, "tagwerk-export-full.csv"),
              let partMarkdown = read(suite, "tagwerk-export-part.md"),
              let rulesMarkdown = read(suite, "tagwerk-export-rules.md"),
              let rulesCSV = read(suite, "tagwerk-export-rules.csv") else { return }
        guard let now = exportTime(fullMarkdown), let rulesNow = exportTime(rulesMarkdown) else {
            suite.expect(false, "the fixtures name the time of their export")
            return
        }
        let first = TTDate(year: 2025, month: 5, day: 1)!
        let last = TTDate(year: 2026, month: 11, day: 16)!

        // Import as `Tagwerk --import` does: parse, check, store; then load.
        let parsed = TTImport.parseFile(input)
        let checked = TTImport.check(parsed, now: now)
        suite.expect(checked.skipped.isEmpty && checked.days == parsed, "the test data imports without skipping")
        suite.expect(parsed.count == 406, "406 days in the test data, as Tagwerk reports: \(parsed.count)")
        TimeTrackingStoreTests.withDirectory(suite, "parity") { dir in
            let db = try TimeTrackingDatabase(directory: dir, container: dir)
            try db.importDays(checked.days, now: now)
            let days = try db.load()
            suite.expect(days == parsed, "the database keeps the imported days")
            let settings = try db.loadSettings()

            func markdown(_ from: TTDate, _ to: TTDate) -> String {
                TTExport.markdown(days, from: from, to: to, now: now, settings: settings, appName: "Tagwerk", .de)
            }
            same(suite, "tagwerk-export-full.md", markdown(first, last), fullMarkdown)
            same(suite, "tagwerk-export-part.md", markdown(TTDate(year: 2026, month: 10, day: 1)!, last), partMarkdown)
            let report = TTReport(days, from: first, to: last, today: now.date, settings: settings, .de)
            same(suite, "tagwerk-export-full.csv", TTExport.csv(report, .de), fullCSV)
            // Tagwerk's own export reads back to the same days.
            suite.expect(TTImport.parseFile(fullMarkdown) == days, "Tagwerk's export reads back")
        }

        // Tagwerk's database with two sets of rules, taken over as a whole (§6.3).
        TimeTrackingStoreTests.withDirectory(suite, "parity-rules") { dir in
            try TimeTrackingStoreTests.withDefaults { defaults in
                let source = dir.appendingPathComponent("tagwerk.db")
                try FileManager.default.copyItem(atPath: directory + "tagwerk-rules.db", toPath: source.path)
                let db = try TimeTrackingDatabase(directory: dir.appendingPathComponent("barforge"), container: dir)
                let result = try TimeTrackingTagwerkImport.takeOver(from: source, into: db, defaults: defaults,
                                                                     now: rulesNow)
                suite.expect(result.days == 406 && result.backup == nil, "406 days taken over")
                suite.expect(try db.connection.text("PRAGMA journal_mode") == "wal"
                             && db.connection.integer("PRAGMA application_id") == TimeTrackingDatabase.applicationID,
                             "the copy is Barforge's database in WAL mode")
                let days = try db.load()
                let settings = try db.loadSettings(defaults: defaults)
                suite.expect(settings.work.count == 2 && settings.rules(last).workdays == 0b0_1111
                             && settings.rules(last).freeDaysCount, "both sets of rules")
                suite.expect(settings.minWork == 30 * 60 && settings.iconSet == .schlossuhr && settings.showTime
                             && settings.hotkeys && settings.idleSecs == 600 && !settings.autoWorkdaysOnly
                             && settings.askAfterLock && !settings.notifyLimit && !settings.notifyBreak,
                             "Tagwerk's preferences arrive in UserDefaults")
                suite.expect(settings.accountFrom == TTDate(year: 2026, month: 1, day: 1)
                             && settings.accountCarry == -12_600, "the time account stays in the database")
                let to = TTDate(year: 2026, month: 11, day: 30)!
                same(suite, "tagwerk-export-rules.md",
                     TTExport.markdown(days, from: first, to: to, now: rulesNow, settings: settings,
                                       appName: "Tagwerk", .de),
                     rulesMarkdown)
                let report = TTReport(days, from: first, to: to, today: rulesNow.date, settings: settings, .de)
                same(suite, "tagwerk-export-rules.csv", TTExport.csv(report, .de), rulesCSV)
            }
        }
    }

    private static func read(_ suite: TestSuite, _ name: String) -> String? {
        // Decoded by hand: `String(contentsOfFile:)` would drop the BOM of the CSV.
        let data = FileManager.default.contents(atPath: directory + name)
        suite.expect(data != nil, "fixture \(name) reads")
        return data.map { String(decoding: $0, as: UTF8.self) }
    }

    /// `Exportiert am 21.11.2026 um 21:28 Uhr.` in a Markdown export.
    static func exportTime(_ markdown: String) -> TTDateTime? {
        let prefix = "Exportiert am "
        guard let line = markdown.split(separator: "\n").first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let words = line.dropFirst(prefix.count).split(separator: " ")
        guard words.count >= 3, words[1] == "um", let date = TTImport.parseDate(String(words[0])),
              let clock = TTFormat.parseClock(String(words[2])) else { return nil }
        return TTDateTime(date, clock)
    }

    /// Compares byte for byte and names the first line that differs.
    static func same(_ suite: TestSuite, _ name: String, _ actual: String, _ expected: String) {
        if actual.utf8.elementsEqual(expected.utf8) {
            suite.expect(true, "\(name) is identical")
            return
        }
        let a = actual.components(separatedBy: "\n")
        let e = expected.components(separatedBy: "\n")
        let index = zip(a, e).enumerated().first { $0.element.0 != $0.element.1 }?.offset ?? Swift.min(a.count, e.count)
        let got = index < a.count ? a[index] : "<end>"
        let want = index < e.count ? e[index] : "<end>"
        suite.expect(false, "\(name) differs from Tagwerk in line \(index + 1):\n  Swift:   \(got)\n  Tagwerk: \(want)")
    }
}
