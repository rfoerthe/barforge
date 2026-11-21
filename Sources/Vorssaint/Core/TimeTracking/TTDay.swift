// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

// Day model: automatically recorded periods plus manual corrections (port of
// Tagwerk's `day.rs`).
//
// The recorded periods (Mac unlocked) stay as they are. Manual decisions (start
// of work, breaks, work away from the Mac, end of work) are a layer of their
// own on top; the working time is computed from both and the rules:
//
// 1. Work away from the Mac counts like unlocked time; gaps shorter than the
//    minimum break count as work.
// 2. A manual start and end of work lengthen or shorten the day. For work away
//    from the Mac the latest entry wins: setting the start or end cuts such
//    work before or after it (`setStart`, `setEnd`); entering it afterwards
//    lets it count before the start or after the end as well.
// 3. Manual breaks are subtracted.
// 4. Only what lies within the working-time frame counts.
//
// On free days (weekend, deselected workdays) the recorded time only counts
// after "Record today" (`TTDay.freeDay`); until then it is recorded but not
// counted, like time outside the frame. Work away from the Mac always counts;
// start and end of work only apply once the recorded time counts.
//
// After the end of work recording goes on without counting, so taking the end
// back returns the time in between.
//
// All times are seconds since midnight (`0...TTLimits.dayEnd`).

/// A break entered by hand.
struct TTBreak: Hashable, Sendable {
    var from: Int
    var to: Int

    init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }

    var span: TTSpan { TTSpan(from, to) }
}

/// Work away from the Mac (a call or meeting while it was locked), entered
/// afterwards or through "Keep working away from the Mac".
struct TTWorkBlock: Hashable, Sendable {
    var from: Int
    var to: Int
    /// Free note such as "Meeting" (empty: none).
    var note: String

    init(from: Int, to: Int, note: String) {
        self.from = from
        self.to = to
        self.note = note
    }

    var span: TTSpan { TTSpan(from, to) }

    /// `Meeting 08:00–09:00`, without a note `Arbeit ohne Mac 08:00–09:00`.
    func describe(_ texts: TimeTrackingTexts) -> String {
        String(format: texts.workBlockFormat, note.isEmpty ? texts.workWithoutMac : note,
               TTFormat.clock(from), TTFormat.clock(to))
    }
}

/// New work away from the Mac after `TTDay.joinWorkGaps`: the extended block
/// and what was added to it.
struct TTJoined: Hashable, Sendable {
    var span: TTSpan
    /// Gaps to neighbouring working time (recorded or away from the Mac).
    var gaps: [TTSpan]
    /// What was left of manual breaks the new block cut into.
    var rests: [TTSpan]

    /// Note after entering the block (`nil` when nothing worth mentioning was
    /// added). Rests under a minute go unmentioned: they only exist because
    /// input is by the minute while recording is by the second.
    func note(minPause: Int, _ texts: TimeTrackingTexts) -> String? {
        let gaps = self.gaps.filter { $0.len >= 60 }
        let rests = self.rests.filter { $0.len >= 60 }
        func list(_ spans: [TTSpan]) -> String {
            spans.map {
                String(format: texts.joinedSpanFormat, TTFormat.clock($0.from), TTFormat.clock($0.to),
                       TTFormat.minutes($0.len, texts))
            }
            .joined(separator: texts.andSeparator)
        }
        var out: [String] = []
        switch rests.count {
        case 0: break
        case 1: out.append(String(format: texts.joinedRestOneFormat, list(rests)))
        default: out.append(String(format: texts.joinedRestManyFormat, list(rests)))
        }
        switch gaps.count {
        case 0: break
        case 1: out.append(String(format: texts.joinedGapOneFormat, list(gaps)))
        default: out.append(String(format: texts.joinedGapManyFormat, list(gaps)))
        }
        if out.isEmpty { return nil }
        let summary = gaps.count + rests.count == 1 ? texts.joinedSummaryOneFormat : texts.joinedSummaryEachFormat
        out.append(String(format: summary, TTFormat.minutes(minPause, texts),
                          TTFormat.clock(span.from), TTFormat.clock(span.to)))
        return out.joined(separator: " ")
    }
}

/// Reason for work away from the Mac (menu bar, week view, records); gives the note.
enum TTActivity: CaseIterable, Sendable {
    case meeting, call, networking, other

    /// In the order of the choice.
    static let all: [TTActivity] = [.meeting, .call, .networking, .other]

    /// Name in menus and pickers.
    func label(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case .meeting: return texts.activityMeeting
        case .call: return texts.activityCall
        case .networking: return texts.activityNetworking
        case .other: return texts.activityOther
        }
    }

    /// Note on the work block (empty for "Other").
    func note(_ texts: TimeTrackingTexts) -> String {
        self == .other ? "" : label(texts)
    }

    var id: Int {
        switch self {
        case .meeting: return 1
        case .call: return 2
        case .networking: return 3
        case .other: return 0
        }
    }

    static func from(id: Int) -> TTActivity {
        all.first { $0.id == id } ?? .other
    }

    /// Short key for persisted state.
    var key: String {
        switch self {
        case .meeting: return "meeting"
        case .call: return "call"
        case .networking: return "networking"
        case .other: return "other"
        }
    }

    static func from(key: String) -> TTActivity {
        all.first { $0.key == key } ?? .other
    }
}

/// Kind of an absence.
enum TTAbsenceKind: CaseIterable, Sendable {
    case vacation
    /// Special leave (wedding, moving house, bereavement): lowers the target
    /// like vacation but always for the whole day.
    case specialLeave
    case sick
    case holiday
    /// Time off in lieu of overtime: the target stays, the time account goes down.
    case timeOff

    /// In the order of the choice.
    static let all: [TTAbsenceKind] = [.vacation, .specialLeave, .sick, .holiday, .timeOff]

    func label(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case .vacation: return texts.absenceVacation
        case .specialLeave: return texts.absenceSpecialLeave
        case .sick: return texts.absenceSick
        case .holiday: return texts.absenceHoliday
        case .timeOff: return texts.absenceTimeOff
        }
    }

    /// Code for the table of days: `U`, `SU`, `K`, `F`, `ZA` in German.
    func code(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case .vacation: return texts.absenceCodeVacation
        case .specialLeave: return texts.absenceCodeSpecialLeave
        case .sick: return texts.absenceCodeSick
        case .holiday: return texts.absenceCodeHoliday
        case .timeOff: return texts.absenceCodeTimeOff
        }
    }

    /// Value in the database.
    var id: Int {
        switch self {
        case .vacation: return 1
        case .sick: return 2
        case .holiday: return 3
        case .timeOff: return 4
        case .specialLeave: return 5
        }
    }

    static func from(id: Int) -> TTAbsenceKind? {
        all.first { $0.id == id }
    }

    /// Does the absence lower the target? Time off does not: there the time
    /// account is meant to go down.
    var reducesTarget: Bool { self != .timeOff }

    /// Is there a half day of it? For vacation, sickness and holidays; special
    /// leave and time off are always whole days.
    var allowsHalf: Bool { self == .vacation || self == .sick || self == .holiday }
}

/// Absence on a day: vacation, sickness and holidays lower its target to zero
/// or (half day) to half, special leave to zero. Time off keeps the target.
struct TTAbsence: Hashable, Sendable {
    let kind: TTAbsenceKind
    /// Only half the day (always `false` where `kind.allowsHalf` is not).
    let half: Bool

    init(_ kind: TTAbsenceKind, half: Bool) {
        self.kind = kind
        self.half = half && kind.allowsHalf
    }

    /// `Urlaub` or `Urlaub (halber Tag)`, as in the export.
    func label(_ texts: TimeTrackingTexts) -> String {
        half ? String(format: texts.absenceHalfFormat, kind.label(texts)) : kind.label(texts)
    }

    /// Short for tables: `Urlaub` or `½ Urlaub`.
    func short(_ texts: TimeTrackingTexts) -> String {
        half ? String(format: texts.absenceShortHalfFormat, kind.label(texts)) : kind.label(texts)
    }

    /// Code for the table of days: `U`, `SU`, `K`, `F`, `ZA`, half days with `½`.
    func code(_ texts: TimeTrackingTexts) -> String {
        half ? String(format: texts.absenceShortHalfFormat, kind.code(texts)) : kind.code(texts)
    }

    /// Reads `label` back (case does not matter).
    static func parse(_ text: String, _ texts: TimeTrackingTexts) -> TTAbsence? {
        let text = text.ttTrimmed.lowercased()
        guard let kind = TTAbsenceKind.all.first(where: { text.hasPrefix($0.label(texts).lowercased()) }) else {
            return nil
        }
        return TTAbsence(kind, half: text.contains(texts.absenceHalfMarker.lowercased()) || text.contains("½"))
    }
}

/// What applies to automatic recording on a free day (weekend, deselected workday).
enum TTFreeDay: CaseIterable, Sendable {
    /// Recorded, but not counted.
    case uncounted
    /// "Record today": the recorded time counts.
    case counted
    /// All entries deleted: nothing is recorded until "Record today".
    case stopped

    /// Does the automatically recorded time count?
    var counts: Bool { self == .counted }

    /// Value in the database.
    var id: Int {
        switch self {
        case .uncounted: return 0
        case .counted: return 1
        case .stopped: return 2
        }
    }

    static func from(id: Int) -> TTFreeDay? {
        allCases.first { $0.id == id }
    }

    /// Note in the Markdown export.
    func label(_ texts: TimeTrackingTexts) -> String {
        switch self {
        case .uncounted: return texts.freeDayUncounted
        case .counted: return texts.freeDayCounted
        case .stopped: return texts.freeDayStopped
        }
    }

    /// From the note in the export (see `label`).
    static func parse(_ text: String, _ texts: TimeTrackingTexts) -> TTFreeDay {
        let text = text.lowercased()
        if text.contains(texts.freeDayStoppedMarker.lowercased()) { return .stopped }
        if text.contains(texts.freeDayNegationMarker.lowercased()) { return .uncounted }
        return .counted
    }
}

/// State of a day as far as the manual decisions go.
enum TTMode: Hashable, Sendable {
    /// Normal, automatic recording.
    case auto
    /// End of work at the given time.
    case closed(Int)
}

/// Figures of a day (what the table shows).
struct TTDayRecord: Hashable, Sendable {
    let date: TTDate
    /// Start (first unlock or set by hand, at the earliest the start of the frame).
    let firstStart: Int
    /// End (last lock or set by hand, at the latest the end of the frame).
    let lastEnd: Int
    /// Working time in seconds, to the second (export, warnings).
    let workSecs: Int
    /// Working time to show: the sum of the blocks by their shown times (see
    /// `TTSpan.shownLen`). With `shownPauseSecs` it is exactly end − start as
    /// shown, and days add up to the week without rounding remainders.
    let shownWorkSecs: Int
    /// Breaks to show: the sum of the single breaks by their shown times.
    let shownPauseSecs: Int

    /// Breaks = time between start and end without work, to the second.
    var pauseSecs: Int { Swift.max((lastEnd - firstStart) - workSecs, 0) }
}

/// A working day with raw data and corrections.
struct TTDay: Hashable, Sendable {
    var date: TTDate
    /// Recorded automatically (Mac unlocked), sorted and without overlaps.
    var periods: [TTSpan] = []
    /// Start of work set by hand.
    var start: Int?
    /// End of work set by hand.
    var end: Int?
    /// Breaks entered by hand.
    var breaks: [TTBreak] = []
    /// Work away from the Mac, sorted and without overlaps.
    var work: [TTWorkBlock] = []
    /// Absence (vacation, special leave, sick, holiday, time off); only changes the target.
    var absence: TTAbsence?
    /// Free day: what applies to automatic recording (set at the first unlock,
    /// see `TTSettings.autoCountsOn`). `nil`: it counts as always, so changed
    /// settings never change past days.
    var freeDay: TTFreeDay?

    init(date: TTDate) {
        self.date = date
    }

    var hasCorrections: Bool {
        start != nil || end != nil || !breaks.isEmpty || !work.isEmpty || absence != nil
    }

    /// Nothing to store (not even a decision about recording on a free day).
    var isEmpty: Bool {
        periods.isEmpty && !hasCorrections && freeDay == nil
    }

    /// Does the automatically recorded time count (see `freeDay`)?
    var periodsCount: Bool { freeDay?.counts ?? true }

    /// Free day whose recorded time does not count (yet). Start, breaks and end
    /// cannot be set then; work away from the Mac counts as always.
    var uncounted: Bool { !periodsCount }

    /// Recorded times that count (none on an uncounted free day).
    private var countedPeriods: [TTSpan] { periodsCount ? periods : [] }

    /// Are there entries besides the absence (recorded time or corrections)?
    var hasEntries: Bool {
        !periods.isEmpty || start != nil || end != nil || !breaks.isEmpty || !work.isEmpty
    }

    /// Are there entries made by hand (start, end, breaks, work away from the Mac)?
    var hasManualEntries: Bool {
        start != nil || end != nil || !breaks.isEmpty || !work.isEmpty
    }

    /// Can `absence` be entered (`today`: the day is today)? A whole-day absence
    /// only on a day without other entries; a half day also next to working
    /// time. Today only entries by hand count: recording adds times again at
    /// every unlock, and they go with the absence (`clearsForAbsence`). No
    /// absence is always possible.
    func acceptsAbsence(_ absence: TTAbsence?, today: Bool) -> Bool {
        (absence?.half ?? true) || !blocksFullAbsence(today: today)
    }

    /// Do the entries prevent a whole-day absence (`today`: see `acceptsAbsence`)?
    func blocksFullAbsence(today: Bool) -> Bool {
        today ? hasManualEntries : hasEntries
    }

    /// Does `absence` clear today's recorded times (whole day next to recorded time)?
    func clearsForAbsence(_ absence: TTAbsence?, today: Bool) -> Bool {
        guard today, let absence, !absence.half else { return false }
        return !periods.isEmpty && acceptsAbsence(absence, today: true)
    }

    /// Does a whole-day absence lock the other entries? Then they can neither
    /// be entered nor changed by hand until the absence is "None" again.
    var locksEntries: Bool { absence.map { !$0.half } ?? false }

    /// Adds a recorded period (overlapping ones merge).
    mutating func addPeriod(from: Int, to: Int) {
        guard to >= from else { return }
        periods.append(TTSpan(from.ttClamped(0, TTLimits.dayEnd), to.ttClamped(0, TTLimits.dayEnd)))
        periods = TTSpan.union(periods)
    }

    var mode: TTMode {
        end.map { .closed($0) } ?? .auto
    }

    /// Sets the start of work (`nil`: the first unlock again). Work away from
    /// the Mac before it goes or starts there; the latest entry wins, as with
    /// breaks. Returns what was cut.
    @discardableResult
    mutating func setStart(_ at: Int?) -> [TTWorkBlock] {
        start = at
        guard let at else { return [] }
        return takeWork(from: 0, to: at)
    }

    /// Sets the end of work (`nil`: the last lock again). Work away from the Mac
    /// after it goes or ends there. Returns what was cut.
    @discardableResult
    mutating func setEnd(_ at: Int?) -> [TTWorkBlock] {
        end = at
        guard let at else { return [] }
        return takeWork(from: at, to: TTLimits.dayEnd)
    }

    /// Removes work away from the Mac between `from` and `to`; returns the removed parts.
    private mutating func takeWork(from: Int, to: Int) -> [TTWorkBlock] {
        let taken = work.compactMap { block -> TTWorkBlock? in
            let (a, b) = (Swift.max(block.from, from), Swift.min(block.to, to))
            return b > a ? TTWorkBlock(from: a, to: b, note: block.note) : nil
        }
        cutWork(from: from, to: to)
        return taken
    }

    mutating func sortBreaks() {
        breaks = breaks.ttStableSorted { ($0.from, $0.to) < ($1.from, $1.to) }
    }

    /// Enters a manual break. Work away from the Mac in that time goes (the
    /// latest entry wins).
    mutating func addBreak(from: Int, to: Int) {
        let (from, to) = (from.ttClamped(0, TTLimits.dayEnd), to.ttClamped(0, TTLimits.dayEnd))
        guard to > from else { return }
        cutWork(from: from, to: to)
        breaks.append(TTBreak(from: from, to: to))
        sortBreaks()
    }

    /// Removes work away from the Mac between `from` and `to` (blocks are
    /// shortened or split).
    mutating func cutWork(from: Int, to: Int) {
        let cut = TTSpan(from, to)
        work = work.flatMap { block in
            TTSpan.subtract([block.span], cut).map { TTWorkBlock(from: $0.from, to: $0.to, note: block.note) }
        }
    }

    /// Enters work away from the Mac. Older work away from the Mac and manual
    /// breaks in that time go (the latest entry wins); adjoining blocks stay
    /// blocks of their own.
    mutating func addWork(from: Int, to: Int, note: String) {
        let (from, to) = (from.ttClamped(0, TTLimits.dayEnd), to.ttClamped(0, TTLimits.dayEnd))
        guard to > from else { return }
        let cut = TTSpan(from, to)
        breaks = breaks.flatMap { TTSpan.subtract([$0.span], cut) }.map { TTBreak(from: $0.from, to: $0.to) }
        cutWork(from: from, to: to)
        work.append(TTWorkBlock(from: from, to: to, note: note.ttTrimmed))
        work = work.ttStableSorted { ($0.from, $0.to) < ($1.from, $1.to) }
    }

    /// Extends new work away from the Mac `from`–`to` so that no gap and no
    /// manual break under the minimum break `minPause` is left:
    /// - If it cuts into a manual break, a rest under the minimum break joins
    ///   the new work (otherwise a break would remain that cannot be entered).
    /// - A gap to neighbouring work under the minimum break (without a manual
    ///   break in it) joins as well.
    func joinWorkGaps(from: Int, to: Int, minPause: Int) -> TTJoined {
        var joined = TTJoined(span: TTSpan(from, to), gaps: [], rests: [])
        func short(_ gap: TTSpan) -> Bool { gap.len > 0 && gap.len < minPause }
        // Rests of manual breaks the new block cuts into.
        for b in breaks {
            let left = TTSpan(b.from, from)
            if b.from < from && b.to > from && short(left) {
                joined.span.from = Swift.min(joined.span.from, b.from)
                joined.rests.append(left)
            }
            let right = TTSpan(to, b.to)
            if b.from < to && b.to > to && short(right) {
                joined.span.to = Swift.max(joined.span.to, b.to)
                joined.rests.append(right)
            }
        }
        let (newFrom, newTo) = (joined.span.from, joined.span.to)
        let manualBreaks = breaks
        func free(_ gap: TTSpan) -> Bool {
            short(gap) && !manualBreaks.contains { $0.from < gap.to && $0.to > gap.from }
        }
        // End of the work before and start of the work after, recorded or away
        // from the Mac (what overlaps adjoins directly once entered).
        let spans = unframedSpans(minPause: minPause)
        if let prev = spans.filter({ $0.from < newFrom }).map({ Swift.min($0.to, newFrom) }).max() {
            let gap = TTSpan(prev, newFrom)
            if free(gap) {
                joined.span.from = prev
                joined.gaps.append(gap)
            }
        }
        if let next = spans.filter({ $0.to > newTo }).map({ Swift.max($0.from, newTo) }).min() {
            let gap = TTSpan(newTo, next)
            if free(gap) {
                joined.span.to = next
                joined.gaps.append(gap)
            }
        }
        joined.rests = joined.rests.ttStableSorted { $0.from < $1.from }
        return joined
    }

    /// Breaks of the day: gaps between the blocks of work (by the settings `s`).
    func pauses(_ s: TTSettings) -> [TTSpan] {
        let spans = self.spans(s)
        return zip(spans, spans.dropFirst()).map { TTSpan($0.to, $1.from) }
    }

    /// Work away from the Mac that counts within the frame (without manual
    /// breaks and after the end of work), with the block it comes from.
    func countedWork(_ s: TTSettings) -> [(span: TTSpan, block: TTWorkBlock)] {
        let spans = self.spans(s)
        return work.flatMap { block in
            spans.compactMap { sp -> (span: TTSpan, block: TTWorkBlock)? in
                let c = TTSpan(Swift.max(block.from, sp.from), Swift.min(block.to, sp.to))
                return c.to > c.from ? (c, block) : nil
            }
        }
    }

    /// Blocks of work without the working-time frame (steps 1–3, `day.rs:674`).
    func unframedSpans(minPause: Int) -> [TTSpan] {
        let manual = work.map(\.span)
        var spans = TTSpan.fillGaps(countedPeriods + manual, minPause: minPause)
        // A manual start counts until the first unlock after it, a manual end
        // from the last lock before it, also in a gap like the locked lunch
        // time. What was unlocked before the start or after the end goes anyway
        // and changes nothing (otherwise the day would depend on an early or
        // late glance at the Mac). The reference is the unlock or lock, also
        // with work away from the Mac before or after (it would shorten the day).
        let unlocked = TTSpan.fillGaps(countedPeriods, minPause: minPause)
        // On a free day whose recorded time does not count, start and end do
        // not apply either: they cannot be set there and can only stem from
        // before; without recorded time they would fill the whole span between.
        let (start, end) = uncounted ? (nil, nil) : (self.start, self.end)
        if let s = start {
            // Start before an unlock: the time until the first unlock after it counts.
            let first: Int
            if unlocked.isEmpty {
                first = spans.first?.from ?? end ?? s
            } else {
                // After the last lock there is no unlock anything could count up to.
                first = unlocked.first { $0.to > s }?.from ?? s
            }
            if s < first { spans.insert(TTSpan(s, first), at: 0) }
            spans = TTSpan.clip(spans, s, TTLimits.dayEnd)
        }
        if let e = end {
            // End after a lock: the time since the last lock before it counts.
            func fromStart(_ to: Int) -> Int { Swift.max(to, start ?? 0) }
            let last: Int
            if unlocked.isEmpty {
                last = spans.last.map { fromStart($0.to) } ?? start ?? e
            } else {
                // Before the first unlock there is no lock anything could count from.
                last = unlocked.last { $0.from < e }.map { fromStart($0.to) } ?? e
            }
            if e > last { spans.append(TTSpan(last, e)) }
            spans = TTSpan.clip(spans, 0, e)
        }
        // Work away from the Mac entered explicitly also counts before the
        // start and after the end of work.
        spans.append(contentsOf: manual)
        spans = TTSpan.union(spans)
        for b in breaks {
            spans = TTSpan.subtract(spans, b.span)
        }
        return spans
    }

    /// Effective blocks of work by the settings `s`.
    func spans(_ s: TTSettings) -> [TTSpan] {
        let r = s.rules(date)
        return TTSpan.clip(unframedSpans(minPause: r.minPause), r.frameFrom, r.frameTo)
    }

    /// Working time outside the working-time frame (not counted).
    func outsideFrameSpans(_ s: TTSettings) -> [TTSpan] {
        let r = s.rules(date)
        let all = unframedSpans(minPause: r.minPause)
        return TTSpan.clip(all, 0, r.frameFrom) + TTSpan.clip(all, r.frameTo, TTLimits.dayEnd)
    }

    /// Blocks of work including the time outside the frame, for the rules of
    /// the Working Hours Act (rest, maximum hours, breaks), which ask about the
    /// actual work and not about what counts. Blocks outside the frame under a
    /// minute stay out, as in the warning about them; so does what is recorded
    /// but not counted on a free day, and what lies after the end of work.
    func actualSpans(_ s: TTSettings) -> [TTSpan] {
        TTSpan.union(spans(s) + outsideFrameSpans(s).filter { $0.len >= 60 })
    }

    /// Recorded but not counted on a free day (without "Record today"): the
    /// recorded time, as far as entries by hand do not make it count anyway,
    /// also outside the frame.
    func uncountedAutoSpans(_ s: TTSettings) -> [TTSpan] {
        guard !periodsCount else { return [] }
        let minPause = s.rules(date).minPause
        var out = TTSpan.fillGaps(periods, minPause: minPause)
        for sp in unframedSpans(minPause: minPause) {
            out = TTSpan.subtract(out, sp)
        }
        return out
    }

    /// First unlock and last lock within the frame (without manual entries;
    /// short locks count as work as everywhere). None on an uncounted free day.
    func autoBoundsInFrame(_ s: TTSettings) -> (from: Int, to: Int)? {
        let r = s.rules(date)
        let spans = TTSpan.clip(TTSpan.fillGaps(countedPeriods, minPause: r.minPause), r.frameFrom, r.frameTo)
        guard let first = spans.first, let last = spans.last else { return nil }
        return (first.from, last.to)
    }

    /// Table row for this day (`nil` when there is nothing to show).
    func record(_ s: TTSettings) -> TTDayRecord? {
        // Only the decision about recording, nothing recorded yet: no row.
        if !hasEntries && absence == nil { return nil }
        let spans = self.spans(s)
        let work = spans.reduce(0) { $0 + $1.len }
        let first: Int
        let last: Int
        if let f = spans.first, let l = spans.last {
            (first, last) = (f.from, l.to)
        } else {
            // Nothing within the frame: neither work nor break.
            let r = s.rules(date)
            first = (self.start ?? periods.first?.from ?? self.work.first?.from ?? end ?? breaks.first?.from ?? 0)
                .ttClamped(r.frameFrom, r.frameTo)
            last = first
        }
        let shownWork = spans.reduce(0) { $0 + TTSpan.shownLen(from: $1.from, to: $1.to) }
        let shownPause = zip(spans, spans.dropFirst()).reduce(0) { $0 + TTSpan.shownLen(from: $1.0.to, to: $1.1.from) }
        return TTDayRecord(date: date, firstStart: first, lastEnd: last, workSecs: work,
                           shownWorkSecs: shownWork, shownPauseSecs: shownPause)
    }

    /// Sum of the breaks of at least 15 minutes between blocks of work (as the
    /// Working Hours Act counts them).
    static func legalPauseSecs(_ spans: [TTSpan]) -> Int {
        zip(spans, spans.dropFirst())
            .map { $1.from - $0.to }
            .filter { $0 >= TTLimits.legalBreakSegment }
            .reduce(0, +)
    }

    /// Work in one stretch up to the end of the last block: since the last
    /// break of at least 15 minutes (like `longestStretchSecs`, only the last part).
    static func currentStretchSecs(_ spans: [TTSpan]) -> Int {
        var current = 0
        for (i, sp) in spans.enumerated() {
            if i > 0 && sp.from - spans[i - 1].to >= TTLimits.legalBreakSegment { current = 0 }
            current += sp.len
        }
        return current
    }

    /// Longest work in one stretch: blocks without a break of at least 15
    /// minutes between them count together (shorter interruptions are no break
    /// under the Act; only the work counts, not the interruption).
    static func longestStretchSecs(_ spans: [TTSpan]) -> Int {
        var (longest, current) = (0, 0)
        for (i, sp) in spans.enumerated() {
            if i > 0 && sp.from - spans[i - 1].to >= TTLimits.legalBreakSegment { current = 0 }
            current += sp.len
            longest = Swift.max(longest, current)
        }
        return longest
    }

    /// Does a manual start go with a manual end? The start must lie before the
    /// end; with one of them missing it always fits.
    static func boundsInOrder(start: Int?, end: Int?) -> Bool {
        guard let start, let end else { return true }
        return start < end
    }

    /// Index of the day `date` in `days` (sorted by date), inserting an empty
    /// day there when it is missing (`day.rs` `day_mut`).
    static func index(of date: TTDate, in days: inout [TTDay]) -> Int {
        var (lo, hi) = (0, days.count)
        while lo < hi {
            let mid = (lo + hi) / 2
            if days[mid].date < date { lo = mid + 1 } else { hi = mid }
        }
        if lo < days.count && days[lo].date == date { return lo }
        days.insert(TTDay(date: date), at: lo)
        return lo
    }
}
