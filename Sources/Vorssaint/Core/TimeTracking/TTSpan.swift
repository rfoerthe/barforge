// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// A stretch of time `[from, to)` within a day, in seconds since midnight
/// (`0...TTLimits.dayEnd`). Port of `Span` and the span algebra in Tagwerk's
/// `day.rs`.
struct TTSpan: Hashable, Sendable, CustomStringConvertible {
    var from: Int
    var to: Int

    init(_ from: Int, _ to: Int) {
        self.from = from
        self.to = to
    }

    /// Length in seconds, never negative.
    var len: Int { Swift.max(to - from, 0) }

    var description: String { "\(TTFormat.clockSeconds(from))–\(TTFormat.clockSeconds(to))" }

    /// Duration between the shown times (without seconds): `17:00:19 – 17:30`
    /// is 30 min as shown, not 29 (`day.rs` `shown_len`).
    static func shownLen(from: Int, to: Int) -> Int {
        Swift.max(to / 60 - from / 60, 0) * 60
    }

    /// Sorts and merges overlapping or touching spans.
    static func union(_ spans: [TTSpan]) -> [TTSpan] {
        let sorted = spans.sorted { ($0.from, $0.to) < ($1.from, $1.to) }
        var out: [TTSpan] = []
        out.reserveCapacity(sorted.count)
        for span in sorted {
            if let last = out.last, span.from <= last.to {
                out[out.count - 1].to = Swift.max(last.to, span.to)
            } else {
                out.append(span)
            }
        }
        return out
    }

    /// Closes gaps shorter than `minPause`: the Mac was locked only briefly, the
    /// time belongs to the running block of work.
    static func fillGaps(_ spans: [TTSpan], minPause: Int) -> [TTSpan] {
        var out: [TTSpan] = []
        for span in union(spans) {
            if let last = out.last, span.from - last.to < minPause {
                out[out.count - 1].to = Swift.max(last.to, span.to)
            } else {
                out.append(span)
            }
        }
        return out
    }

    /// Cuts every span to `lo..<hi` and drops what is left empty.
    static func clip(_ spans: [TTSpan], _ lo: Int, _ hi: Int) -> [TTSpan] {
        spans.compactMap { span in
            let clipped = TTSpan(Swift.max(span.from, lo), Swift.min(span.to, hi))
            return clipped.to > clipped.from ? clipped : nil
        }
    }

    /// Removes `cut` from every span (a span may split in two).
    static func subtract(_ spans: [TTSpan], _ cut: TTSpan) -> [TTSpan] {
        guard cut.to > cut.from else { return spans }
        var out: [TTSpan] = []
        out.reserveCapacity(spans.count + 1)
        for span in spans {
            if span.to <= cut.from || span.from >= cut.to {
                out.append(span)
                continue
            }
            if span.from < cut.from { out.append(TTSpan(span.from, cut.from)) }
            if span.to > cut.to { out.append(TTSpan(cut.to, span.to)) }
        }
        return out
    }
}

extension Array {
    /// Stable sort like Rust's `sort_by_key`: elements that are not in
    /// increasing order either way keep their order.
    func ttStableSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
        enumerated()
            .sorted { lhs, rhs in
                if areInIncreasingOrder(lhs.element, rhs.element) { return true }
                if areInIncreasingOrder(rhs.element, lhs.element) { return false }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
