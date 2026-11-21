// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import Combine

/// The view of the Records window: the table with the inspector, or the week.
enum RecordsMode: Int {
    case days = 0
    case week = 1
}

/// The state of the Records window and what it does (Tagwerk's `records.rs`
/// without the AppKit layout): it reads the days through the service, edits
/// them through `TimeTrackingService.editDay` so a running period stays
/// consistent, and keeps the undo history. The decisions themselves are the
/// pure functions of `TTEdits` and `TTRecords`. Main thread only.
final class RecordsModel: ObservableObject {
    /// A refused input, shown right above its fields.
    struct InspectorError: Equatable {
        var input: TTEditInput
        var text: String
    }

    /// The note that a new start or end of work cut work away from the Mac.
    struct CutNote: Equatable {
        var date: TTDate
        var bound: TTEditBound
    }

    /// Without an absence: whole or half day for the kind chosen next, per
    /// day, so a rebuild does not forget it.
    struct HalfChoice: Equatable {
        var date: TTDate
        var half: Bool
    }

    /// Why a change was not saved.
    enum NotSaved {
        case refused(TTEditInput?, String)
        case failed(String)
    }

    @Published private(set) var days: [TTDay] = []
    @Published private(set) var settings = TTSettings()
    @Published private(set) var now: TTDateTime
    @Published private(set) var rows: [TTRecordsRow] = []
    /// Bumped whenever `rows` is rebuilt, so the table reloads only then.
    @Published private(set) var rowsVersion = 0
    @Published private(set) var cards: [TTRecordsCard] = []
    @Published private(set) var footer = ""
    /// The database could not be read.
    @Published private(set) var error: String?
    /// What recording does (`nil`: recording is off).
    @Published private(set) var status: TTStatus?
    /// The window's subtitle.
    @Published private(set) var statusLine = ""
    @Published private(set) var filter = TTRecordsFilter()
    @Published private(set) var mode: RecordsMode
    @Published private(set) var inspectorShown: Bool
    @Published private(set) var selected: TTDate?
    /// Bumped when the table should scroll to the selected day.
    @Published private(set) var revealToken = 0
    /// Bumped when the inspector is built anew (as Tagwerk's `build_inspector`):
    /// after every change that is not a running input in a time field.
    @Published private(set) var inspectorEpoch = 0
    @Published var inspectorError: InspectorError?
    @Published var cutNote: CutNote?
    @Published private(set) var halfChoice: HalfChoice?
    @Published var recordedOpen: Bool {
        didSet { UserDefaults.standard.set(recordedOpen, forKey: DefaultsKey.timeTrackingRecordsRecordedOpen) }
    }
    /// The Monday of the week the week view shows.
    @Published private(set) var weekMonday: TTDate
    /// The week view shows the whole working-time frame, not only this week's working time.
    @Published private(set) var weekFullFrame: Bool
    private(set) var history = TTEditHistory()

    weak var window: NSWindow?
    /// The export dialog's controls while it is open.
    var exportAccessory: RecordsExportAccessory?
    private var pendingReload = false

    private var service: TimeTrackingService { TimeTrackingService.shared }
    var texts: TimeTrackingTexts { FeatureStrings.timeTrackingTexts(L10n.shared.language) }
    var strings: TimeTrackingRecordsStrings { FeatureStrings.timeTrackingRecords(L10n.shared.language) }

    init() {
        let defaults = UserDefaults.standard
        let now = TimeTrackingService.shared.now()
        self.now = now
        mode = RecordsMode(rawValue: defaults.integer(forKey: DefaultsKey.timeTrackingRecordsView)) ?? .days
        inspectorShown = defaults.object(forKey: DefaultsKey.timeTrackingRecordsInspector) as? Bool ?? true
        recordedOpen = defaults.bool(forKey: DefaultsKey.timeTrackingRecordsRecordedOpen)
        // A freshly opened window shows the current week.
        weekMonday = TTWeekLayout.monday(now.date)
        weekFullFrame = defaults.bool(forKey: DefaultsKey.timeTrackingRecordsWeekFullFrame)
    }

    // MARK: Loading

    func day(_ date: TTDate) -> TTDay? {
        days.first { $0.date == date }
    }

    /// Reads everything again and shows it.
    func load() {
        pendingReload = false
        do {
            let state = try service.recordsState()
            days = state.days
            settings = state.settings
            now = state.now
            error = nil
        } catch {
            now = service.now()
            self.error = String(format: strings.readFailedFormat, String(describing: error))
        }
        status = service.status
        statusLine = service.snapshot?.menu.status.text ?? strings.subtitleOff
        rebuild()
    }

    /// The service changed (a tick, the menu bar, an event): read again once
    /// the current work is done.
    func scheduleReload() {
        guard !pendingReload else { return }
        pendingReload = true
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pendingReload else { return }
            self.load()
        }
    }

    private func rebuild() {
        let today = now.date
        rows = TTRecords.rows(days, settings: settings, filter: filter, today: today)
        rowsVersion += 1
        cards = TTRecords.cards(days, settings: settings, today: today, texts, strings)
        updateFooter()
    }

    private func updateFooter() {
        footer = error ?? TTRecords.footer(rows: rows, days: days, settings: settings, filter: filter,
                                           selected: selected, today: now.date, texts, strings)
    }

    // MARK: Selection, view and filter

    /// A day chosen in the table (`nil`: none). A day added without a row
    /// stays selected when the table loses its selection.
    func select(_ date: TTDate?) {
        if date == nil, let current = selected, !rows.contains(where: { $0.date == current }) { return }
        guard date != selected else { return }
        selected = date
        inspectorError = nil
        cutNote = nil
        inspectorEpoch += 1
        updateFooter()
    }

    /// Shows a day (also one without a row) in the table and the inspector
    /// (`records.rs` `go_to`).
    func goTo(_ date: TTDate) {
        // A filter that hides the day is reset, or its row would stay invisible.
        if filter.isActive, !rows.contains(where: { $0.date == date }), day(date) != nil {
            setFilter(TTRecordsFilter())
        }
        if mode != .days { setMode(.days) }
        select(date)
        if !inspectorShown { toggleInspector() }
        revealToken += 1
    }

    /// ⌘T: today in the table, or the current week in the week view.
    func goToday() {
        switch mode {
        case .days: goTo(service.now().date)
        case .week: showWeek(of: service.now().date)
        }
    }

    /// Switches between "Days" and "Week". The week shows the week of the
    /// selected day (without a selection the current one) (`records.rs` `set_mode`).
    func setMode(_ mode: RecordsMode) {
        guard mode != self.mode else { return }
        self.mode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.timeTrackingRecordsView)
        if mode == .week { showWeek(of: selected ?? service.now().date) }
    }

    /// Double-click or "Show in Week View" on a row: its week (a week row:
    /// that week). A day is selected as well, so "Days" shows it when coming back.
    func showInWeek(_ row: TTRecordsRow) {
        if let date = row.date { select(date) }
        setMode(.week)
        switch row {
        case let .week(monday, _, _, _, _): showWeek(of: monday)
        case let .day(day, _, _): showWeek(of: day.date)
        case let .missing(date, _): showWeek(of: date)
        }
    }

    // MARK: Week view

    /// Shows the week of `date` in the week view.
    func showWeek(of date: TTDate) {
        let monday = TTWeekLayout.monday(date)
        if monday != weekMonday { weekMonday = monday }
    }

    /// ‹ and › or the arrow keys: `weeks` weeks on or back.
    func stepWeek(_ weeks: Int) {
        weekMonday = weekMonday.adding(days: 7 * weeks)
    }

    /// "Whole working hours" in the week view (remembered).
    func setWeekFullFrame(_ on: Bool) {
        guard on != weekFullFrame else { return }
        weekFullFrame = on
        UserDefaults.standard.set(on, forKey: DefaultsKey.timeTrackingRecordsWeekFullFrame)
    }

    /// The state for the week view, with what runs right now. After the end of
    /// work recording goes on, but nothing runs along any more.
    var weekSnapshot: TTWeekSnapshot {
        let running: Bool
        switch status {
        case .running?, .away?: running = true
        default: running = false
        }
        return TTWeekSnapshot(days: days, settings: settings, now: now, running: running)
    }

    /// Work away from the Mac entered in the week view (already checked by
    /// `TTWeekLayout.workInput`). Short gaps to neighbouring work join the new
    /// block, with a note (`week_view.rs` `show_add_work`).
    func addWork(_ date: TTDate, _ entered: TTSpan, activity: TTActivity) {
        let minPause = settings.rules(date).minPause
        var span = entered
        var note: String?
        if let day = day(date) {
            let joined = day.joinWorkGaps(from: entered.from, to: entered.to, minPause: minPause)
            span = joined.span
            note = joined.note(minPause: minPause, texts)
        }
        let before = day(date)
        save(date, .addWork(span.from, span.to, activity.note(texts)), rebuild: true)
        // Only when it was saved (not refused, and not waiting for a question).
        if let note, day(date) != before { showSheetLater(strings.gapAddedTitle, note) }
    }

    func toggleInspector() {
        guard mode == .days else { return }
        inspectorShown.toggle()
        UserDefaults.standard.set(inspectorShown, forKey: DefaultsKey.timeTrackingRecordsInspector)
    }

    func setFilter(_ filter: TTRecordsFilter) {
        guard filter != self.filter else { return }
        self.filter = filter
        rebuild()
    }

    // MARK: Editing

    /// Applies an edit to the selected day. `rebuild`: a whole change (button,
    /// checkbox, popup); without it a running input in a time field, which
    /// the history merges into one step.
    func apply(_ edit: TTEdit, rebuild: Bool = true) {
        guard let date = selected else { return }
        save(date, edit, rebuild: rebuild)
    }

    /// Saves a change of the day `date` and shows it. Would it make the first
    /// entry long before the first day so far, a question comes first (see
    /// `TTEdits.beforeFirstText`); then it is saved only after "Enter".
    func save(_ date: TTDate, _ edit: TTEdit, rebuild: Bool) {
        let day = self.day(date) ?? TTDay(date: date)
        let t = service.now()
        // What is refused anyway needs no question.
        let goes = edit.addsEntry && !TTEdits.refuses(day, edit)
            && TTEdits.refusal(day, edit, settings: settings, now: t, texts, strings) == nil
        if goes, let text = TTEdits.beforeFirstText(days, date: date, settings: settings, today: t.date, texts, strings) {
            confirmBeforeFirst(date, text) { [weak self] in
                guard let self, let cut = self.storeEdit(date, edit, rebuild: true), self.mode == .week else { return }
                self.showSheetLater(self.strings.workCutTitle, TTEdits.cutText(cut, self.strings))
            }
            return
        }
        // In the inspector the note stands below the field, in the week as a message.
        if let cut = storeEdit(date, edit, rebuild: rebuild), mode == .week {
            showSheetLater(strings.workCutTitle, TTEdits.cutText(cut, strings))
        }
    }

    /// Saves a change without asking (see `save`). Returns whether a new start
    /// or end of work cut work away from the Mac.
    @discardableResult
    private func storeEdit(_ date: TTDate, _ edit: TTEdit, rebuild: Bool) -> TTEditBound? {
        let (settings, texts, strings) = (self.settings, self.texts, self.strings)
        let service = self.service
        var outcome: TTEditOutcome?
        do {
            try service.editDay(date) { day in
                outcome = TTEdits.apply(edit, to: &day, settings: settings, now: service.now(), texts, strings)
            }
        } catch {
            load()
            report(date, .failed(String(describing: error)), rebuild: rebuild)
            return nil
        }
        guard let outcome else { return nil }
        if let refusal = outcome.refusal {
            load()
            report(date, .refused(edit.input, refusal), rebuild: rebuild)
            return nil
        }
        if outcome.before != outcome.after {
            history.record(TTEditStep(name: edit.name, date: date, before: outcome.before, after: outcome.after),
                           followUp: !rebuild)
        }
        saved(rebuild: rebuild)
        let cut = outcome.cut(edit)
        if let cut, selected == date { cutNote = CutNote(date: date, bound: cut) }
        return cut
    }

    /// After saving: read again and show everything. A rebuild clears the
    /// notes of the inspector; a running input only the refused start or end.
    private func saved(rebuild: Bool) {
        if rebuild {
            inspectorError = nil
            cutNote = nil
            inspectorEpoch += 1
        } else if let input = inspectorError?.input, input == .start || input == .end {
            inspectorError = nil
        }
        load()
    }

    /// A change that was not saved: above its input when the inspector shows
    /// the day, otherwise as a message on the window.
    func report(_ date: TTDate, _ e: NotSaved, rebuild: Bool) {
        if case let .refused(input?, text) = e, mode == .days, inspectorShown, selected == date {
            if rebuild { inspectorEpoch += 1 }
            inspectorError = InspectorError(input: input, text: text)
            return
        }
        switch e {
        case let .refused(_, text): showSheetLater(strings.notSaved, text)
        case let .failed(text): showSheetLater(strings.saveFailed, text)
        }
    }

    /// The absence chose in the inspector: kind (`nil`: none) and whole or
    /// half day. Whole or half without an absence applies to the kind chosen
    /// next (saved only then) (`absence_changed`).
    func absenceChanged(_ date: TTDate, kind: TTAbsenceKind?, half: Bool, fromPart: Bool) {
        let isToday = date == service.now().date
        // Next to other entries only a half day ("Whole Day" is locked).
        let busy = day(date)?.blocksFullAbsence(today: isToday) ?? false
        if fromPart { halfChoice = HalfChoice(date: date, half: half) }
        if fromPart && kind == nil {
            inspectorEpoch += 1
            return
        }
        setAbsence(date, kind.map { TTAbsence($0, half: busy || half) })
    }

    /// Whole or half day preselected for `date` without an absence.
    func prefersHalf(_ date: TTDate) -> Bool {
        halfChoice?.date == date && halfChoice?.half == true
    }

    /// Enters, changes or removes an absence. A whole-day absence today next
    /// to recorded time asks first: the time goes, and recording ends for
    /// today (`set_absence`).
    func setAbsence(_ date: TTDate, _ absence: TTAbsence?) {
        let isToday = date == service.now().date
        guard let absence, let day = day(date), day.clearsForAbsence(absence, today: isToday) else {
            save(date, .setAbsence(absence), rebuild: true)
            return
        }
        let recorded = day.periods.reduce(0) { $0 + $1.len }
        // Vacation, sickness and holidays come as half days too, next to the recorded time.
        let half = absence.kind.allowsHalf ? TTAbsence(absence.kind, half: true) : nil
        var buttons = [AlertButton(strings.absenceWholeButton, destructive: true), AlertButton(strings.cancel, isDefault: true)]
        if half != nil { buttons.append(AlertButton(strings.absenceHalfButton)) }
        ask(String(format: strings.absenceTodayTitleFormat, absence.label(texts)),
            TTEdits.absenceTodayText(recorded: recorded, half: half != nil, texts, strings), buttons: buttons) { [weak self] i in
            guard let self else { return }
            switch i {
            case 0: self.save(date, .setAbsence(absence), rebuild: true)
            case 2: self.save(date, .setAbsence(half), rebuild: true)
            default: self.inspectorEpoch += 1
            }
        }
    }

    /// "Add" under the breaks.
    func addBreak(from: Int, to: Int) {
        guard let date = selected else { return }
        let min = settings.rules(date).minPause
        if to - from >= min {
            apply(.addBreak(from, to))
        } else if to > from {
            inspectorError = InspectorError(input: .breaks, text: String(format: strings.breakMinFormat, min / 60))
        } else {
            inspectorError = InspectorError(input: .breaks, text: strings.breakOrder)
        }
    }

    /// "Add" under work away from the Mac. Short gaps to neighbouring work
    /// join the new block, with a note.
    func addWork(from: Int, to: Int, activity: TTActivity) {
        guard let date = selected else { return }
        let minWork = settings.minWork
        guard to > from else {
            inspectorError = InspectorError(input: .work, text: strings.workOrder)
            return
        }
        if TTSpan.shownLen(from: from, to: to) < minWork {
            inspectorError = InspectorError(input: .work, text: TTRecords.minWorkText(minWork, strings))
            return
        }
        let minPause = settings.rules(date).minPause
        var span = TTSpan(from, to)
        var note: String?
        if let day = day(date) {
            let joined = day.joinWorkGaps(from: from, to: to, minPause: minPause)
            span = joined.span
            note = joined.note(minPause: minPause, texts)
        }
        apply(.addWork(span.from, span.to, activity.note(texts)))
        if let note { showSheetLater(strings.gapAddedTitle, note) }
    }

    /// "Delete All Entries…": asks first, naming what goes.
    func confirmClearDay(_ date: TTDate) {
        guard let day = day(date) else { return }
        let isToday = date == service.now().date
        ask(String(format: strings.clearTitleFormat, TTRecords.longDate(date, strings)),
            TTEdits.clearDayText(day, isToday: isToday, texts, strings),
            buttons: [AlertButton(strings.delete, destructive: true), AlertButton(strings.cancel, isDefault: true)]) { [weak self] i in
            if i == 0 { self?.save(date, .clearDay, rebuild: true) }
        }
    }

    // MARK: Undo and redo

    func canStep(redo: Bool) -> Bool {
        !(redo ? history.redo : history.undo).isEmpty
    }

    /// `Undo Remove Break`, without a step only `Undo`.
    func historyTitle(redo: Bool) -> String {
        let step = redo ? history.redo.last : history.undo.last
        return TTEdits.historyTitle(redo: redo, name: step?.name.title(strings), strings)
    }

    /// Undo or redo (`redo`): takes back or repeats what the last step
    /// changed, as far as it has not changed differently since (see
    /// `TTCorrections.rewind`), and shows the day. The step moves to the other
    /// side, so both can alternate. If it works only partly or not at all, a
    /// note says why; a step that does not work at all goes (`step_history`).
    func stepHistory(redo: Bool) {
        guard let step = redo ? history.redo.popLast() : history.undo.popLast() else { return }
        let (done, target) = redo ? (step.before, step.after) : (step.after, step.before)
        var outcome: TTRewind?
        do {
            try service.editDay(step.date) { day in
                outcome = TTCorrections.rewind(&day, done: done, target: target)
            }
        } catch {
            // Nothing changed: the step stays where it was.
            if redo { history.redo.append(step) } else { history.undo.append(step) }
            showSheetLater(strings.saveFailed, String(describing: error))
            return
        }
        guard let outcome else { return }
        if case .refused = outcome {
        } else if redo {
            history.undo.append(step)
        } else {
            history.redo.append(step)
        }
        saved(rebuild: true)
        if let note = TTEdits.rewindNote(redo: redo, name: step.name.title(strings), date: step.date, outcome,
                                         texts, strings) {
            showSheetLater(note.title, note.text)
        }
        // Show what changed.
        if mode == .days {
            goTo(step.date)
        } else {
            select(step.date)
            showWeek(of: step.date)
        }
    }

    /// The history refers to the state before an import: it goes.
    func forgetHistory() {
        history = TTEditHistory()
    }

    func reloadAfterImport() {
        forgetHistory()
        saved(rebuild: true)
    }

    // MARK: Questions and messages

    struct AlertButton {
        var title: String
        var destructive = false
        /// Return chooses it (otherwise nothing does, so it is not confirmed by accident).
        var isDefault = false
        /// Escape chooses it.
        var isCancel = false

        init(_ title: String, destructive: Bool = false, isDefault: Bool = false, isCancel: Bool = false) {
            self.title = title
            self.destructive = destructive
            self.isDefault = isDefault
            self.isCancel = isCancel
        }
    }

    /// Asks with a sheet on the window; `done` gets the index of the button.
    /// Waits while another sheet is open.
    func ask(_ title: String, _ text: String, buttons: [AlertButton], style: NSAlert.Style = .warning,
             done: @escaping (Int) -> Void) {
        guard let window else { return }
        if window.attachedSheet != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.ask(title, text, buttons: buttons, style: style, done: done)
            }
            return
        }
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = text
        for b in buttons {
            let button = alert.addButton(withTitle: b.title)
            button.hasDestructiveAction = b.destructive
            button.keyEquivalent = b.isDefault ? "\r" : b.isCancel ? "\u{1b}" : ""
        }
        if buttons.contains(where: \.isDefault) == false, let first = alert.buttons.first {
            first.keyEquivalent = "\r"
        }
        alert.beginSheetModal(for: window) { response in
            done(response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
        }
    }

    /// A message with "OK" as a sheet, once no other sheet is open (from the
    /// handler of another sheet, for example).
    func showSheetLater(_ title: String, _ text: String, style: NSAlert.Style = .informational) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.ask(title, text, buttons: [AlertButton(self.strings.ok, isDefault: true)], style: style) { _ in }
        }
    }

    /// The question before the first entry long before the first recorded
    /// day; "Enter" runs `proceed`, "Cancel" changes nothing.
    private func confirmBeforeFirst(_ date: TTDate, _ text: String, proceed: @escaping () -> Void) {
        ask(String(format: strings.beforeFirstTitleFormat, TTRecords.longDate(date, strings)), text,
            buttons: [AlertButton(strings.enter), AlertButton(strings.cancel, isDefault: true)]) { [weak self] i in
            if i == 0 {
                proceed()
            } else {
                // The inspector back to the saved state.
                self?.inspectorEpoch += 1
            }
        }
    }

    /// "Edit Day…": chooses a day in a calendar and opens it.
    func askDay() {
        guard let window, window.attachedSheet == nil else { return }
        let today = service.now().date
        let picker = NSDatePicker()
        picker.datePickerStyle = .clockAndCalendar
        picker.datePickerElements = .yearMonthDay
        picker.locale = RecordsTime.locale
        picker.calendar = RecordsTime.calendar
        picker.timeZone = RecordsTime.calendar.timeZone
        picker.maxDate = RecordsTime.date(today, 12 * 3600)
        picker.dateValue = RecordsTime.date(selected ?? today, 12 * 3600)
        picker.isBezeled = false
        picker.drawsBackground = false
        picker.sizeToFit()
        let alert = NSAlert()
        alert.messageText = strings.editDay
        alert.informativeText = strings.editDayMessage
        alert.addButton(withTitle: strings.open)
        alert.addButton(withTitle: strings.cancel)
        alert.accessoryView = picker
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self else { return }
            self.goTo(Swift.min(RecordsTime.day(picker.dateValue), self.service.now().date))
        }
    }
}

/// Days and times of day as `Date` for the pickers: local wall-clock time in
/// the Gregorian calendar, like `TTDateTime(local:timeZone:)`.
enum RecordsTime {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }

    /// 24 hours in every language, as in the table.
    static var locale: Locale {
        Locale(identifier: L10n.shared.language == .de ? "de_DE" : "en_GB")
    }

    /// `secs` on the day `date` (24:00 becomes 23:59).
    static func date(_ date: TTDate, _ secs: Int) -> Date {
        let s = secs.ttClamped(0, TTLimits.dayEnd - 60)
        let components = DateComponents(year: date.year, month: date.month, day: date.day, hour: s / 3600,
                                        minute: s % 3600 / 60)
        return calendar.date(from: components) ?? Date()
    }

    /// Seconds since midnight of a picked time, down to the shown minute.
    static func secs(_ value: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: value)
        return (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60
    }

    static func day(_ value: Date) -> TTDate {
        TTDateTime(local: value, timeZone: calendar.timeZone).date
    }
}
