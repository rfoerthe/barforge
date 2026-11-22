// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import SwiftUI

/// What the sheet "Change working time" opens with: new rules (from today
/// with today's rules) or an existing set with its date and rules.
struct TimeTrackingRulesRequest: Identifiable {
    let editing: TTRulesEditing
    let date: TTDate
    let rules: TTWorkRules
    let title: String

    var id: String {
        switch editing {
        case .new: return "new"
        case let .existing(from): return from?.iso ?? "first"
        }
    }
}

/// The sheet "Change working time" (Tagwerk's `build_sheet`): one set of
/// working-time rules. The fields change only the draft; nothing is saved
/// before "Apply". Under the date it says until when the set applies and
/// which days change, orange when that is retroactive or replaces a set
/// (`TTSettingsModel.sheetHint`).
struct TimeTrackingRulesSheet: View {
    let request: TimeTrackingRulesRequest
    /// The settings before "Apply", for the hint.
    let settings: TTSettings
    let today: TTDate
    let onApply: (_ from: TTDate?, _ rules: TTWorkRules) -> Void

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TTWorkRules
    @State private var validFrom: Date
    @State private var weeklyText: String
    @State private var pauseText: String
    @State private var frameFromText: String
    @State private var frameToText: String
    @State private var error: String?

    init(request: TimeTrackingRulesRequest, settings: TTSettings, today: TTDate,
         onApply: @escaping (_ from: TTDate?, _ rules: TTWorkRules) -> Void) {
        self.request = request
        self.settings = settings
        self.today = today
        self.onApply = onApply
        let r = request.rules
        _draft = State(initialValue: r)
        _validFrom = State(initialValue: request.date.localNoon)
        _weeklyText = State(initialValue: TTFormat.hours(r.weeklyTarget, FeatureStrings.timeTrackingTexts(L10n.shared.language)))
        _pauseText = State(initialValue: "\(r.minPause / 60)")
        _frameFromText = State(initialValue: TTFormat.clock(r.frameFrom))
        _frameToText = State(initialValue: TTFormat.clock(r.frameTo))
    }

    private var strings: TimeTrackingSettingsStrings { FeatureStrings.timeTrackingSettings(l10n.language) }
    private var texts: TimeTrackingTexts { FeatureStrings.timeTrackingTexts(l10n.language) }

    /// From when the set applies: `nil` for the first set (since always).
    private var from: TTDate? {
        request.editing.isFirst ? nil : TTDate(localDate: validFrom)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(request.title).font(.headline)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow {
                    label(strings.validFrom)
                    if request.editing.isFirst {
                        Text(strings.rowBeginning)
                    } else {
                        DatePicker(strings.validFrom, selection: $validFrom, displayedComponents: .date)
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                            .fixedSize()
                    }
                }
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    let hint = TTSettingsModel.sheetHint(settings, editing: request.editing, from: from,
                                                         draft: draft, today: today, strings, texts)
                    caption(hint.text)
                        .foregroundStyle(hint.warn ? Color.orange : Color.secondary)
                }
                section {
                    label(strings.regularHours)
                    HStack(spacing: 6) {
                        TimeTrackingField(text: $weeklyText) { commitWeekly() }
                        Stepper(strings.regularHours, value: weeklyStepperBinding,
                                in: Double(TTLimits.weeklyRange.lowerBound) / 3600...Double(TTLimits.weeklyRange.upperBound) / 3600,
                                step: 0.5)
                            .labelsHidden()
                        Text(strings.hoursPerWeek)
                    }
                }
                GridRow {
                    label(strings.workdays)
                    HStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { bit in
                            Toggle(texts.weekdayShortNames[bit], isOn: workdayBinding(bit))
                                .toggleStyle(.checkbox)
                        }
                    }
                }
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    caption(TTSettingsModel.dailyNote(draft, strings, texts))
                }
                section {
                    label(strings.freeDays)
                    Toggle(strings.freeDaysCount, isOn: $draft.freeDaysCount)
                        .toggleStyle(.checkbox)
                        .help(strings.freeDaysCountHelp)
                }
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    caption(strings.freeDaysCaption)
                }
                section {
                    label(strings.frame)
                    // Text fields, not time pickers: those end at 23:59, the end may be 24:00.
                    HStack(spacing: 6) {
                        TimeTrackingField(text: $frameFromText, placeholder: "07:00", help: strings.frameFromHelp) {
                            commitFrame()
                        }
                        Text(strings.frameTo)
                        TimeTrackingField(text: $frameToText, placeholder: "22:00", help: strings.frameToHelp) {
                            commitFrame()
                        }
                    }
                }
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    caption(strings.frameCaption)
                }
                section {
                    label(strings.minBreak)
                    HStack(spacing: 6) {
                        TimeTrackingField(text: $pauseText) { commitPause() }
                        Stepper(strings.minBreak, value: pauseStepperBinding,
                                in: TTLimits.minPauseRange.lowerBound / 60...TTLimits.minPauseRange.upperBound / 60)
                            .labelsHidden()
                        Text(strings.minutes)
                    }
                }
                GridRow {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    caption(strings.minBreakCaption)
                }
            }
            if let error {
                caption(error).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(strings.cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(strings.apply) { apply() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    // MARK: Layout

    private func label(_ text: String) -> some View {
        Text(text).gridColumnAlignment(.trailing)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 400, alignment: .leading)
    }

    /// A row that starts a new group, with space above it.
    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Group {
            GridRow {
                Color.clear.frame(height: 10).gridCellColumns(2)
            }
            GridRow { content() }
        }
    }

    // MARK: Fields

    private var weeklyStepperBinding: Binding<Double> {
        Binding(
            get: { Double(draft.weeklyTarget) / 3600 },
            set: { hours in setWeekly(Int((hours * 3600).rounded())) })
    }

    private var pauseStepperBinding: Binding<Int> {
        Binding(get: { draft.minPause / 60 }, set: { setPause($0 * 60) })
    }

    private func workdayBinding(_ bit: Int) -> Binding<Bool> {
        Binding(
            get: { draft.workdays & (1 << bit) != 0 },
            set: { on in
                let days = on ? draft.workdays | (1 << bit) : draft.workdays & ~(1 << bit)
                // One workday always stays.
                if days & TTLimits.allWorkdays == 0 {
                    error = strings.errorWorkday
                } else {
                    draft.workdays = days
                    error = nil
                }
            })
    }

    private func setWeekly(_ secs: Int) {
        draft.weeklyTarget = secs
        weeklyText = TTFormat.hours(secs, texts)
        error = nil
    }

    private func setPause(_ secs: Int) {
        draft.minPause = secs
        pauseText = "\(secs / 60)"
        error = nil
    }

    private var weeklyError: String {
        String(format: strings.errorWeeklyFormat, TTLimits.weeklyRange.lowerBound / 3600,
               TTLimits.weeklyRange.upperBound / 3600)
    }

    private var pauseError: String {
        String(format: strings.errorPauseFormat, TTLimits.minPauseRange.lowerBound / 60,
               TTLimits.minPauseRange.upperBound / 60)
    }

    /// The input stays when it is wrong, so it can be corrected.
    @discardableResult
    private func commitWeekly() -> Bool {
        guard let secs = TTSettingsModel.weeklyTarget(weeklyText) else {
            error = weeklyError
            return false
        }
        setWeekly(secs)
        return true
    }

    @discardableResult
    private func commitPause() -> Bool {
        guard let secs = TTSettingsModel.minutes(pauseText, in: TTLimits.minPauseRange) else {
            error = pauseError
            return false
        }
        setPause(secs)
        return true
    }

    @discardableResult
    private func commitFrame() -> Bool {
        switch TTSettingsModel.parseFrame(frameFromText, frameToText) {
        case let .success(frame):
            draft.frameFrom = frame.from
            draft.frameTo = frame.to
            frameFromText = TTFormat.clock(frame.from)
            frameToText = TTFormat.clock(frame.to)
            error = nil
            return true
        case let .failure(why):
            error = why.text(strings)
            return false
        }
    }

    /// "Apply": takes over what is typed, sets the rules and closes. A wrong
    /// input keeps the sheet open with its message.
    private func apply() {
        guard commitWeekly(), commitPause(), commitFrame() else { return }
        onApply(from, draft)
        dismiss()
    }
}
