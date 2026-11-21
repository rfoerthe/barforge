// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import SwiftUI

/// The content of the Records window: in "Days" the five cards, the table
/// and the inspector; in "Week" the week view (M7, a placeholder until then);
/// the footer below both.
struct RecordsRootView: View {
    @ObservedObject var model: RecordsModel

    var body: some View {
        VStack(spacing: 0) {
            switch model.mode {
            case .days:
                RecordsCardsRow(cards: model.cards)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                Divider()
                HStack(spacing: 0) {
                    RecordsTable(model: model)
                        .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
                    if model.inspectorShown {
                        Divider()
                        RecordsInspector(model: model)
                            .frame(width: 340)
                    }
                }
            case .week:
                RecordsWeekPlaceholder(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            Text(model.footer)
                .font(.system(size: NSFont.smallSystemFontSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26, alignment: .leading)
                .padding(.horizontal, 20)
        }
        .frame(minWidth: 940, minHeight: 480)
    }
}

/// A balance in its colour: green in the plus (and even), red in the minus.
func recordsBalanceColor(_ secs: Int) -> Color {
    Color(nsColor: TimeTrackingPalette.balance(secs))
}

/// The five cards of the overview.
struct RecordsCardsRow: View {
    let cards: [TTRecordsCard]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                RecordsCard(card: card)
            }
        }
    }
}

private struct RecordsCard: View {
    let card: TTRecordsCard

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.title)
                .font(.system(size: NSFont.smallSystemFontSize))
                .foregroundStyle(.secondary)
            Text(card.value)
                .font(.system(size: 24, weight: .semibold).monospacedDigit())
                .foregroundStyle(card.valueBalance.map(recordsBalanceColor) ?? Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.system(size: NSFont.smallSystemFontSize).monospacedDigit())
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .quaternarySystemFill)))
    }

    /// The detail line, with the balance at its end in colour.
    private var detail: AttributedString {
        var text = AttributedString(card.detail)
        text.foregroundColor = Color.secondary
        if let balance = card.detailBalance {
            var value = AttributedString(TTFormat.balance(balance))
            value.foregroundColor = recordsBalanceColor(balance)
            text += value
        }
        return text
    }
}

/// "Week" until the week view arrives (M7).
struct RecordsWeekPlaceholder: View {
    @ObservedObject var model: RecordsModel

    var body: some View {
        let s = model.strings
        VStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text(s.weekPlaceholderTitle)
                .font(.title2.weight(.semibold))
            if let date = model.selected {
                Text(TTRecords.weekTitle(monday: TTRecords.monday(date), week: date.isoWeek.week, model.texts, s))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(s.weekPlaceholderText)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button(s.days) { model.setMode(.days) }
                .padding(.top, 4)
        }
        .padding(40)
    }
}

// MARK: Table

/// The table of days: an `NSTableView`, because it handles hundreds of rows,
/// floating week rows across all columns and coloured cells that turn
/// readable on the selection.
struct RecordsTable: NSViewRepresentable {
    @ObservedObject var model: RecordsModel

    func makeCoordinator() -> RecordsTableCoordinator {
        RecordsTableCoordinator(model: model)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let s = model.strings
        let table = NSTableView()
        table.style = .fullWidth
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = false
        table.allowsEmptySelection = true
        table.allowsColumnReordering = false
        table.floatsGroupRows = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        // Identifier, title, width, minimum and maximum (extra room goes to the date).
        let columns: [(RecordsTableCoordinator.Column, String, CGFloat, CGFloat, CGFloat)] = [
            (.mark, "", 42, 42, 42),
            (.date, s.columnDate, 150, 110, 10_000),
            (.start, s.columnStart, 64, 56, 120),
            (.end, s.columnEnd, 64, 56, 120),
            (.work, s.columnWork, 96, 76, 150),
            (.pause, s.columnBreaks, 70, 60, 130),
            (.balance, s.columnBalance, 80, 66, 130),
        ]
        for (id, title, width, min, max) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id.rawValue))
            column.title = title
            column.width = width
            column.minWidth = min
            column.maxWidth = max
            if id == .mark {
                column.resizingMask = []
                column.headerToolTip = s.markColumnTip
            } else if id != .date {
                column.headerCell.alignment = .right
            }
            table.addTableColumn(column)
        }
        table.autosaveName = "BarforgeTimeTrackingRecordsTable"
        table.autosaveTableColumns = true
        table.dataSource = coordinator
        table.delegate = coordinator
        table.target = coordinator
        table.doubleAction = #selector(RecordsTableCoordinator.doubleClicked(_:))
        let menu = NSMenu()
        let item = NSMenuItem(title: s.showInWeek, action: #selector(RecordsTableCoordinator.showInWeek(_:)),
                              keyEquivalent: "")
        item.target = coordinator
        menu.addItem(item)
        table.menu = menu
        coordinator.table = table

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        coordinator.update(model: model)
        DispatchQueue.main.async { [weak table] in
            guard let table else { return }
            coordinator.revealSelection()
            table.window?.makeFirstResponder(table)
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.update(model: model)
    }
}

/// Data source and delegate of the table (`records.rs` `cell_view` and the
/// table delegate).
final class RecordsTableCoordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuItemValidation {
    enum Column: String {
        case mark, date, start, end, work, pause, balance
    }

    private(set) var model: RecordsModel
    weak var table: NSTableView?
    private var rows: [TTRecordsRow] = []
    private var version = -1
    private var revealToken = -1
    private var syncing = false

    init(model: RecordsModel) {
        self.model = model
    }

    /// Takes over new rows (only when they changed) and the selection.
    func update(model: RecordsModel) {
        self.model = model
        guard let table else { return }
        if model.rowsVersion != version {
            version = model.rowsVersion
            rows = model.rows
            syncing = true
            table.reloadData()
            syncing = false
        }
        syncSelection()
        if model.revealToken != revealToken {
            revealToken = model.revealToken
            revealSelection()
        }
    }

    private func syncSelection() {
        guard let table else { return }
        let row = model.selected.flatMap { date in rows.firstIndex { $0.date == date } }
        syncing = true
        defer { syncing = false }
        if let row {
            if table.selectedRow != row { table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
        } else if table.selectedRow >= 0 {
            table.deselectAll(nil)
        }
    }

    func revealSelection() {
        guard let table, let date = model.selected, let row = rows.firstIndex(where: { $0.date == date }) else { return }
        table.scrollRowToVisible(row)
    }

    private func row(_ index: Int) -> TTRecordsRow? {
        rows.indices.contains(index) ? rows[index] : nil
    }

    // MARK: Data source and delegate

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        self.row(row)?.isWeek ?? false
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        !(self.row(row)?.isWeek ?? true)
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        self.row(row)?.isWeek == true ? 28 : 26
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !syncing, let table else { return }
        model.select(row(table.selectedRow)?.date)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row index: Int) -> NSView? {
        guard let row = row(index) else { return nil }
        let column = tableColumn.flatMap { Column(rawValue: $0.identifier.rawValue) }
        switch row {
        case let .week(monday, week, workdays, total, balance):
            return weekCell(monday: monday, week: week, workdays: workdays, total: total, balance: balance)
        case let .day(day, rec, warnings):
            guard let column else { return nil }
            return dayCell(column, day: day, rec: rec, warnings: warnings)
        case let .missing(date, target):
            guard let column else { return nil }
            return missingCell(column, date: date, target: target)
        }
    }

    // MARK: Cells

    private var strings: TimeTrackingRecordsStrings { model.strings }
    private var texts: TimeTrackingTexts { model.texts }

    private static func digits(_ weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: weight)
    }

    private static func label(_ text: String, font: NSFont = digits(), color: NSColor? = nil,
                              alignment: NSTextAlignment = .left) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.alignment = alignment
        field.lineBreakMode = .byTruncatingTail
        if let color { field.textColor = color }
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    /// `KW 47  ·  16.11. – 22.11.2026` on the left, total and coloured balance on the right.
    private func weekCell(monday: TTDate, week: Int, workdays: Int, total: Int, balance: Int) -> NSView {
        let cell = NSTableCellView()
        let title = Self.label(TTRecords.weekTitle(monday: monday, week: week, texts, strings),
                               font: .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold))
        let summary = NSMutableAttributedString(
            string: TTRecords.weekTotal(workdays: workdays, total: total, strings),
            attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: Self.digits()])
        summary.append(NSAttributedString(string: TTFormat.balance(balance),
                                          attributes: [.foregroundColor: TimeTrackingPalette.balance(balance),
                                                       .font: Self.digits()]))
        let right = NSTextField(labelWithAttributedString: summary)
        right.alignment = .right
        right.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(title)
        cell.addSubview(right)
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            title.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            right.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
            right.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            right.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: 12),
        ])
        cell.textField = title
        return cell
    }

    private func dayCell(_ column: Column, day: TTDay, rec: TTDayRecord, warnings: [TTWarning]) -> NSView? {
        let today = model.now.date
        if column == .mark {
            // Two fixed places, so the symbols line up across rows: the
            // warning sign on the left, the pencil for corrections on the right.
            var marks: [(slot: Int, symbol: String, color: NSColor, tip: String)] = []
            if !warnings.isEmpty {
                marks.append((0, "exclamationmark.triangle.fill", .systemOrange,
                              warnings.map { $0.text(texts) }.joined(separator: "\n")))
            }
            if day.hasCorrections {
                marks.append((1, "pencil", .secondaryLabelColor, strings.correctedTip))
            }
            return markCell(marks)
        }
        let isToday = rec.date == today
        // Without working time (a vacation day, a free day whose recorded time
        // does not count) there is neither start nor end.
        let worked = rec.workSecs > 0 || (!day.periods.isEmpty && !day.uncounted)
        let balance = model.settings.dayBalance(day, rec, today: today)
        let text: String
        var secondary = false
        switch column {
        case .date: text = TTExport.date(rec.date, texts)
        case .start where !worked, .end where !worked:
            text = "–"
            secondary = true
        case .start: text = TTFormat.clock(rec.firstStart)
        case .end:
            let running: Bool
            switch model.status {
            case .running?, .away?: running = true
            default: running = false
            }
            if isToday && day.end == nil && running {
                text = strings.running
                secondary = true
            } else {
                text = TTFormat.clock(rec.lastEnd)
            }
        case .work: text = TTExport.hoursMinutesUnit(rec.shownWorkSecs)
        case .pause: text = TTExport.hoursMinutesUnit(rec.shownPauseSecs)
        case .balance:
            // With an absence there is a balance even without working time
            // (time off); work on a free day that does not count has none.
            text = balance.map(TTFormat.balance) ?? "–"
            secondary = balance == nil
        case .mark: return nil
        }
        let tint = column == .balance ? balance.map(TimeTrackingPalette.balance) : nil
        let cell = RecordsTintedCell(tint: tint)
        let font = Self.digits(isToday && column == .date ? .semibold : .regular)
        let field = Self.label(text, font: font, color: tint ?? (secondary ? .secondaryLabelColor : nil),
                               alignment: column == .date ? .left : .right)
        cell.addSubview(field)
        cell.textField = field
        var constraints = [
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ]
        if column == .date, let absence = day.absence {
            // The absence as a code behind the date ("½ U"); spelled out in the
            // tooltip and the inspector.
            let code = Self.label(absence.code(texts), font: .systemFont(ofSize: NSFont.smallSystemFontSize),
                                  color: .secondaryLabelColor)
            code.toolTip = absence.label(texts)
            cell.addSubview(code)
            field.setContentHuggingPriority(NSLayoutConstraint.Priority(751), for: .horizontal)
            code.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            constraints += [
                code.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 6),
                code.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -2),
                code.firstBaselineAnchor.constraint(equalTo: field.firstBaselineAnchor),
            ]
        } else {
            constraints.append(field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2))
        }
        NSLayoutConstraint.activate(constraints)
        return cell
    }

    private func missingCell(_ column: Column, date: TTDate, target: Int) -> NSView? {
        if column == .mark {
            return markCell([(0, "questionmark.circle", .tertiaryLabelColor, strings.missingTip)])
        }
        let text: String
        switch column {
        case .date: text = TTExport.date(date, texts)
        case .start, .end, .pause: text = "–"
        case .work: text = TTExport.hoursMinutesUnit(0)
        case .balance: text = TTFormat.balance(-target)
        case .mark: return nil
        }
        let tint = column == .balance ? TimeTrackingPalette.balance(-target) : nil
        let cell = RecordsTintedCell(tint: tint)
        let field = Self.label(text, color: tint ?? .secondaryLabelColor, alignment: column == .date ? .left : .right)
        cell.addSubview(field)
        cell.textField = field
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    private func markCell(_ marks: [(slot: Int, symbol: String, color: NSColor, tip: String)]) -> NSView {
        let cell = NSTableCellView()
        for mark in marks {
            let image = NSImageView()
            image.image = NSImage(systemSymbolName: mark.symbol, accessibilityDescription: mark.tip)
            image.contentTintColor = mark.color
            image.toolTip = mark.tip
            image.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(image)
            NSLayoutConstraint.activate([
                image.centerXAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4 + 18 * (CGFloat(mark.slot) + 0.5)),
                image.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            if cell.imageView == nil { cell.imageView = image }
        }
        if !marks.isEmpty { cell.toolTip = marks.map(\.tip).joined(separator: "\n") }
        return cell
    }

    // MARK: Week view

    /// Double-click on a row: its week in the week view.
    @objc func doubleClicked(_ sender: Any?) {
        guard let table, let row = row(table.clickedRow) else { return }
        model.showInWeek(row)
    }

    /// "Show in Week View" from the context menu.
    @objc func showInWeek(_ sender: Any?) {
        guard let table, let row = row(table.clickedRow) else { return }
        model.showInWeek(row)
    }

    /// Only over a row (a right-click into the empty space: dimmed).
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard item.action == #selector(showInWeek(_:)), let table else { return true }
        return row(table.clickedRow) != nil
    }
}

/// A cell whose text has its own colour (the balance). In the selected row it
/// takes the selection's text colour, so it stays readable: green or red on
/// the accent colour would not be.
final class RecordsTintedCell: NSTableCellView {
    private let tint: NSColor?

    init(tint: NSColor?) {
        self.tint = tint
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        tint = nil
        super.init(coder: coder)
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            guard let tint else { return }
            textField?.textColor = backgroundStyle == .emphasized ? .labelColor : tint
        }
    }
}
