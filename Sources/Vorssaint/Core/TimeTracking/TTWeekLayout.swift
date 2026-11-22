// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import CoreGraphics
import Foundation

// The week view of the Records window as pure logic (Tagwerk's `week_view.rs`
// without AppKit): a calendar week as a calendar, one column a day, one block
// per stretch of work from start to end. It shows the result of automatic
// recording and manual corrections, so exactly the stretches that count as
// working time. Work outside the working-time frame is "not counted", days
// with rule violations carry a warning sign in their header.
//
// Here are the columns and their blocks, the hours of the grid, the geometry,
// the presets for work away from the Mac, dragging the start and end of work
// with its limits and label, the context menu and the VoiceOver texts. The
// view (`RecordsWeekView`) only draws them and turns clicks into edits.

/// The texts the week view needs: the general ones, those of the Records
/// window and its own.
struct TTWeekTexts {
    let texts: TimeTrackingTexts
    let records: TimeTrackingRecordsStrings
    let week: TimeTrackingWeekStrings

    static let de = TTWeekTexts(texts: .de, records: .de, week: .de)
    static let enUS = TTWeekTexts(texts: .enUS, records: .enUS, week: .enUS)

    static func of(_ language: AppLanguage) -> TTWeekTexts {
        TTWeekTexts(texts: FeatureStrings.timeTrackingTexts(language),
                    records: FeatureStrings.timeTrackingRecords(language),
                    week: FeatureStrings.timeTrackingWeek(language))
    }
}

/// The state the Records window hands over (`week_view.rs` `Snapshot`).
struct TTWeekSnapshot: Hashable, Sendable {
    /// All days including the running period up to `now`, sorted by date.
    var days: [TTDay]
    var settings: TTSettings
    var now: TTDateTime
    /// Is recording running right now?
    var running: Bool
}

/// What a block in the calendar is.
enum TTWeekBlockKind: Hashable, Sendable {
    /// Counts as working time.
    case work
    /// Outside the working-time frame: recorded, but not counted.
    case outside
    /// Free day without "Record today": recorded, but not counted (see `TTDay.freeDay`).
    case freeDay
}

/// Which bounds of a block were set by hand, and when work away from the Mac
/// lay in it (`week_view.rs` `notes`).
enum TTWeekNote: Hashable, Sendable {
    case startManual
    case afterBreak
    case beforeBreak
    /// Work away from the Mac in the block (the part that counts) and its note.
    case away(TTSpan, String)
    case endManual

    func text(_ t: TTWeekTexts) -> String {
        let w = t.week
        switch self {
        case .startManual: return w.noteStartManual
        case .afterBreak: return w.noteAfterBreak
        case .beforeBreak: return w.noteBeforeBreak
        case let .away(span, note):
            let suffix = note.isEmpty ? "" : String(format: w.noteAwaySuffixFormat, note)
            return String(format: w.noteAwayFormat, TTFormat.clock(span.from), TTFormat.clock(span.to), suffix)
        case .endManual: return w.noteEndManual
        }
    }

    /// Work away from the Mac is an element of its own for VoiceOver.
    var isAway: Bool {
        if case .away = self { return true }
        return false
    }
}

/// A block in the calendar (`week_view.rs` `Block`).
struct TTWeekBlock: Hashable, Sendable {
    var from: Int
    var to: Int
    var kind: TTWeekBlockKind
    /// Runs right now (ends "now").
    var running: Bool
    var notes: [TTWeekNote]

    var span: TTSpan { TTSpan(from, to) }
}

/// Work away from the Mac in a column (`week_view.rs` `Manual`).
struct TTWeekManual: Hashable, Sendable {
    /// The part that counts (hatched).
    var span: TTSpan
    /// The entered block it comes from (removed when deleting).
    var block: TTSpan
    var note: String
}

/// Start and end of work of a column as shown, to move them (`week_view.rs` `Edges`).
struct TTWeekEdges: Hashable, Sendable {
    var start: Int
    var end: Int
    /// Without the manual entry (dragging snaps there; dragged there, it no longer applies).
    var autoStart: Int?
    var autoEnd: Int?
    var manualStart: Bool
    var manualEnd: Bool
    /// The last block still runs: its end is "now", no end of work.
    var running: Bool

    init(start: Int, end: Int, autoStart: Int?, autoEnd: Int?, manualStart: Bool, manualEnd: Bool,
         running: Bool) {
        self.start = start
        self.end = end
        self.autoStart = autoStart
        self.autoEnd = autoEnd
        self.manualStart = manualStart
        self.manualEnd = manualEnd
        self.running = running
    }

    /// Shown value, value without the manual entry, and whether it is set by hand.
    func get(_ bound: TTEditBound) -> (value: Int, auto: Int?, manual: Bool) {
        switch bound {
        case .start: return (start, autoStart, manualStart)
        case .end: return (end, autoEnd, manualEnd)
        }
    }
}

/// A day column (`week_view.rs` `Column`).
struct TTWeekColumn: Hashable, Sendable {
    var date: TTDate
    var blocks: [TTWeekBlock] = []
    var workSecs = 0
    /// Breaks between start and end (as in the Days view).
    var pauseSecs = 0
    /// Rule violations.
    var warnings: [TTWarning] = []
    /// Work away from the Mac that counts (hatched, clickable).
    var manual: [TTWeekManual] = []
    /// Breaks between the blocks (clickable).
    var gaps: [TTSpan] = []
    var absence: TTAbsence?
    /// Workday without working time and absence that still counts its target
    /// (see `TTSettings.missingWorkdays`): the target missing in the balance.
    var missing: Int?
    /// Whole-day absence: work away from the Mac can neither be entered nor
    /// deleted until the absence is "None" (see `TTDay.locksEntries`).
    var locked = false
    /// Start and end of work (only with working time).
    var edges: TTWeekEdges?

    init(date: TTDate) {
        self.date = date
    }
}

/// What a dragged bound saves (`week_view.rs`: `Some(None)` and `Some(Some(at))`).
enum TTBoundChange: Hashable, Sendable {
    /// Automatic again (the value without the manual entry).
    case auto
    case at(Int)

    var value: Int? {
        if case let .at(t) = self { return t }
        return nil
    }
}

/// Why an input in a dialog of the week view is not taken.
struct TTWeekRefusal: Error, Hashable, Sendable {
    let text: String
}

/// The start or end of work being dragged (`week_view.rs` `Drag`).
struct TTWeekDrag {
    var col: Int
    var date: TTDate
    var bound: TTEditBound
    /// State when the mouse button went down.
    var edges: TTWeekEdges
    /// y on mouse down and the pointer's distance to the edge (so it does not jump).
    var y0: CGFloat = 0
    var offset: CGFloat = 0
    /// The mouse moved far enough (otherwise it was a click).
    var active = false
    /// The time the edge stands at, and whether it snapped to the recorded value.
    var at: Int
    var snapped = false
    /// Work away from the Mac that would go with the new value.
    var cut: [TTSpan] = []
    /// Change of the day's working time with the new value (seconds, as shown).
    var workDiff = 0
    /// All days (for the warnings) with the day in the preview; `day` is the day before.
    var days: [TTDay]
    var day: TTDay
}

/// The shown week and its layout (`week_view.rs` `Data`).
struct TTWeekModel {
    var snap: TTWeekSnapshot?
    var monday: TTDate
    var cols: [TTWeekColumn] = []
    var hours: (from: Int, to: Int) = (7, 22)
    /// Width of the columns relative to each other (see `TTWeekLayout.columnWeights`).
    var weights: [Double] = Array(repeating: 1, count: 7)
    /// Show the whole working-time frame instead of only this week's working time.
    var fullFrame = false

    init(snap: TTWeekSnapshot? = nil, monday: TTDate, fullFrame: Bool = false) {
        self.snap = snap
        self.monday = monday
        self.fullFrame = fullFrame
    }

    /// Builds columns, hours and widths from the state. A drag in progress keeps its preview.
    mutating func rebuild(drag: inout TTWeekDrag?) {
        if let snap {
            cols = TTWeekLayout.columns(snap, monday: monday)
            // "Now" only belongs into the grid in the running week.
            let now: Int? = TTRecords.monday(snap.now.date) == monday ? snap.now.secs : nil
            hours = TTWeekLayout.hourRange(snap.settings, cols, now: now, compact: !fullFrame)
            weights = TTWeekLayout.columnWeights(snap.settings, cols)
        }
        if var g = drag, g.active {
            TTWeekLayout.preview(&self, &g)
            drag = g
        }
    }

    mutating func rebuild() {
        var none: TTWeekDrag?
        rebuild(drag: &none)
    }
}

/// What can be done at a spot of the grid, for the context menu and the
/// double-click (`week_view.rs` `Context`).
struct TTWeekContext: Hashable, Sendable {
    var date: TTDate
    /// Work away from the Mac under the pointer: the entered block and its note.
    var work: TTWeekWorkHit?
    /// Free area under the pointer: the preset for work away from the Mac.
    var preset: TTSpan?
    /// Time under the pointer (to copy).
    var time: TTWeekTimeHit?
    /// The absence can be changed (`current`: the entered one).
    var absenceEditable = false
    var currentAbsence: TTAbsence?
    /// Has the day entries besides the absence? Then only a half day goes.
    var busy = false
    /// Day without a target (free day): an entered absence can only be removed.
    var noTarget = false
    /// The day can be emptied ("Delete All Entries…"): it has entries besides the absence.
    var clearable = false
    /// Free day: does the recorded time count? `nil`: no free day with a mark.
    var counting: Bool?
    /// Start and end of the day and which of them can be changed here.
    var edges: TTWeekEdges?
    var bounds: [TTEditBound] = []

    init(date: TTDate) {
        self.date = date
    }
}

struct TTWeekWorkHit: Hashable, Sendable {
    var block: TTSpan
    var note: String
}

/// Start or end of a block (clickable to copy).
enum TTWeekPart: Hashable, Sendable {
    case start, end
}

/// A copied time: which block, which part (for the feedback in the grid).
struct TTWeekFlash: Hashable, Sendable {
    var date: TTDate
    var from: Int
    var kind: TTWeekBlockKind
    var part: TTWeekPart
}

struct TTWeekTimeHit: Hashable, Sendable {
    var flash: TTWeekFlash
    var text: String
}

/// An entry of the context menu.
enum TTWeekMenuAction: Hashable, Sendable {
    case openDay, copyTime, addWork, toggleCounting, absence, clearDay, removeWork
    case change(TTEditBound)
    case reset(TTEditBound)
}

/// An item of the submenu "Absence" (`week_view.rs` `AbsenceItem`).
struct TTWeekAbsenceItem: Hashable, Sendable {
    /// Empty: a separator.
    var title: String
    /// See `TTWeekLayout.absence(ofTag:)` (negative: display only).
    var tag: Int
    /// The entered absence (check mark).
    var checked: Bool
    var enabled: Bool
}

/// A choice in the submenu "Absence" (`absence == nil`: none).
struct TTWeekAbsenceChoice: Hashable, Sendable {
    var absence: TTAbsence?
}

/// What a VoiceOver element stands for.
enum TTWeekAxPart: Hashable, Sendable {
    /// Day header.
    case header
    /// Block, break or work away from the Mac in the grid.
    case span(TTSpan)
}

/// The grid's geometry in a flipped view (top = early) (`week_view.rs` `Geo`).
struct TTWeekGeometry {
    /// Height of the day headers, width of the hour column, room in the grid.
    static let headerHeight: CGFloat = 46
    static let gutterWidth: CGFloat = 54
    static let gridPadTop: CGFloat = 10
    static let gridPadBottom: CGFloat = 10

    let width: CGFloat
    let height: CGFloat
    /// Left edges of the seven columns and the right edge of the last.
    let xs: [CGFloat]
    let hourHeight: CGFloat
    let h0: Int
    let h1: Int

    init(size: CGSize, _ model: TTWeekModel) {
        width = size.width
        height = size.height
        let n = CGFloat(Swift.max(model.hours.to - model.hours.from, 1))
        let total = model.weights.reduce(0, +)
        let unit = Swift.max((size.width - Self.gutterWidth) / CGFloat(total), 1)
        var xs = Array(repeating: Self.gutterWidth, count: 8)
        for i in 0..<7 {
            let weight = model.weights.indices.contains(i) ? model.weights[i] : 1
            xs[i + 1] = xs[i] + CGFloat(weight) * unit
        }
        self.xs = xs
        hourHeight = Swift.max((size.height - Self.headerHeight - Self.gridPadTop - Self.gridPadBottom) / n, 1)
        h0 = model.hours.from
        h1 = model.hours.to
    }

    /// Width of the column `col`.
    func colWidth(_ col: Int) -> CGFloat {
        let c = Swift.min(Swift.max(col, 0), 6)
        return xs[c + 1] - xs[c]
    }

    var gridTop: CGFloat { Self.headerHeight + Self.gridPadTop }

    /// y of a time of day.
    func y(_ secs: Int) -> CGFloat {
        gridTop + CGFloat(secs - h0 * 3600) / 3600 * hourHeight
    }

    /// Time of day at `y` (only within the grid).
    func secs(at y: CGFloat) -> Int? {
        let secs = h0 * 3600 + Int(((y - gridTop) / hourHeight * 3600).rounded(.down))
        return (h0 * 3600..<h1 * 3600).contains(secs) ? secs : nil
    }

    /// Time of day at `y`, also outside the grid (to drag).
    func rawSecs(_ y: CGFloat) -> Int {
        h0 * 3600 + Int(((y - gridTop) / hourHeight * 3600).rounded())
    }

    /// Left edge of the column `col` (7: the right edge of the last).
    func x(_ col: Int) -> CGFloat {
        xs[Swift.min(Swift.max(col, 0), 7)]
    }

    func blockRect(_ col: Int, _ b: TTWeekBlock) -> CGRect {
        let top = y(Swift.max(b.from, h0 * 3600))
        let bottom = Swift.max(y(Swift.min(b.to, h1 * 3600)), top + 3)
        return CGRect(x: x(col) + 3, y: top + 0.5, width: colWidth(col) - 6, height: bottom - top - 1)
    }

    /// The area of a break between two blocks.
    func gapRect(_ col: Int, _ gap: TTSpan) -> CGRect {
        let top = y(Swift.max(gap.from, h0 * 3600))
        let bottom = Swift.max(y(Swift.min(gap.to, h1 * 3600)), top)
        return CGRect(x: x(col) + 3, y: top, width: colWidth(col) - 6, height: bottom - top)
    }

    /// The area of work away from the Mac (within its block).
    func spanRect(_ col: Int, _ sp: TTSpan) -> CGRect {
        let top = y(Swift.max(sp.from, h0 * 3600))
        let bottom = Swift.max(y(Swift.min(sp.to, h1 * 3600)), top + 1)
        return CGRect(x: x(col) + 3, y: top + 0.5, width: colWidth(col) - 6, height: bottom - top - 1)
    }

    func headerRect(_ col: Int) -> CGRect {
        CGRect(x: x(col), y: 0, width: colWidth(col), height: Self.headerHeight)
    }

    func column(at x: CGFloat) -> Int? {
        if x < Self.gutterWidth || x >= width { return nil }
        return (1...7).first { x < xs[$0] }.map { $0 - 1 } ?? 6
    }

    /// y of the edge `bound` (where the grip sits).
    func edgeY(_ e: TTWeekEdges, _ bound: TTEditBound) -> CGFloat {
        switch bound {
        case .start: return y(e.start) + 0.5
        case .end: return y(e.end) - 0.5
        }
    }
}

/// The logic of the week view (`week_view.rs`).
enum TTWeekLayout {
    /// The compact grid shows at least this many hours.
    static let minHours = 9
    /// Width of a free day without entries relative to a workday.
    static let narrow = 0.45
    /// Catch area of the edges outside and inside the block (points).
    static let edgeOut: CGFloat = 6
    static let edgeIn: CGFloat = 2.5
    /// From this mouse movement on it is a drag (points), otherwise a click.
    static let dragSlop: CGFloat = 3
    /// This close to the recorded value the edge snaps there (points).
    static let magnet: CGFloat = 6
    /// Shortest distance between start and end of work when moving them.
    static let minDay = 5 * 60
    /// Breaks under this height (points) get neither a hand nor a tooltip.
    static let minGapHeight: CGFloat = 4
    /// Preset for work away from the Mac before the start and after the end (seconds).
    static let freePresetSecs = 30 * 60

    // MARK: Week

    /// Monday of the week of `d`.
    static func monday(_ d: TTDate) -> TTDate { TTRecords.monday(d) }

    /// `KW 47  ·  16. – 22. November 2026` (complete across months and years).
    static func title(monday: TTDate, _ t: TTWeekTexts) -> String {
        let sunday = monday.adding(days: 6)
        let w = t.week
        let week = monday.isoWeek.week
        func month(_ d: TTDate) -> String { t.records.monthNames[d.month - 1] }
        if monday.year != sunday.year {
            return String(format: w.titleAcrossYearsFormat, week, monday.day, month(monday), monday.year, sunday.day,
                          month(sunday), sunday.year)
        }
        if monday.month != sunday.month {
            return String(format: w.titleSameYearFormat, week, monday.day, month(monday), sunday.day, month(sunday),
                          sunday.year)
        }
        return String(format: w.titleSameMonthFormat, week, monday.day, sunday.day, month(sunday), sunday.year)
    }

    /// The whole hours the grid shows.
    ///
    /// Compact (`compact`): the time worked this week with an hour of room
    /// before and after, so the blocks fill the grid. `now` (only in the
    /// running week) belongs to it, and it is at least `minHours` long. The
    /// room and the filling stay within the working-time frame; work outside
    /// always belongs to it.
    ///
    /// Otherwise, and in a week without work: the whole frame and, if work lay
    /// outside, that time too.
    static func hourRange(_ s: TTSettings, _ cols: [TTWeekColumn], now: Int?, compact: Bool) -> (from: Int, to: Int) {
        let blocks = cols.flatMap(\.blocks)
        let first = blocks.map(\.from).min()
        let last = blocks.map(\.to).max()
        func hours(_ from: Int, _ to: Int) -> (Int, Int) {
            let h0 = (from / 3600).ttClamped(0, 23)
            return (h0, ((to + 3599) / 3600).ttClamped(h0 + 1, 24))
        }
        // When the frame changes within the week, the widest counts (without
        // columns: the newest rules).
        let rules = cols.isEmpty ? [s.rules(.max)] : cols.map { s.rules($0.date) }
        let frameFrom = rules.map(\.frameFrom).min() ?? TTWorkRules.default.frameFrom
        let frameTo = rules.map(\.frameTo).max() ?? TTWorkRules.default.frameTo
        let (frame0, frame1) = hours(frameFrom, frameTo)
        guard let first, let last, compact else {
            return hours(first.map { Swift.min($0, frameFrom) } ?? frameFrom, last.map { Swift.max($0, frameTo) } ?? frameTo)
        }
        let clampedNow = now.map { $0.ttClamped(frameFrom, frameTo) }
        let (used0, used1) = hours(clampedNow.map { Swift.min($0, first) } ?? first,
                                   clampedNow.map { Swift.max($0, last) } ?? last)
        // An hour of room, but not beyond the frame (unless the work lies there).
        var h0 = Swift.max(used0 - 1, Swift.min(frame0, used0))
        var h1 = Swift.min(used1 + 1, Swift.max(frame1, used1))
        // Up to the minimum height: below and above in turn, as far as the frame reaches.
        while h1 - h0 < minHours && (h1 < frame1 || h0 > frame0) {
            if h1 < frame1 { h1 += 1 }
            if h1 - h0 < minHours && h0 > frame0 { h0 -= 1 }
        }
        return (h0, h1)
    }

    /// Width of the day columns relative to each other: free days without any
    /// entry (usually the weekend) are narrow, so the workdays get the room.
    static func columnWeights(_ s: TTSettings, _ cols: [TTWeekColumn]) -> [Double] {
        var weights = Array(repeating: 1.0, count: 7)
        for (i, c) in cols.prefix(7).enumerated()
        where !s.isWorkday(c.date) && c.blocks.isEmpty && c.absence == nil {
            weights[i] = narrow
        }
        return weights
    }

    /// The columns of the week from `monday`.
    static func columns(_ snap: TTWeekSnapshot, monday: TTDate) -> [TTWeekColumn] {
        (0..<7).map { column(snap.days, snap, date: monday.adding(days: $0)) }
    }

    /// The column of the day `date` from `days` (normally `snap.days`; while
    /// dragging a copy with the new start or end of work).
    static func column(_ days: [TTDay], _ snap: TTWeekSnapshot, date: TTDate) -> TTWeekColumn {
        let s = snap.settings
        let today = snap.now.date
        var c = TTWeekColumn(date: date)
        guard let day = days.first(where: { $0.date == date }) else {
            let missing = !s.missingWorkdays(days, from: date, to: date, today: today).isEmpty
            c.missing = missing ? s.dailyTarget(date) : nil
            return c
        }
        let spans = day.spans(s)
        let nowSecs = snap.now.secs
        let n = spans.count
        var blocks = spans.enumerated().map { k, sp in
            TTWeekBlock(from: sp.from, to: sp.to, kind: .work,
                        running: snap.running && date == snap.now.date && k + 1 == n && sp.to >= nowSecs - 60,
                        notes: notes(day, s, sp, first: k == 0, last: k + 1 == n))
        }
        // A free day whose recorded time does not count has no start and end
        // until "Count recorded time" (as in the menu and the inspector), also
        // next to work away from the Mac.
        c.edges = day.uncounted ? nil : edges(day, s, blocks)
        // As with the warnings: blocks under a minute are not worth showing.
        blocks += day.outsideFrameSpans(s).filter { $0.len >= 60 }.map {
            TTWeekBlock(from: $0.from, to: $0.to, kind: .outside, running: false, notes: [])
        }
        blocks += day.uncountedAutoSpans(s).filter { $0.len >= 60 }.map {
            TTWeekBlock(from: $0.from, to: $0.to, kind: .freeDay, running: false, notes: [])
        }
        c.blocks = blocks
        let rec = day.record(s)
        c.workSecs = rec?.shownWorkSecs ?? 0
        c.pauseSecs = rec?.shownPauseSecs ?? 0
        c.warnings = TTWarning.dayWarnings(days, date: date, settings: s)
        c.manual = day.countedWork(s).map { TTWeekManual(span: $0.span, block: $0.block.span, note: $0.block.note) }
        c.gaps = day.pauses(s)
        c.absence = day.absence
        // Entries, but no working time (only a break, say): the target counts anyway.
        let record = rec ?? TTDayRecord(date: date, firstStart: 0, lastEnd: 0, workSecs: 0, shownWorkSecs: 0,
                                        shownPauseSecs: 0)
        if day.absence == nil && record.workSecs <= 0 {
            let target = s.countedTarget(day, record, today: today)
            c.missing = target > 0 ? target : nil
        }
        c.locked = day.locksEntries
        return c
    }

    /// Start and end of work from the blocks that count (`work`, in order),
    /// with the values without the manual entries.
    static func edges(_ day: TTDay, _ s: TTSettings, _ work: [TTWeekBlock]) -> TTWeekEdges? {
        guard let first = work.first, let last = work.last else { return nil }
        var withoutStart = day
        withoutStart.start = nil
        var withoutEnd = day
        withoutEnd.end = nil
        return TTWeekEdges(start: first.from, end: last.to,
                           autoStart: withoutStart.spans(s).first?.from,
                           autoEnd: withoutEnd.spans(s).last?.to,
                           manualStart: day.start != nil, manualEnd: day.end != nil, running: last.running)
    }

    /// Which bounds of a block were set by hand and when work away from the
    /// Mac lay in it.
    static func notes(_ day: TTDay, _ s: TTSettings, _ sp: TTSpan, first: Bool, last: Bool) -> [TTWeekNote] {
        var out: [TTWeekNote] = []
        let r = s.rules(day.date)
        if first, let start = day.start, start.ttClamped(r.frameFrom, r.frameTo) == sp.from {
            out.append(.startManual)
        }
        if day.breaks.contains(where: { $0.to == sp.from }) { out.append(.afterBreak) }
        if day.breaks.contains(where: { $0.from == sp.to }) { out.append(.beforeBreak) }
        for (w, block) in day.countedWork(s) where w.from >= sp.from && w.to <= sp.to {
            out.append(.away(w, block.note))
        }
        if last, let end = day.end, end.ttClamped(r.frameFrom, r.frameTo) == sp.to {
            out.append(.endManual)
        }
        return out
    }

    /// `Woche: 31:20 h  ·  Pausen: 3:05 h  ·  Saldo +0:08 h` (balance up to
    /// today, as in the panel).
    static func weekSummary(_ snap: TTWeekSnapshot, monday: TTDate, _ cols: [TTWeekColumn], _ t: TTWeekTexts) -> String {
        let (head, balance) = weekSummaryParts(snap, monday: monday, cols, t)
        return balance.map { head + TTFormat.balance($0) } ?? head
    }

    /// Like `weekSummary`, the balance apart (it is set in colour): the text
    /// then ends with "Saldo ".
    static func weekSummaryParts(_ snap: TTWeekSnapshot, monday: TTDate, _ cols: [TTWeekColumn],
                                 _ t: TTWeekTexts) -> (head: String, balance: Int?) {
        let total = cols.reduce(0) { $0 + $1.workSecs }
        let pauses = cols.reduce(0) { $0 + $1.pauseSecs }
        let today = snap.now.date
        if monday > today { return (t.week.summaryNone, nil) }
        let head = String(format: t.week.summaryFormat, TTExport.hoursMinutesUnit(total),
                          TTExport.hoursMinutesUnit(pauses))
        let to = Swift.min(monday.adding(days: 6), today)
        let (work, target) = snap.settings.balance(snap.days, from: monday, to: to, today: today)
        // Without working time and without target (time off, say) there is no balance.
        if work == 0 && target == 0 { return (head, nil) }
        return (head + t.week.summaryBalance, work - target)
    }

    /// Tooltip of a workday without working time and absence (`target`: the missing target).
    static func missingText(_ target: Int, _ t: TTWeekTexts) -> String {
        String(format: t.week.missingFormat, TTExport.hoursMinutesUnit(target))
    }

    /// `Hinweise an 2 Tagen` (empty without any).
    static func warningsSummary(_ cols: [TTWeekColumn], _ t: TTWeekTexts) -> String {
        switch cols.filter({ !$0.warnings.isEmpty }).count {
        case 0: return ""
        case 1: return t.week.warningsOneDay
        case let n: return String(format: t.week.warningsManyDaysFormat, n)
        }
    }

    /// `Di, 17.11.2026`
    static func shortDay(_ d: TTDate, _ t: TTWeekTexts) -> String {
        String(format: t.week.shortDayFormat, t.texts.weekdayShortNames[d.weekday], TTFormat.day(d, t.texts))
    }

    /// `Di 17.11.` in the day header.
    static func headerTitle(_ d: TTDate, _ t: TTWeekTexts) -> String {
        String(format: t.week.headerDateFormat, t.texts.weekdayShortNames[d.weekday], d.day, d.month)
    }

    /// `08:05 Uhr` / `08:05`.
    static func clock(_ secs: Int, _ t: TTWeekTexts) -> String {
        String(format: t.week.clockFormat, TTFormat.clock(secs))
    }

    /// The second line of a block: its duration, or "not counted".
    static func blockDetail(_ b: TTWeekBlock, _ t: TTWeekTexts) -> String {
        switch b.kind {
        case .work: return TTExport.hoursMinutesUnit(TTSpan.shownLen(from: b.from, to: b.to))
        case .outside, .freeDay: return t.week.notCounted
        }
    }

    /// What the day header shows below the date: the working time; without it
    /// the absence, on a workday without entry the missing target (otherwise a dash).
    static func headerTotal(_ c: TTWeekColumn, _ t: TTWeekTexts) -> String {
        if c.workSecs > 0 { return TTExport.hoursMinutesUnit(c.workSecs) }
        if let absence = c.absence { return absence.short(t.texts) }
        if let target = c.missing { return TTFormat.balance(-target) }
        return "–"
    }

    // MARK: Moving start and end of work

    /// Rust's `div_euclid` for a positive divisor.
    static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }

    /// Range in which `bound` can move: within the working-time frame (work
    /// only counts there) and the visible grid `grid`, at least `minDay` from
    /// the other end, today at most until now (`limit`, see `freeLimit`). In
    /// whole minutes.
    static func dragLimits(_ e: TTWeekEdges, _ bound: TTEditBound, _ s: TTWorkRules, limit: Int?,
                           grid: (Int, Int)) -> (lo: Int, hi: Int)? {
        guard let limit else { return nil }
        var (lo, hi): (Int, Int)
        switch bound {
        case .start: (lo, hi) = (Swift.max(s.frameFrom, grid.0), Swift.min(e.end - minDay, s.frameTo, limit))
        case .end: (lo, hi) = (Swift.max(e.start + minDay, s.frameFrom), Swift.min(s.frameTo, grid.1, limit))
        }
        (lo, hi) = (floorDiv(lo + 59, 60) * 60, floorDiv(hi, 60) * 60)
        return lo <= hi ? (lo, hi) : nil
    }

    /// The time while dragging at `raw`: on 5 minutes (`fine`: on the minute)
    /// within `limits`; closer than `magnet` to the value without manual entry
    /// (`auto`) it snaps there (second value `true`). The catch area reaches
    /// at most half a step, or the grid values right next to the recorded
    /// value (08:10 and 08:15 next to 08:12) would no longer be reachable.
    static func dragValue(_ raw: Int, auto: Int?, magnet: Int, fine: Bool, limits: (lo: Int, hi: Int)) -> (Int, Bool) {
        let step = fine ? 60 : 300
        let magnet = Swift.min(magnet, step / 2)
        if let a = auto, (limits.lo...limits.hi).contains(a), abs(raw - a) <= magnet {
            return (a, true)
        }
        return ((floorDiv(raw + step / 2, step) * step).ttClamped(limits.lo, limits.hi), false)
    }

    /// What is saved for `bound` when the edge stands at `at`: `nil` = change
    /// nothing, `.auto` = automatic again (at the value without the manual
    /// entry), otherwise the time.
    static func dragResult(_ e: TTWeekEdges, _ bound: TTEditBound, at: Int) -> TTBoundChange? {
        let (current, auto, manual) = e.get(bound)
        if at == auto { return manual ? .auto : nil }
        if manual && at == current { return nil }
        return .at(at)
    }

    /// `+25 Min.`, `−1:05 h` (minutes with sign).
    static func diffText(_ minutes: Int, _ t: TTWeekTexts) -> String {
        let sign = minutes > 0 ? "+" : "\u{2212}"
        let m = abs(minutes)
        return m < 60 ? String(format: t.week.diffMinutesFormat, sign, m)
            : String(format: t.week.diffHoursFormat, sign, m / 60, m % 60)
    }

    /// `Beginn 07:30 · +25 Min.`: the time while dragging and how far it is
    /// from the value before (`before`); at the value without manual entry
    /// `· automatisch`. `workDiff` is the change of the day's working time
    /// (seconds, by the shown minutes). When it differs from the move, the
    /// label names it (`· Arbeitszeit +1:45 h`): when a manual end after
    /// detached work away from the Mac lets the time since the last lock
    /// count (see `TTDay.setEnd`), or work away from the Mac goes.
    static func dragLabel(_ bound: TTEditBound, at: Int, before: Int, auto: Int?, workDiff: Int,
                          _ t: TTWeekTexts) -> String {
        let w = t.week
        var text = String(format: w.dragLabelFormat, bound == .start ? w.dragStart : w.dragEnd, TTFormat.clock(at))
        let diff = at / 60 - before / 60
        if at == auto {
            text += w.dragSeparator + w.dragAuto
        } else if diff != 0 {
            text += w.dragSeparator + diffText(diff, t)
        }
        // This much more working time the move alone would give.
        let expected = bound == .start ? -diff : diff
        let work = floorDiv(workDiff, 60)
        if work != expected {
            text += w.dragSeparator + (work == 0 ? w.dragWorkUnchanged : String(format: w.dragWorkFormat, diffText(work, t)))
        }
        return text
    }

    /// What the dialog "Change …" saves for `bound` with the entered time `at`
    /// (to the minute), like `dragResult`: `.success(nil)` = change nothing
    /// (also "Apply" without a change: the value stays automatic, there is no
    /// step to undo), `.success(.auto)` = automatic again (the minute of the
    /// recorded value), otherwise the time. The same limits as dragging apply
    /// (see `boundProblem`); the failure says why the time does not work.
    static func dialogResult(_ e: TTWeekEdges, _ bound: TTEditBound, at: Int, _ s: TTWorkRules, limit: Int?,
                             _ t: TTWeekTexts) -> Result<TTBoundChange?, TTWeekRefusal> {
        let (current, auto, _) = e.get(bound)
        // The field only shows minutes: the same minute is the same value.
        let value: Int
        if at / 60 == current / 60 {
            value = current
        } else if let auto, auto / 60 == at / 60 {
            value = auto
        } else {
            value = at
        }
        switch dragResult(e, bound, at: value) {
        // Back to the recorded value always works (like "reset").
        case nil: return .success(nil)
        case .auto?: return .success(.auto)
        case let .at(time)?:
            if let text = boundProblem(e, bound, at: time, s, limit: limit, t) { return .failure(TTWeekRefusal(text: text)) }
            return .success(.at(time))
        }
    }

    /// Why `bound` cannot be put at `at` (`nil`: it can). The same limits as
    /// dragging (`dragLimits`, without the visible grid): not in the future
    /// (`limit`, see `freeLimit`), start before end (`TTDay.boundsInOrder`, as
    /// in the panel and the inspector), within the frame and at least
    /// `minDay` from the other end.
    static func boundProblem(_ e: TTWeekEdges, _ bound: TTEditBound, at: Int, _ s: TTWorkRules, limit: Int?,
                             _ t: TTWeekTexts) -> String? {
        let w = t.week
        guard let limit else { return w.boundFuture }
        if at > limit { return bound == .start ? w.startFuture : w.endFuture }
        let (start, end) = bound == .start ? (at, e.end) : (e.start, at)
        if !TTDay.boundsInOrder(start: start, end: end) {
            return bound == .start ? String(format: w.startBeforeEndFormat, TTFormat.clock(e.end))
                : String(format: w.endAfterStartFormat, TTFormat.clock(e.start))
        }
        if !(s.frameFrom...s.frameTo).contains(at) {
            return String(format: bound == .start ? w.startFrameFormat : w.endFrameFormat, TTFormat.clock(s.frameFrom),
                          TTFormat.clock(s.frameTo))
        }
        if let (lo, hi) = dragLimits(e, bound, s, limit: limit, grid: (0, TTLimits.dayEnd)), (lo...hi).contains(at) {
            return nil
        }
        return String(format: w.minDayFormat, minDay / 60)
    }

    /// Sets `bound` of the day to `at` (`nil`: automatic); returns the work
    /// away from the Mac that goes with it.
    @discardableResult
    static func applyBound(_ day: inout TTDay, _ bound: TTEditBound, _ at: Int?) -> [TTSpan] {
        let cut = bound == .start ? day.setStart(at) : day.setEnd(at)
        return cut.map(\.span)
    }

    /// Computes the dragged day's column with the current value again.
    static func preview(_ d: inout TTWeekModel, _ g: inout TTWeekDrag) {
        guard let i = g.days.firstIndex(where: { $0.date == g.date }) else { return }
        var day = g.day
        g.cut = dragResult(g.edges, g.bound, at: g.at).map { applyBound(&day, g.bound, $0.value) } ?? []
        g.days[i] = day
        guard let snap = d.snap else { return }
        let col = column(g.days, snap, date: g.date)
        // As in the day header: by the shown times.
        let before = g.day.record(snap.settings)?.shownWorkSecs ?? 0
        g.workDiff = col.workSecs - before
        if d.cols.indices.contains(g.col) { d.cols[g.col] = col }
    }

    /// Catch areas of the edges: top of the first and bottom of the last block
    /// that counts (not the "now" of a running block, and not where nothing
    /// can change).
    static func edgeRects(_ geo: TTWeekGeometry, _ d: TTWeekModel) -> [(col: Int, bound: TTEditBound, rect: CGRect)] {
        guard let snap = d.snap else { return [] }
        let grid = (geo.h0 * 3600, geo.h1 * 3600)
        var out: [(col: Int, bound: TTEditBound, rect: CGRect)] = []
        for (i, c) in d.cols.enumerated() {
            // Absent all day: start and end are locked (see `TTDay.locksEntries`).
            guard let e = c.edges, !c.locked else { continue }
            let limit = freeLimit(c.date, now: snap.now)
            let rules = snap.settings.rules(c.date)
            let (x, w) = (geo.x(i) + 3, geo.colWidth(i) - 6)
            if dragLimits(e, .start, rules, limit: limit, grid: grid) != nil {
                let top = geo.y(e.start) + 0.5
                out.append((i, .start, CGRect(x: x, y: top - edgeOut, width: w, height: edgeOut + edgeIn)))
            }
            if !e.running && dragLimits(e, .end, rules, limit: limit, grid: grid) != nil {
                let bottom = geo.y(e.end) - 0.5
                out.append((i, .end, CGRect(x: x, y: bottom - edgeIn, width: w, height: edgeIn + edgeOut)))
            }
        }
        return out
    }

    /// VoiceOver: the start or end 5 minutes earlier or later (`later`), on
    /// the 5-minute grid within `limits`. `nil` when it goes no further.
    static func nudgeValue(_ current: Int, later: Bool, limits: (lo: Int, hi: Int)) -> Int? {
        let at = later ? (floorDiv(current, 300) + 1) * 300 : (floorDiv(current + 299, 300) - 1) * 300
        let clamped = at.ttClamped(limits.lo, limits.hi)
        return clamped == current ? nil : clamped
    }

    // MARK: Work away from the Mac

    /// Until which time of day work away from the Mac can be entered on
    /// `date`: today until now, on future days not at all.
    static func freeLimit(_ date: TTDate, now: TTDateTime) -> Int? {
        if date < now.date { return TTLimits.dayEnd - 60 }
        if date == now.date { return now.secs }
        return nil
    }

    /// The preset for work away from the Mac at a click at `at` into the
    /// column `c`: in a break the whole break, before the start and after the
    /// end 30 minutes (or the minimum `minWork`, when it is longer) from the
    /// click, rounded down to 5 minutes. When that hits "now" (or 23:59) and
    /// would stay shorter than the minimum, the preset starts earlier, as far
    /// as the free area reaches, otherwise it is the whole free area. The
    /// dialog takes the preset unchanged (see `workInput`). `nil` on a block
    /// and in the future.
    static func freePreset(_ c: TTWeekColumn, at: Int, now: TTDateTime, minWork: Int) -> TTSpan? {
        if c.locked { return nil }
        guard let limit = freeLimit(c.date, now: now) else { return nil }
        if !(0..<limit).contains(at) || c.blocks.contains(where: { ($0.from..<$0.to).contains(at) }) { return nil }
        if let gap = c.gaps.first(where: { ($0.from..<$0.to).contains(at) }) { return gap }
        let from = at / 300 * 300
        let to = Swift.min(from + Swift.max(freePresetSecs, minWork), limit)
        if TTSpan.shownLen(from: from, to: to) >= minWork { return TTSpan(from, to) }
        // Longer towards the front, but not into a block.
        let areaFrom = freeSpans(c, now: now).first { ($0.from..<$0.to).contains(at) }?.from ?? from
        let earlier = floorDiv(to / 60 * 60 - minWork, 300) * 300
        return TTSpan(Swift.min(Swift.max(earlier, areaFrom), from), to)
    }

    /// Checks the input of the dialog "Add work away from the Mac": `f` to `t`
    /// (to the minute) on the day with the breaks `pauses`, entered until at
    /// most `limit` (see `freeLimit`). Returns the span entered, otherwise why
    /// it is refused.
    ///
    /// The minimum `minWork` only guards against entries by mistake: the
    /// unchanged preset `preset` and an input that fills exactly one break
    /// also count when shorter, then to the second like preset or break, so
    /// no rest of the break stays.
    static func workInput(from f: Int, to t: Int, preset: TTSpan, pauses: [TTSpan], minWork: Int, limit: Int?,
                          _ x: TTWeekTexts) -> Result<TTSpan, TTWeekRefusal> {
        guard let limit else { return .failure(TTWeekRefusal(text: x.week.workFuture)) }
        if t <= f { return .failure(TTWeekRefusal(text: x.week.endBeforeStart)) }
        if t > limit { return .failure(TTWeekRefusal(text: x.week.endInFuture)) }
        func same(_ sp: TTSpan) -> Bool { sp.from / 60 == f / 60 && sp.to / 60 == t / 60 }
        if let sp = ([preset] + pauses).first(where: same) { return .success(sp) }
        if TTSpan.shownLen(from: f, to: t) < minWork {
            return .failure(TTWeekRefusal(text: TTRecords.minWorkText(minWork, x.records)))
        }
        return .success(TTSpan(f, t))
    }

    /// Free areas of a column (before the start, breaks, after the end) in
    /// which a click enters work away from the Mac.
    static func freeSpans(_ c: TTWeekColumn, now: TTDateTime) -> [TTSpan] {
        guard !c.locked, let limit = freeLimit(c.date, now: now) else { return [] }
        let blocks = c.blocks.map(\.span).ttStableSorted { $0.from < $1.from }
        var out: [TTSpan] = []
        var t = 0
        for b in blocks {
            out.append(TTSpan(t, Swift.min(b.from, limit)))
            t = Swift.max(t, b.to)
        }
        out.append(TTSpan(t, limit))
        return out.filter { $0.to > $0.from }
    }

    /// `12:03 – 12:58 Uhr (55 Min.)`
    static func spanText(_ sp: TTSpan, _ t: TTWeekTexts) -> String {
        let len = TTSpan.shownLen(from: sp.from, to: sp.to)
        let duration = len < 3600 ? String(format: t.texts.minutesFormat, len / 60) : TTExport.hoursMinutesUnit(len)
        return String(format: t.week.spanFormat, TTFormat.clock(sp.from), TTFormat.clock(sp.to), duration)
    }

    /// The label of work away from the Mac: its note or the reason ("Other" without a note).
    static func workLabel(_ note: String, _ t: TTWeekTexts) -> String {
        let trimmed = note.ttTrimmed
        return trimmed.isEmpty ? t.texts.activityOther : trimmed
    }

    /// Room for the label of width `w` in the hatching `r`: centred, else at
    /// the bottom or top edge, else right of the times; never over the times
    /// of the block (`taken`).
    static func workLabelRect(_ r: CGRect, taken: [CGRect], width w: CGFloat) -> CGRect? {
        let h: CGFloat = 12
        if w + 10 > r.width { return nil }
        let right = r.minX + r.width - 5
        func beside() -> CGRect? {
            // A line with a time that lies in the hatching: right-aligned next to it.
            let lines = taken.filter { $0.minY >= r.minY - 2 && $0.minY + h <= r.minY + r.height + 2 }
            guard let line = lines.min(by: { $0.minY < $1.minY }) else { return nil }
            let used = taken.filter { abs($0.minY - line.minY) < 1 }.map { $0.minX + $0.width }
                .reduce(-CGFloat.greatestFiniteMagnitude, Swift.max)
            return used + 8 + w <= right ? CGRect(x: right - w, y: line.minY + 1, width: w, height: h) : nil
        }
        if r.height < h { return beside() }
        func free(_ c: CGRect) -> Bool {
            !taken.contains { t in
                c.minX < t.minX + t.width && t.minX < c.minX + c.width
                    && c.minY < t.minY + t.height && t.minY < c.minY + c.height
            }
        }
        let pad = Swift.min((r.height - h) / 2, 1.5)
        let (y0, y1) = (r.minY + pad, r.minY + r.height - h - pad)
        let candidates = [r.minY + (r.height - h) / 2, y1, y0].map { CGRect(x: r.minX, y: $0, width: r.width, height: h) }
        return candidates.first(where: free) ?? beside()
    }

    /// `r` without the parts at the top and bottom that lie in one of `zones`.
    static func withoutZones(_ r: CGRect, _ zones: [CGRect]) -> CGRect {
        var (top, bottom) = (r.minY, r.minY + r.height)
        let (left, right) = (r.minX, r.minX + r.width)
        for z in zones {
            let (zt, zb) = (z.minY, z.minY + z.height)
            if z.minX >= right || z.minX + z.width <= left { continue }
            if zt <= top && top < zb { top = zb }
            if zt < bottom && bottom <= zb { bottom = zt }
        }
        return CGRect(x: r.minX, y: top, width: r.width, height: Swift.max(bottom - top, 0))
    }

    // MARK: Context menu

    /// The entries of the context menu for `ctx`: title and action (`nil` =
    /// display only, empty title = separator). Empty when there is nothing to
    /// do at the spot.
    static func contextEntries(_ ctx: TTWeekContext, canOpen: Bool, _ t: TTWeekTexts) -> [(title: String, action: TTWeekMenuAction?)] {
        let w = t.week
        var out: [(title: String, action: TTWeekMenuAction?)] = []
        if canOpen { out.append((t.records.editDay, .openDay)) }
        if let time = ctx.time { out.append((String(format: w.copyTimeFormat, time.text), .copyTime)) }
        if ctx.preset != nil { out.append((w.addWorkHere, .addWork)) }
        // With a check mark when the recorded time counts.
        if ctx.counting != nil { out.append((t.records.countRecorded, .toggleCounting)) }
        // Becomes the submenu with the kinds.
        if ctx.absenceEditable { out.append((t.records.sectionAbsence, .absence)) }
        if ctx.clearable { out.append((t.records.clearDay, .clearDay)) }
        if let work = ctx.work {
            if !out.isEmpty { out.append(("", nil)) }
            let what = work.note.isEmpty ? t.texts.workWithoutMac : work.note
            out.append((String(format: w.workLineFormat, what, spanText(work.block, t)), nil))
            out.append((w.deleteWork, .removeWork))
        }
        if let e = ctx.edges, !ctx.bounds.isEmpty {
            if !out.isEmpty { out.append(("", nil)) }
            for bound in ctx.bounds {
                out.append((bound == .start ? w.changeStart : w.changeEnd, .change(bound)))
                let (_, auto, manual) = e.get(bound)
                if let auto, manual {
                    out.append((String(format: bound == .start ? w.resetStartFormat : w.resetEndFormat,
                                       TTFormat.clock(auto)), .reset(bound)))
                }
            }
        }
        if out.isEmpty { return out }
        // The day as a heading.
        return [(shortDay(ctx.date, t), nil), ("", nil)] + out
    }

    /// The items of the submenu "Absence" (`busy`: the day has other entries,
    /// whole days only after deleting them, see `TTDay.acceptsAbsence`). On a
    /// day without a target (`noTarget`) no absence can be entered, an
    /// existing one only removed: then there are only "None" and that one.
    static func absenceEntries(current: TTAbsence?, busy: Bool, noTarget: Bool, _ t: TTWeekTexts) -> [TTWeekAbsenceItem] {
        func item(_ title: String, _ tag: Int, _ checked: Bool, _ enabled: Bool) -> TTWeekAbsenceItem {
            TTWeekAbsenceItem(title: title, tag: tag, checked: checked, enabled: enabled)
        }
        var out = [item(t.records.absenceNone, 0, current == nil, true), item("", -1, false, false)]
        if noTarget {
            if let current { out.append(item(current.label(t.texts), absenceTag(current), true, true)) }
            out.append(item("", -1, false, false))
            out.append(item(t.week.absenceFreeDay, -1, false, false))
            return out
        }
        for kind in TTAbsenceKind.all {
            // Half days with vacation, sickness and holidays.
            for half in kind.allowsHalf ? [false, true] : [false] {
                let a = TTAbsence(kind, half: half)
                let checked = current == a
                out.append(item(a.label(t.texts), absenceTag(a), checked, checked || half || !busy))
            }
        }
        if busy {
            out.append(item("", -1, false, false))
            out.append(item(t.week.absenceBlocked, -1, false, false))
        }
        return out
    }

    /// The tag of the menu item for `a` in the submenu "Absence" (see `absence(ofTag:)`).
    static func absenceTag(_ a: TTAbsence) -> Int {
        let i = TTAbsenceKind.all.firstIndex(of: a.kind) ?? 0
        return 1 + 2 * i + (a.half ? 1 : 0)
    }

    /// The choice in the submenu "Absence" (`nil`: no choice, display only).
    static func absence(ofTag tag: Int) -> TTWeekAbsenceChoice? {
        if tag == 0 { return TTWeekAbsenceChoice(absence: nil) }
        guard tag > 0 else { return nil }
        let i = (tag - 1) / 2
        guard TTAbsenceKind.all.indices.contains(i) else { return nil }
        return TTWeekAbsenceChoice(absence: TTAbsence(TTAbsenceKind.all[i], half: (tag - 1) % 2 == 1))
    }

    // MARK: VoiceOver

    /// Text to read: without the separators of the display.
    static func spoken(_ text: String) -> String {
        text.replacingOccurrences(of: "  ·  ", with: ", ")
    }

    /// `3 Std. 35 Min.` or `45 Min.` (to read; VoiceOver reads `3:35 h` as a time).
    static func spokenDuration(_ secs: Int, _ t: TTWeekTexts) -> String {
        let m = Swift.max(secs, 0) / 60
        switch (m / 60, m % 60) {
        case let (0, min): return String(format: t.week.spokenMinutesFormat, min)
        case let (h, 0): return String(format: t.week.spokenHoursFormat, h)
        case let (h, min): return String(format: t.week.spokenHoursMinutesFormat, h, min)
        }
    }

    /// Appends `more` as another sentence (without a double point after "Min.").
    static func addSentence(_ text: inout String, _ more: String) {
        TTSentence.append(more, to: &text)
    }

    /// `Dienstag, 17. November`
    static func spokenDay(_ d: TTDate, _ t: TTWeekTexts) -> String {
        String(format: t.week.axDayFormat, t.records.weekdayNames[d.weekday], d.day, t.records.monthNames[d.month - 1])
    }

    /// What VoiceOver reads in the week: per day the header with working time,
    /// breaks and warnings, then the blocks, breaks and work away from the Mac
    /// in order.
    static func axItems(_ cols: [TTWeekColumn], _ t: TTWeekTexts) -> [(col: Int, part: TTWeekAxPart, text: String)] {
        let w = t.week
        var out: [(col: Int, part: TTWeekAxPart, text: String)] = []
        for (i, c) in cols.enumerated() {
            let day = spokenDay(c.date, t)
            var head = c.blocks.isEmpty ? String(format: w.axNoWorkFormat, day)
                : String(format: w.axWorkFormat, day, spokenDuration(c.workSecs, t), spokenDuration(c.pauseSecs, t))
            if let absence = c.absence { addSentence(&head, absence.label(t.texts)) }
            if let target = c.missing { addSentence(&head, String(format: w.axMissingFormat, spokenDuration(target, t))) }
            for warning in c.warnings { addSentence(&head, String(format: w.axWarningFormat, warning.text(t.texts))) }
            out.append((i, .header, head))

            func range(_ sp: TTSpan) -> String {
                String(format: w.axRangeFormat, TTFormat.clock(sp.from), TTFormat.clock(sp.to))
            }
            var parts: [(span: TTSpan, text: String)] = []
            for b in c.blocks {
                let sp = b.span
                let len = spokenDuration(TTSpan.shownLen(from: b.from, to: b.to), t)
                var text: String
                switch (b.kind, b.running) {
                case (.outside, _): text = String(format: w.axOutsideFormat, range(sp), len)
                case (.freeDay, _): text = String(format: w.axFreeDayFormat, range(sp), len)
                case (.work, true): text = String(format: w.axRunningFormat, clock(b.from, t), len)
                case (.work, false): text = String(format: w.axWorkSpanFormat, range(sp), len)
                }
                // Work away from the Mac is an element of its own (below).
                for note in b.notes where !note.isAway { addSentence(&text, note.text(t)) }
                parts.append((sp, text))
            }
            for g in c.gaps {
                parts.append((g, String(format: w.axPauseFormat, range(g),
                                        spokenDuration(TTSpan.shownLen(from: g.from, to: g.to), t))))
            }
            for m in c.manual {
                let what = m.note.isEmpty ? w.axAway : String(format: w.axAwayNoteFormat, m.note)
                parts.append((m.span, String(format: w.axAwaySpanFormat, what, range(m.span))))
            }
            parts = parts.ttStableSorted { ($0.span.from, $0.span.to) < ($1.span.from, $1.span.to) }
            out += parts.map { (i, .span($0.span), $0.text) }
        }
        return out
    }

    // MARK: Tooltips

    /// The tooltip of a day header: working time, breaks, absence, missing
    /// target, warnings and the double-click (`canOpen`).
    static func headerTip(_ c: TTWeekColumn, canOpen: Bool, editable: Bool, _ t: TTWeekTexts) -> String {
        let w = t.week
        let day = shortDay(c.date, t)
        var lines: [String] = []
        if c.workSecs > 0 {
            lines.append(String(format: w.tipDayFormat, day, TTExport.hoursMinutesUnit(c.workSecs),
                                TTExport.hoursMinutesUnit(c.pauseSecs)))
        }
        if let absence = c.absence {
            if lines.isEmpty { lines.append(day) }
            lines.append(absence.label(t.texts))
            if c.locked && editable { lines.append(w.tipLocked) }
        }
        if let target = c.missing {
            lines.append(day)
            lines.append(missingText(target, t))
        }
        var text = lines.joined(separator: "\n")
        if !c.warnings.isEmpty {
            text += text.isEmpty ? String(format: w.tipWarningsForFormat, day) : "\n\n" + w.tipWarnings
            for warning in c.warnings { text += "\n" + String(format: w.tipBulletFormat, warning.text(t.texts)) }
        }
        if canOpen { text += (text.isEmpty ? "" : "\n\n") + w.tipDoubleClick }
        return text
    }

    /// The tooltip of a block: day, times, duration, kind and notes, and what
    /// clicks and drags do there.
    static func blockTip(_ c: TTWeekColumn, _ b: TTWeekBlock, boundsEditable: Bool, editable: Bool,
                         _ t: TTWeekTexts) -> String {
        let w = t.week
        let end = b.running ? w.tipRunning : clock(b.to, t)
        var lines = [String(format: w.tipBlockFormat, shortDay(c.date, t), TTFormat.clock(b.from), end,
                            TTExport.hoursMinutesUnit(TTSpan.shownLen(from: b.from, to: b.to)))]
        if b.kind == .outside { lines.append(w.tipOutside) }
        if b.kind == .freeDay {
            lines.append(w.tipFreeDay)
            if editable { lines.append(w.tipCountHint) }
        }
        lines += b.notes.map { $0.text(t) }
        lines.append(w.tipClick)
        if let e = c.edges, boundsEditable && !c.locked, b.kind == .work {
            if b.from == e.start { lines.append(w.tipDragTop) }
            if b.to == e.end && !e.running { lines.append(w.tipDragBottom) }
        }
        if editable && !c.locked && c.manual.contains(where: { $0.span.from < b.to && $0.span.to > b.from }) {
            lines.append(w.tipHatch)
        }
        return lines.joined(separator: "\n")
    }

    /// The tooltip of a break between blocks.
    static func gapTip(_ c: TTWeekColumn, _ gap: TTSpan, _ t: TTWeekTexts) -> String {
        String(format: t.week.tipGapFormat, shortDay(c.date, t), spanText(gap, t))
    }
}
