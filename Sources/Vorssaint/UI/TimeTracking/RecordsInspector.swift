// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import SwiftUI

/// The inspector on the right of the Records window (`records.rs`
/// `build_inspector`): head with the day's figures and warnings, then
/// absence, recording, start of work, breaks, work away from the Mac, end of
/// work, the recorded periods and "Delete All Entries…". Every change goes
/// through the model; what is allowed is decided by `TTEdits`.
struct RecordsInspector: View {
    @ObservedObject var model: RecordsModel

    var body: some View {
        ScrollView {
            Group {
                if let date = model.selected {
                    // Built anew after every whole change, like Tagwerk's inspector;
                    // a running input in a time field keeps it.
                    RecordsDayInspector(model: model, date: date)
                        .id("\(date.iso)-\(model.inspectorEpoch)")
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.strings.noDayTitle)
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                        RecordsCaption(model.strings.noDayHint)
                    }
                }
            }
            .padding(EdgeInsets(top: 18, leading: 20, bottom: 20, trailing: 20))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A small grey text that wraps.
private struct RecordsCaption: View {
    let text: String
    var color: Color = .secondary

    init(_ text: String, color: Color = .secondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: NSFont.smallSystemFontSize))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The ⓘ next to a heading: the explanation as tooltip and, on click, as popover.
private struct RecordsInfoButton: View {
    let text: String
    let label: String
    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.tertiary)
        .help(text)
        .accessibilityLabel(label)
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            Text(text)
                .frame(width: 280, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        }
    }
}

private struct RecordsDayInspector: View {
    @ObservedObject var model: RecordsModel
    let date: TTDate
    @State private var breakFrom: Int
    @State private var breakTo: Int
    @State private var workFrom: Int
    @State private var workTo: Int
    @State private var reason = TTActivity.meeting

    init(model: RecordsModel, date: TTDate) {
        _model = ObservedObject(wrappedValue: model)
        self.date = date
        let settings = model.settings
        let minPause = settings.rules(date).minPause
        _breakFrom = State(initialValue: 12 * 3600)
        _breakTo = State(initialValue: 12 * 3600 + Swift.max(minPause, 30 * 60))
        // Suggested: the first break of the day, otherwise lunchtime.
        let pause = model.day(date)?.pauses(settings).first
        _workFrom = State(initialValue: (pause?.from ?? 12 * 3600) / 60 * 60)
        _workTo = State(initialValue: (pause?.to ?? 12 * 3600 + 30 * 60) / 60 * 60)
    }

    private var s: TimeTrackingRecordsStrings { model.strings }
    private var texts: TimeTrackingTexts { model.texts }
    private var settings: TTSettings { model.settings }
    private var day: TTDay? { model.day(date) }
    private var isToday: Bool { date == model.now.date }
    /// A future day: only an absence, no times (see `TTEdits.refusal`).
    private var future: Bool { date > model.now.date }
    /// A whole-day absence locks the other entries (see `TTDay.locksEntries`).
    private var locked: Bool { day?.locksEntries ?? false }
    private var uncounted: Bool { day?.uncounted ?? false }
    /// What can only be set while the recorded time counts and the day is not
    /// in the future (removing always works).
    private var settable: Bool { !locked && !uncounted && !future }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Divider().padding(.vertical, 8)
            absenceSection
            recordingSection
            startSection
            breaksSection
            workSection
            endSection
            recordedSection
            if day?.hasEntries == true {
                Divider().padding(.top, 14).padding(.bottom, 8)
                Button(s.clearDay, role: .destructive) { model.confirmClearDay(date) }
                    .help(s.clearDayTip)
            }
        }
    }

    // MARK: Head

    @ViewBuilder private var header: some View {
        Text(TTRecords.longDate(date, s))
            .font(.system(size: 15, weight: .semibold))
            .padding(.bottom, 2)
        switch TTRecords.dayStats(date, day: day, days: model.days, settings: settings, today: model.now.date) {
        case let .numbers(work, pause, balance):
            HStack(alignment: .top, spacing: 22) {
                stat(TTExport.hoursMinutesUnit(work), s.statWork)
                stat(TTExport.hoursMinutesUnit(pause), s.statBreaks)
                stat(balance.map(TTFormat.balance) ?? "–", s.statBalance,
                     color: balance.map(recordsBalanceColor) ?? Color.secondary)
            }
            .padding(.bottom, 4)
        case let .note(note):
            RecordsCaption(note.text(s))
        }
        ForEach(Array(TTWarning.dayWarnings(model.days, date: date, settings: settings).enumerated()),
                id: \.offset) { _, warning in
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(nsColor: .systemOrange))
                    .accessibilityLabel(s.warningTip)
                RecordsCaption(warning.text(texts) + ".")
            }
        }
    }

    private func stat(_ value: String, _ caption: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
            Text(caption)
                .font(.system(size: NSFont.smallSystemFontSize))
                .foregroundStyle(.secondary)
        }
    }

    /// Heading of a section with its explanation behind the ⓘ.
    private func heading(_ title: String, help: String, first: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.headline).help(help)
            RecordsInfoButton(text: help, label: s.explanation)
        }
        .padding(.top, first ? 0 : 12)
    }

    @ViewBuilder private func error(_ input: TTEditInput) -> some View {
        if let error = model.inspectorError, error.input == input {
            RecordsCaption(error.text, color: Color(nsColor: .systemRed))
        }
    }

    @ViewBuilder private func cutNote(_ bound: TTEditBound) -> some View {
        if model.cutNote == RecordsModel.CutNote(date: date, bound: bound) {
            RecordsCaption(TTEdits.cutText(bound, s), color: Color(nsColor: TimeTrackingPalette.orange))
        }
    }

    /// Time of day (hour:minute with arrows) for this day; today not in the future.
    private func timePicker(_ value: Int, _ set: @escaping (Int) -> Void) -> some View {
        let latest = isToday ? model.now.secs : TTLimits.dayEnd
        let (lower, upper) = (RecordsTime.date(date, 0), RecordsTime.date(date, latest))
        let binding = Binding<Date>(
            get: { RecordsTime.date(date, Swift.min(value, latest)) },
            set: { set(RecordsTime.secs($0)) })
        return DatePicker("", selection: binding, in: lower...Swift.max(lower, upper), displayedComponents: .hourAndMinute)
            .labelsHidden()
            .datePickerStyle(.stepperField)
            .environment(\.locale, RecordsTime.locale)
            .environment(\.calendar, RecordsTime.calendar)
            .fixedSize()
    }

    private func spanText(_ from: Int, _ to: Int) -> String {
        "\(TTFormat.clock(from)) – \(TTFormat.clock(to))"
    }

    // MARK: Absence

    @ViewBuilder private var absenceSection: some View {
        let absence = day?.absence
        // A whole day only on a day without other entries (today only those by hand count).
        let busy = day?.blocksFullAbsence(today: isToday) ?? false
        // Without a target no new absence; an existing one can only be removed.
        let workday = settings.isWorkday(date)
        let half = absence?.half ?? (busy || model.prefersHalf(date))
        heading(s.sectionAbsence, help: s.helpAbsence, first: true)
        error(.absence)
        HStack(spacing: 8) {
            Picker("", selection: Binding<Int>(
                get: { absence.flatMap { a in TTAbsenceKind.all.firstIndex(of: a.kind) }.map { $0 + 1 } ?? 0 },
                set: { i in
                    let kind = i > 0 && i <= TTAbsenceKind.all.count ? TTAbsenceKind.all[i - 1] : nil
                    model.absenceChanged(date, kind: kind, half: half, fromPart: false)
                })) {
                Text(s.absenceNone).tag(0)
                ForEach(Array(TTAbsenceKind.all.enumerated()), id: \.offset) { i, kind in
                    let current = absence?.kind == kind
                    // Only whole days (special leave, time off) are locked next to entries.
                    Text(kind.label(texts)).tag(i + 1)
                        .disabled((!workday && !current) || (busy && !kind.allowsHalf && !current))
                }
            }
            .labelsHidden()
            .fixedSize()
            .disabled(!workday && absence == nil)
            .help(workday ? "" : s.freeDayAbsence)
            Picker("", selection: Binding<Bool>(
                get: { half },
                set: { model.absenceChanged(date, kind: absence?.kind, half: $0, fromPart: true) })) {
                Text(s.wholeDay).tag(false).disabled(busy && (absence?.half ?? true))
                Text(s.halfDay).tag(true)
            }
            .labelsHidden()
            .fixedSize()
            // Half days come with vacation, sickness and holidays.
            .disabled(!(absence.map { $0.kind.allowsHalf && workday } ?? workday))
            .help(absence == nil ? s.partTipNone : s.partTip)
        }
        if let effect = TTRecords.absenceEffect(date, day: day, settings: settings, today: model.now.date, s) {
            RecordsCaption(effect)
        }
    }

    // MARK: Recording

    /// Only on a free day with a decision about recording (as "Record today"
    /// in the panel).
    @ViewBuilder private var recordingSection: some View {
        if let free = day?.freeDay, !locked {
            // "Counts" means: as working time. Whether it goes into balance and
            // time account is up to the working-time rules.
            let counts = settings.workCountsOn(date)
            let balance = counts ? s.countBalanceYes : s.countBalanceNo
            heading(s.sectionRecording, help: String(format: s.helpRecordingFormat, balance))
            Toggle(s.countRecorded, isOn: Binding(get: { free.counts }, set: { model.apply(.setCounting($0)) }))
                .toggleStyle(.checkbox)
                .help(String(format: s.countTipFormat, balance))
            switch free {
            case .counted: RecordsCaption(counts ? s.freeDayCountedInBalance : s.freeDayCountedNotInBalance)
            case .stopped: RecordsCaption(s.freeDayStoppedNote)
            case .uncounted: RecordsCaption(s.freeDayUncountedNote)
            }
        }
    }

    // MARK: Start and end of work

    /// First unlock and last lock within the frame, and whether the raw ones
    /// lie outside it (then the note says "within working hours").
    private var autoBounds: (bounds: (from: Int, to: Int)?, firstOutside: Bool, lastOutside: Bool) {
        let auto = day?.autoBoundsInFrame(settings)
        return (auto, day?.periods.first?.from != auto?.from, day?.periods.last?.to != auto?.to)
    }

    @ViewBuilder private var startSection: some View {
        let rec = day?.record(settings)
        let manual = day?.start
        let value = manual ?? rec?.firstStart ?? 8 * 3600
        let auto = autoBounds
        heading(s.sectionStart, help: s.helpStart)
        error(.start)
        HStack(spacing: 8) {
            Toggle(s.setManually, isOn: Binding(get: { manual != nil },
                                                set: { model.apply(.setStart($0 ? value : nil)) }))
                .toggleStyle(.checkbox)
                // A start already set can still be removed.
                .disabled(!(settable || (!locked && manual != nil)))
                .help(future ? s.futureText : "")
            timePicker(value) { model.apply(.setStart($0), rebuild: false) }
                .disabled(!(manual != nil && settable))
        }
        cutNote(.start)
        RecordsCaption(TTRecords.startNote(future: future, uncounted: uncounted, auto: auto.bounds,
                                           inFrame: auto.firstOutside, s))
    }

    @ViewBuilder private var endSection: some View {
        let rec = day?.record(settings)
        let manual = day?.end
        let value = manual ?? rec?.lastEnd ?? (isToday ? model.now.secs : 17 * 3600)
        let auto = autoBounds
        heading(s.sectionEnd, help: s.helpEnd)
        error(.end)
        HStack(spacing: 8) {
            Toggle(s.setManually, isOn: Binding(get: { manual != nil },
                                                set: { model.apply(.setEnd($0 ? value : nil)) }))
                .toggleStyle(.checkbox)
                .disabled(!(settable || (!locked && manual != nil)))
                .help(future ? s.futureText : "")
            timePicker(value) { model.apply(.setEnd($0), rebuild: false) }
                .disabled(!(manual != nil && settable))
        }
        cutNote(.end)
        RecordsCaption(TTRecords.endNote(future: future, uncounted: uncounted, auto: auto.bounds,
                                         inFrame: auto.lastOutside, openToday: isToday && manual == nil, s))
    }

    // MARK: Breaks and work away from the Mac

    @ViewBuilder private var breaksSection: some View {
        let breaks = day?.breaks ?? []
        heading(s.sectionBreaks, help: String(format: s.helpBreaksFormat, settings.rules(date).minPause / 60))
        if breaks.isEmpty {
            Text(s.noBreaks).foregroundStyle(.secondary)
        }
        ForEach(Array(breaks.enumerated()), id: \.offset) { i, b in
            HStack(spacing: 8) {
                Text(spanText(b.from, b.to)).monospacedDigit()
                Text(TTRecords.shortDuration(TTSpan.shownLen(from: b.from, to: b.to), texts))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                removeButton(s.removeBreak) { model.apply(.removeBreak(i)) }
            }
        }
        error(.breaks)
        HStack(spacing: 6) {
            timePicker(breakFrom) { breakFrom = $0 }
            Text(s.to)
            timePicker(breakTo) { breakTo = $0 }
            Button(s.add) { model.addBreak(from: breakFrom, to: breakTo) }
                .help(future ? s.futureText : uncounted ? s.uncountedNote : "")
        }
        .disabled(!settable)
        .padding(.top, 6)
    }

    @ViewBuilder private var workSection: some View {
        let work = day?.work ?? []
        heading(s.sectionWork, help: s.helpWork)
        if work.isEmpty {
            Text(s.nothingEntered).foregroundStyle(.secondary)
        }
        ForEach(Array(work.enumerated()), id: \.offset) { i, w in
            HStack(spacing: 8) {
                Text(spanText(w.from, w.to)).monospacedDigit()
                Text(TTRecords.shortDuration(TTSpan.shownLen(from: w.from, to: w.to), texts))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(w.note)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(w.note)
                Spacer(minLength: 0)
                removeButton(s.removeWork) { model.apply(.removeWork(i)) }
            }
        }
        error(.work)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                timePicker(workFrom) { workFrom = $0 }
                Text(s.to)
                timePicker(workTo) { workTo = $0 }
            }
            HStack(spacing: 6) {
                Picker("", selection: $reason) {
                    ForEach(TTActivity.all, id: \.self) { activity in
                        Text(activity.label(texts)).tag(activity)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .help(s.reason)
                Button(s.add) { model.addWork(from: workFrom, to: workTo, activity: reason) }
                    .help(future ? s.futureText : "")
            }
        }
        .disabled(locked || future)
        .padding(.top, 6)
    }

    private func removeButton(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(label)
        .accessibilityLabel(label)
        .disabled(locked)
    }

    // MARK: Recorded automatically

    /// Collapsed (the default) only the count and span; the triangle shows
    /// the single times, for all days.
    @ViewBuilder private var recordedSection: some View {
        let periods = day?.periods ?? []
        let open = model.recordedOpen
        HStack(spacing: 4) {
            Button { model.recordedOpen.toggle() } label: {
                Image(systemName: open ? "chevron.down" : "chevron.right")
                    .frame(width: 12)
            }
            .buttonStyle(.borderless)
            .help(s.recordedToggleTip)
            .accessibilityLabel(s.recordedToggleTip)
            heading(s.sectionRecorded, help: String(format: s.helpRecordedFormat,
                                                    settings.rules(date).frameText(texts)), first: true)
        }
        .padding(.top, 12)
        if !open || periods.isEmpty {
            Text(TTRecords.recordedSummary(periods, s))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        if open {
            ForEach(Array(periods.enumerated()), id: \.offset) { _, p in
                HStack(spacing: 8) {
                    Text(spanText(p.from, p.to)).monospacedDigit().foregroundStyle(.secondary)
                    Text(TTRecords.shortDuration(TTSpan.shownLen(from: p.from, to: p.to), texts))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
