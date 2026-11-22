// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import SwiftUI

/// Time Tracking tab in the menu panel: Tagwerk's menu as a panel section.
/// On top the display lines (status with a coloured dot, a database error in
/// red, today's working time of the target, breaks, start, the week's
/// balance, the time account and up to six warnings), below the actions with
/// Tagwerk's rules for when each appears (`TTMenu.actions`).
struct TimeTrackingSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = TimeTrackingService.shared
    @AppStorage(DefaultsKey.timeTrackingEnabled) private var enabled = false
    var collapsible = true

    private var strings: TimeTrackingFeatureStrings { FeatureStrings.timeTracking(l10n.language) }
    private var texts: TimeTrackingTexts { FeatureStrings.timeTrackingTexts(l10n.language) }
    private var menu: TimeTrackingMenuTexts { FeatureStrings.timeTrackingMenu(l10n.language) }

    var body: some View {
        PanelSection(.timeTracking, title: strings.title, collapsible: collapsible) {
            VStack(alignment: .leading, spacing: 10) {
                if let snapshot = service.snapshot {
                    TimeTrackingOverview(snapshot: snapshot, fault: service.databaseFault, texts: texts, menu: menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .panelCard()
                    TimeTrackingActions(snapshot: snapshot, texts: texts, menu: menu)
                        .panelCard(padded: false)
                } else if enabled, let fault = service.databaseFault {
                    TimeTrackingMarkedLine(text: errorText(fault), color: TimeTrackingPalette.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .panelCard()
                } else {
                    offCard
                }
            }
            .onAppear { service.refreshDisplay() }
            .onReceive(NotificationCenter.default.publisher(for: .menuPanelWillShow)) { _ in
                service.refreshDisplay()
            }
        }
    }

    private func errorText(_ fault: TimeTrackingDatabaseFault) -> String {
        let failure = TTMenu.dbFailure(fault.failure, menu)
        return TTMenu.dbErrorText(what: failure.what, detail: fault.message)
    }

    /// Recording is off: say so and offer to turn it on.
    private var offCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(menu.offHint)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(menu.turnOn) {
                enabled = true
                service.syncWithPreferences()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
    }
}

/// The display lines (`menubar.rs` `refresh`, first half). Pure display:
/// nothing here can be clicked.
private struct TimeTrackingOverview: View {
    let snapshot: TimeTrackingSnapshot
    let fault: TimeTrackingDatabaseFault?
    let texts: TimeTrackingTexts
    let menu: TimeTrackingMenuTexts

    var body: some View {
        let info = snapshot.today
        let status = snapshot.menu.status
        let colors = TimeTrackingPalette.status(TTStatusTone(status.kind))
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Circle()
                    .fill(Color(nsColor: colors.dot))
                    .frame(width: 8, height: 8)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                    .accessibilityHidden(true)
                Text(status.text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(nsColor: colors.text))
                    .fixedSize(horizontal: false, vertical: true)
            }
            // A database error stands right under the status, before the figures.
            if let fault {
                let failure = TTMenu.dbFailure(fault.failure, menu)
                TimeTrackingMarkedLine(text: TTMenu.dbErrorText(what: failure.what, detail: fault.message),
                                       color: TimeTrackingPalette.red)
            }
            figureRow(menu.workedToday, TTExport.hoursMinutesUnit(info.workSecs),
                      color: info.targetSecs > 0 && info.workSecs >= info.targetSecs ? TimeTrackingPalette.green : nil,
                      note: info.targetSecs > 0
                          ? String(format: menu.ofTargetFormat, TTExport.hoursMinutesUnit(info.targetSecs)) : nil)
            figureRow(menu.breaksToday, TTExport.hoursMinutesUnit(info.pauseSecs))
            figureRow(menu.startedToday, info.firstStart.map { TTMenu.clock($0, menu) } ?? "–",
                      note: info.startManual ? menu.manualStart : nil)
            figureRow(menu.weekBalance, TTFormat.balance(info.weekBalance),
                      color: TimeTrackingPalette.balance(info.weekBalance))
            figureRow(menu.timeAccount, TTFormat.balance(info.account),
                      color: TimeTrackingPalette.balance(info.account))
            ForEach(Array(info.warnings.prefix(TTMenu.maxWarnings).enumerated()), id: \.offset) { _, warning in
                TimeTrackingMarkedLine(text: warning.text(texts), color: TimeTrackingPalette.orange)
            }
        }
    }

    /// "Worked today:  6:43 h  of 7:48 h": a label, the value (semibold,
    /// digits of equal width, green or red for balances) and a muted note.
    private func figureRow(_ label: String, _ value: String, color: NSColor? = nil, note: String? = nil)
        -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .foregroundStyle(.primary)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(color.map { Color(nsColor: $0) } ?? .primary)
            if let note {
                Text(note)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

/// A warning or an error: a filled triangle in front of the text, both in
/// `color`; a long text wraps under the text, not under the triangle.
private struct TimeTrackingMarkedLine: View {
    let text: String
    let color: NSColor

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color(nsColor: color))
                .font(.system(size: 11))
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Color(nsColor: color))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The actions (`menubar.rs`, the menu below the figures), each shown by
/// `TTMenu.actions`.
private struct TimeTrackingActions: View {
    let snapshot: TimeTrackingSnapshot
    let texts: TimeTrackingTexts
    let menu: TimeTrackingMenuTexts
    @State private var choosingStart = false
    @State private var choosingEnd = false

    private var service: TimeTrackingService { .shared }
    private var actions: TTMenuActions { snapshot.menu.actions }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let first = firstGroup
            if !first.isEmpty {
                ForEach(first, id: \.self) { row($0) }
            }
            if actions.start || actions.close || actions.reopen {
                if !first.isEmpty { divider }
                if actions.start { startMenu }
                if actions.close { endMenu }
                if actions.reopen {
                    TimeTrackingRowButton(title: menu.reopenDay, symbol: "arrow.uturn.backward") {
                        service.reopenDay()
                    }
                }
            }
            if TimeTrackingService.recordsAvailable {
                divider
                TimeTrackingRowButton(title: menu.records, symbol: "tablecells") { service.showRecords() }
            }
        }
        .padding(.vertical, 4)
    }

    private enum Row: Hashable { case countDay, pause, away, countPause }

    private var firstGroup: [Row] {
        var rows: [Row] = []
        if actions.countDay { rows.append(.countDay) }
        if actions.pause { rows.append(.pause) }
        if actions.away { rows.append(.away) }
        if actions.countPause { rows.append(.countPause) }
        return rows
    }

    @ViewBuilder
    private func row(_ row: Row) -> some View {
        switch row {
        case .countDay:
            TimeTrackingRowButton(title: menu.recordToday, symbol: "calendar.badge.clock",
                                  checked: actions.countDayChecked) {
                service.setCounting(!actions.countDayChecked)
            }
        case .pause:
            TimeTrackingRowButton(title: actions.pauseAction.title(menu), symbol: actions.pauseAction.symbolName) {
                service.togglePause()
            }
        case .away:
            TimeTrackingRowMenu(title: menu.keepWorkingAway, symbol: "figure.walk") {
                ForEach(TTActivity.all, id: \.self) { activity in
                    Button {
                        service.goAway(activity)
                    } label: {
                        Label(activity.label(texts), systemImage: Self.symbol(activity))
                    }
                }
                Divider()
                Text(menu.awayNote)
            }
        case .countPause:
            TimeTrackingRowMenu(title: menu.countBreak, symbol: "arrow.uturn.backward.circle") {
                ForEach(snapshot.pausesToday, id: \.self) { pause in
                    Menu(TTMenu.pauseTitle(pause, texts: texts, menu: menu)) {
                        // Per break the reason, as with "Keep working away from the Mac".
                        ForEach(TTActivity.all, id: \.self) { activity in
                            Button {
                                service.countPauseAsWork(pause, activity: activity)
                            } label: {
                                Label(activity.label(texts), systemImage: Self.symbol(activity))
                            }
                            .id(TTMenu.countPauseTag(from: pause.from, activity: activity))
                        }
                    }
                }
            }
        }
    }

    /// "Set start of work ›": now, 15 or 30 minutes ago, another time, and
    /// the first unlock again.
    private var startMenu: some View {
        TimeTrackingRowMenu(title: menu.setStart, symbol: "sunrise") {
            relativeItems { service.setStart(at: $0) }
            Divider()
            Button(menu.otherTime) { choosingStart = true }
            if actions.startReset {
                Divider()
                Button(TTMenu.startResetTitle(unlock: actions.startResetUnlock, menu: menu)) {
                    service.setStart(at: nil)
                }
            }
        }
        .popover(isPresented: $choosingStart, arrowEdge: .trailing) {
            TimeTrackingTimePicker(title: menu.setStart, prompt: menu.startPrompt, choice: snapshot.menu.startChoice,
                                   menu: menu, isPresented: $choosingStart) { service.setStart(at: $0) }
        }
    }

    /// "End of work ›": the same choices without the first unlock.
    private var endMenu: some View {
        TimeTrackingRowMenu(title: menu.endOfWork, symbol: "moon") {
            relativeItems { service.closeDay(at: $0) }
            Divider()
            Button(menu.otherTime) { choosingEnd = true }
        }
        .popover(isPresented: $choosingEnd, arrowEdge: .trailing) {
            TimeTrackingTimePicker(title: menu.endOfWork, prompt: menu.endPrompt, choice: snapshot.menu.endChoice,
                                   menu: menu, isPresented: $choosingEnd) { service.closeDay(at: $0) }
        }
    }

    /// "Now (09:12)", "15 min ago (08:57)", "30 min ago (08:42)"; the time is
    /// taken anew at the click, never before midnight.
    @ViewBuilder
    private func relativeItems(_ apply: @escaping (Int) -> Void) -> some View {
        let now = service.now().secs
        ForEach(TTMenu.relativeMinutes, id: \.self) { minutes in
            Button(TTMenu.relativeTitle(minutes: minutes, now: now, menu: menu)) {
                apply(TTMenu.relativeTime(minutes: minutes, now: service.now().secs))
            }
        }
    }

    private var divider: some View {
        Divider().padding(.vertical, 4).padding(.horizontal, 8)
    }

    /// SF Symbol for the reason of work away from the Mac (`activity_symbol`).
    static func symbol(_ activity: TTActivity) -> String {
        switch activity {
        case .meeting: return "person.2"
        case .call: return "phone"
        case .networking: return "person.3"
        case .other: return "ellipsis.circle"
        }
    }
}

/// One action, laid out like a menu item: symbol, title and, for "Record
/// today", a checkmark while the day counts.
private struct TimeTrackingRowButton: View {
    let title: String
    let symbol: String
    var checked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TimeTrackingRowLabel(title: title, symbol: symbol, trailing: checked ? "checkmark" : nil)
        }
        .buttonStyle(TimeTrackingRowStyle())
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}

/// An action with a submenu (the chevron says so).
private struct TimeTrackingRowMenu<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        Menu {
            content()
        } label: {
            TimeTrackingRowLabel(title: title, symbol: symbol, trailing: "chevron.right")
                .background(TimeTrackingRowStyle.highlight(hovering))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .onHover { hovering = $0 }
        .accessibilityLabel(title)
    }
}

private struct TimeTrackingRowLabel: View {
    let title: String
    let symbol: String
    let trailing: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 6)
            if let trailing {
                Image(systemName: trailing)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Highlights the row under the pointer, like a menu.
private struct TimeTrackingRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration)
    }

    static func highlight(_ on: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(on ? Color.primary.opacity(0.08) : Color.clear)
            .padding(.horizontal, 4)
    }

    private struct Row: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .background(TimeTrackingRowStyle.highlight(hovering || configuration.isPressed))
                .onHover { hovering = $0 }
        }
    }
}

/// "Other time…": hours and minutes of today, from midnight to now, narrower
/// where the start or end of work asks for it (`menubar.rs` `chosen_time`).
private struct TimeTrackingTimePicker: View {
    let title: String
    let prompt: String
    let choice: TTTimeChoice
    let menu: TimeTrackingMenuTexts
    @Binding var isPresented: Bool
    let apply: (Int) -> Void
    @State private var selection = Date()

    private var midnight: Date { Calendar.current.startOfDay(for: Date()) }

    private func date(_ secs: Int) -> Date { midnight.addingTimeInterval(TimeInterval(secs)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(prompt)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DatePicker(title, selection: $selection, in: date(choice.earliest)...date(choice.latest),
                       displayedComponents: .hourAndMinute)
                .datePickerStyle(.stepperField)
                .labelsHidden()
                .fixedSize()
            HStack {
                Spacer()
                Button(menu.cancel) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(menu.apply) {
                    isPresented = false
                    // Only the time of day counts; today and not in the future.
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: selection)
                    let secs = (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60
                    apply(choice.clamp(secs, now: TimeTrackingService.shared.now().secs))
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 250)
        .onAppear { selection = date(choice.initial) }
    }
}
