// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Formatting and parsing of times, durations and balances (Tagwerk's
/// `fmt_*` and `parse_*` in `day.rs` and `rules.rs`). Functions that produce
/// words take the texts of the app's language; the rest are the same in every
/// language.
enum TTFormat {
    /// `08:05` (24:00 possible) (`day.rs` `fmt_clock`).
    static func clock(_ secs: Int) -> String {
        let s = secs.ttClamped(0, TTLimits.dayEnd)
        return String(format: "%02d:%02d", s / 3600, (s % 3600) / 60)
    }

    /// `08:05:30` (24:00:00 possible) (`day.rs` `fmt_clock_s`).
    static func clockSeconds(_ secs: Int) -> String {
        let s = secs.ttClamped(0, TTLimits.dayEnd)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    /// Reads `8:05`, `08:05`, `08:05:30`, `8.05`, `08:05 Uhr` or `24:00`
    /// (`day.rs` `parse_clock`).
    static func parseClock(_ text: String) -> Int? {
        var s = text.ttTrimmed
        while s.hasSuffix("Uhr") { s.removeLast(3) }
        s = s.ttTrimmed
        let parts = s.components(separatedBy: CharacterSet(charactersIn: ":."))
        var numbers: [Int] = []
        for part in parts {
            guard let number = Int(part.ttTrimmed) else { return nil }
            numbers.append(number)
        }
        let (h, m, sec): (Int, Int, Int)
        switch numbers.count {
        case 2: (h, m, sec) = (numbers[0], numbers[1], 0)
        case 3: (h, m, sec) = (numbers[0], numbers[1], numbers[2])
        default: return nil
        }
        guard (0...24).contains(h), (0..<60).contains(m), (0..<60).contains(sec) else { return nil }
        let total = h * 3600 + m * 60 + sec
        return total <= TTLimits.dayEnd ? total : nil
    }

    /// `7:48` (hours and minutes of a non-negative duration).
    static func hoursMinutes(_ secs: Int) -> String {
        String(format: "%d:%02d", secs / 3600, secs % 3600 / 60)
    }

    /// `7:48 Std.` / `7:48 h` (`rules.rs` `fmt_hm`).
    static func duration(_ secs: Int, _ texts: TimeTrackingTexts) -> String {
        let m = Swift.max(secs, 0) / 60
        return String(format: texts.durationFormat, m / 60, m % 60)
    }

    /// `9 Min.` / `9 min`, below a minute `unter 1 Min.` (as in `Joined::note`).
    static func minutes(_ secs: Int, _ texts: TimeTrackingTexts) -> String {
        secs < 60 ? texts.underOneMinute : String(format: texts.minutesFormat, secs / 60)
    }

    /// `39` or `38,5` (hours with at most two decimals, `rules.rs` `fmt_hours`).
    static func hours(_ secs: Int, _ texts: TimeTrackingTexts) -> String {
        // Rust formats with a point; the language only picks the separator below.
        var s = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(secs) / 3600)
        while s.hasSuffix("0") { s.removeLast() }
        while s.hasSuffix(".") { s.removeLast() }
        return s.replacingOccurrences(of: ".", with: texts.decimalSeparator)
    }

    /// Reads `39`, `38,5` or `38.5` (hours) and returns seconds in whole
    /// minutes (`rules.rs` `parse_hours`).
    static func parseHours(_ text: String) -> Int? {
        guard let hours = Double(text.ttTrimmed.replacingOccurrences(of: ",", with: ".")),
              hours.isFinite else { return nil }
        let minutes = (hours * 60).rounded()
        // Rust's `as i64` saturates; a value that large is no input anyone means.
        guard minutes.magnitude < 9.0e18 else { return nil }
        let (secs, overflow) = Int(minutes).multipliedReportingOverflow(by: 60)
        return overflow ? nil : secs
    }

    /// `01.12.2026` / `2026-12-01` (`rules.rs` `fmt_day`).
    static func day(_ date: TTDate, _ texts: TimeTrackingTexts) -> String {
        String(format: texts.dayFormat, date.day, date.month, date.year)
    }

    /// `+1:05 h` or `−0:30 h`, with the minus sign U+2212 (`rules.rs` `fmt_balance`).
    static func balance(_ secs: Int) -> String {
        let m = secs.magnitude / 60
        let sign = secs < 0 && m > 0 ? "\u{2212}" : "+"
        return "\(sign)\(m / 60):" + String(format: "%02d", Int(m % 60)) + " h"
    }

    /// `+12:30` or `−3:15`: a balance without unit, for input fields
    /// (`rules.rs` `fmt_signed_hm`).
    static func signedHoursMinutes(_ secs: Int) -> String {
        var s = balance(secs)
        while s.hasSuffix(" h") { s.removeLast(2) }
        return s
    }

    /// Reads a balance: `+12:30`, `-3:15`, `−3:15`, `12:30` or hours `12,5` and
    /// `-0.25` (`rules.rs` `parse_balance`).
    static func parseBalance(_ text: String) -> Int? {
        var s = text.ttTrimmed
        while s.hasSuffix("h") { s.removeLast() }
        s = s.ttTrimmed
        let negative: Bool
        var rest: Substring
        if let first = s.first, ["-", "\u{2212}", "\u{2013}"].contains(first) {
            negative = true
            rest = s.dropFirst()
        } else {
            negative = false
            rest = s.hasPrefix("+") ? s.dropFirst() : Substring(s)
        }
        rest = Substring(String(rest).ttTrimmed)
        let secs: Int
        if let colon = rest.firstIndex(of: ":") {
            guard let h = Int(rest[..<colon].ttTrimmed),
                  let m = Int(rest[rest.index(after: colon)...].ttTrimmed),
                  h >= 0, (0..<60).contains(m) else { return nil }
            let (hourSecs, overflow) = h.multipliedReportingOverflow(by: 3600)
            guard !overflow else { return nil }
            secs = hourSecs + m * 60
        } else {
            guard let hours = parseHours(String(rest)), hours >= 0 else { return nil }
            secs = hours
        }
        guard secs <= TTLimits.carryMax else { return nil }
        return negative ? -secs : secs
    }
}

extension Int {
    /// `clamp` as in Rust (the bounds are always in order here).
    func ttClamped(_ lo: Int, _ hi: Int) -> Int {
        Swift.min(Swift.max(self, lo), hi)
    }
}

extension StringProtocol {
    var ttTrimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
