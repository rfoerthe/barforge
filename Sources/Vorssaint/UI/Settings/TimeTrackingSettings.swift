// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import SwiftUI
import UserNotifications

/// Settings page of Time Tracking (port of Tagwerk's settings window): one
/// card per tab of Tagwerk (General, Working Time, Recording, Notifications)
/// and one for the data. The preferences live in UserDefaults; the dated
/// working-time rules and the time account belong to the data and are read
/// from and saved to the database, also while recording is off. The
/// decisions (hints, rows, texts, defaults) are `TTSettingsModel`'s.
struct TimeTrackingSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = TimeTrackingService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.timeTrackingEnabled) private var enabled = false
    @AppStorage(DefaultsKey.timeTrackingStatusItem) private var statusItem = true
    @AppStorage(DefaultsKey.timeTrackingIconSet) private var iconSet = TTIconSet.default.id
    @AppStorage(DefaultsKey.timeTrackingShowTime) private var showTime = false
    @AppStorage(DefaultsKey.timeTrackingHotkeys) private var hotkeys = false
    @AppStorage(DefaultsKey.timeTrackingLegalHints) private var legalHints = true
    @AppStorage(DefaultsKey.timeTrackingMinWorkSeconds) private var minWorkSecs = 15 * 60
    @AppStorage(DefaultsKey.timeTrackingIdleSeconds) private var idleSecs = 0
    @AppStorage(DefaultsKey.timeTrackingAskAfterLock) private var askAfterLock = false
    @AppStorage(DefaultsKey.timeTrackingAutoWorkdaysOnly) private var autoWorkdaysOnly = true
    @AppStorage(DefaultsKey.timeTrackingNotifyLimit) private var notifyLimit = true
    @AppStorage(DefaultsKey.timeTrackingNotifyBreak) private var notifyBreak = true

    /// The settings as stored; the page edits their database part (rules and
    /// time account) through it.
    @State private var settings = TTSettings()
    @State private var errorText: String?
    @State private var selectedRule: TTRuleRow.ID?
    @State private var sheet: TimeTrackingRulesRequest?
    @State private var pendingDelete: TTDate?
    @State private var confirmReset = false
    @State private var confirmTakeOver = false
    @State private var takeOverReport: TimeTrackingSettingsReport?
    @State private var minWorkText = ""
    @State private var idleText = ""
    @State private var carryText = ""
    @State private var permission: TTNotificationPermission?
    @State private var tagwerkRunning = false

    private var strings: TimeTrackingSettingsStrings { FeatureStrings.timeTrackingSettings(l10n.language) }
    private var feature: TimeTrackingFeatureStrings { FeatureStrings.timeTracking(l10n.language) }
    private var texts: TimeTrackingTexts { FeatureStrings.timeTrackingTexts(l10n.language) }
    private var menu: TimeTrackingMenuTexts { FeatureStrings.timeTrackingMenu(l10n.language) }
    private var today: TTDate { service.now().date }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(feature.title).font(.title2.bold())
                    Text(feature.hubDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                generalCard
                workingTimeCard
                recordingCard
                notificationsCard
                dataCard
                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .toggleStyle(.switch)
        .onAppear {
            load()
            minWorkText = "\(minWorkSecs / 60)"
            idleText = "\((idleSecs > 0 ? idleSecs : TTSettingsModel.idleDefault) / 60)"
            tagwerkRunning = TimeTrackingTagwerkImport.isTagwerkRunning
            refreshPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermission()
            tagwerkRunning = TimeTrackingTagwerkImport.isTagwerkRunning
        }
        .onReceive(permissions.$notifications) { _ in refreshPermission() }
        .sheet(item: $sheet) { request in
            TimeTrackingRulesSheet(request: request, settings: settings, today: today) { from, rules in
                save { $0.setRules(from: from, rules, replaces: request.editing.replaces) }
            }
        }
        .alert(deleteText.title, isPresented: deleteBinding) {
            Button(strings.deleteRules, role: .destructive) {
                if let from = pendingDelete { save { $0.removeRules(from: from) } }
                pendingDelete = nil
            }
            Button(strings.cancel, role: .cancel) { pendingDelete = nil }
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(deleteText.info)
        }
        .alert(strings.resetTitle, isPresented: $confirmReset) {
            Button(strings.resetConfirm, role: .destructive) { restoreDefaults() }
            Button(strings.cancel, role: .cancel) {}
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(TTSettingsModel.resetInfo(settings, today: today, strings, texts))
        }
        .alert(strings.takeOverConfirmTitle, isPresented: $confirmTakeOver) {
            Button(strings.takeOverConfirmButton, role: .destructive) { takeOver() }
            Button(strings.cancel, role: .cancel) {}
                .keyboardShortcut(.defaultAction)
        } message: {
            Text(tagwerkRunning ? strings.takeOverConfirmInfo + "\n\n" + strings.tagwerkRunning
                                : strings.takeOverConfirmInfo)
        }
        .alert(takeOverReport?.title ?? "", isPresented: reportBinding, presenting: takeOverReport) { _ in
            Button {
                takeOverReport = nil
            } label: {
                Text(verbatim: "OK")
            }
            .keyboardShortcut(.defaultAction)
        } message: { report in
            Text(report.message)
        }
    }

    // MARK: General

    private var generalCard: some View {
        SettingsCard(title: strings.generalSection) {
            SettingsRow(symbol: AppFeature.timeTracking.symbolName, title: feature.recordToggle,
                        caption: feature.recordCaption) {
                Toggle(feature.recordToggle, isOn: $enabled)
                    .labelsHidden()
                    .onChange(of: enabled) { _, _ in
                        service.syncWithPreferences()
                        load()
                    }
            }
            SettingsRow(symbol: "menubar.rectangle", title: strings.statusItem, caption: strings.statusItemCaption) {
                Toggle(strings.statusItem, isOn: $statusItem).labelsHidden()
            }
            if statusItem {
                SettingsMenuRow(symbol: "paintpalette", title: strings.iconSet, selection: $iconSet) {
                    ForEach(TTIconSet.allCases, id: \.self) { set in
                        Label {
                            Text(set.name(texts))
                        } icon: {
                            Image(nsImage: TimeTrackingGlyphs.image(set, .running, size: 14, minWidth: popupIconWidth,
                                                                    description: set.name(texts)))
                        }
                        .tag(set.id)
                    }
                }
                iconPreview
                    .padding(.leading, settingsRowTextInset)
                SettingsRow(symbol: "textformat.123", title: strings.showTime, caption: strings.showTimeCaption) {
                    Toggle(strings.showTime, isOn: $showTime).labelsHidden()
                }
            }
            Divider()
            SettingsRow(symbol: "keyboard", title: strings.globalShortcuts, caption: strings.globalShortcutsCaption) {
                Toggle(strings.globalShortcuts, isOn: $hotkeys)
                    .labelsHidden()
                    .onChange(of: hotkeys) { _, _ in service.syncWithPreferences() }
            }
            if hotkeys {
                ShortcutPreferenceRow(role: .timeTrackingPause, isEnabled: enabled && hotkeys,
                                      label: menu.shortcutPause, symbolName: "pause.circle") {
                    service.syncWithPreferences()
                }
                ShortcutPreferenceRow(role: .timeTrackingRecords, isEnabled: enabled && hotkeys,
                                      label: menu.shortcutRecords, symbolName: "list.bullet.rectangle") {
                    service.syncWithPreferences()
                }
                if service.shortcutRegistrationFailed {
                    Text(l10n.s.shortcutUnavailable)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    /// Icons in the menu of icon sets are equally wide, so the names line up.
    private var popupIconWidth: CGFloat {
        TTIconSet.allCases.map { CGFloat(TTGlyphs.layout($0, size: 14).width) }.max() ?? 0
    }

    /// The four states of the chosen set as in the menu bar (`PREVIEW_STATES`).
    private var iconPreview: some View {
        let set = TTIconSet.from(id: iconSet)
        let states: [(TTGlyphState, String, String)] = [
            (.running, strings.previewRunning, menu.iconRunning),
            (.onBreak, strings.previewBreak, menu.iconBreak),
            (.outside, strings.previewOutside, menu.iconOutside),
            (.closed, strings.previewClosed, menu.iconClosed),
        ]
        return HStack(alignment: .top, spacing: 18) {
            ForEach(states, id: \.1) { state, label, description in
                VStack(spacing: 5) {
                    TimeTrackingGlyphPreview(image: TimeTrackingGlyphs.image(set, state, size: 18,
                                                                             description: description))
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                .help(description)
            }
        }
    }

    // MARK: Working time

    private var ruleRows: [TTRuleRow] { TTSettingsModel.ruleRows(settings, today: today, strings, texts) }

    private var selectedRow: TTRuleRow? { ruleRows.first { $0.id == selectedRule } }

    private var workingTimeCard: some View {
        SettingsCard(title: strings.workingTimeSection) {
            Text(TTSettingsModel.rulesNowText(settings, today: today, strings, texts))
                .fixedSize(horizontal: false, vertical: true)
            rulesTable
            HStack(spacing: 8) {
                Button(strings.newRules) { openSheet(nil) }
                    .help(strings.newRulesHelp)
                Button(strings.editRules) { openSheet(selectedRow) }
                    .disabled(selectedRow == nil)
                Button(strings.deleteRules) { pendingDelete = selectedRow?.from }
                    .disabled(selectedRow?.from == nil)
                    .help(strings.deleteRulesHelp)
            }
            Text(strings.rulesCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            SettingsRow(symbol: "calendar.badge.clock", title: strings.accountStart,
                        caption: strings.accountStartCaption) {
                HStack(spacing: 8) {
                    DatePicker(strings.accountStart, selection: accountDateBinding, displayedComponents: .date)
                        .datePickerStyle(.stepperField)
                        .labelsHidden()
                        .disabled(settings.accountFrom == nil)
                    Toggle(strings.accountStart, isOn: accountOnBinding).labelsHidden()
                }
            }
            SettingsRow(symbol: "plusminus", title: strings.carry, caption: strings.carryCaption) {
                HStack(spacing: 6) {
                    TimeTrackingField(text: $carryText, width: 76, commit: commitCarry)
                    Text(strings.carryUnit).foregroundStyle(.secondary)
                }
            }
            Divider()
            SettingsRow(symbol: "building.columns", title: strings.legalHints, caption: strings.legalHintsCaption) {
                Toggle(strings.legalHints, isOn: $legalHints)
                    .labelsHidden()
                    .onChange(of: legalHints) { _, on in
                        if on, notifyLimit || notifyBreak { requestPermission() }
                        service.reloadSettings()
                    }
            }
        }
    }

    private var rulesTable: some View {
        Table(ruleRows, selection: $selectedRule) {
            TableColumn(strings.columnFrom) { row in cell(row, 0) }.width(min: 76, ideal: 86)
            TableColumn(strings.columnWeekly) { row in cell(row, 1) }.width(min: 56, ideal: 66)
            TableColumn(strings.columnWorkdays) { row in cell(row, 2) }.width(min: 90, ideal: 120)
            TableColumn(strings.columnFrame) { row in cell(row, 3) }.width(min: 86, ideal: 96)
            TableColumn(strings.columnPause) { row in cell(row, 4) }.width(min: 56, ideal: 64)
            TableColumn(strings.columnFreeDays) { row in
                cell(row, 5).help(strings.columnFreeDaysHelp)
            }
            .width(min: 60, ideal: 72)
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: TTRuleRow.ID.self) { _ in
            EmptyView()
        } primaryAction: { ids in
            // Double click: edit the row.
            if let id = ids.first, let row = ruleRows.first(where: { $0.id == id }) { openSheet(row) }
        }
        .frame(height: 128)
    }

    private func cell(_ row: TTRuleRow, _ column: Int) -> some View {
        Text(row.cells[column])
            .monospacedDigit()
            .fontWeight(row.current ? .semibold : .regular)
            .foregroundStyle(row.planned ? .secondary : .primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .help(TTSettingsModel.rowTip(row, strings))
    }

    /// The sheet for new rules (`nil`: from today with today's rules) or for the row's set.
    private func openSheet(_ row: TTRuleRow?) {
        guard let row, let period = settings.work.first(where: { $0.from == row.from }) else {
            sheet = TimeTrackingRulesRequest(editing: .new, date: today, rules: settings.rules(today),
                                             title: strings.sheetNewTitle)
            return
        }
        let title = period.from.map { String(format: strings.sheetEditTitleFormat, TTFormat.day($0, texts)) }
            ?? strings.sheetFirstTitle
        sheet = TimeTrackingRulesRequest(editing: .existing(period.from), date: period.from ?? today,
                                         rules: period.rules, title: title)
    }

    private var deleteText: (title: String, info: String) {
        guard let from = pendingDelete else { return ("", "") }
        return TTSettingsModel.deleteInfo(settings, from: from, today: today, strings, texts)
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    /// Without a start, the 1st of January of this year is offered.
    private var accountDateBinding: Binding<Date> {
        Binding(
            get: { (settings.accountFrom ?? TTDate(year: today.year, month: 1, day: 1) ?? today).localNoon },
            set: { date in
                guard settings.accountFrom != nil else { return }
                save { $0.accountFrom = TTDate(localDate: date) }
            })
    }

    private var accountOnBinding: Binding<Bool> {
        Binding(
            get: { settings.accountFrom != nil },
            set: { on in
                let start = TTDate(year: today.year, month: 1, day: 1) ?? today
                save { $0.accountFrom = on ? start : nil }
            })
    }

    private func commitCarry() {
        guard let value = TTFormat.parseBalance(carryText) else {
            errorText = strings.carryError
            return
        }
        errorText = nil
        if value != settings.accountCarry {
            save { $0.accountCarry = value }
        } else {
            carryText = TTFormat.signedHoursMinutes(value)
        }
    }

    // MARK: Recording

    private var recordingCard: some View {
        SettingsCard(title: strings.recordingSection) {
            SettingsRow(symbol: "figure.walk", title: strings.minWork, caption: strings.minWorkCaption) {
                HStack(spacing: 6) {
                    Text(strings.atLeast).foregroundStyle(.secondary)
                    TimeTrackingField(text: $minWorkText, commit: commitMinWork)
                    Stepper(strings.minWork, onIncrement: { stepMinWork(by: TTSettingsModel.workStep) },
                            onDecrement: { stepMinWork(by: -TTSettingsModel.workStep) })
                        .labelsHidden()
                    Text(strings.minutesShort).foregroundStyle(.secondary)
                }
            }
            SettingsRow(symbol: "hourglass", title: strings.idle, caption: strings.idleCaption) {
                Toggle(strings.idle, isOn: idleOnBinding).labelsHidden()
            }
            HStack(spacing: 6) {
                TimeTrackingField(text: $idleText, commit: commitIdle)
                Stepper(strings.idleMinutes, onIncrement: { stepIdle(by: 1) }, onDecrement: { stepIdle(by: -1) })
                    .labelsHidden()
                Text(strings.idleMinutes).foregroundStyle(.secondary)
            }
            .disabled(idleSecs <= 0)
            .padding(.leading, settingsRowTextInset)
            SettingsRow(symbol: "lock", title: strings.askAfterLock,
                        caption: TTSettingsModel.askNote(settings, today: today, strings)) {
                Toggle(strings.askAfterLock, isOn: $askAfterLock)
                    .labelsHidden()
                    .onChange(of: askAfterLock) { _, on in
                        if on { requestPermission() }
                        service.reloadSettings()
                    }
            }
            SettingsRow(symbol: "calendar", title: strings.autoWorkdaysOnly, caption: strings.autoWorkdaysOnlyCaption) {
                Toggle(strings.autoWorkdaysOnly, isOn: $autoWorkdaysOnly)
                    .labelsHidden()
                    .onChange(of: autoWorkdaysOnly) { _, _ in service.reloadSettings() }
            }
        }
    }

    private func setMinWork(_ secs: Int) {
        errorText = nil
        minWorkSecs = secs
        minWorkText = "\(secs / 60)"
        service.reloadSettings()
    }

    private func commitMinWork() {
        guard let secs = TTSettingsModel.minutes(minWorkText, in: TTLimits.minWorkRange) else {
            errorText = String(format: strings.errorMinWorkFormat, TTLimits.minWorkRange.lowerBound / 60,
                               TTLimits.minWorkRange.upperBound / 60)
            return
        }
        if secs != minWorkSecs { setMinWork(secs) } else { errorText = nil }
    }

    /// Like the arrows of Tagwerk's stepper: from the stored value, within its bounds.
    private func stepMinWork(by step: Int) {
        let old = minWorkSecs / 60
        let range = (TTLimits.minWorkRange.lowerBound / 60)...(TTLimits.minWorkRange.upperBound / 60)
        setMinWork(TTSettingsModel.stepMinutes(old: old, stepped: (old + step).ttClamped(to: range)) * 60)
    }

    private var idleOnBinding: Binding<Bool> {
        Binding(
            get: { idleSecs > 0 },
            set: { on in
                errorText = nil
                if on {
                    idleSecs = TTSettingsModel.minutes(idleText, in: TTLimits.idleRange) ?? TTSettingsModel.idleDefault
                } else {
                    idleSecs = 0
                }
                idleText = "\((idleSecs > 0 ? idleSecs : TTSettingsModel.idleDefault) / 60)"
                service.reloadSettings()
            })
    }

    private func setIdle(_ secs: Int) {
        errorText = nil
        idleSecs = secs
        idleText = "\(secs / 60)"
        service.reloadSettings()
    }

    private func commitIdle() {
        guard idleSecs > 0 else { return }
        guard let secs = TTSettingsModel.minutes(idleText, in: TTLimits.idleRange) else {
            errorText = String(format: strings.errorIdleFormat, TTLimits.idleRange.lowerBound / 60,
                               TTLimits.idleRange.upperBound / 60)
            return
        }
        if secs != idleSecs { setIdle(secs) } else { errorText = nil }
    }

    private func stepIdle(by minutes: Int) {
        setIdle((idleSecs + minutes * 60).ttClamped(to: TTLimits.idleRange))
    }

    // MARK: Notifications

    private var notificationsCard: some View {
        SettingsCard(title: strings.notificationsSection) {
            SettingsRow(symbol: "bell.badge", title: strings.permission, caption: permission?.note(strings)) {
                HStack(spacing: 8) {
                    if let permission {
                        Label {
                            Text(permission.text(strings))
                        } icon: {
                            Image(systemName: permissionSymbol(permission))
                                .foregroundStyle(permissionColor(permission))
                        }
                        if permission.needsSettings {
                            Button(strings.openSystemSettings) { permissions.openNotificationSettings() }
                                .controlSize(.small)
                        }
                    }
                }
            }
            SettingsRow(symbol: "clock.badge.exclamationmark", title: strings.notifyLimit,
                        caption: legalHints ? nil : strings.remindersOffCaption) {
                Toggle(strings.notifyLimit, isOn: $notifyLimit)
                    .labelsHidden()
                    .disabled(!legalHints)
                    .onChange(of: notifyLimit) { _, on in reminderChanged(on) }
            }
            SettingsRow(symbol: "cup.and.saucer", title: strings.notifyBreak,
                        caption: legalHints ? nil : strings.remindersOffCaption) {
                Toggle(strings.notifyBreak, isOn: $notifyBreak)
                    .labelsHidden()
                    .disabled(!legalHints)
                    .onChange(of: notifyBreak) { _, on in reminderChanged(on) }
            }
            Text(strings.remindersCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func reminderChanged(_ on: Bool) {
        if on, legalHints { requestPermission() }
        service.reloadSettings()
    }

    private func permissionSymbol(_ p: TTNotificationPermission) -> String {
        switch p {
        case .allowed: return "checkmark.circle.fill"
        case .unavailable: return "bell.slash"
        case .notDetermined, .denied, .hidden: return "exclamationmark.triangle.fill"
        }
    }

    private func permissionColor(_ p: TTNotificationPermission) -> Color {
        switch p {
        case .allowed: return .green
        case .unavailable: return .secondary
        case .notDetermined, .denied, .hidden: return .orange
        }
    }

    private func refreshPermission() {
        TimeTrackingNotificationAccess.permission { permission = $0 }
    }

    private func requestPermission() {
        TimeTrackingNotificationAccess.request { permission = $0 }
    }

    // MARK: Data

    private var dataCard: some View {
        SettingsCard(title: strings.dataSection) {
            SettingsRow(symbol: "folder", title: strings.dataFolder, caption: strings.dataFolderCaption) {
                Button(strings.showInFinder) { showDataFolder() }
            }
            SettingsRow(symbol: "square.and.arrow.down.on.square", title: strings.takeOver,
                        caption: service.tagwerkDatabaseURL == nil ? strings.takeOverMissing
                                                                    : strings.takeOverCaption) {
                Button(strings.takeOverButton) {
                    tagwerkRunning = TimeTrackingTagwerkImport.isTagwerkRunning
                    confirmTakeOver = true
                }
                .disabled(service.tagwerkDatabaseURL == nil)
            }
            if tagwerkRunning {
                Text(strings.tagwerkRunning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, settingsRowTextInset)
            }
            SettingsRow(symbol: "arrow.counterclockwise", title: strings.resetDefaults,
                        caption: strings.resetDefaultsCaption) {
                Button(strings.resetButton) {
                    load()
                    confirmReset = true
                }
            }
        }
    }

    private func showDataFolder() {
        guard let directory = TimeTrackingDatabase.defaultDirectory,
              PrivateFileStore.createDirectory(at: directory) else { return }
        NSWorkspace.shared.open(directory)
    }

    private func takeOver() {
        do {
            let result = try service.takeOverTagwerk()
            var message = String(format: strings.takeOverDoneFormat, result.days)
            message += result.backup.map { String(format: strings.takeOverBackupFormat, $0.path) }
                ?? strings.takeOverNoBackup
            takeOverReport = TimeTrackingSettingsReport(title: strings.takeOverDoneTitle, message: message)
        } catch {
            takeOverReport = TimeTrackingSettingsReport(title: strings.takeOverFailedTitle,
                                                        message: String(describing: error))
        }
        load()
        syncFields()
    }

    private var reportBinding: Binding<Bool> {
        Binding(get: { takeOverReport != nil }, set: { if !$0 { takeOverReport = nil } })
    }

    private func restoreDefaults() {
        do {
            try service.restoreDefaults()
            load()
        } catch {
            errorText = String(format: strings.errorSaveFormat, String(describing: error))
        }
        syncFields()
    }

    // MARK: Storage

    /// Reads the settings anew (database and UserDefaults).
    private func load() {
        do {
            settings = try service.loadSettings()
            errorText = nil
        } catch {
            errorText = String(format: strings.errorLoadFormat, String(describing: error))
        }
        carryText = TTFormat.signedHoursMinutes(settings.accountCarry)
        if let selectedRule, !ruleRows.contains(where: { $0.id == selectedRule }) { self.selectedRule = nil }
    }

    /// The fields after their values changed from outside the page.
    private func syncFields() {
        minWorkText = "\(minWorkSecs / 60)"
        idleText = "\((idleSecs > 0 ? idleSecs : TTSettingsModel.idleDefault) / 60)"
    }

    /// Changes the database part of the settings, saves it and lets
    /// recording take it over.
    private func save(_ change: (inout TTSettings) -> Void) {
        var changed = settings
        change(&changed)
        do {
            try service.saveRulesAndAccount(changed)
            load()
        } catch {
            errorText = String(format: strings.errorSaveFormat, String(describing: error))
        }
    }
}

/// The result of taking over Tagwerk's data, shown in an alert.
struct TimeTrackingSettingsReport: Identifiable {
    let title: String
    let message: String
    var id: String { title + message }
}

/// A number or time typed into a field: taken over on Return and when the
/// field loses focus (like Tagwerk's fields with `sendsActionOnEndEditing`).
struct TimeTrackingField: View {
    @Binding var text: String
    let width: CGFloat
    let placeholder: String
    let help: String?
    let commit: () -> Void
    @FocusState private var focused: Bool

    init(text: Binding<String>, width: CGFloat = 52, placeholder: String = "", help: String? = nil,
         commit: @escaping () -> Void) {
        _text = text
        self.width = width
        self.placeholder = placeholder
        self.help = help
        self.commit = commit
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: width)
            .focused($focused)
            .onSubmit(commit)
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            .help(help ?? "")
    }
}

/// A glyph as in the menu bar: template images in the text colour.
private struct TimeTrackingGlyphPreview: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleNone
        view.contentTintColor = .textColor
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        view.image = image
        view.setAccessibilityLabel(image.accessibilityDescription)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        image.size
    }
}

/// Whether macOS lets Barforge notify, with Tagwerk's "hidden" state
/// (allowed, but neither as banners nor in Notification Center).
enum TimeTrackingNotificationAccess {
    static func permission(_ done: @escaping (TTNotificationPermission) -> Void) {
        guard Notifier.isAvailable else {
            done(.unavailable)
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authorized: Bool?
            switch settings.authorizationStatus {
            case .notDetermined: authorized = nil
            case .denied: authorized = false
            default: authorized = true
            }
            let visible = settings.alertStyle != .none || settings.notificationCenterSetting == .enabled
            let permission = TTNotificationPermission(authorized: authorized, visible: visible)
            DispatchQueue.main.async { done(permission) }
        }
    }

    /// Asks for the permission (macOS asks only once) and reports the state after.
    static func request(_ done: @escaping (TTNotificationPermission) -> Void) {
        guard Notifier.isAvailable else {
            done(.unavailable)
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            DispatchQueue.main.async { permission(done) }
        }
    }
}

extension TTDate {
    /// The local day of `localDate`.
    init(localDate: Date) {
        self = TTDateTime(local: localDate, timeZone: .autoupdatingCurrent).date
    }

    /// Noon of this day in the local time zone, for date pickers.
    var localNoon: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }
}
