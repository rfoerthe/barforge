// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// A calendar day without time or time zone (proleptic Gregorian), the port of
/// chrono's `NaiveDate` as Tagwerk uses it. The calendar maths is done here on
/// purpose, without `Calendar`, so results never depend on the user's settings.
struct TTDate: Comparable, Hashable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    /// `nil` for a day that does not exist (31 April, 29 February 2026 …).
    init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), day >= 1, day <= TTDate.daysInMonth(year: year, month: month) else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day with chrono's `num_days_from_ce` (0001-01-01 is 1). Tagwerk
    /// stores the start of the time account this way.
    init(ordinal: Int) {
        // Howard Hinnant's civil_from_days, shifted from 1970-01-01 to 0001-01-01.
        let z = ordinal - TTDate.unixEpochOrdinal + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let month = mp < 10 ? mp + 3 : mp - 9
        year = yoe + era * 400 + (month <= 2 ? 1 : 0)
        self.month = month
        day = doy - (153 * mp + 2) / 5 + 1
    }

    /// chrono's `num_days_from_ce`: 0001-01-01 is 1, the day before is 0.
    var ordinal: Int {
        let y = year - (month <= 2 ? 1 : 0)
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468 + TTDate.unixEpochOrdinal
    }

    /// `num_days_from_ce` of 1970-01-01.
    private static let unixEpochOrdinal = 719_163

    /// chrono's `NaiveDate::MIN` and `NaiveDate::MAX`.
    static let min = TTDate(unchecked: -262_144, 1, 1)
    static let max = TTDate(unchecked: 262_143, 12, 31)

    private init(unchecked year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: return isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    /// Day of the week, Monday = 0 … Sunday = 6 (chrono's `num_days_from_monday`).
    var weekday: Int {
        // 0001-01-01 was a Monday.
        ((ordinal - 1) % 7 + 7) % 7
    }

    /// Saturday or Sunday.
    var isWeekend: Bool { weekday >= 5 }

    func adding(days: Int) -> TTDate {
        TTDate(ordinal: ordinal + days)
    }

    /// The day before (`nil` only before `TTDate.min`, like chrono's `pred_opt`).
    var predecessor: TTDate? { self > TTDate.min ? adding(days: -1) : nil }

    /// The day after (`nil` only after `TTDate.max`, like chrono's `succ_opt`).
    var successor: TTDate? { self < TTDate.max ? adding(days: 1) : nil }

    /// Whole days from `other` to this day (`self - other` in chrono).
    func days(since other: TTDate) -> Int {
        ordinal - other.ordinal
    }

    /// ISO 8601 week: the week with the year's first Thursday is week 1.
    var isoWeek: (year: Int, week: Int) {
        let thursday = adding(days: 3 - weekday)
        let januaryFirst = TTDate(unchecked: thursday.year, 1, 1)
        return (thursday.year, (thursday.ordinal - januaryFirst.ordinal) / 7 + 1)
    }

    /// `2026-11-30` (as in Tagwerk's database, export and import).
    var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    var description: String { iso }

    /// Reads `2026-11-30` (also without leading zeros in month and day).
    init?(iso text: String) {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    static func < (lhs: TTDate, rhs: TTDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
