// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// A warning about a rule violation (`rules.rs` `Warning`).
///
/// Breaks, maximum hours and rest are checked twice: with the counted working
/// time and, if that finds nothing, with the actual time including the time
/// outside the working-time frame (`TTDay.actualSpans`); `outside` says the
/// violation only arises with that uncounted time.
enum TTWarning: Hashable, Sendable {
    /// Too little break for the working time (`required` seconds prescribed).
    case breaks(required: Int, outside: Bool)
    /// More than 6 hours in one stretch without a break (`work` seconds).
    case longStretch(work: Int, outside: Bool)
    /// More than 10 hours of work.
    case maxHours(work: Int, outside: Bool)
    /// Rest since the last working day too short.
    case rest(rest: Int, outside: Bool)
    /// Working time outside the frame (not counted): when, and the frame that
    /// applied. Tagwerk keeps the frame as German text; here it is the span, so
    /// the text follows the app's language.
    case outsideFrame(spans: [TTSpan], frame: TTSpan)
    /// Work on the weekend (`counted`: it counts as overtime, see
    /// `TTWorkRules.freeDaysCount`).
    case weekend(counted: Bool)
    /// Work on a free weekday (deselected workday); `counted` as for `weekend`.
    case freeWeekday(counted: Bool)

    func text(_ texts: TimeTrackingTexts) -> String {
        // The violation only arises with time that does not count: say so, or
        // the warning does not fit the working time shown.
        func with(_ outside: Bool) -> String { outside ? texts.warningOutsideSuffix : "" }
        switch self {
        case let .breaks(required, outside):
            return String(format: texts.warningBreaksFormat, required >= 45 * 60 ? 9 : 6, required / 60, with(outside))
        case let .longStretch(work, outside):
            return String(format: texts.warningLongStretchFormat, TTFormat.duration(work, texts), with(outside))
        case let .maxHours(work, outside):
            return String(format: texts.warningMaxHoursFormat, TTFormat.duration(work, texts), with(outside))
        case let .rest(rest, outside):
            return String(format: texts.warningRestFormat, TTFormat.duration(rest, texts), with(outside))
        case let .outsideFrame(spans, frame):
            let frameText = String(format: texts.frameFormat, TTFormat.clock(frame.from), TTFormat.clock(frame.to))
            return String(format: texts.warningOutsideFrameFormat, TTWarning.spansText(spans, texts), frameText)
        case .weekend(true): return texts.warningWeekendCounted
        case .weekend(false): return texts.warningWeekendUncounted
        case .freeWeekday(true): return texts.warningFreeWeekdayCounted
        case .freeWeekday(false): return texts.warningFreeWeekdayUncounted
        }
    }

    /// `00:00–00:24 Uhr`, `06:30–07:00 und 22:00–23:15 Uhr`, or with many
    /// spans `4 Zeiträume (1:05 Std.)` (`rules.rs` `fmt_spans`).
    static func spansText(_ spans: [TTSpan], _ texts: TimeTrackingTexts) -> String {
        // Rounded to whole minutes (23:59:59 becomes 24:00).
        func round(_ t: Int) -> String { TTFormat.clock((t + 30) / 60 * 60) }
        let parts = spans.map { "\(round($0.from))–\(round($0.to))" }
        switch parts.count {
        case 0: return ""
        case 1: return String(format: texts.spansOneFormat, parts[0])
        case 2, 3:
            return String(format: texts.spansFewFormat, parts.dropLast().joined(separator: texts.listSeparator),
                          parts[parts.count - 1])
        default:
            return String(format: texts.spansManyFormat, parts.count,
                          TTFormat.duration(spans.reduce(0) { $0 + $1.len }, texts))
        }
    }

    /// Violations of breaks and maximum hours in the blocks `spans` (`outside`:
    /// including the time outside the frame): too little break, too long in one
    /// stretch, more than 10 hours (`rules.rs` `legal_checks`).
    static func legalChecks(_ spans: [TTSpan], outside: Bool) -> [TTWarning?] {
        let work = spans.reduce(0) { $0 + $1.len }
        let pause = TTDay.legalPauseSecs(spans)
        let breaks: TTWarning?
        if work > 9 * 3600 && pause < 45 * 60 {
            breaks = .breaks(required: 45 * 60, outside: outside)
        } else if work > 6 * 3600 && pause < 30 * 60 {
            breaks = .breaks(required: 30 * 60, outside: outside)
        } else {
            breaks = nil
        }
        // Without any break the warning above says it all; otherwise when it
        // was taken matters too.
        let noBreakAtAll = pause == 0 && breaks != nil
        let longest = TTDay.longestStretchSecs(spans)
        let stretch: TTWarning? = longest > TTLimits.maxStretch && !noBreakAtAll
            ? .longStretch(work: longest, outside: outside) : nil
        let max: TTWarning? = work > TTLimits.maxDailyWork ? .maxHours(work: work, outside: outside) : nil
        return [breaks, stretch, max]
    }

    /// Warnings for the day `date`. `days` must be sorted by date; the previous
    /// working day is needed for the rest period (`rules.rs` `day_warnings`).
    static func dayWarnings(_ days: [TTDay], date: TTDate, settings s: TTSettings) -> [TTWarning] {
        guard let idx = days.firstIndex(where: { $0.date == date }) else { return [] }
        let day = days[idx]
        var out: [TTWarning] = []
        let spans = day.spans(s)
        let work = spans.reduce(0) { $0 + $1.len }
        let actual = day.actualSpans(s)

        // The checks of the Working Hours Act (breaks, stretch, maximum hours
        // and rest) only while its hints are on (plan E2); the hints about free
        // days and the working-time frame are not about the Act.
        if s.legalHints {
            out.append(contentsOf: legalWarnings(days, index: idx, spans: spans, actual: actual, settings: s))
        }
        // Work on a day without a target: it only goes into the balance when the
        // rules say so, on the weekend as on a deselected workday.
        if work > 0 && !s.isWorkday(date) {
            let countsInBalance = s.workCountsOn(date)
            out.append(date.isWeekend ? .weekend(counted: countsInBalance) : .freeWeekday(counted: countsInBalance))
        }
        // Spans under a minute (a short unlock at night) are not worth a warning.
        let outside = day.outsideFrameSpans(s).filter { $0.len >= 60 }
        if !outside.isEmpty {
            let r = s.rules(date)
            out.append(.outsideFrame(spans: outside, frame: TTSpan(r.frameFrom, r.frameTo)))
        }
        return out
    }

    /// Breaks, stretch and maximum hours of the day `days[index]` (counted,
    /// then with the time outside the frame), and its rest since the last day
    /// with work (`spans`/`actual`: its counted and actual blocks).
    private static func legalWarnings(_ days: [TTDay], index idx: Int, spans: [TTSpan], actual: [TTSpan],
                                      settings s: TTSettings) -> [TTWarning] {
        let date = days[idx].date
        let counted = legalChecks(spans, outside: false)
        let withOutside = actual == spans ? [nil, nil, nil] : legalChecks(actual, outside: true)
        var out = zip(counted, withOutside).compactMap { $0 ?? $1 }
        // Rest since the end of the last day with work, counted or actual.
        func rest(_ first: TTSpan?, _ previous: (date: TTDate, end: Int)?) -> Int? {
            guard let first, let previous else { return nil }
            return date.days(since: previous.date) * TTLimits.dayEnd + first.from - previous.end
        }
        let before = days[..<idx].reversed()
        let countedPrevious = before.lazy.compactMap { d -> (date: TTDate, end: Int)? in
            guard let r = d.record(s), r.workSecs > 0 else { return nil }
            return (d.date, r.lastEnd)
        }.first
        let actualPrevious = before.lazy.compactMap { d -> (date: TTDate, end: Int)? in
            d.actualSpans(s).last.map { (d.date, $0.to) }
        }.first
        if let r = rest(spans.first, countedPrevious), r < TTLimits.minRest {
            out.append(.rest(rest: r, outside: false))
        } else if let r = rest(actual.first, actualPrevious), r < TTLimits.minRest {
            out.append(.rest(rest: r, outside: true))
        }
        return out
    }
}
