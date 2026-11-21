// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import SwiftUI

/// "Week" in the Records window (Tagwerk's `week_view.rs`): the bar with
/// navigation, title, warnings and summary above the calendar grid. The grid
/// is an `NSView`, because it draws itself and handles dragging, hovering,
/// tooltips, cursors and VoiceOver elements. The logic is `TTWeekLayout`;
/// every change goes through the model's edit and undo path.
struct RecordsWeekView: View {
    @ObservedObject var model: RecordsModel

    var body: some View {
        VStack(spacing: 0) {
            RecordsWeekBar(model: model)
            Divider()
            RecordsWeekGrid(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// ‹ ›, Today, whole working hours, the week's title, its warnings and its
/// working time, breaks and balance.
private struct RecordsWeekBar: View {
    @ObservedObject var model: RecordsModel

    var body: some View {
        let t = TTWeekTexts.of(L10n.shared.language)
        let w = t.week
        let snap = model.weekSnapshot
        let cols = TTWeekLayout.columns(snap, monday: model.weekMonday)
        let warnings = TTWeekLayout.warningsSummary(cols, t)
        HStack(spacing: 10) {
            ControlGroup {
                Button { model.stepWeek(-1) } label: {
                    Image(systemName: "chevron.left").accessibilityLabel(w.previousWeek)
                }
                .help(w.previousWeekTip)
                Button { model.stepWeek(1) } label: {
                    Image(systemName: "chevron.right").accessibilityLabel(w.nextWeek)
                }
                .help(w.nextWeekTip)
            }
            .fixedSize()
            Button(t.records.today) { model.showWeek(of: TimeTrackingService.shared.now().date) }
                .help(w.todayTip)
                .fixedSize()
            // A symbol: a title would take the room of the week's title.
            Toggle(isOn: Binding(get: { model.weekFullFrame }, set: { model.setWeekFullFrame($0) })) {
                Image(systemName: "arrow.up.and.down").accessibilityLabel(w.fullFrame)
            }
            .toggleStyle(.button)
            .help(w.fullFrameTip)
            .fixedSize()
            .padding(.trailing, 4)
            Text(TTWeekLayout.title(monday: model.weekMonday, t))
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(-1)
            Spacer(minLength: 8)
            if !warnings.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(nsColor: .systemOrange))
                        .accessibilityLabel(t.records.warningTip)
                    Text(warnings)
                        .foregroundStyle(Color(nsColor: .systemOrange))
                        .lineLimit(1)
                }
                .help(w.warningsRowTip)
                .fixedSize()
                .padding(.trailing, 8)
            }
            Text(summary(snap, cols, t))
                .font(.body.monospacedDigit())
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// The summary in grey, its balance in colour.
    private func summary(_ snap: TTWeekSnapshot, _ cols: [TTWeekColumn], _ t: TTWeekTexts) -> AttributedString {
        let (head, balance) = TTWeekLayout.weekSummaryParts(snap, monday: model.weekMonday, cols, t)
        var text = AttributedString(head)
        text.foregroundColor = Color.secondary
        if let balance {
            var value = AttributedString(TTFormat.balance(balance))
            value.foregroundColor = recordsBalanceColor(balance)
            text += value
        }
        return text
    }
}

/// The calendar grid of the week.
struct RecordsWeekGrid: NSViewRepresentable {
    @ObservedObject var model: RecordsModel

    func makeNSView(context: Context) -> RecordsWeekGridView {
        let view = RecordsWeekGridView(model: model)
        view.refreshFromModel()
        DispatchQueue.main.async { [weak view] in
            guard let view, model.mode == .week else { return }
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ view: RecordsWeekGridView, context: Context) {
        view.model = model
        view.refreshFromModel()
    }
}

// MARK: - Grid

/// The self-drawn calendar grid (flipped: top = early). It keeps what only
/// the screen needs (hover, drag, the copied time, the open menu); the days
/// come from the model, and every change goes back to it.
final class RecordsWeekGridView: NSView, NSViewToolTipOwner {
    weak var model: RecordsModel?

    private var data = TTWeekModel(monday: TTWeekLayout.monday(TTDate(year: 2026, month: 1, day: 1)!))
    private var selected: TTDate?
    private var language: AppLanguage?
    /// Mouse position over the grid (for the frame around the free area below it).
    private var hover: CGPoint?
    /// The frame shown last (day and area); drawn anew only when it changes.
    private var hoverSpan: HoverSpan?
    /// The edge under the mouse: the grip appears there.
    private var hoverEdge: EdgeKey?
    /// The start or end being dragged.
    private var drag: TTWeekDrag?
    /// The time just copied (for the feedback in the grid).
    private var flash: TTWeekFlash?
    private var flashGeneration = 0
    private var popover: NSPopover?
    /// What the open context menu refers to.
    private var pending: TTWeekContext?
    private var tips: [NSView.ToolTipTag: String] = [:]
    /// Counts the states shown (for the VoiceOver elements).
    private var generation = 0
    private var axCache: (key: [Int], elements: [Any])?

    private struct HoverSpan: Equatable {
        var date: TTDate
        var span: TTSpan
    }

    private struct EdgeKey: Equatable {
        var col: Int
        var bound: TTEditBound
    }

    /// The feedback "copied" stays this long (seconds).
    private static let flashSeconds: TimeInterval = 1.2
    private static let lineHeight: CGFloat = 14

    init(model: RecordsModel) {
        self.model = model
        super.init(frame: .zero)
        // Mouse moves for the frame around free areas (follows the visible area).
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways,
                                                              .inVisibleRect], owner: self, userInfo: nil))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private var t: TTWeekTexts { TTWeekTexts.of(L10n.shared.language) }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    /// A click into the inactive window can copy right away.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: State

    /// Takes the model's state over; rebuilds and redraws only when it changed.
    func refreshFromModel() {
        guard let model else { return }
        let snap = model.weekSnapshot
        let language = L10n.shared.language
        var changed = language != self.language
        if data.monday != model.weekMonday {
            // Another week: a drag in progress ends.
            if drag != nil { endDragState() }
            data.monday = model.weekMonday
            popover?.close()
            changed = true
        }
        if data.snap != snap || data.fullFrame != model.weekFullFrame { changed = true }
        if changed {
            self.language = language
            data.snap = snap
            data.fullFrame = model.weekFullFrame
            data.rebuild(drag: &drag)
            rendered()
        }
        if model.selected != selected {
            selected = model.selected
            needsDisplay = true
        }
    }

    /// After a new state: redraw, tooltips, cursors and VoiceOver elements anew.
    private func rendered() {
        generation += 1
        needsDisplay = true
        updateTooltips()
        window?.invalidateCursorRects(for: self)
        NSAccessibility.post(element: self, notification: .layoutChanged)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateTooltips()
        window?.invalidateCursorRects(for: self)
    }

    private var geo: TTWeekGeometry { TTWeekGeometry(size: bounds.size, data) }
    private var now: TTDateTime { data.snap?.now ?? TimeTrackingService.shared.now() }

    /// "Now" to check an input: the clock, as the shown state can be older.
    private var inputNow: TTDateTime { Swift.max(now, TimeTrackingService.shared.now()) }

    private func column(of date: TTDate) -> TTWeekColumn? {
        data.cols.first { $0.date == date }
    }

    // MARK: Text in the blocks

    private enum Style { case strong, plain }

    /// A piece of text in a block (start and end clickable on their own).
    private struct Piece {
        var text: String
        var rect: CGRect
        var style: Style
        var part: TTWeekPart?

        /// The clickable area (a little larger than the text).
        var hitRect: CGRect { rect.insetBy(dx: -3, dy: -1) }
    }

    /// A block with its rectangle and text as drawn.
    private struct BlockBox {
        var col: Int
        var block: TTWeekBlock
        var rect: CGRect
        var pieces: [Piece]
    }

    private static func attributes(_ font: NSFont, _ color: NSColor,
                                   _ alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        return [.font: font, .foregroundColor: color, .paragraphStyle: style]
    }

    private static func digits(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
        .monospacedDigitSystemFont(ofSize: size, weight: weight)
    }

    private static func width(_ text: String, _ attrs: [NSAttributedString.Key: Any]) -> CGFloat {
        (text as NSString).size(withAttributes: attrs).width.rounded(.up)
    }

    private static func fonts(_ strong: NSColor, _ plain: NSColor) -> (strong: [NSAttributedString.Key: Any],
                                                                      plain: [NSAttributedString.Key: Any]) {
        (attributes(digits(11, .semibold), strong), attributes(digits(11, .regular), plain))
    }

    /// The text of a block in pieces, so start and end are clickable on their own.
    private func pieces(_ r: CGRect, _ b: TTWeekBlock) -> [Piece] {
        guard r.height >= 13 else { return [] }
        let f = Self.fonts(.labelColor, .labelColor)
        let tx = r.minX + 7
        let right = r.maxX - 2
        let top = r.minY + (r.height >= 18 ? 2 : 0)
        let start = TTFormat.clock(b.from)
        let (end, endPart): (String, TTWeekPart?) = b.running ? (t.week.now, nil) : (TTFormat.clock(b.to), .end)
        let detail = TTWeekLayout.blockDetail(b, t)
        var out: [Piece] = []
        @discardableResult
        func push(_ text: String, _ x: CGFloat, _ line: Int, _ style: Style, _ part: TTWeekPart?) -> CGFloat {
            let w = Self.width(text, style == .strong ? f.strong : f.plain)
            let y = top + CGFloat(line) * Self.lineHeight
            if x + w <= right && y + Self.lineHeight <= r.maxY + 2 {
                out.append(Piece(text: text, rect: CGRect(x: x, y: y, width: w, height: 15), style: style, part: part))
            }
            return x + w
        }
        if tx + Self.width("\(start) – \(end)", f.strong) <= right {
            // Wide: "08:12 – 11:58", the duration below.
            var x = push(start, tx, 0, .strong, .start)
            x = push(" – ", x, 0, .strong, nil)
            push(end, x, 0, .strong, endPart)
            if r.height >= 32 { push(detail, tx, 1, .plain, nil) }
        } else {
            // Narrow: start, "– end" and duration below each other.
            push(start, tx, 0, .strong, .start)
            if r.height >= 32 {
                let x = push("– ", tx, 1, .strong, nil)
                push(end, x, 1, .strong, endPart)
            }
            if r.height >= 46 { push(detail, tx, 2, .plain, nil) }
        }
        return out
    }

    /// All blocks of the week with their text.
    private func blockBoxes(_ geo: TTWeekGeometry) -> [BlockBox] {
        data.cols.enumerated().flatMap { i, c in
            c.blocks.map { b in
                let rect = geo.blockRect(i, b)
                return BlockBox(col: i, block: b, rect: rect, pieces: pieces(rect, b))
            }
        }
    }

    // MARK: What lies under the pointer

    private enum Hit {
        /// A time to copy.
        case time(TTWeekTimeHit)
        /// A day header with warnings.
        case warnings(TTDate, [TTWarning], CGRect)
        /// A free area (also a break) with the preset for work away from the Mac.
        case free(TTDate, TTSpan)
        /// Work away from the Mac (hatched); the details come from `context`.
        case work
    }

    private func hit(_ p: CGPoint) -> Hit? {
        let geo = self.geo
        for bx in blockBoxes(geo) {
            for piece in bx.pieces {
                guard let part = piece.part, piece.hitRect.contains(p) else { continue }
                let flash = TTWeekFlash(date: data.cols[bx.col].date, from: bx.block.from, kind: bx.block.kind, part: part)
                return .time(TTWeekTimeHit(flash: flash, text: piece.text))
            }
        }
        guard let col = geo.column(at: p.x), data.cols.indices.contains(col), let snap = data.snap else { return nil }
        let c = data.cols[col]
        if !c.locked && c.manual.contains(where: { geo.spanRect(col, $0.span).contains(p) }) { return .work }
        if let at = geo.secs(at: p.y),
           let preset = TTWeekLayout.freePreset(c, at: at, now: snap.now, minWork: snap.settings.minWork) {
            return .free(c.date, preset)
        }
        let rect = geo.headerRect(col)
        return !c.warnings.isEmpty && rect.contains(p) ? .warnings(c.date, c.warnings, rect) : nil
    }

    /// The edge under `p` (column and bound).
    private func edge(at p: CGPoint) -> EdgeKey? {
        TTWeekLayout.edgeRects(geo, data).first { $0.rect.contains(p) }.map { EdgeKey(col: $0.col, bound: $0.bound) }
    }

    /// The free area under `p` with the preset (for the frame). On an edge
    /// there is no frame; the grip appears there.
    private func hoverSpan(at p: CGPoint?) -> HoverSpan? {
        guard let p, edge(at: p) == nil, case let .free(date, preset)? = hit(p) else { return nil }
        return HoverSpan(date: date, span: preset)
    }

    private func setHover(_ p: CGPoint?) {
        hover = p
        let edge = p.flatMap { self.edge(at: $0) }
        if hoverSpan(at: p) != hoverSpan || edge != hoverEdge { needsDisplay = true }
    }

    /// What can be done at `p` (`nil` beside the day columns).
    private func context(at p: CGPoint) -> TTWeekContext? {
        let geo = self.geo
        guard let col = geo.column(at: p.x), data.cols.indices.contains(col), let snap = data.snap else { return nil }
        let c = data.cols[col]
        var ctx = TTWeekContext(date: c.date)
        ctx.time = blockBoxes(geo).filter { $0.col == col }.lazy.compactMap { bx -> TTWeekTimeHit? in
            guard let piece = bx.pieces.first(where: { $0.part != nil && $0.hitRect.contains(p) }),
                  let part = piece.part else { return nil }
            return TTWeekTimeHit(flash: TTWeekFlash(date: c.date, from: bx.block.from, kind: bx.block.kind, part: part),
                                 text: piece.text)
        }.first
        let day = snap.days.first { $0.date == c.date }
        // On free days there is no target: at most an absence to remove.
        let current = day?.absence
        ctx.absenceEditable = snap.settings.isWorkday(c.date) || current != nil
        ctx.currentAbsence = current
        ctx.noTarget = !snap.settings.isWorkday(c.date)
        // Today only entries by hand count for the absence (see `TTDay.acceptsAbsence`).
        ctx.busy = day?.blocksFullAbsence(today: snap.now.date == c.date) ?? false
        // Only with entries besides the absence: "Absence › None" removes it alone.
        ctx.clearable = day?.hasEntries ?? false
        if let day, !day.locksEntries, let free = day.freeDay { ctx.counting = free.counts }
        ctx.edges = c.edges
        // Start on the first block, end on the last (or at the edge).
        let zones = TTWeekLayout.edgeRects(geo, data)
        let work = c.blocks.filter { $0.kind == .work }
        for (bound, block) in [(TTEditBound.start, work.first), (.end, work.last)] {
            guard let zone = zones.first(where: { $0.col == col && $0.bound == bound })?.rect else { continue }
            let onBlock = block.map { geo.blockRect(col, $0).contains(p) } ?? false
            if onBlock || zone.contains(p) { ctx.bounds.append(bound) }
        }
        if !c.locked, let m = c.manual.first(where: { geo.spanRect(col, $0.span).contains(p) }) {
            ctx.work = TTWeekWorkHit(block: m.block, note: m.note)
        }
        if ctx.work == nil, let at = geo.secs(at: p.y) {
            ctx.preset = TTWeekLayout.freePreset(c, at: at, now: snap.now, minWork: snap.settings.minWork)
        }
        return ctx
    }

    /// Can the day be edited in "Days"? Not in the future.
    private func canOpen(_ date: TTDate) -> Bool {
        date <= now.date
    }

    // MARK: Mouse and keys

    override func mouseMoved(with event: NSEvent) {
        setHover(convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        setHover(nil)
    }

    /// A click on a time copies it, on a day header with a warning sign shows
    /// the warnings, on a free area enters work away from the Mac, on work
    /// away from the Mac opens its menu. A double-click on a day header or a
    /// block opens the day in "Days". On the edge of the start or end of work
    /// dragging begins; without a move the click applies on mouse up.
    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        window?.makeFirstResponder(self)
        // A click into a day column makes it the day being edited.
        if let ctx = context(at: p) { selectDay(ctx.date) }
        switch event.clickCount {
        case 1:
            if !beginDrag(p) { click(p) }
        case 2:
            // Only where the first click did nothing (except the warnings).
            switch hit(p) {
            case nil, .warnings?:
                if let ctx = context(at: p), canOpen(ctx.date) { openDay(ctx.date) }
            default: break
            }
        default: break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        dragMoved(convert(event.locationInWindow, from: nil), fine: event.modifierFlags.contains(.option))
    }

    override func mouseUp(with event: NSEvent) {
        endDrag(convert(event.locationInWindow, from: nil))
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53 where drag?.active == true: cancelDrag() // Esc
        case 123: model?.stepWeek(-1) // ←
        case 124: model?.stepWeek(1) // →
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        if drag?.active == true { cancelDrag() }
    }

    /// Right-click: everything that goes at this spot, as a menu.
    override func menu(for event: NSEvent) -> NSMenu? {
        let p = convert(event.locationInWindow, from: nil)
        guard let ctx = context(at: p) else { return nil }
        selectDay(ctx.date)
        guard let menu = contextMenu(ctx) else { return nil }
        pending = ctx
        return menu
    }

    /// A simple click: copy a time, show the warnings, enter work away from the Mac, or its menu.
    private func click(_ p: CGPoint) {
        switch hit(p) {
        case let .time(time)?: copyTime(time)
        case let .warnings(date, warnings, rect)?: showWarnings(date, warnings, rect)
        case let .free(date, preset)?: showAddWork(date, preset: preset, error: nil)
        case .work?:
            if let ctx = context(at: p), let menu = contextMenu(ctx) {
                pending = ctx
                menu.popUp(positioning: nil, at: p, in: self)
            }
        case nil: break
        }
    }

    private func selectDay(_ date: TTDate) {
        guard let model, model.selected != date else { return }
        model.select(date)
        selected = date
        needsDisplay = true
    }

    private func openDay(_ date: TTDate) {
        popover?.close()
        model?.goTo(date)
    }

    // MARK: Dragging the start and end of work

    /// Mouse down on an edge: prepares dragging (`false`: no edge).
    private func beginDrag(_ p: CGPoint) -> Bool {
        guard let key = edge(at: p), data.cols.indices.contains(key.col), let snap = data.snap else { return false }
        let c = data.cols[key.col]
        guard let edges = c.edges, let day = snap.days.first(where: { $0.date == c.date }) else { return false }
        let at = edges.get(key.bound).value
        drag = TTWeekDrag(col: key.col, date: c.date, bound: key.bound, edges: edges, y0: p.y, offset: p.y - geo.y(at),
                          at: at, days: snap.days, day: day)
        return true
    }

    /// The mouse moved with the button down: the edge follows (`fine`: ⌥, to the minute).
    private func dragMoved(_ p: CGPoint, fine: Bool) {
        // No mouse moves come while dragging: remember the spot here.
        hover = p
        guard var g = drag else { return }
        if !g.active {
            if abs(p.y - g.y0) < TTWeekLayout.dragSlop { return }
            g.active = true
            // While dragging the arrow up and down everywhere.
            window?.disableCursorRects()
            NSCursor.rowResize.set()
        }
        guard let snap = data.snap else { return }
        let geo = self.geo
        let limit = TTWeekLayout.freeLimit(g.date, now: snap.now)
        guard let limits = TTWeekLayout.dragLimits(g.edges, g.bound, snap.settings.rules(g.date), limit: limit,
                                                   grid: (geo.h0 * 3600, geo.h1 * 3600)) else {
            drag = g
            return
        }
        let magnet = Int(TTWeekLayout.magnet / geo.hourHeight * 3600)
        let (at, snapped) = TTWeekLayout.dragValue(geo.rawSecs(p.y - g.offset), auto: g.edges.get(g.bound).auto,
                                                   magnet: magnet, fine: fine, limits: limits)
        let newly = snapped && !g.snapped
        g.at = at
        g.snapped = snapped
        TTWeekLayout.preview(&data, &g)
        drag = g
        if newly {
            // Snapping you can feel (on the trackpad).
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        needsDisplay = true
    }

    /// The mouse button released: saves the new value, or without a move the click.
    private func endDrag(_ p: CGPoint) {
        guard let g = drag else {
            // After Esc: frame or grip where the mouse is now.
            setHover(p)
            return
        }
        drag = nil
        if !g.active {
            click(p)
            return
        }
        restoreCursor()
        if let change = TTWeekLayout.dragResult(g.edges, g.bound, at: g.at) {
            setBound(g.date, g.bound, change.value)
        }
        // Without a change (or if saving failed) the saved state again.
        reload()
        setHover(p)
    }

    /// Esc while dragging: everything as before.
    private func cancelDrag() {
        endDragState()
        reload()
    }

    private func endDragState() {
        drag = nil
        restoreCursor()
    }

    private func restoreCursor() {
        guard let window else { return }
        window.enableCursorRects()
        window.invalidateCursorRects(for: self)
    }

    /// Rebuilds from the model's current state (also right after a change,
    /// before SwiftUI hands it over).
    private func reload() {
        data.snap = nil
        refreshFromModel()
        needsDisplay = true
    }

    /// Saves the start or end of work (`nil`: automatic again), like the inspector, so ⌘Z takes it back.
    private func setBound(_ date: TTDate, _ bound: TTEditBound, _ at: Int?) {
        model?.save(date, bound == .start ? .setStart(at) : .setEnd(at), rebuild: true)
        reload()
    }

    /// VoiceOver: the start or end 5 minutes earlier or later, on the 5-minute
    /// grid. `false` when it goes no further.
    private func nudge(_ date: TTDate, _ bound: TTEditBound, later: Bool) -> Bool {
        guard let snap = data.snap, let e = column(of: date)?.edges,
              let limits = TTWeekLayout.dragLimits(e, bound, snap.settings.rules(date),
                                                   limit: TTWeekLayout.freeLimit(date, now: snap.now),
                                                   grid: (0, TTLimits.dayEnd)),
              let at = TTWeekLayout.nudgeValue(e.get(bound).value, later: later, limits: limits) else { return false }
        if let change = TTWeekLayout.dragResult(e, bound, at: at) { setBound(date, bound, change.value) }
        return true
    }

    // MARK: Dialogs

    /// A time field for `secs` on the day `date` (hours and minutes with arrows).
    private static func timeField(_ date: TTDate, _ secs: Int) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        picker.locale = RecordsTime.locale
        picker.calendar = RecordsTime.calendar
        picker.timeZone = RecordsTime.calendar.timeZone
        picker.dateValue = RecordsTime.date(date, secs)
        picker.sizeToFit()
        return picker
    }

    /// The dialog "Change Start of Work" or "Change End of Work" as a sheet.
    private func showBoundDialog(_ date: TTDate, _ bound: TTEditBound) {
        guard let window, window.attachedSheet == nil, let e = column(of: date)?.edges else { return }
        let t = self.t
        let field = Self.timeField(date, e.get(bound).value)
        let title = bound == .start ? t.records.editSetStart : t.records.editSetEnd
        var text = bound == .start ? t.week.startDialogText : t.week.endDialogText
        if date == now.date && bound == .end { text += t.week.endDialogToday }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = String(format: t.week.dialogInfoFormat, TTWeekLayout.shortDay(date, t), text)
        alert.addButton(withTitle: t.week.apply)
        alert.addButton(withTitle: t.records.cancel).keyEquivalent = "\u{1b}"
        alert.accessoryView = field
        alert.layout()
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self, let snap = self.data.snap else { return }
            let at = RecordsTime.secs(field.dateValue)
            let limit = TTWeekLayout.freeLimit(date, now: self.inputNow)
            switch TTWeekLayout.dialogResult(e, bound, at: at, snap.settings.rules(date), limit: limit, t) {
            case let .failure(refusal): self.model?.showSheetLater(title, refusal.text)
            case let .success(change?): self.setBound(date, bound, change.value)
            case .success(nil): break
            }
        }
    }

    /// The dialog "Add Work Away from the Mac" as a sheet: from, to and reason.
    /// `error` shows in red above the fields why the previous input was refused
    /// (the fields are filled with it then), as in the inspector.
    private func showAddWork(_ date: TTDate, preset: TTSpan, error: (text: String, span: TTSpan, activity: TTActivity)?) {
        guard let window, window.attachedSheet == nil else { return }
        let t = self.t
        let span = error?.span ?? preset
        let from = Self.timeField(date, span.from)
        let to = Self.timeField(date, span.to)
        let reason = NSPopUpButton()
        reason.addItems(withTitles: TTActivity.all.map { $0.label(t.texts) })
        reason.selectItem(at: TTActivity.all.firstIndex(of: error?.activity ?? .meeting) ?? 0)

        func row(_ views: [NSView]) -> NSStackView {
            let r = NSStackView(views: views)
            r.orientation = .horizontal
            r.alignment = .firstBaseline
            r.spacing = 6
            return r
        }
        let fromLabel = NSTextField(labelWithString: t.week.fromLabel)
        let reasonLabel = NSTextField(labelWithString: t.records.reason)
        let times = row([fromLabel, from, NSTextField(labelWithString: t.records.to), to])
        let why = row([reasonLabel, reason])
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        if let error {
            // As wide as the fields below, so the dialog does not grow.
            let width = Swift.max(times.fittingSize.width, why.fittingSize.width)
            let problem = NSTextField(wrappingLabelWithString: error.text)
            problem.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            problem.textColor = .systemRed
            problem.isSelectable = false
            problem.preferredMaxLayoutWidth = width
            problem.widthAnchor.constraint(lessThanOrEqualToConstant: width).isActive = true
            stack.addArrangedSubview(problem)
        }
        stack.addArrangedSubview(times)
        stack.addArrangedSubview(why)
        // The fields flush below "From" and "Reason".
        reasonLabel.widthAnchor.constraint(equalTo: fromLabel.widthAnchor).isActive = true
        stack.setFrameSize(stack.fittingSize)

        let alert = NSAlert()
        alert.messageText = t.records.editAddWork
        alert.informativeText = String(format: t.week.workDialogTextFormat, TTWeekLayout.shortDay(date, t))
        if error != nil { alert.alertStyle = .warning }
        alert.addButton(withTitle: t.records.add)
        alert.addButton(withTitle: t.records.cancel).keyEquivalent = "\u{1b}"
        alert.accessoryView = stack
        alert.layout()
        alert.window.initialFirstResponder = from
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self, let model = self.model else { return }
            let activity = TTActivity.all.indices.contains(reason.indexOfSelectedItem)
                ? TTActivity.all[reason.indexOfSelectedItem] : .meeting
            let (f, to) = (RecordsTime.secs(from.dateValue), RecordsTime.secs(to.dateValue))
            let pauses = model.day(date)?.pauses(model.settings) ?? []
            let limit = TTWeekLayout.freeLimit(date, now: self.inputNow)
            switch TTWeekLayout.workInput(from: f, to: to, preset: preset, pauses: pauses,
                                          minWork: model.settings.minWork, limit: limit, t) {
            case let .success(entered):
                model.addWork(date, entered, activity: activity)
                self.reload()
            case let .failure(refusal):
                // Ask again, once the sheet is closed.
                DispatchQueue.main.async { [weak self] in
                    self?.showAddWork(date, preset: preset, error: (refusal.text, TTSpan(f, to), activity))
                }
            }
        }
    }

    // MARK: Context menu

    private func contextMenu(_ ctx: TTWeekContext) -> NSMenu? {
        let t = self.t
        let entries = TTWeekLayout.contextEntries(ctx, canOpen: canOpen(ctx.date), t)
        guard !entries.isEmpty else { return nil }
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (i, entry) in entries.enumerated() {
            if entry.title.isEmpty {
                menu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(title: entry.title, action: nil, keyEquivalent: "")
            switch entry.action {
            case .absence?:
                let sub = NSMenu()
                sub.autoenablesItems = false
                for e in TTWeekLayout.absenceEntries(current: ctx.currentAbsence, busy: ctx.busy, noTarget: ctx.noTarget, t) {
                    if e.title.isEmpty {
                        sub.addItem(.separator())
                        continue
                    }
                    let choice = NSMenuItem(title: e.title, action: e.tag >= 0 ? #selector(absenceChosen(_:)) : nil,
                                            keyEquivalent: "")
                    if e.tag >= 0 { choice.target = self }
                    choice.tag = e.tag
                    choice.isEnabled = e.enabled
                    choice.state = e.checked ? .on : .off
                    sub.addItem(choice)
                }
                item.submenu = sub
            case let action?:
                item.action = #selector(menuChosen(_:))
                item.target = self
                item.tag = i
                item.representedObject = MenuAction(action)
                if action == .toggleCounting { item.state = ctx.counting == true ? .on : .off }
            case nil:
                item.isEnabled = false
            }
            menu.addItem(item)
        }
        return menu
    }

    /// Boxes a menu action for `representedObject`.
    private final class MenuAction: NSObject {
        let action: TTWeekMenuAction

        init(_ action: TTWeekMenuAction) {
            self.action = action
        }
    }

    @objc private func menuChosen(_ sender: NSMenuItem) {
        guard let ctx = pending, let action = (sender.representedObject as? MenuAction)?.action else { return }
        pending = nil
        let date = ctx.date
        switch action {
        case .openDay: openDay(date)
        case .copyTime:
            if let time = ctx.time { copyTime(time) }
        case .addWork:
            if let preset = ctx.preset { showAddWork(date, preset: preset, error: nil) }
        case .toggleCounting:
            if let on = ctx.counting {
                model?.save(date, .setCounting(!on), rebuild: true)
                reload()
            }
        case .absence: break
        case .clearDay: model?.confirmClearDay(date)
        case .removeWork:
            if let work = ctx.work {
                model?.save(date, .cutWork(work.block.from, work.block.to), rebuild: true)
                reload()
            }
        case let .change(bound): showBoundDialog(date, bound)
        case let .reset(bound): setBound(date, bound, nil)
        }
    }

    @objc private func absenceChosen(_ sender: NSMenuItem) {
        guard let ctx = pending, let choice = TTWeekLayout.absence(ofTag: sender.tag) else { return }
        pending = nil
        model?.setAbsence(ctx.date, choice.absence)
        reload()
    }

    // MARK: Copying with feedback

    private func copyTime(_ time: TTWeekTimeHit) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(time.text, forType: .string)
        // A confirmation you can feel on the trackpad (where there is one).
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        flashGeneration += 1
        let generation = flashGeneration
        flash = time.flash
        needsDisplay = true
        // Hide the feedback after a moment (unless something was copied since).
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flashSeconds) { [weak self] in
            guard let self, self.flashGeneration == generation else { return }
            self.flash = nil
            self.needsDisplay = true
        }
    }

    // MARK: Warnings in a popover

    /// The filled warning sign in the warning colour (as in the panel and "Days").
    private static func warningImage(_ pointSize: CGFloat, _ description: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            .applying(.init(paletteColors: [.white, .systemOrange]))
        return NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: description)?
            .withSymbolConfiguration(config)
    }

    /// The cup for the breaks in the day header.
    private static func pauseImage(_ pointSize: CGFloat, _ color: NSColor, _ description: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            .applying(.init(paletteColors: [color]))
        return NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: description)?
            .withSymbolConfiguration(config)
    }

    private func showWarnings(_ date: TTDate, _ warnings: [TTWarning], _ rect: CGRect) {
        let t = self.t
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        let title = NSTextField(labelWithString: String(format: t.week.popoverTitleFormat, TTWeekLayout.shortDay(date, t)))
        title.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        stack.addArrangedSubview(title)
        for warning in warnings {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 6
            if let image = Self.warningImage(NSFont.systemFontSize, t.records.warningTip) {
                row.addArrangedSubview(NSImageView(image: image))
            }
            let label = NSTextField(wrappingLabelWithString: warning.text(t.texts))
            label.preferredMaxLayoutWidth = 300
            label.isSelectable = false
            row.addArrangedSubview(label)
            stack.addArrangedSubview(row)
        }
        stack.setFrameSize(stack.fittingSize)
        let controller = NSViewController()
        controller.view = stack
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = controller
        // The view is flipped: maxY is the bottom, the popover hangs below the header.
        popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        self.popover = popover
    }

    // MARK: Drawing

    private static func fill(_ rect: CGRect, _ color: NSColor) {
        color.setFill()
        rect.fill()
    }

    private static func roundFill(_ rect: CGRect, _ radius: CGFloat, _ color: NSColor) {
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }

    /// Diagonal hatching in a rounded rectangle.
    private static func hatch(_ rect: CGRect, _ color: NSColor) {
        guard rect.height > 0, rect.width > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).addClip()
        color.setStroke()
        var off = -rect.height
        while off < rect.width {
            NSBezierPath.strokeLine(from: NSPoint(x: rect.minX + off, y: rect.minY + rect.height),
                                    to: NSPoint(x: rect.minX + off + rect.height, y: rect.minY))
            off += 6
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func hline(_ x0: CGFloat, _ x1: CGFloat, _ y: CGFloat, _ color: NSColor) {
        fill(CGRect(x: x0, y: y.rounded(.down), width: x1 - x0, height: 1), color)
    }

    private static func vline(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat, _ color: NSColor) {
        fill(CGRect(x: x.rounded(.down), y: y0, width: 1, height: y1 - y0), color)
    }

    private static func dashed(_ path: NSBezierPath, _ pattern: [CGFloat]) {
        path.setLineDash(pattern, count: pattern.count, phase: 0)
    }

    private static func draw(_ image: NSImage, in rect: CGRect) {
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    private static func text(_ s: String, in rect: CGRect, _ attrs: [NSAttributedString.Key: Any]) {
        (s as NSString).draw(in: rect, withAttributes: attrs)
    }

    private static func text(_ s: String, at p: CGPoint, _ attrs: [NSAttributedString.Key: Any]) {
        (s as NSString).draw(at: p, withAttributes: attrs)
    }

    override func draw(_ dirtyRect: NSRect) {
        // While dragging no frame for work away from the Mac: the edge moves away under the mouse.
        let p = drag == nil ? hover : nil
        let hover = hoverSpan(at: p)
        hoverSpan = hover
        let edge = p.flatMap { self.edge(at: $0) }
        hoverEdge = edge
        let shownDrag = drag.flatMap { $0.active ? $0 : nil }
        let grip = shownDrag.map { EdgeKey(col: $0.col, bound: $0.bound) } ?? edge
        drawGrid(hover: hover, grip: grip, drag: shownDrag)
    }

    private func drawGrid(hover: HoverSpan?, grip: EdgeKey?, drag: TTWeekDrag?) {
        let t = self.t
        let geo = self.geo
        let d = data
        let headerHeight = TTWeekGeometry.headerHeight
        let label = NSColor.labelColor
        let secondary = NSColor.secondaryLabelColor
        let separator = NSColor.separatorColor
        let accent = NSColor.controlAccentColor
        let orange = NSColor.systemOrange
        let shade = NSColor.labelColor.withAlphaComponent(0.035)
        let gridTop = geo.gridTop
        let gridBottom = geo.y(geo.h1 * 3600)
        let today = d.snap?.now.date
        let settings = d.snap?.settings ?? TTSettings()

        Self.fill(bounds, .textBackgroundColor)

        // Shaded: free days (no target) and the time outside the frame (not counted).
        for (i, c) in d.cols.enumerated() {
            let x = geo.x(i)
            if !settings.isWorkday(c.date) {
                Self.fill(CGRect(x: x, y: headerHeight, width: geo.colWidth(i), height: geo.height - headerHeight), shade)
            } else {
                let r = settings.rules(c.date)
                for (a, b) in [(geo.h0 * 3600, r.frameFrom), (r.frameTo, geo.h1 * 3600)] where b > a {
                    let (ya, yb) = (geo.y(a), geo.y(b))
                    Self.fill(CGRect(x: x, y: ya, width: geo.colWidth(i), height: yb - ya), shade)
                }
            }
            if c.date == today {
                Self.fill(geo.headerRect(i), accent.withAlphaComponent(0.05))
                Self.fill(CGRect(x: x, y: headerHeight, width: geo.colWidth(i), height: geo.height - headerHeight),
                          accent.withAlphaComponent(0.05))
            }
            if !c.warnings.isEmpty { Self.fill(geo.headerRect(i), orange.withAlphaComponent(0.08)) }
        }

        // Hour lines and labels, half hours lighter.
        let hourAttrs = Self.attributes(Self.digits(10, .regular), secondary, .right)
        // `separatorColor` is translucent already; the half hours even more discreet.
        let half = NSColor.labelColor.withAlphaComponent(0.04)
        for hour in geo.h0...geo.h1 {
            let y = geo.y(hour * 3600)
            Self.hline(TTWeekGeometry.gutterWidth - 4, geo.width, y, separator)
            Self.text(String(format: "%02d:00", hour), in: CGRect(x: 0, y: y - 7, width: TTWeekGeometry.gutterWidth - 8, height: 14),
                      hourAttrs)
            if hour < geo.h1 && geo.hourHeight >= 24 {
                Self.hline(TTWeekGeometry.gutterWidth, geo.width, geo.y(hour * 3600 + 1800), half)
            }
        }

        // Column separators and day headers (with a warning sign on rule violations).
        for i in 0...7 {
            Self.vline(geo.x(i), 0, gridBottom + TTWeekGeometry.gridPadBottom, separator)
        }
        Self.hline(0, geo.width, headerHeight - 1, separator)
        let icon = Self.warningImage(11, t.records.warningTip)
        let cup = Self.pauseImage(9, secondary, t.records.columnBreaks)
        let magenta = TimeTrackingPalette.selection
        for (i, c) in d.cols.enumerated() {
            let x = geo.x(i)
            let isToday = c.date == today
            let isSelected = c.date == selected
            let warn = !c.warnings.isEmpty
            // The day being edited: the date white on a magenta pill.
            let color: NSColor = isSelected ? .white : isToday ? accent : settings.isWorkday(c.date) ? label : secondary
            let title = TTWeekLayout.headerTitle(c.date, t)
            let attrs = Self.attributes(.systemFont(ofSize: 12, weight: isToday ? .semibold : .medium), color)
            let tw = Self.width(title, attrs)
            let iconWidth: CGFloat = warn ? ((icon?.size.width).map { $0 + 4 } ?? 0) : 0
            // The pill reaches beyond the date on both sides; the warning sign
            // stands before it with the usual distance.
            let pad: CGFloat = isSelected ? 7 : 0
            let x0 = Swift.max(x + (geo.colWidth(i) - iconWidth - tw - 2 * pad) / 2, x + 2).rounded()
            if warn, let icon {
                Self.draw(icon, in: CGRect(x: x0, y: 7 + (15 - icon.size.height) / 2, width: icon.size.width,
                                           height: icon.size.height))
            }
            let textX = x0 + iconWidth + pad
            let titleRect = CGRect(x: textX, y: 7, width: geo.x(i + 1) - 2 - textX, height: 16)
            if isSelected {
                let pill = CGRect(x: x0 + iconWidth, y: 5, width: Swift.min(tw + 2 * pad, geo.x(i + 1) - 2 - x0 - iconWidth),
                                  height: 19)
                Self.roundFill(pill, 9.5, magenta)
            }
            Self.text(title, in: titleRect, attrs)
            // Without working time the absence, on a workday without entry the
            // missing target in red (otherwise a dash).
            let total = TTWeekLayout.headerTotal(c, t)
            let totalColor: NSColor = warn ? orange
                : (c.workSecs == 0 && c.absence == nil && c.missing != nil) ? TimeTrackingPalette.balance(-(c.missing ?? 0))
                : secondary
            let totalRect = CGRect(x: x + 2, y: 24, width: geo.colWidth(i) - 4, height: 15)
            // Next to it the breaks with a cup, when there is room.
            let a = Self.attributes(Self.digits(11, .regular), totalColor)
            let pa = Self.attributes(Self.digits(11, .regular), secondary)
            let pause = TTExport.hoursMinutesUnit(c.pauseSecs)
            let (w1, w2) = (Self.width(total, a), Self.width(pause, pa))
            let cupWidth = (cup?.size.width).map { $0 + 3 } ?? 0
            let width = w1 + 12 + cupWidth + w2
            if c.workSecs > 0 && width <= totalRect.width {
                let tx = (x + (geo.colWidth(i) - width) / 2).rounded()
                Self.text(total, in: CGRect(x: tx, y: 24, width: w1, height: 15), a)
                var px = tx + w1 + 12
                if let cup {
                    Self.draw(cup, in: CGRect(x: px, y: 24 + (14 - cup.size.height) / 2, width: cup.size.width,
                                              height: cup.size.height))
                    px += cupWidth
                }
                Self.text(pause, in: CGRect(x: px, y: 24, width: w2, height: 15), pa)
            } else {
                Self.text(total, in: totalRect, Self.attributes(Self.digits(11, .regular), totalColor, .center))
            }
        }

        // An absence: a band over the day's working-time frame, dashed, with
        // its kind at the top; blocks worked anyway lie above it.
        let teal = TimeTrackingPalette.absence
        let bandAttrs = Self.attributes(.systemFont(ofSize: 11, weight: .semibold), teal, .center)
        for (i, c) in d.cols.enumerated() {
            guard let absence = c.absence else { continue }
            let rules = settings.rules(c.date)
            let (from, to) = (Swift.max(rules.frameFrom, geo.h0 * 3600), Swift.min(rules.frameTo, geo.h1 * 3600))
            guard to > from else { continue }
            let r = geo.spanRect(i, TTSpan(from, to))
            Self.roundFill(r, 4, teal.withAlphaComponent(0.12))
            let border = NSBezierPath(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            border.lineWidth = 1
            Self.dashed(border, [4, 3])
            teal.withAlphaComponent(0.6).setStroke()
            border.stroke()
            // Spelled out when it fits ("Urlaub (halber Tag)"), else short ("½ Urlaub").
            let room = r.width - 8
            let long = absence.label(t.texts)
            let text = Self.width(long, bandAttrs) <= room ? long : absence.short(t.texts)
            Self.text(text, in: CGRect(x: r.minX + 4, y: r.minY + 6, width: room, height: 15), bandAttrs)
        }

        // Blocks (like appointments).
        let fonts = Self.fonts(label, secondary)
        let flashFonts = Self.fonts(.white, .white)
        var bubble: (CGRect, String)?
        let workAttrs = Self.attributes(.systemFont(ofSize: 10, weight: .medium), secondary, .center)
        for bx in blockBoxes(geo) {
            let b = bx.block
            let manual = d.cols[bx.col].manual.filter { $0.span.from < b.to && $0.span.to > b.from }
            let work = b.kind == .work
            let tint = work ? accent.withAlphaComponent(b.running ? 0.13 : 0.22) : orange.withAlphaComponent(0.16)
            let bar = work ? accent : orange
            Self.roundFill(bx.rect, 4, tint)
            // Work away from the Mac hatched.
            if b.kind == .work {
                for m in manual { Self.hatch(geo.spanRect(bx.col, m.span), accent.withAlphaComponent(0.35)) }
            }
            // A coloured edge on the left, as with appointments in Calendar.
            Self.roundFill(CGRect(x: bx.rect.minX, y: bx.rect.minY, width: 3, height: bx.rect.height), 1.5, bar)
            for piece in bx.pieces {
                let flashed = piece.part != nil && flash.map {
                    $0.date == d.cols[bx.col].date && $0.from == b.from && $0.kind == b.kind && $0.part == piece.part
                } == true
                if flashed {
                    Self.roundFill(piece.hitRect, 4, accent)
                    Self.text(piece.text, at: piece.rect.origin, piece.style == .strong ? flashFonts.strong : flashFonts.plain)
                    bubble = (piece.hitRect, String(format: t.week.copiedFormat, piece.text))
                } else {
                    Self.text(piece.text, at: piece.rect.origin, piece.style == .strong ? fonts.strong : fonts.plain)
                }
            }
            // The kind of work away from the Mac light in the hatching, when there is room.
            if b.kind == .work {
                let taken = bx.pieces.map(\.hitRect)
                for m in manual {
                    let text = TTWeekLayout.workLabel(m.note, t)
                    if let at = TTWeekLayout.workLabelRect(geo.spanRect(bx.col, m.span), taken: taken,
                                                           width: Self.width(text, workAttrs)) {
                        Self.text(text, in: at, workAttrs)
                    }
                }
            }
        }

        // Start and end of work as a line in the text colour at the edge (not
        // the "now" of a running block): recorded thin and muted, set by hand
        // strong and with a dot at the right end.
        let edgeColor = NSColor.labelColor
        let edgeAuto = edgeColor.withAlphaComponent(0.55)
        for (i, c) in d.cols.enumerated() {
            guard let e = c.edges else { continue }
            let (x, w) = (geo.x(i) + 3, geo.colWidth(i) - 6)
            for (bound, manual) in [(TTEditBound.start, e.manualStart), (.end, e.manualEnd)] {
                if bound == .end && e.running { continue }
                let y = geo.edgeY(e, bound)
                let (thick, color): (CGFloat, NSColor) = manual ? (2.5, edgeColor) : (1.5, edgeAuto)
                // The line lies within the block.
                let (top, mid) = bound == .start ? (y, y + thick / 2) : (y - thick, y - thick / 2)
                Self.roundFill(CGRect(x: x, y: top, width: w, height: thick), thick / 2, color)
                if manual {
                    let r: CGFloat = 3.5
                    edgeColor.setFill()
                    NSBezierPath(ovalIn: CGRect(x: x + w - 2 * r, y: mid - r, width: 2 * r, height: 2 * r)).fill()
                }
            }
        }

        // While dragging: work away from the Mac that would go, dashed.
        if let g = drag {
            let cutAttrs = Self.attributes(.systemFont(ofSize: 10, weight: .medium), orange, .center)
            for sp in g.cut {
                let r = geo.spanRect(g.col, sp).insetBy(dx: 0.75, dy: 0.75)
                guard r.height > 0 else { continue }
                let path = NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4)
                orange.withAlphaComponent(0.08).setFill()
                path.fill()
                orange.setStroke()
                path.lineWidth = 1
                Self.dashed(path, [4, 3])
                path.stroke()
                if r.height >= 14 {
                    Self.text(t.week.cutLabel, in: CGRect(x: r.minX, y: r.minY + (r.height - 13) / 2, width: r.width,
                                                          height: 13), cutAttrs)
                }
            }
        }

        // Breaks between the blocks: their length, when there is room.
        let gapAttrs = Self.attributes(Self.digits(10, .medium), secondary, .center)
        for (i, c) in d.cols.enumerated() {
            for gap in c.gaps {
                let r = geo.gapRect(i, gap)
                guard r.height >= 16 else { continue }
                let text = String(format: t.week.pauseFormat,
                                  TTExport.hoursMinutesUnit(TTSpan.shownLen(from: gap.from, to: gap.to)))
                Self.text(text, in: CGRect(x: r.minX, y: r.minY + (r.height - 13) / 2, width: r.width, height: 13), gapAttrs)
            }
        }

        // A frame around the free area under the mouse (a click enters work away from the Mac there).
        if let hover, let i = d.cols.firstIndex(where: { $0.date == hover.date }) {
            let r = geo.gapRect(i, hover.span).insetBy(dx: 0.75, dy: 0.75)
            if r.height > 0 {
                let path = NSBezierPath(roundedRect: r, xRadius: 4, yRadius: 4)
                accent.withAlphaComponent(0.08).setFill()
                path.fill()
                accent.setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
        }

        // The time now as a red line in today's column.
        if let snap = d.snap, let i = d.cols.firstIndex(where: { $0.date == today }),
           (geo.h0 * 3600...geo.h1 * 3600).contains(snap.now.secs) {
            let red = NSColor.systemRed
            let y = geo.y(snap.now.secs)
            let x = geo.x(i)
            Self.fill(CGRect(x: x, y: y - 0.75, width: geo.colWidth(i), height: 1.5), red)
            red.setFill()
            NSBezierPath(ovalIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)).fill()
        }

        // The grip at the edge under the mouse or the one being dragged.
        if let grip, d.cols.indices.contains(grip.col), let e = d.cols[grip.col].edges {
            let y = geo.edgeY(e, grip.bound)
            let cx = geo.x(grip.col) + geo.colWidth(grip.col) / 2
            let (w, h): (CGFloat, CGFloat) = (32, 6)
            let r = CGRect(x: cx - w / 2, y: y - h / 2, width: w, height: h)
            Self.roundFill(r.insetBy(dx: -1.5, dy: -1.5), h / 2 + 1.5, .textBackgroundColor)
            Self.roundFill(r, h / 2, edgeColor)
        }

        // While dragging: time and difference as a label at the edge (above
        // the start, below the end).
        if let g = drag, d.cols.indices.contains(g.col), let e = d.cols[g.col].edges {
            let text = TTWeekLayout.dragLabel(g.bound, at: g.at, before: g.edges.get(g.bound).value,
                                              auto: g.edges.get(g.bound).auto, workDiff: g.workDiff, t)
            let y = geo.edgeY(e, g.bound)
            let a = Self.attributes(Self.digits(11, .medium), .textBackgroundColor, .center)
            let (w, h) = (Self.width(text, a) + 16, CGFloat(20))
            let cx = geo.x(g.col) + geo.colWidth(g.col) / 2
            let lo = TTWeekGeometry.gutterWidth + 2
            let x = Swift.min(Swift.max(cx - w / 2, lo), Swift.max(geo.width - w - 2, lo))
            let wanted = g.bound == .start ? y - h - 8 : y + 8
            let top = Swift.min(Swift.max(wanted, headerHeight + 2), Swift.max(geo.height - h - 2, headerHeight + 2))
            let r = CGRect(x: x, y: top, width: w, height: h)
            Self.roundFill(r, h / 2, NSColor.labelColor.withAlphaComponent(0.85))
            Self.text(text, in: CGRect(x: x, y: top + 3, width: w, height: 15), a)
        }

        // An empty week, unless there are absences: their bands already say
        // why (the note would lie across them).
        if d.cols.allSatisfy({ $0.blocks.isEmpty && $0.absence == nil }) {
            let a = Self.attributes(.systemFont(ofSize: 13, weight: .regular), secondary, .center)
            let y = (gridTop + gridBottom) / 2 - 9
            Self.text(t.week.emptyWeek, in: CGRect(x: TTWeekGeometry.gutterWidth, y: y,
                                                   width: geo.width - TTWeekGeometry.gutterWidth, height: 18), a)
        }

        // The day being edited: a dashed magenta frame around the whole column
        // (above the blocks), unlike the teal band of an absence also around the header.
        if let i = d.cols.firstIndex(where: { $0.date == selected }) {
            let r = CGRect(x: geo.x(i), y: 0, width: geo.colWidth(i), height: gridBottom + TTWeekGeometry.gridPadBottom)
            magenta.setStroke()
            let frame = NSBezierPath(rect: r.insetBy(dx: 0.75, dy: 0.75))
            frame.lineWidth = 1.5
            Self.dashed(frame, [5, 3])
            frame.stroke()
        }

        // The feedback "… copied" as a bubble over the time (last, so it is on top).
        if let bubble {
            let (pill, copied) = bubble
            let text = "✓ " + copied
            let a = Self.attributes(.systemFont(ofSize: 11, weight: .medium), .textBackgroundColor, .center)
            let (w, h) = (Self.width(text, a) + 16, CGFloat(20))
            let lo = TTWeekGeometry.gutterWidth + 2
            let x = Swift.min(Swift.max(pill.midX - w / 2, lo), Swift.max(geo.width - w - 2, lo))
            let above = pill.minY - h - 4
            let y = above >= headerHeight ? above : pill.maxY + 4
            Self.roundFill(CGRect(x: x, y: y, width: w, height: h), h / 2, NSColor.labelColor.withAlphaComponent(0.85))
            Self.text(text, in: CGRect(x: x, y: y + 3, width: w, height: 15), a)
        }
    }

    // MARK: Tooltips and cursors

    /// Tooltips for the blocks (times, length, manual corrections), the day
    /// headers (working time, breaks, warnings) and the breaks.
    private func updateTooltips() {
        removeAllToolTips()
        tips.removeAll()
        let t = self.t
        let geo = self.geo
        let today = data.snap?.now.date
        var out: [(CGRect, String)] = []
        for (i, c) in data.cols.enumerated() {
            let header = TTWeekLayout.headerTip(c, canOpen: today.map { c.date <= $0 } ?? false, editable: true, t)
            if !header.isEmpty { out.append((geo.headerRect(i), header)) }
            for b in c.blocks {
                out.append((geo.blockRect(i, b), TTWeekLayout.blockTip(c, b, boundsEditable: true, editable: true, t)))
            }
            if !c.locked {
                for gap in c.gaps {
                    let r = geo.gapRect(i, gap)
                    if r.height >= TTWeekLayout.minGapHeight { out.append((r, TTWeekLayout.gapTip(c, gap, t))) }
                }
            }
        }
        for (rect, text) in out where rect.width > 0 && rect.height > 0 {
            let tag = addToolTip(rect, owner: self, userData: nil)
            tips[tag] = text
        }
    }

    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint,
              userData data: UnsafeMutableRawPointer?) -> String {
        tips[tag] ?? ""
    }

    /// A pointing hand over clickable times, day headers with warnings, free
    /// areas and work away from the Mac; the arrows up and down on the edges.
    override func resetCursorRects() {
        let geo = self.geo
        let zones = TTWeekLayout.edgeRects(geo, data).map(\.rect)
        var clickable = blockBoxes(geo).flatMap { $0.pieces.filter { $0.part != nil }.map(\.hitRect) }
        clickable += data.cols.enumerated().filter { !$0.element.warnings.isEmpty }.map { geo.headerRect($0.offset) }
        if let now = data.snap?.now {
            // Free areas with breaks: a click enters work away from the Mac
            // (without the edges, which have a pointer of their own).
            for (i, c) in data.cols.enumerated() {
                clickable += TTWeekLayout.freeSpans(c, now: now)
                    .map { TTWeekLayout.withoutZones(geo.gapRect(i, $0), zones) }
                    .filter { $0.height > 0 }
            }
        }
        for (i, c) in data.cols.enumerated() where !c.locked {
            clickable += c.manual.map { geo.spanRect(i, $0.span) }
        }
        for r in clickable { addCursorRect(r, cursor: .pointingHand) }
        for r in zones { addCursorRect(r, cursor: .rowResize) }
    }

    // MARK: VoiceOver

    // The grid draws itself; for VoiceOver it is a group with an element per
    // day header, block, break and work away from the Mac.

    override func isAccessibilityElement() -> Bool { true }

    override func accessibilityRole() -> NSAccessibility.Role? { .group }

    override func accessibilityLabel() -> String? {
        guard let snap = data.snap else { return nil }
        let t = self.t
        let summary = TTWeekLayout.weekSummary(snap, monday: data.monday, data.cols, t)
        return String(format: t.week.axWeekFormat, TTWeekLayout.spoken(TTWeekLayout.title(monday: data.monday, t)),
                      TTWeekLayout.spoken(summary))
    }

    /// The elements carry their place on the screen; they are built anew when
    /// the state, the size or the place changes, otherwise they stay the same
    /// objects so VoiceOver keeps its place.
    override func accessibilityChildren() -> [Any]? {
        func onScreen(_ r: CGRect) -> CGRect {
            guard let window else { return r }
            return window.convertToScreen(convert(r, to: nil))
        }
        let frame = onScreen(bounds)
        let key = [generation, Int(frame.minX.rounded()), Int(frame.minY.rounded()), Int(frame.width.rounded()),
                   Int(frame.height.rounded())]
        if let cache = axCache, cache.key == key { return cache.elements }
        let t = self.t
        let geo = self.geo
        let zones = TTWeekLayout.edgeRects(geo, data)
        let elements: [Any] = TTWeekLayout.axItems(data.cols, t).map { item in
            let rect: CGRect
            switch item.part {
            case .header: rect = geo.headerRect(item.col)
            case let .span(sp): rect = geo.spanRect(item.col, sp)
            }
            let element = NSAccessibilityElement.element(withRole: .staticText, frame: onScreen(rect), label: item.text,
                                                         parent: self)
            // First and last block: the start and end of work as actions.
            let c = data.cols[item.col]
            if case let .span(sp) = item.part, let e = c.edges, let ax = element as? NSAccessibilityElement {
                let work = c.blocks.filter { $0.kind == .work }
                let bounds = [(TTEditBound.start, work.first?.span == sp), (.end, work.last?.span == sp)]
                    .filter { bound, on in on && zones.contains { $0.col == item.col && $0.bound == bound } }
                    .map(\.0)
                if !bounds.isEmpty { ax.setAccessibilityCustomActions(boundActions(c.date, bounds, e, t)) }
            }
            return element
        }
        axCache = (key, elements)
        return elements
    }

    /// Actions for VoiceOver on a block: the start or end 5 minutes earlier
    /// or later, change (dialog) and, when set by hand, reset.
    private func boundActions(_ date: TTDate, _ bounds: [TTEditBound], _ e: TTWeekEdges,
                              _ t: TTWeekTexts) -> [NSAccessibilityCustomAction] {
        let w = t.week
        var out: [NSAccessibilityCustomAction] = []
        for bound in bounds {
            let start = bound == .start
            out.append(NSAccessibilityCustomAction(name: start ? w.startEarlier : w.endEarlier) { [weak self] in
                self?.nudge(date, bound, later: false) ?? false
            })
            out.append(NSAccessibilityCustomAction(name: start ? w.startLater : w.endLater) { [weak self] in
                self?.nudge(date, bound, later: true) ?? false
            })
            out.append(NSAccessibilityCustomAction(name: start ? w.changeStart : w.changeEnd) { [weak self] in
                self?.showBoundDialog(date, bound)
                return true
            })
            if e.get(bound).manual {
                out.append(NSAccessibilityCustomAction(name: start ? w.resetStart : w.resetEnd) { [weak self] in
                    self?.setBound(date, bound, nil)
                    return true
                })
            }
        }
        return out
    }
}
