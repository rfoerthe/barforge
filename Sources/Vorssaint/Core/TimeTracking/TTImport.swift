// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Why a day of an import is not taken over (see `TTImport.check`).
enum TTImportProblem: Hashable, Sendable {
    case future
    case laterToday
    case boundsReversed
    case absenceWithEntries

    func text(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case .future: return texts.importProblemFuture
        case .laterToday: return texts.importProblemLaterToday
        case .boundsReversed: return texts.importProblemBoundsReversed
        case .absenceWithEntries: return texts.importProblemAbsenceWithEntries
        }
    }
}

/// Reading Markdown back (port of the import part of Tagwerk's `store.rs`).
///
/// The parser is tolerant: unknown lines are skipped, and it understands
/// Tagwerk's German files, the files this port writes in English, and the
/// summary-only files of early Tagwerk versions.
struct TTImport: Hashable, Sendable {
    /// Days that are taken over.
    var days: [TTDay]
    /// Days that are not, with the reason.
    var skipped: [(date: TTDate, problem: TTImportProblem)]

    init(days: [TTDay], skipped: [(date: TTDate, problem: TTImportProblem)]) {
        self.days = days
        self.skipped = skipped
    }

    static func == (lhs: TTImport, rhs: TTImport) -> Bool {
        lhs.days == rhs.days && lhs.skipped.map(\.date) == rhs.skipped.map(\.date)
            && lhs.skipped.map(\.problem) == rhs.skipped.map(\.problem)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(days)
        hasher.combine(skipped.map(\.date))
        hasher.combine(skipped.map(\.problem))
    }

    /// The languages whose files the parser reads, besides the keywords below.
    static let languages: [TimeTrackingTexts] = [.de, .enUS]

    /// The texts a Markdown export is written in: German as Tagwerk, English
    /// for every other app language, so the file always reads back in.
    static func markdownTexts(for language: AppLanguage) -> TimeTrackingTexts {
        language == .de ? .de : .enUS
    }

    /// `Übersprungen: 12.03.2026 (Arbeitsbeginn nicht vor dem Feierabend), …`;
    /// empty when nothing was skipped. With many days the first three are named.
    func skippedText(_ texts: TimeTrackingTexts) -> String {
        if skipped.isEmpty { return "" }
        var parts = skipped.prefix(3).map {
            String(format: texts.importSkippedDayFormat, TTFormat.day($0.date, texts), $0.problem.text(texts))
        }
        if skipped.count > 3 {
            parts.append(String(format: texts.importSkippedMoreFormat, skipped.count - 3))
        }
        return String(format: texts.importSkippedFormat, parts.joined(separator: ", "))
    }

    /// Checks parsed days (`parseFile`) for what the Records window does not
    /// allow either: times in the future, a start of work not before the end,
    /// a full-day absence next to other entries. Such days are skipped: a file
    /// edited by hand or from an older version would otherwise bring days that
    /// compute wrongly and cannot be made in the window. Breaks without a
    /// length go silently (`store.rs` `check_import`).
    static func check(_ days: [TTDay], now: TTDateTime) -> TTImport {
        let (today, clock) = (now.date, now.secs)
        var out = TTImport(days: [], skipped: [])
        for var d in days {
            d.breaks.removeAll { $0.to <= $0.from }
            let latest = [d.periods.last?.to, d.work.last?.to, d.breaks.map(\.to).max(), d.start, d.end]
                .compactMap { $0 }
                .max()
            let problem: TTImportProblem?
            if d.date > today && d.hasEntries {
                problem = .future
            } else if d.date == today, let latest, latest > clock {
                problem = .laterToday
            } else if !TTDay.boundsInOrder(start: d.start, end: d.end) {
                problem = .boundsReversed
            } else if d.locksEntries && d.hasEntries {
                problem = .absenceWithEntries
            } else {
                problem = nil
            }
            if let problem {
                out.skipped.append((d.date, problem))
            } else if !d.isEmpty {
                out.days.append(d)
            }
        }
        return out
    }

    /// `Mo, 16.11.2026`, `16.11.2026`, `Mon, 2026-11-16` or `2026-11-16`
    /// (`store.rs` `parse_date`: the last word counts).
    static func parseDate(_ text: String) -> TTDate? {
        guard let token = text.ttTrimmed.split(separator: " ", omittingEmptySubsequences: false).last?.ttTrimmed
        else { return nil }
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count == 3 {
            func number(_ part: Substring, _ digits: ClosedRange<Int>) -> Int? {
                digits.contains(part.count) && part.allSatisfy({ $0.isASCII && $0.isNumber }) ? Int(part) : nil
            }
            guard let day = number(parts[0], 1...2), let month = number(parts[1], 1...2),
                  let year = number(parts[2], 1...6) else { return nil }
            return TTDate(year: year, month: month, day: day)
        }
        return TTDate(iso: token)
    }

    /// `08:12:30` or `08:12` as a duration (`store.rs` `parse_duration`).
    static func parseDuration(_ text: String) -> Int? {
        let parts = text.ttTrimmed.split(separator: ":", omittingEmptySubsequences: false)
        var numbers: [Int] = []
        for part in parts {
            guard let n = Int(part.ttTrimmed) else { return nil }
            numbers.append(n)
        }
        switch numbers.count {
        case 3: return numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
        case 2: return numbers[0] * 3600 + numbers[1] * 60
        default: return nil
        }
    }

    private enum Section {
        case summary, corrections, periods, other
    }

    /// Reads all days from a Markdown text: an export, or a file of an earlier
    /// Tagwerk version that only has the summary table (`store.rs` `parse_file`).
    static func parseFile(_ text: String) -> [TTDay] {
        var days: [TTDay] = []
        var legacy: [(date: TTDate, first: Int, last: Int, work: Int)] = []
        var hasPeriodsSection = false
        var section = Section.summary

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.ttTrimmed
            if line.hasPrefix("## ") {
                let head = line.dropFirst(3).lowercased()
                if head.contains("korrektur") || head.contains("correction") {
                    section = .corrections
                } else if head.contains("period") {
                    hasPeriodsSection = true
                    section = .periods
                } else {
                    section = .other
                }
                continue
            }
            guard line.hasPrefix("|") else { continue }
            var inner = Substring(line)
            while inner.hasPrefix("|") { inner.removeFirst() }
            while inner.hasSuffix("|") { inner.removeLast() }
            let cells = inner.split(separator: "|", omittingEmptySubsequences: false).map(\.ttTrimmed)
            guard let date = cells.first.flatMap(parseDate) else { continue }
            switch section {
            case .summary where cells.count >= 4:
                if let first = TTFormat.parseClock(cells[1]), let last = TTFormat.parseClock(cells[2]),
                   let work = parseDuration(cells[3]) {
                    legacy.removeAll { $0.date == date }
                    legacy.append((date, first, Swift.max(last, first), work))
                }
            case .corrections where cells.count >= 3:
                parseCorrection(cells, date: date, into: &days)
            case .periods where cells.count >= 3:
                if let from = TTFormat.parseClock(cells[1]), let to = TTFormat.parseClock(cells[2]) {
                    days[TTDay.index(of: date, in: &days)].addPeriod(from: from, to: to)
                }
            default:
                break
            }
        }

        // An older file without periods: derive them from the summary.
        if !hasPeriodsSection {
            for entry in legacy {
                let i = TTDay.index(of: entry.date, in: &days)
                guard days[i].periods.isEmpty else { continue }
                let (first, last, work) = (entry.first, entry.last, entry.work)
                if work >= last - first || work <= 0 {
                    days[i].addPeriod(from: first, to: Swift.min(first + Swift.max(work, 0), TTLimits.dayEnd))
                } else {
                    // The break goes in the middle, so start, end and working time all fit.
                    let half = work / 2
                    days[i].addPeriod(from: first, to: first + half)
                    days[i].addPeriod(from: last - (work - half), to: last)
                }
            }
        }
        return days.filter { !$0.isEmpty }
    }

    /// One row of the corrections: kind, from, to, note.
    private static func parseCorrection(_ cells: [String], date: TTDate, into days: inout [TTDay]) {
        let kind = cells[1].lowercased()
        let note = cells.count > 4 ? cells[4] : ""
        if kind.contains("erfassung") || kind.contains("recording") {
            // Without times; what applies is in the note.
            days[TTDay.index(of: date, in: &days)].freeDay = parseFreeDay(note)
            return
        }
        if kind.contains("abwesen") || kind.contains("absen") {
            // Without times; the kind is in the note.
            if let absence = parseAbsence(note) {
                days[TTDay.index(of: date, in: &days)].absence = absence
            }
            return
        }
        guard let from = TTFormat.parseClock(cells[2]) else { return }
        let to = cells.count > 3 ? TTFormat.parseClock(cells[3]) : nil
        let i = TTDay.index(of: date, in: &days)
        if kind.contains("beginn") || kind.contains("start") {
            days[i].start = from
        } else if kind.contains("feierabend") || kind.contains("end") {
            days[i].end = from
        } else if kind.contains("pause") || kind.contains("break") {
            // "läuft" (an open break of earlier versions) is skipped.
            if let to {
                days[i].breaks.append(TTBreak(from: from, to: Swift.max(to, from)))
                days[i].sortBreaks()
            }
        } else if kind.contains("ohne mac") || kind.contains("arbeit") || kind.contains("work") {
            if let to {
                days[i].addWork(from: from, to: to, note: note == "–" ? "" : note)
            }
        }
    }

    /// An absence in any of the `languages`.
    static func parseAbsence(_ text: String) -> TTAbsence? {
        for texts in languages {
            if let absence = TTAbsence.parse(text, texts) { return absence }
        }
        return nil
    }

    /// What applies to recording on a free day, from the note in any of the `languages`.
    static func parseFreeDay(_ text: String) -> TTFreeDay {
        let text = text.lowercased()
        if languages.contains(where: { text.contains($0.freeDayStoppedMarker.lowercased()) }) { return .stopped }
        if languages.contains(where: { text.contains($0.freeDayNegationMarker.lowercased()) }) { return .uncounted }
        return .counted
    }
}
