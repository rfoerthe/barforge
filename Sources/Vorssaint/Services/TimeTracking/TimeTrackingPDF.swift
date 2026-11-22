// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import CoreGraphics
import CoreText
import Foundation

/// The PDF export (port of Tagwerk's `pdf.rs`): the overview of a range
/// (`TTReport`) as a table with weekly totals, the total and the warnings, on
/// A4 over as many pages as it takes. Always black on white whatever the
/// appearance.
///
/// Tagwerk sets a text with tab stops and lets the printing system break the
/// pages. Here the lines are a plain model (`lines`, testable without any
/// window) and Core Text draws them straight into a PDF context, so the export
/// works off-screen and without a print operation.
enum TimeTrackingPDF {
    /// A4 in points and the margin all round.
    static let page = CGSize(width: 595, height: 842)
    static let margin: CGFloat = 50
    /// Right edges of the columns start, end, working time, breaks and balance.
    static let columns: [CGFloat] = [215, 280, 365, 430, 595 - 2 * 50]
    /// Where the text of a warning starts.
    static let hintIndent: CGFloat = 105

    /// How a line is set.
    enum Style: Hashable, Sendable {
        case title, meta, header, day, week, total, note, heading, warning, plain

        var size: CGFloat {
            switch self {
            case .title: return 16
            case .meta, .header, .note: return 8.5
            case .day, .total: return 10
            case .week: return 9
            case .heading: return 12
            case .warning, .plain: return 9.5
            }
        }

        var bold: Bool {
            switch self {
            case .title, .header, .week, .total, .heading: return true
            default: return false
            }
        }

        var gray: Bool {
            switch self {
            case .meta, .header, .week, .note: return true
            default: return false
            }
        }

        /// A row of the table (six cells: the first left, the rest right-aligned).
        var isRow: Bool {
            switch self {
            case .header, .day, .week, .total: return true
            default: return false
            }
        }
    }

    /// A line of the PDF: a table row, a warning (day and text) or a paragraph.
    struct Line: Hashable, Sendable {
        var style: Style
        var cells: [String]
        /// Space above the line in points.
        var before: CGFloat

        init(_ style: Style, _ cells: [String], before: CGFloat) {
            self.style = style
            self.cells = cells
            self.before = before
        }
    }

    /// The overview as lines (`pdf.rs` `compose`).
    static func lines(_ report: TTReport, settings: TTSettings, now: TTDateTime, appName: String,
                      _ texts: TimeTrackingTexts, _ s: TimeTrackingRecordsStrings) -> [Line] {
        func hm(_ secs: Int) -> String { TTExport.hoursMinutesUnit(secs) }
        var out: [Line] = []
        out.append(Line(.title, [String(format: s.pdfTitleFormat, appName, TTFormat.day(report.from, texts),
                                        TTFormat.day(report.to, texts))], before: 0))
        // The rules of the range; when they change, a line per set.
        let summaries = settings.summaryBetween(report.from, report.to, texts)
        let exported = String(format: s.pdfExportedFormat, TTFormat.day(now.date, texts), TTFormat.clock(now.secs))
        if summaries.count == 1 {
            out.append(Line(.meta, [exported + "  ·  " + summaries[0]], before: 3))
        } else {
            out.append(Line(.meta, [exported], before: 3))
            out += summaries.map { Line(.meta, [$0], before: 1) }
        }
        out.append(Line(.header, [s.columnDate, s.columnStart, s.columnEnd, s.columnWork, s.columnBreaks,
                                  s.columnBalance], before: 16))
        var i = 0
        while i < report.days.count {
            let week = report.days[i].date.isoWeek
            var j = i
            while j < report.days.count && report.days[j].date.isoWeek == week { j += 1 }
            for (k, d) in report.days[i..<j].enumerated() {
                var date = TTExport.date(d.date, texts)
                if !d.absence.isEmpty { date += "  \(d.absence)" }
                if d.corrected { date += "  ✎" }
                if !d.warnings.isEmpty { date += "  ⚠" }
                // Without working time there is neither start nor end, and a balance only with a target.
                func clock(_ t: Int) -> String { d.work > 0 ? TTFormat.clock(t) : "–" }
                out.append(Line(.day, [date, clock(d.firstStart), clock(d.lastEnd), hm(d.work), hm(d.pause),
                                       d.hasBalance ? TTFormat.balance(d.balance) : "–"],
                                before: k == 0 ? 9 : 2))
            }
            let days = report.days[i..<j]
            out.append(Line(.week, [String(format: s.pdfWeekFormat, week.week), "", "",
                                    hm(days.reduce(0) { $0 + $1.work }), hm(days.reduce(0) { $0 + $1.pause }),
                                    TTFormat.balance(days.reduce(0) { $0 + $1.balance })], before: 3))
            i = j
        }
        let totals = report.totals
        let label = totals.days == 1 ? texts.exportWorkdayOne : texts.exportWorkdayMany
        out.append(Line(.total, [String(format: s.pdfTotalFormat, totals.days, label), "", "", hm(totals.work),
                                 hm(totals.pause), TTFormat.balance(report.balance)], before: 12))
        out.append(Line(.note, [String(format: s.pdfTargetFormat, hm(totals.target),
                                       TTExport.targetNote(settings, from: report.from, to: report.to,
                                                           today: now.date, texts))], before: 4))
        out.append(Line(.heading, [s.pdfWarningsHeading], before: 20))
        let warnings = report.days.flatMap { d in d.warnings.map { Line(.warning, [TTExport.date(d.date, texts), $0], before: 3) } }
        out += warnings.isEmpty ? [Line(.plain, [texts.exportNoWarnings], before: 3)] : warnings
        return out
    }

    /// The overview as PDF data.
    static func data(_ report: TTReport, settings: TTSettings, now: TTDateTime, appName: String,
                     _ texts: TimeTrackingTexts, _ s: TimeTrackingRecordsStrings) -> Data {
        render(lines(report, settings: settings, now: now, appName: appName, texts, s))
    }

    /// Writes the overview as PDF to `url`.
    static func write(_ report: TTReport, settings: TTSettings, now: TTDateTime, appName: String,
                      _ texts: TimeTrackingTexts, _ s: TimeTrackingRecordsStrings, to url: URL) throws {
        try data(report, settings: settings, now: now, appName: appName, texts, s).write(to: url, options: .atomic)
    }

    // MARK: Drawing

    /// Draws the lines on A4 pages; a line that no longer fits starts a new page.
    static func render(_ lines: [Line]) -> Data {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: page)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        let width = page.width - 2 * margin
        let bottom = page.height - 2 * margin
        var y: CGFloat = 0
        context.beginPDFPage(nil)
        for line in lines {
            let font = font(line.style)
            let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font), leading = CTFontGetLeading(font)
            let lineHeight = ceil(ascent + descent + leading)
            let gray: CGFloat = line.style.gray ? 0.4 : 0
            let color = CGColor(gray: gray, alpha: 1)
            // What goes where: (x, right-aligned, wrapped lines of the cell).
            var placed: [(x: CGFloat, right: Bool, lines: [CTLine])] = []
            if line.style.isRow {
                for (i, cell) in line.cells.enumerated() where !cell.isEmpty {
                    let ctLine = CTLineCreateWithAttributedString(attributed(cell, font, color))
                    placed.append(i == 0 ? (0, false, [ctLine]) : (columns[i - 1], true, [ctLine]))
                }
            } else if line.style == .warning, line.cells.count == 2 {
                placed.append((0, false, [CTLineCreateWithAttributedString(attributed(line.cells[0], font, color))]))
                placed.append((hintIndent, false, wrap(line.cells[1], font, color, width: width - hintIndent)))
            } else {
                placed.append((0, false, wrap(line.cells.first ?? "", font, color, width: width)))
            }
            let rows = placed.map(\.lines.count).max() ?? 1
            let height = CGFloat(rows) * lineHeight
            if y > 0 && y + line.before + height > bottom {
                context.endPDFPage()
                context.beginPDFPage(nil)
                y = 0
            } else if y > 0 {
                y += line.before
            }
            for item in placed {
                for (n, ctLine) in item.lines.enumerated() {
                    let lineWidth = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
                    let x = margin + (item.right ? item.x - lineWidth : item.x)
                    let baseline = page.height - margin - y - CGFloat(n) * lineHeight - ascent
                    context.textPosition = CGPoint(x: x, y: baseline)
                    CTLineDraw(ctLine, context)
                }
            }
            y += height
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    /// The system font with digits of equal width (`monospacedDigitSystemFont`).
    static func font(_ style: Style) -> CTFont {
        let base = CTFontCreateUIFontForLanguage(.system, style.size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, style.size, nil)
        let digits: [CFString: Any] = [
            kCTFontFeatureTypeIdentifierKey: kNumberSpacingType,
            kCTFontFeatureSelectorIdentifierKey: kMonospacedNumbersSelector,
        ]
        var attributes: [CFString: Any] = [kCTFontFeatureSettingsAttribute: [digits]]
        if style.bold {
            attributes[kCTFontTraitsAttribute] = [kCTFontWeightTrait: 0.3]
        }
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(CTFontCopyFontDescriptor(base),
                                                                  attributes as CFDictionary)
        return CTFontCreateWithFontDescriptor(descriptor, style.size, nil)
    }

    private static func attributed(_ text: String, _ font: CTFont, _ color: CGColor) -> CFAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        return NSAttributedString(string: text, attributes: attributes) as CFAttributedString
    }

    /// `text` broken into lines of at most `width` points.
    private static func wrap(_ text: String, _ font: CTFont, _ color: CGColor, width: CGFloat) -> [CTLine] {
        let string = attributed(text, font, color)
        let length = CFAttributedStringGetLength(string)
        guard length > 0 else { return [] }
        let typesetter = CTTypesetterCreateWithAttributedString(string)
        var lines: [CTLine] = []
        var start = 0
        while start < length {
            let count = Swift.max(CTTypesetterSuggestLineBreak(typesetter, start, Double(width)), 1)
            lines.append(CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count)))
            start += count
        }
        return lines
    }
}
