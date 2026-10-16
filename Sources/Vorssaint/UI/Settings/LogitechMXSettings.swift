// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Settings > Mouse > Logitech MX mice: the switch, then one panel per
/// connected MX Master model with what Logi Options+ offers for it. Only
/// what the mouse reports is shown, so a 3S never offers the 4's panel.
struct LogitechMXSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = LogitechMXService.shared
    @AppStorage(DefaultsKey.logitechMXEnabled) private var enabled = false

    private var text: LogitechMXStrings { FeatureStrings.logitechMX(l10n.language) }

    /// One panel per model: settings belong to the model, not the unit.
    private var models: [LogitechMXDeviceSnapshot] {
        var seen: Set<LogitechMXModel> = []
        return service.devices.filter { seen.insert($0.model).inserted }
    }

    var body: some View {
        SettingsCard(title: text.title) {
            SettingsRow(symbol: AppFeature.logitechMX.symbolName, title: text.title, caption: text.caption) {
                Toggle(text.title, isOn: $enabled)
                    .labelsHidden()
                    .onChange(of: enabled) { _, on in
                        LogitechMXService.shared.syncWithPreferences()
                        if on, !permissions.accessibility { permissions.requestAccessibility() }
                    }
            }
            if enabled {
                VStack(alignment: .leading, spacing: 12) {
                    if service.optionsPlusRunning {
                        Label(text.optionsPlusWarning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if models.isEmpty {
                        Text(text.noDevice)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(models) { device in
                        LogitechMXDevicePanel(device: device)
                            .id(device.model)
                    }
                }
                .padding(.leading, settingsRowTextInset)
            }
        }
        .settingsSectionAnchor(.logitechMX, cornerRadius: 16)
        .onAppear { LogitechMXService.shared.syncWithPreferences() }
    }
}

private struct LogitechMXDevicePanel: View {
    let device: LogitechMXDeviceSnapshot
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.radialMenuEnabled) private var radialMenuEnabled = false
    @State private var profile = LogitechMXProfile()
    @State private var loaded = false

    private var text: LogitechMXStrings { FeatureStrings.logitechMX(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            buttons
            if device.hasThumbWheel {
                Divider()
                thumbWheel
            }
            Divider()
            pointAndScroll
            if device.haptics != nil {
                Divider()
                haptics
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            guard !loaded else { return }
            profile = LogitechMXService.shared.profile(for: device.model)
            loaded = true
        }
    }

    private func save() {
        LogitechMXService.shared.save(profile, for: device.model)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name).font(.headline)
                Text(device.viaReceiver ? text.viaReceiver : text.viaBluetooth)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let battery = device.battery, battery.percent != nil || battery.charging {
                batteryBadge(battery)
            }
            if let mode = device.wheelMode {
                Label(mode == .ratchet ? text.ratchet : text.freeSpin,
                      systemImage: mode == .ratchet ? "gearshape" : "circle.dotted")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .help(text.wheelMode)
            }
        }
    }

    /// The charge the mouse last reported, with the system's battery glyph.
    private func batteryBadge(_ battery: HIDPP.BatteryState) -> some View {
        let percent = battery.percent ?? (battery.full ? 100 : nil)
        let symbol: String
        if battery.charging {
            symbol = "battery.100percent.bolt"
        } else {
            switch percent ?? 50 {
            case ..<13: symbol = "battery.0percent"
            case ..<38: symbol = "battery.25percent"
            case ..<63: symbol = "battery.50percent"
            case ..<88: symbol = "battery.75percent"
            default: symbol = "battery.100percent"
            }
        }
        let low = !battery.charging && (percent ?? 100) <= 10
        return Label(percent.map { "\($0) %" } ?? text.charging, systemImage: symbol)
            .font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(low ? Color.red : Color.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .help(battery.charging ? "\(text.battery), \(text.charging)" : text.battery)
            .accessibilityLabel(text.battery)
            .accessibilityValue(percent.map { "\($0) %" } ?? text.charging)
    }

    // MARK: Buttons

    private var buttons: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text.buttonsSection).font(.subheadline.weight(.semibold))
            ForEach(device.controls) { control in
                controlRow(control)
            }
        }
    }

    private func controlRow(_ control: LogitechMXControl) -> some View {
        let assignment = profile.assignment(for: control)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: control.symbolName(on: device.model))
                    .frame(width: 20)
                    .foregroundStyle(.secondary)
                Text(text.name(control, on: device.model))
                Spacer(minLength: 12)
                actionPicker(selection: Binding(
                    get: { assignment.action.kind },
                    set: { kind in
                        var updated = assignment
                        updated.action = LogitechMXAction(kind: kind)
                        profile.setAssignment(updated, for: control)
                        save()
                    }),
                             menu: buttonMenu(for: control))
            }
            Group {
                if assignment.action.kind == .gestures {
                    gestureEditor(control, assignment: assignment)
                } else {
                    payloadEditor(assignment.action) { action in
                        var updated = assignment
                        updated.action = action
                        profile.setAssignment(updated, for: control)
                        save()
                    }
                }
                if assignment.action.kind == .radialMenu,
                   !(AppFeature.radialMenu.isAvailable && radialMenuEnabled) {
                    note(text.radialMenuOffNote)
                }
                if control == .hapticPanel, let force = device.panelForce {
                    panelForceEditor(force)
                }
            }
            .padding(.leading, 30)
        }
    }

    /// The haptic panel's pressure point, shown from the lightest press the
    /// mouse accepts (0 %) to the firmest (100 %).
    private func panelForceEditor(_ force: HIDPP.ForceButtonInfo) -> some View {
        let value = force.sanitized(profile.hapticPanelForce ?? device.panelForceValue ?? force.defaultValue)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                CommitSlider(title: text.panelForce, value: Double(value),
                             range: Double(force.minimum)...Double(force.maximum), step: 1,
                             readout: { "\(force.percent(Int($0))) %" }) {
                    profile.hapticPanelForce = force.sanitized(Int($0))
                    save()
                }
                Button(text.panelForceDefault) {
                    profile.hapticPanelForce = force.defaultValue
                    save()
                }
                .disabled(value == force.defaultValue)
            }
            HStack {
                Text(text.panelForceLight)
                Spacer()
                Text(text.panelForceFirm)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.leading, 132)
            .padding(.trailing, 160)
            note(text.panelForceCaption)
        }
    }

    private func buttonMenu(for control: LogitechMXControl) -> [[LogitechMXAction.Kind]] {
        LogitechMXAction.buttonMenu.map { group in
            group.filter { kind in
                if kind == .native { return control.hasNativeFunction }
                if kind == .gestures { return device.gestureControls.contains(control) }
                return isOffered(kind)
            }
        }.filter { !$0.isEmpty }
    }

    /// Device actions only where the mouse has what they switch.
    private func isOffered(_ kind: LogitechMXAction.Kind) -> Bool {
        switch kind {
        case .modeShift: return device.hasSmartShift
        case .cyclePointerSpeed: return device.dpiRange != nil
        default: return true
        }
    }

    private func actionPicker(selection: Binding<LogitechMXAction.Kind>,
                              menu: [[LogitechMXAction.Kind]]) -> some View {
        Picker(selection: selection) {
            ForEach(Array(menu.enumerated()), id: \.offset) { _, group in
                Section {
                    ForEach(group, id: \.self) { kind in
                        Text(text.name(kind)).tag(kind)
                    }
                }
            }
        } label: {
            EmptyView()
        }
        .labelsHidden()
        .frame(width: 230)
    }

    @ViewBuilder
    private func gestureEditor(_ control: LogitechMXControl, assignment: LogitechMXAssignment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(text.gesturePreset)
                Spacer(minLength: 12)
                Picker(selection: Binding(
                    get: { assignment.gestures.preset },
                    set: { preset in
                        var updated = assignment
                        updated.gestures.preset = preset
                        profile.setAssignment(updated, for: control)
                        save()
                    })) {
                    ForEach(LogitechMXGesturePreset.allCases) { preset in
                        Text(text.name(preset)).tag(preset)
                    }
                } label: {
                    EmptyView()
                }
                .labelsHidden()
                .frame(width: 200)
            }
            note(assignment.gestures.preset == .pan ? text.panCaption : text.gestureCaption)
            if assignment.gestures.preset != .pan {
                ForEach(LogitechMXGestureDirection.allCases) { direction in
                    gestureDirectionRow(control, assignment: assignment, direction: direction)
                }
            }
        }
    }

    @ViewBuilder
    private func gestureDirectionRow(_ control: LogitechMXControl, assignment: LogitechMXAssignment,
                                     direction: LogitechMXGestureDirection) -> some View {
        let action = assignment.gestures.action(for: direction)
        let custom = assignment.gestures.preset == .custom
        let update: (LogitechMXAction) -> Void = { newAction in
            var updated = assignment
            updated.gestures.custom[direction] = newAction
            profile.setAssignment(updated, for: control)
            save()
        }
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: direction.symbolName)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text(text.name(direction))
                    .foregroundStyle(custom ? .primary : .secondary)
                Spacer(minLength: 12)
                if custom {
                    actionPicker(selection: Binding(get: { action.kind },
                                                    set: { update(LogitechMXAction(kind: $0)) }),
                                 menu: LogitechMXAction.gestureMenu.map { $0.filter(isOffered) }
                                    .filter { !$0.isEmpty })
                } else {
                    Text(text.name(action.kind))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            if custom {
                payloadEditor(action, update: update)
                    .padding(.leading, 26)
            }
        }
    }

    @ViewBuilder
    private func payloadEditor(_ action: LogitechMXAction,
                               update: @escaping (LogitechMXAction) -> Void) -> some View {
        switch action.kind {
        case .shortcut:
            ShortcutRecorderButton(shortcut: action.shortcut ?? GlobalShortcut.keepAwakeDefault,
                                   isEnabled: true,
                                   waitingTitle: l10n.s.shortcutPressKeys,
                                   emptyTitle: action.shortcut == nil ? text.recordShortcut : nil,
                                   invalidAction: { NSSound.beep() },
                                   captureAction: { shortcut in
                                       update(LogitechMXAction(kind: .shortcut, payload: shortcut.storageValue))
                                   })
                .frame(width: 200, height: 24)
        case .openApp:
            HStack(spacing: 8) {
                if action.payload.isEmpty {
                    Text(text.noAppChosen).foregroundStyle(.secondary)
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: action.payload))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(FileManager.default.displayName(atPath: action.payload))
                }
                Button(text.chooseApp) {
                    if let path = chooseApplication() {
                        update(LogitechMXAction(kind: .openApp, payload: path))
                    }
                }
            }
            .font(.callout)
        case .tool:
            Picker(selection: Binding(
                get: { action.tool ?? .screenshot },
                set: { update(LogitechMXAction(kind: .tool, payload: $0.rawValue)) })) {
                ForEach(RadialMenuTool.allCases) { tool in
                    Text(tool.feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language))).tag(tool)
                }
            } label: {
                EmptyView()
            }
            .labelsHidden()
            .frame(width: 230)
            .onAppear {
                if action.tool == nil { update(LogitechMXAction(kind: .tool, payload: RadialMenuTool.screenshot.rawValue)) }
            }
        default:
            EmptyView()
        }
    }

    private func chooseApplication() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    // MARK: Thumb wheel

    private var thumbWheel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text.thumbWheelSection).font(.subheadline.weight(.semibold))
            HStack {
                Text(text.thumbAction)
                Spacer(minLength: 12)
                Picker(selection: Binding(get: { profile.thumbWheel },
                                          set: { profile.thumbWheel = $0; save() })) {
                    ForEach(LogitechMXThumbWheelAction.allCases) { action in
                        Label(text.name(action), systemImage: action.symbolName).tag(action)
                    }
                } label: {
                    EmptyView()
                }
                .labelsHidden()
                .frame(width: 230)
            }
            if profile.thumbWheel == .shortcuts {
                thumbShortcutRow(text.thumbForward, value: profile.thumbWheelForward) {
                    profile.thumbWheelForward = $0
                }
                thumbShortcutRow(text.thumbBackward, value: profile.thumbWheelBackward) {
                    profile.thumbWheelBackward = $0
                }
            }
            if profile.thumbWheel.divertsWheel, profile.thumbWheel != .none {
                CommitSlider(title: text.thumbSpeed,
                             value: Double(profile.thumbWheelSensitivity),
                             range: Double(LogitechMXSupport.thumbWheelSensitivityRange.lowerBound)
                                 ... Double(LogitechMXSupport.thumbWheelSensitivityRange.upperBound),
                             step: 1, readout: { "\(Int($0))" }) {
                    profile.thumbWheelSensitivity = Int($0)
                    save()
                }
            }
            Toggle(text.thumbInverted, isOn: Binding(get: { profile.thumbWheelInverted },
                                                     set: { profile.thumbWheelInverted = $0; save() }))
        }
    }

    private func thumbShortcutRow(_ title: String, value: String,
                                  set: @escaping (String) -> Void) -> some View {
        let shortcut = GlobalShortcut(storageValue: value)
        return HStack {
            Text(title)
            Spacer(minLength: 12)
            ShortcutRecorderButton(shortcut: shortcut ?? GlobalShortcut.keepAwakeDefault,
                                   isEnabled: true,
                                   waitingTitle: l10n.s.shortcutPressKeys,
                                   emptyTitle: shortcut == nil ? text.recordShortcut : nil,
                                   invalidAction: { NSSound.beep() },
                                   captureAction: { set($0.storageValue); save() })
                .frame(width: 200, height: 24)
        }
    }

    // MARK: Point & scroll

    private var pointAndScroll: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text.pointScrollSection).font(.subheadline.weight(.semibold))
            if let range = device.dpiRange {
                let primary = range.sanitized(profile.dpi ?? device.dpi ?? 1000)
                CommitSlider(title: text.pointerSpeed, value: Double(primary),
                             range: Double(range.minimum)...Double(range.maximum),
                             step: Double(max(range.step, 1)), readout: { "\(Int($0)) DPI" }) {
                    profile.dpi = range.sanitized(Int($0))
                    save()
                }
                CommitSlider(title: text.alternateSpeed,
                             value: Double(range.sanitized(profile.alternateDPI
                                ?? LogitechMXSupport.defaultAlternateDPI(primary: primary, range: range))),
                             range: Double(range.minimum)...Double(range.maximum),
                             step: Double(max(range.step, 1)), readout: { "\(Int($0)) DPI" }) {
                    profile.alternateDPI = range.sanitized(Int($0))
                    save()
                }
                note(text.alternateCaption)
            }
            if device.hasSmartShift {
                let current = LogitechMXSupport.smartShiftSetting(fromFirmware: device.smartShiftThreshold ?? 0)
                let smartShiftOn = profile.smartShiftEnabled ?? current.enabled
                SettingsRow(symbol: "dial.medium", title: text.smartShift, caption: text.smartShiftCaption) {
                    Toggle(text.smartShift, isOn: Binding(get: { smartShiftOn },
                                                          set: { profile.smartShiftEnabled = $0; save() }))
                        .labelsHidden()
                }
                if smartShiftOn {
                    CommitSlider(title: text.sensitivity,
                                 value: Double(profile.smartShiftThreshold ?? current.threshold),
                                 range: Double(LogitechMXSupport.smartShiftThresholdRange.lowerBound)
                                     ... Double(LogitechMXSupport.smartShiftThresholdRange.upperBound),
                                 step: 1, readout: { "\(Int($0))" }) {
                        profile.smartShiftThreshold = Int($0)
                        save()
                    }
                }
                if device.tunableTorque {
                    CommitSlider(title: text.scrollForce,
                                 value: Double(profile.scrollForce ?? Int(device.scrollForce ?? 50)),
                                 range: Double(LogitechMXSupport.scrollForceRange.lowerBound)
                                     ... Double(LogitechMXSupport.scrollForceRange.upperBound),
                                 step: 1, readout: { "\(Int($0)) %" }) {
                        profile.scrollForce = Int($0)
                        save()
                    }
                    .disabled(device.wheelMode == .freeSpin)
                    note(text.scrollForceCaption)
                }
            }
            if device.wheelCanInvert {
                Toggle(text.wheelInverted, isOn: Binding(get: { profile.wheelInverted },
                                                         set: { profile.wheelInverted = $0; save() }))
            }
        }
    }

    // MARK: Haptics

    private var haptics: some View {
        let enabled = profile.hapticEnabled ?? device.haptic?.enabled ?? true
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(text.hapticsSection).font(.subheadline.weight(.semibold))
                Spacer()
                Button(text.hapticTry) {
                    LogitechMXService.shared.playHapticSample(deviceID: device.id)
                }
                .disabled(!enabled)
            }
            Toggle(text.hapticEnable, isOn: Binding(get: { enabled },
                                                    set: { profile.hapticEnabled = $0; save() }))
            if enabled {
                CommitSlider(title: text.hapticIntensity,
                             value: Double(profile.hapticLevel ?? device.haptic?.level ?? 50),
                             range: 1...100, step: device.haptics?.fourLevelsOnly == true ? 25 : 1,
                             readout: { "\(Int($0)) %" }) {
                    profile.hapticLevel = Int($0)
                    save()
                }
                Toggle(text.hapticOnGestures, isOn: Binding(get: { profile.hapticOnGestures },
                                                            set: { profile.hapticOnGestures = $0; save() }))
            }
        }
    }

    private func note(_ string: String) -> some View {
        Text(string)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A slider that writes to the mouse once, when the drag ends, instead of
/// sending a device request for every step the knob passes.
private struct CommitSlider: View {
    let title: String
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let readout: (Double) -> String
    let commit: (Double) -> Void
    @State private var draft: Double?

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(minWidth: 120, alignment: .leading)
            Slider(value: Binding(get: { draft ?? value }, set: { draft = $0 }),
                   in: range, step: step) { editing in
                if !editing, let draft {
                    commit(draft)
                    self.draft = nil
                }
            }
            .labelsHidden()
            Text(readout(draft ?? value))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
    }
}
