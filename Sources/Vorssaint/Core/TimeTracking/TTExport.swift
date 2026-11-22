// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

// Export of the records as Markdown and CSV, and the overview both CSV and the
// PDF are made from (port of the export part of Tagwerk's `store.rs`).
//
// Every function takes the texts of the language to write in. With `.de` and
// the app name "Tagwerk" the output is byte for byte what Tagwerk writes
// (`TimeTrackingParityTests` holds it to that). Markdown in either language
// reads back with `TTImport.parseFile`.

/// Format of an export (`store.rs` `ExportFormat`).
enum TTExportFormat: CaseIterable, Sendable {
    /// Complete: overview, warnings, corrections and recorded periods; can be imported again.
    case markdown
    /// The overview as a table for Excel or Numbers.
    case csv
    /// The overview with weekly totals and warnings for printing.
    case pdf

    func label(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case .markdown: return texts.exportFormatMarkdown
        case .csv: return texts.exportFormatCSV
        case .pdf: return texts.exportFormatPDF
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .csv: return "csv"
        case .pdf: return "pdf"
        }
    }

    /// Format by name (`md`, `markdown`, `csv`, `pdf`) or file extension.
    static func from(name: String) -> TTExportFormat? {
        var name = name.ttTrimmed
        while name.hasPrefix(".") { name.removeFirst() }
        switch name.lowercased() {
        case "md", "markdown": return .markdown
        case "csv": return .csv
        case "pdf": return .pdf
        default: return nil
        }
    }

    /// Format by the extension of the file name `path`.
    static func from(path: String) -> TTExportFormat? {
        let ext = (path as NSString).pathExtension
        return ext.isEmpty ? nil : from(name: ext)
    }
}

enum TTExport {
    /// Default range of an export: the last four weeks (28 days including today).
    static let defaultDays = 28

    /// The last 28 days up to and including `today`.
    static func defaultRange(today: TTDate) -> (from: TTDate, to: TTDate) {
        (today.adding(days: -(defaultDays - 1)), today)
    }

    /// Suggested file name: `timetracking-2026-10-21_2026-11-17.md` (Tagwerk
    /// says `tagwerk-…`).
    static func fileName(from: TTDate, to: TTDate, format: TTExportFormat) -> String {
        "timetracking-\(from.iso)_\(to.iso).\(format.fileExtension)"
    }

    /// The note on the target of an export from `from` to `to` (`today`:
    /// today): what it rests on and which days count, as `TTSettings.balance`
    /// computes it. Part of Markdown and PDF (`store.rs` `target_note`).
    static func targetNote(_ settings: TTSettings, from: TTDate, to: TTDate, today: TTDate,
                           _ texts: TimeTrackingTexts) -> String {
        let basis = settings.targetBasis(from, to, texts)
        // The running day only counts as far as its target is worked (until the end of work).
        let format = from <= today && today <= to ? texts.targetNoteTodayFormat : texts.targetNoteFormat
        return String(format: format, basis)
    }

    // MARK: Formatting (`store.rs`)

    /// `Mo, 16.11.2026` / `Mon, 2026-11-16`.
    static func date(_ date: TTDate, _ texts: TimeTrackingTexts) -> String {
        String(format: texts.weekdayDateFormat, texts.weekdayShortNames[date.weekday], TTFormat.day(date, texts))
    }

    /// `HH:MM:SS` for durations (hours may exceed 24).
    static func hms(_ secs: Int) -> String {
        let s = Swift.max(secs, 0)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    /// `7:48` (without unit, for tables).
    static func hoursMinutes(_ secs: Int) -> String {
        let m = Swift.max(secs, 0) / 60
        return String(format: "%d:%02d", m / 60, m % 60)
    }

    /// `7:48 h` (the same in every language, as in Tagwerk's `fmt_hm`).
    static func hoursMinutesUnit(_ secs: Int) -> String {
        hoursMinutes(secs) + " h"
    }

    // MARK: CSV

    /// The overview as CSV for spreadsheets: one row a day, fields separated
    /// by semicolons, line ends CRLF and a BOM, so a German Excel opens it
    /// directly; decimals with the language's separator. Balances have a plain
    /// minus so they can be computed with; a day without a balance (work on a
    /// free day that does not count) leaves that field empty, like start and
    /// end on a day without working time (`store.rs` `export_csv`).
    static func csv(_ report: TTReport, _ texts: TimeTrackingTexts) -> String {
        func field(_ s: String) -> String {
            guard s.contains(where: { $0 == ";" || $0 == "\"" || $0 == "\n" }) else { return s }
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var out = "\u{FEFF}"
        out += texts.csvHeader + "\r\n"
        for d in report.days {
            let balance = d.balance
            // Without working time (a vacation day, for example) there is neither start nor end.
            func clock(_ t: Int) -> String { d.work > 0 ? TTFormat.clock(t) : "" }
            // Rust formats with a point; the language only picks the separator.
            let hours = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(d.work) / 3600)
                .replacingOccurrences(of: ".", with: texts.decimalSeparator)
            let cells = [
                TTFormat.day(d.date, texts),
                texts.weekdayShortNames[d.date.weekday],
                clock(d.firstStart),
                clock(d.lastEnd),
                hoursMinutes(d.work),
                hours,
                hoursMinutes(d.pause),
                hoursMinutes(d.target),
                d.hasBalance ? (balance < 0 ? "-" : "+") + hoursMinutes(abs(balance)) : "",
                d.absence,
                d.corrected ? texts.csvYes : texts.csvNo,
                d.warnings.joined(separator: " | "),
            ]
            out += cells.map(field).joined(separator: ";") + "\r\n"
        }
        return out
    }

    // MARK: Markdown

    /// Markdown with the overview (with total and balance), warnings,
    /// corrections and recorded periods for the days from `from` to `to`
    /// inclusive. Reads back with `TTImport.parseFile`. `days` (sorted by
    /// date) may hold days outside the range: the day before `from` gives the
    /// rest period, the first recorded day where missing workdays start
    /// (`store.rs` `export_markdown`). `appName` names the app in the title
    /// and in the note on the recorded periods.
    static func markdown(_ all: [TTDay], from: TTDate, to: TTDate, now: TTDateTime, settings: TTSettings,
                         appName: String, _ texts: TimeTrackingTexts) -> String {
        let today = now.date
        let days = all.filter { $0.date >= from && $0.date <= to }
        var s = String(format: texts.exportTitleFormat, appName, TTFormat.day(from, texts), TTFormat.day(to, texts))
        s += "\n\n"
        // When the rules change in the range, they follow as a list below the explanation.
        let periods = settings.rulesBetween(from, to)
        let locks: String
        let frame: String
        if periods.count == 1 {
            let r = periods[0].rules
            locks = String(format: texts.exportLocksUnderFormat, r.minPause / 60)
            frame = " (\(r.frameText(texts)))"
        } else {
            locks = texts.exportLocksUnderMinimum
            frame = ""
        }
        s += String(format: texts.exportIntroFormat, TTFormat.day(today, texts),
                    TTFormat.clock(now.secs), locks, frame)
        s += "\n\n"
        if periods.count > 1 {
            s += texts.exportRulesHeading + "\n\n"
            for line in settings.summaryBetween(from, to, texts) {
                s += "- \(line)\n"
            }
            s += "\n"
        }
        s += texts.exportOverviewHeader + "\n"
        s += "|:------|:------:|:----:|------------:|-----------:|------:|\n"
        // `counted`: working time that goes into the balance (without free
        // days where it does not count), by the shown times as in the window,
        // so Markdown, CSV, PDF and window name the same balance and the total
        // matches the rows. Working time and breaks beside it are to the second.
        var (work, counted, pause, target, count) = (0, 0, 0, 0, 0)
        // Workdays without an entry appear with their target in between.
        var missing = settings.missingWorkdays(all, from: from, to: to, today: today)[...]
        func addMissing(before: TTDate?) {
            while let date = missing.first, before.map({ date < $0 }) ?? true {
                missing.removeFirst()
                let dayTarget = settings.dailyTarget(date)
                target += dayTarget
                s += "| \(self.date(date, texts)) | – | – | \(hms(0)) | \(hms(0)) | \(TTFormat.balance(-dayTarget)) |\n"
            }
        }
        for d in days {
            guard let r = d.record(settings) else { continue }
            addMissing(before: d.date)
            let dayTarget = settings.countedTarget(d, r, today: today)
            let dayCounted = settings.countedWork(d.date, r.shownWorkSecs)
            let dayBalance = settings.dayBalance(d, r, today: today)
            work += r.workSecs
            counted += dayCounted
            pause += r.pauseSecs
            target += dayTarget
            if r.workSecs > 0 { count += 1 }
            let cells = [
                date(r.date, texts),
                TTFormat.clockSeconds(Swift.min(r.firstStart, TTLimits.dayEnd - 1)),
                TTFormat.clockSeconds(Swift.min(r.lastEnd, TTLimits.dayEnd - 1)),
                hms(r.workSecs),
                hms(r.pauseSecs),
                dayBalance.map(TTFormat.balance) ?? "–",
            ]
            s += "| " + cells.joined(separator: " | ") + " |\n"
        }
        addMissing(before: nil)
        let label = count == 1 ? texts.exportWorkdayOne : texts.exportWorkdayMany
        s += String(format: texts.exportTotalFormat, count, label, hms(work), hms(pause),
                    TTFormat.balance(counted - target)) + "\n"
        s += "\n" + String(format: texts.exportTargetFormat, hoursMinutesUnit(target),
                           targetNote(settings, from: from, to: to, today: today, texts)) + "\n"

        s += "\n\(texts.exportWarningsHeading)\n\n"
        let warnings = days.flatMap { d in
            TTWarning.dayWarnings(all, date: d.date, settings: settings).map { (d.date, $0) }
        }
        if warnings.isEmpty {
            s += texts.exportNoWarnings + "\n"
        } else {
            s += texts.exportWarningsHeader + "\n"
            s += "|:------|:--------|\n"
            for (day, warning) in warnings {
                s += "| \(date(day, texts)) | \(warning.text(texts)) |\n"
            }
        }

        s += "\n\(texts.exportCorrectionsHeading)\n\n"
        s += texts.exportCorrectionsIntro + "\n\n"
        s += texts.exportCorrectionsHeader + "\n"
        s += "|:------|:----|:---:|:---:|:------|\n"
        for d in days {
            let day = date(d.date, texts)
            if let start = d.start {
                s += "| \(day) | \(texts.correctionStart) | \(TTFormat.clockSeconds(start)) | – | |\n"
            }
            for b in d.breaks {
                s += "| \(day) | \(texts.correctionBreak) | \(TTFormat.clockSeconds(b.from)) | \(TTFormat.clockSeconds(b.to)) | |\n"
            }
            for w in d.work {
                let note = w.note.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ")
                s += "| \(day) | \(texts.workWithoutMac) | \(TTFormat.clockSeconds(w.from)) | \(TTFormat.clockSeconds(w.to)) | \(note) |\n"
            }
            if let end = d.end {
                s += "| \(day) | \(texts.correctionEnd) | \(TTFormat.clockSeconds(end)) | – | |\n"
            }
            if let absence = d.absence {
                s += "| \(day) | \(texts.correctionAbsence) | – | – | \(absence.label(texts)) |\n"
            }
            if let freeDay = d.freeDay {
                s += "| \(day) | \(texts.correctionCounting) | – | – | \(freeDay.label(texts)) |\n"
            }
        }

        s += "\n\(texts.exportPeriodsHeading)\n\n"
        s += String(format: texts.exportPeriodsIntroFormat, appName) + "\n\n"
        s += texts.exportPeriodsHeader + "\n"
        s += "|:------|:---:|:---:|\n"
        for d in days {
            let day = date(d.date, texts)
            for p in d.periods {
                s += "| \(day) | \(TTFormat.clockSeconds(p.from)) | \(TTFormat.clockSeconds(p.to)) |\n"
            }
        }
        return s
    }
}

/// A day in the overview (`TTReport`), with the figures of the Records window
/// (working time and breaks by the shown times) (`store.rs` `ReportDay`).
struct TTReportDay: Hashable, Sendable {
    var date: TTDate
    var firstStart: Int
    var lastEnd: Int
    var work: Int
    var pause: Int
    /// Working time that goes into the balance (`TTSettings.countedWork`; 0 on
    /// a free day where it does not count).
    var counted: Int
    /// Target that goes into the balance (`TTSettings.countedTarget`).
    var target: Int
    /// Absence such as `Urlaub (halber Tag)` (empty: none).
    var absence: String
    /// Corrected by hand?
    var corrected: Bool
    var warnings: [String]

    /// Balance of the day: counted working time minus target.
    var balance: Int { counted - target }

    /// Is there a balance: counted working time or a target? Work on a free
    /// day that does not count has none.
    var hasBalance: Bool { counted > 0 || target > 0 }
}

/// Overview of a range: the basis of CSV and PDF (`store.rs` `Report`).
struct TTReport: Hashable, Sendable {
    var from: TTDate
    var to: TTDate
    var days: [TTReportDay]

    init(from: TTDate, to: TTDate, days: [TTReportDay]) {
        self.from = from
        self.to = to
        self.days = days
    }

    /// `days`: all days, sorted by date (for the rest period on the first day
    /// and the workdays without an entry that count into the target from the
    /// first recorded day on); `today`: today.
    init(_ all: [TTDay], from: TTDate, to: TTDate, today: TTDate, settings: TTSettings,
         _ texts: TimeTrackingTexts) {
        var rows: [TTReportDay] = all
            .filter { $0.date >= from && $0.date <= to }
            .compactMap { d in
                guard let r = d.record(settings) else { return nil }
                return TTReportDay(
                    date: r.date, firstStart: r.firstStart, lastEnd: r.lastEnd,
                    work: r.shownWorkSecs, pause: r.shownPauseSecs,
                    counted: settings.countedWork(d.date, r.shownWorkSecs),
                    target: settings.countedTarget(d, r, today: today),
                    absence: d.absence?.label(texts) ?? "",
                    corrected: d.hasCorrections,
                    warnings: TTWarning.dayWarnings(all, date: d.date, settings: settings).map { $0.text(texts) })
            }
        // Workdays without an entry: no working time, but the target.
        rows += settings.missingWorkdays(all, from: from, to: to, today: today).map { date in
            TTReportDay(date: date, firstStart: 0, lastEnd: 0, work: 0, pause: 0, counted: 0,
                        target: settings.dailyTarget(date), absence: "", corrected: false, warnings: [])
        }
        self.init(from: from, to: to, days: rows.ttStableSorted { $0.date < $1.date })
    }

    /// Totals: working time, breaks, target and the number of days with working time.
    var totals: (work: Int, pause: Int, target: Int, days: Int) {
        days.reduce((0, 0, 0, 0)) { t, d in
            (t.0 + d.work, t.1 + d.pause, t.2 + d.target, t.3 + (d.work > 0 ? 1 : 0))
        }
    }

    /// Balance of the range (work on free days only where it counts).
    var balance: Int { days.reduce(0) { $0 + $1.balance } }
}
