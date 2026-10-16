// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The pure half of the Logitech MX extension: which mice it serves, what
/// each control can be set to, how the choices persist, and the small state
/// machines that turn raw device events into actions. Mirrors what Logi
/// Options+ offers for the MX Master 3, 3S and 4, without its account,
/// plugins or per-app profiles.
enum LogitechMXModel: String, CaseIterable, Codable, Identifiable {
    case mxMaster3
    case mxMaster3S
    case mxMaster4

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mxMaster3: return "MX Master 3"
        case .mxMaster3S: return "MX Master 3S"
        case .mxMaster4: return "MX Master 4"
        }
    }

    /// Bluetooth and receiver model IDs Logitech uses for these mice,
    /// including the "for Mac" editions. Only consulted when the device name
    /// is missing; the name is the better witness.
    private static let modelIDs: [UInt16: LogitechMXModel] = [
        0x4082: .mxMaster3, 0xB023: .mxMaster3, 0xB028: .mxMaster3,
        0xB034: .mxMaster3S, 0xB035: .mxMaster3S, 0xB043: .mxMaster3S, 0xB044: .mxMaster3S,
        0xB042: .mxMaster4,
    ]

    /// The device's own name decides ("MX Master 3S", "MX Master 3 Mac",
    /// "MX Master 4"); other Logitech mice are left alone.
    static func identify(name: String?, modelID: UInt16? = nil) -> LogitechMXModel? {
        if let name {
            let lowered = name.lowercased()
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
            if lowered.contains("mxmaster4") { return .mxMaster4 }
            if lowered.contains("mxmaster3s") { return .mxMaster3S }
            if lowered.contains("mxmaster3") { return .mxMaster3 }
            if !lowered.isEmpty { return nil }
        }
        return modelID.flatMap { modelIDs[$0] }
    }
}

/// A physical control the extension can reassign, by its HID++ control ID.
enum LogitechMXControl: UInt16, CaseIterable, Identifiable {
    case middleButton = 0x0052
    case backButton = 0x0053
    case forwardButton = 0x0056
    case gestureButton = 0x00C3
    case modeShiftButton = 0x00C4
    /// The MX Master 4's pressure-sensitive thumb panel.
    case hapticPanel = 0x01A0

    var id: UInt16 { rawValue }

    var symbolName: String {
        switch self {
        case .middleButton: return "computermouse"
        case .backButton: return "arrow.backward.circle"
        case .forwardButton: return "arrow.forward.circle"
        case .gestureButton: return "hand.draw"
        case .modeShiftButton: return "dial.medium"
        case .hapticPanel: return "hand.point.up.braille"
        }
    }

    /// What a control does when the extension leaves it alone. Options+
    /// ships the same defaults, with the radial menu standing in for its
    /// Actions Ring.
    var defaultAssignment: LogitechMXAssignment {
        switch self {
        case .gestureButton: return LogitechMXAssignment(action: .gestures, gestures: .init(preset: .windows))
        case .hapticPanel: return LogitechMXAssignment(action: .radialMenu)
        default: return LogitechMXAssignment(action: .native)
        }
    }

    /// Whether "native" means anything for this control. Without software
    /// the gesture button and the haptic panel do nothing at all.
    var hasNativeFunction: Bool {
        switch self {
        case .gestureButton, .hapticPanel: return false
        default: return true
        }
    }
}

/// One thing a control can do. Raw values persist; never rename them.
struct LogitechMXAction: Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        // The control's own job, unchanged.
        case native
        case none
        // Mouse
        case middleClick, back, forward, gestures, modeShift, cyclePointerSpeed
        // Navigation
        case missionControl, appExpose, showDesktop, launchpad, desktopLeft, desktopRight, spotlight
        // Media and display
        case playPause, nextTrack, previousTrack, volumeUp, volumeDown, mute, brightnessUp, brightnessDown
        // Editing
        case copy, cut, paste, undo, redo, newTab, closeTab, zoomIn, zoomOut, zoomReset, emoji, lockScreen
        // Vorssaint
        case radialMenu, tool
        // Payload-carrying
        case shortcut, openApp
    }

    var kind: Kind
    /// A shortcut storage value, an application path or a tool identifier.
    var payload: String = ""

    static let native = LogitechMXAction(kind: .native)
    static let none = LogitechMXAction(kind: .none)
    static let gestures = LogitechMXAction(kind: .gestures)
    static let radialMenu = LogitechMXAction(kind: .radialMenu)

    init(kind: Kind, payload: String = "") {
        self.kind = kind
        self.payload = payload
    }

    init(_ kind: Kind) { self.init(kind: kind) }

    var shortcut: GlobalShortcut? {
        kind == .shortcut ? GlobalShortcut(storageValue: payload) : nil
    }

    var tool: RadialMenuTool? {
        kind == .tool ? RadialMenuTool(rawValue: payload) : nil
    }

    /// Actions that need a payload and do not have a usable one yet.
    var isComplete: Bool {
        switch kind {
        case .shortcut: return shortcut != nil
        case .openApp: return !payload.isEmpty
        case .tool: return tool != nil
        default: return true
        }
    }

    /// Posting keys or clicks into other apps goes through Accessibility.
    var needsAccessibility: Bool {
        switch kind {
        case .native, .none, .modeShift, .cyclePointerSpeed, .launchpad, .openApp, .tool, .radialMenu:
            return false
        default:
            return true
        }
    }

    /// The choices a button menu lists, grouped as the menu shows them.
    static let buttonMenu: [[Kind]] = [
        [.native, .none],
        [.gestures, .middleClick, .back, .forward, .modeShift, .cyclePointerSpeed],
        [.missionControl, .appExpose, .showDesktop, .launchpad, .desktopLeft, .desktopRight, .spotlight],
        [.playPause, .nextTrack, .previousTrack, .volumeUp, .volumeDown, .mute, .brightnessUp, .brightnessDown],
        [.copy, .cut, .paste, .undo, .redo, .newTab, .closeTab, .zoomIn, .zoomOut, .zoomReset, .emoji, .lockScreen],
        [.radialMenu, .tool, .shortcut, .openApp],
    ]

    /// A gesture direction can do anything a button can, except start
    /// another gesture or fall back to a native job it does not have.
    static let gestureMenu: [[Kind]] = buttonMenu.map { group in
        group.filter { $0 != .gestures && $0 != .native }
    }.filter { !$0.isEmpty }
}

extension LogitechMXAction {
    private enum CodingKeys: String, CodingKey { case kind, payload }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(Kind.self, forKey: .kind)
        payload = try container.decodeIfPresent(String.self, forKey: .payload) ?? ""
    }
}

// MARK: - Gestures

enum LogitechMXGestureDirection: String, Codable, CaseIterable, Identifiable {
    case click, up, down, left, right
    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .click: return "smallcircle.filled.circle"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }
}

/// Hold a button and move the mouse: Options+ offers the same five presets
/// plus a custom set (its app navigation needs the app switcher it owns).
enum LogitechMXGesturePreset: String, Codable, CaseIterable, Identifiable {
    case windows, media, zoom, pan, custom
    var id: String { rawValue }

    /// The fixed actions of a preset. Pan has none: it scrolls while held.
    func action(for direction: LogitechMXGestureDirection) -> LogitechMXAction {
        switch (self, direction) {
        case (.windows, .click), (.windows, .up): return LogitechMXAction(.missionControl)
        case (.windows, .down): return LogitechMXAction(.appExpose)
        case (.windows, .left): return LogitechMXAction(.desktopLeft)
        case (.windows, .right): return LogitechMXAction(.desktopRight)
        case (.media, .click): return LogitechMXAction(.playPause)
        case (.media, .up): return LogitechMXAction(.volumeUp)
        case (.media, .down): return LogitechMXAction(.volumeDown)
        case (.media, .left): return LogitechMXAction(.previousTrack)
        case (.media, .right): return LogitechMXAction(.nextTrack)
        case (.zoom, .click): return LogitechMXAction(.zoomReset)
        case (.zoom, .up): return LogitechMXAction(.zoomIn)
        case (.zoom, .down): return LogitechMXAction(.zoomOut)
        case (.zoom, _), (.pan, _), (.custom, _): return .none
        }
    }
}

struct LogitechMXGestures: Codable, Equatable {
    var preset: LogitechMXGesturePreset = .windows
    var custom: [LogitechMXGestureDirection: LogitechMXAction] = [:]

    init(preset: LogitechMXGesturePreset = .windows,
         custom: [LogitechMXGestureDirection: LogitechMXAction] = [:]) {
        self.preset = preset
        self.custom = custom
    }

    func action(for direction: LogitechMXGestureDirection) -> LogitechMXAction {
        guard preset == .custom else { return preset.action(for: direction) }
        let action = custom[direction] ?? .none
        return action.kind == .gestures || action.kind == .native ? .none : action
    }

    private enum CodingKeys: String, CodingKey { case preset, custom }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preset = (try? container.decode(LogitechMXGesturePreset.self, forKey: .preset)) ?? .windows
        let raw = (try? container.decode([String: LossyAction].self, forKey: .custom)) ?? [:]
        custom = [:]
        for (key, value) in raw {
            if let direction = LogitechMXGestureDirection(rawValue: key), let action = value.action {
                custom[direction] = action
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preset, forKey: .preset)
        let raw = Dictionary(uniqueKeysWithValues: custom.map { ($0.key.rawValue, $0.value) })
        try container.encode(raw, forKey: .custom)
    }
}

/// A control's whole assignment: its action and, for gestures, the set.
struct LogitechMXAssignment: Codable, Equatable {
    var action: LogitechMXAction
    var gestures: LogitechMXGestures = LogitechMXGestures()

    init(action: LogitechMXAction, gestures: LogitechMXGestures = LogitechMXGestures()) {
        self.action = action
        self.gestures = gestures
    }

    /// Gestures post input for every preset, pan included.
    var needsAccessibility: Bool {
        action.kind == .gestures || action.needsAccessibility
    }

    private enum CodingKeys: String, CodingKey { case action, gestures }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(LogitechMXAction.self, forKey: .action)
        gestures = (try? container.decode(LogitechMXGestures.self, forKey: .gestures)) ?? LogitechMXGestures()
    }
}

/// Decodes one action without failing its container: an action written by a
/// newer version is dropped instead of losing the whole profile.
private struct LossyAction: Decodable {
    let action: LogitechMXAction?
    init(from decoder: Decoder) throws { action = try? LogitechMXAction(from: decoder) }
}

private struct LossyAssignment: Decodable {
    let assignment: LogitechMXAssignment?
    init(from decoder: Decoder) throws { assignment = try? LogitechMXAssignment(from: decoder) }
}

// MARK: - Thumb wheel

/// What turning the thumb wheel does. Raw values persist; never rename them.
enum LogitechMXThumbWheelAction: String, Codable, CaseIterable, Identifiable {
    /// The wheel's own job: horizontal scrolling, left to the system.
    case horizontalScroll
    case volume, zoom, tabs, desktops, brightness, pages, shortcuts, none

    var id: String { rawValue }

    /// Every choice but the native one diverts the wheel to this app.
    var divertsWheel: Bool { self != .horizontalScroll }

    var symbolName: String {
        switch self {
        case .horizontalScroll: return "arrow.left.and.right"
        case .volume: return "speaker.wave.2"
        case .zoom: return "plus.magnifyingglass"
        case .tabs: return "rectangle.stack"
        case .desktops: return "rectangle.split.3x1"
        case .brightness: return "sun.max"
        case .pages: return "arrow.uturn.backward"
        case .shortcuts: return "keyboard"
        case .none: return "nosign"
        }
    }

    /// The pair of actions one step forward or back fires. Shortcuts take
    /// theirs from the profile.
    func stepActions(forward: GlobalShortcut?, backward: GlobalShortcut?)
        -> (forward: LogitechMXAction, backward: LogitechMXAction)? {
        switch self {
        case .horizontalScroll, .none: return nil
        case .volume: return (LogitechMXAction(.volumeUp), LogitechMXAction(.volumeDown))
        case .zoom: return (LogitechMXAction(.zoomIn), LogitechMXAction(.zoomOut))
        case .tabs: return (LogitechMXAction(kind: .shortcut, payload: LogitechMXSupport.nextTab.storageValue),
                            LogitechMXAction(kind: .shortcut, payload: LogitechMXSupport.previousTab.storageValue))
        case .desktops: return (LogitechMXAction(.desktopRight), LogitechMXAction(.desktopLeft))
        case .brightness: return (LogitechMXAction(.brightnessUp), LogitechMXAction(.brightnessDown))
        case .pages: return (LogitechMXAction(.forward), LogitechMXAction(.back))
        case .shortcuts:
            return (forward.map { LogitechMXAction(kind: .shortcut, payload: $0.storageValue) } ?? .none,
                    backward.map { LogitechMXAction(kind: .shortcut, payload: $0.storageValue) } ?? .none)
        }
    }

    /// Desktop switching animates; steps closer than this are dropped so one
    /// flick moves one desktop instead of racing through all of them.
    var minimumStepInterval: TimeInterval { self == .desktops ? 0.35 : 0 }
}

// MARK: - Profile

/// Everything set for one mouse model. Values left nil keep whatever the
/// device holds, so a profile never overwrites a setting the user never
/// touched here.
struct LogitechMXProfile: Codable, Equatable {
    var assignments: [UInt16: LogitechMXAssignment] = [:]
    var thumbWheel: LogitechMXThumbWheelAction = .horizontalScroll
    var thumbWheelForward: String = ""
    var thumbWheelBackward: String = ""
    var thumbWheelInverted = false
    var thumbWheelSensitivity = LogitechMXSupport.defaultThumbWheelSensitivity
    var wheelInverted = false
    var smartShiftEnabled: Bool?
    var smartShiftThreshold: Int?
    var scrollForce: Int?
    var dpi: Int?
    var alternateDPI: Int?
    var hapticEnabled: Bool?
    var hapticLevel: Int?
    var hapticOnGestures = true
    /// The haptic panel's press force in device units; nil keeps the device's.
    var hapticPanelForce: Int?

    init() {}

    func assignment(for control: LogitechMXControl) -> LogitechMXAssignment {
        assignments[control.rawValue] ?? control.defaultAssignment
    }

    mutating func setAssignment(_ assignment: LogitechMXAssignment, for control: LogitechMXControl) {
        assignments[control.rawValue] = assignment == control.defaultAssignment ? nil : assignment
    }

    var thumbWheelShortcuts: (forward: GlobalShortcut?, backward: GlobalShortcut?) {
        (GlobalShortcut(storageValue: thumbWheelForward), GlobalShortcut(storageValue: thumbWheelBackward))
    }

    private enum CodingKeys: String, CodingKey {
        case assignments, thumbWheel, thumbWheelForward, thumbWheelBackward, thumbWheelInverted,
             thumbWheelSensitivity, wheelInverted, smartShiftEnabled, smartShiftThreshold, scrollForce,
             dpi, alternateDPI, hapticEnabled, hapticLevel, hapticOnGestures, hapticPanelForce
    }

    /// Tolerant on purpose: a hand-edited or newer blob keeps every field it
    /// can, and values out of range come back to the nearest legal one.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = (try? c.decode([String: LossyAssignment].self, forKey: .assignments)) ?? [:]
        for (key, value) in raw {
            guard let cid = UInt16(key), LogitechMXControl(rawValue: cid) != nil,
                  let assignment = value.assignment else { continue }
            assignments[cid] = assignment
        }
        thumbWheel = (try? c.decode(LogitechMXThumbWheelAction.self, forKey: .thumbWheel)) ?? .horizontalScroll
        thumbWheelForward = (try? c.decode(String.self, forKey: .thumbWheelForward)) ?? ""
        thumbWheelBackward = (try? c.decode(String.self, forKey: .thumbWheelBackward)) ?? ""
        thumbWheelInverted = (try? c.decode(Bool.self, forKey: .thumbWheelInverted)) ?? false
        thumbWheelSensitivity = LogitechMXSupport.sanitizedSensitivity(
            (try? c.decode(Int.self, forKey: .thumbWheelSensitivity))
                ?? LogitechMXSupport.defaultThumbWheelSensitivity)
        wheelInverted = (try? c.decode(Bool.self, forKey: .wheelInverted)) ?? false
        smartShiftEnabled = try? c.decode(Bool.self, forKey: .smartShiftEnabled)
        smartShiftThreshold = (try? c.decode(Int.self, forKey: .smartShiftThreshold))
            .map(LogitechMXSupport.sanitizedSmartShiftThreshold)
        scrollForce = (try? c.decode(Int.self, forKey: .scrollForce)).map(LogitechMXSupport.sanitizedScrollForce)
        dpi = try? c.decode(Int.self, forKey: .dpi)
        alternateDPI = try? c.decode(Int.self, forKey: .alternateDPI)
        hapticEnabled = try? c.decode(Bool.self, forKey: .hapticEnabled)
        hapticLevel = (try? c.decode(Int.self, forKey: .hapticLevel)).map(LogitechMXSupport.sanitizedHapticLevel)
        hapticOnGestures = (try? c.decode(Bool.self, forKey: .hapticOnGestures)) ?? true
        hapticPanelForce = (try? c.decode(Int.self, forKey: .hapticPanelForce)).flatMap { $0 > 0 ? $0 : nil }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        let raw = Dictionary(uniqueKeysWithValues: assignments.map { (String($0.key), $0.value) })
        try c.encode(raw, forKey: .assignments)
        try c.encode(thumbWheel, forKey: .thumbWheel)
        try c.encode(thumbWheelForward, forKey: .thumbWheelForward)
        try c.encode(thumbWheelBackward, forKey: .thumbWheelBackward)
        try c.encode(thumbWheelInverted, forKey: .thumbWheelInverted)
        try c.encode(thumbWheelSensitivity, forKey: .thumbWheelSensitivity)
        try c.encode(wheelInverted, forKey: .wheelInverted)
        try c.encodeIfPresent(smartShiftEnabled, forKey: .smartShiftEnabled)
        try c.encodeIfPresent(smartShiftThreshold, forKey: .smartShiftThreshold)
        try c.encodeIfPresent(scrollForce, forKey: .scrollForce)
        try c.encodeIfPresent(dpi, forKey: .dpi)
        try c.encodeIfPresent(alternateDPI, forKey: .alternateDPI)
        try c.encodeIfPresent(hapticEnabled, forKey: .hapticEnabled)
        try c.encodeIfPresent(hapticLevel, forKey: .hapticLevel)
        try c.encode(hapticOnGestures, forKey: .hapticOnGestures)
        try c.encodeIfPresent(hapticPanelForce, forKey: .hapticPanelForce)
    }
}

enum LogitechMXSupport {
    static let smartShiftThresholdRange = 1...50
    static let scrollForceRange = 1...100
    static let hapticLevelRange = 0...100
    static let thumbWheelSensitivityRange = 1...10
    static let defaultThumbWheelSensitivity = 5
    /// The thumb wheel's diverted resolution on every MX Master so far.
    static let defaultThumbWheelResolution = 120

    static let nextTab = GlobalShortcut(keyCode: 48, modifiers: [.control])
    static let previousTab = GlobalShortcut(keyCode: 48, modifiers: [.control, .shift])

    static func sanitizedSmartShiftThreshold(_ value: Int) -> Int {
        min(max(value, smartShiftThresholdRange.lowerBound), smartShiftThresholdRange.upperBound)
    }

    static func sanitizedScrollForce(_ value: Int) -> Int {
        min(max(value, scrollForceRange.lowerBound), scrollForceRange.upperBound)
    }

    static func sanitizedHapticLevel(_ value: Int) -> Int {
        min(max(value, hapticLevelRange.lowerBound), hapticLevelRange.upperBound)
    }

    static func sanitizedSensitivity(_ value: Int) -> Int {
        min(max(value, thumbWheelSensitivityRange.lowerBound), thumbWheelSensitivityRange.upperBound)
    }

    /// Profiles persist as one JSON blob keyed by model. Anything that does
    /// not parse is dropped rather than trusted.
    static func decodeProfiles(_ data: Data?) -> [LogitechMXModel: LogitechMXProfile] {
        guard let data, !data.isEmpty,
              let raw = try? JSONDecoder().decode([String: LossyProfile].self, from: data) else { return [:] }
        var profiles: [LogitechMXModel: LogitechMXProfile] = [:]
        for (key, value) in raw {
            if let model = LogitechMXModel(rawValue: key), let profile = value.profile {
                profiles[model] = profile
            }
        }
        return profiles
    }

    static func encodeProfiles(_ profiles: [LogitechMXModel: LogitechMXProfile]) -> Data? {
        let raw = Dictionary(uniqueKeysWithValues: profiles.map { ($0.key.rawValue, $0.value) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(raw)
    }

    private struct LossyProfile: Decodable {
        let profile: LogitechMXProfile?
        init(from decoder: Decoder) throws { profile = try? LogitechMXProfile(from: decoder) }
    }

    /// Whether a control must be diverted to this app, and with raw motion.
    /// A control left at its native job stays with the system, so the
    /// side buttons keep feeding Vorssaint's own mouse features untouched.
    /// Without Accessibility nothing that posts input could happen, so such
    /// a control keeps its own job instead of going dead.
    static func reporting(for assignment: LogitechMXAssignment, control: LogitechMXControl,
                          supportsRawXY: Bool,
                          accessibilityGranted: Bool = true) -> (diverted: Bool, rawXY: Bool) {
        if !accessibilityGranted, assignment.needsAccessibility, control.hasNativeFunction {
            return (false, false)
        }
        switch assignment.action.kind {
        case .native where control.hasNativeFunction:
            return (false, false)
        case .gestures:
            return (true, supportsRawXY)
        default:
            return (true, false)
        }
    }

    /// Two pointer speeds the "change pointer speed" action toggles between.
    static func nextPointerSpeed(current: Int, primary: Int, alternate: Int) -> Int {
        current == alternate ? primary : alternate
    }

    /// The alternate speed Options+ suggests when none is set: half, which
    /// works as a precision speed on a high-resolution sensor.
    static func defaultAlternateDPI(primary: Int, range: HIDPP.DPIRange) -> Int {
        range.sanitized(max(range.minimum, primary / 2))
    }

    /// Movement before a held gesture button counts as a gesture: about 3 mm
    /// whatever the pointer speed, since raw motion arrives in sensor counts.
    static func gestureThreshold(dpi: Int) -> Int {
        max(30, dpi * 12 / 100)
    }

    /// Steps per thumb wheel turn grow with the sensitivity: 2 at the lowest
    /// setting, 20 at the highest.
    static func thumbWheelCountsPerStep(sensitivity: Int, resolution: Int = defaultThumbWheelResolution) -> Int {
        let steps = 2 * sanitizedSensitivity(sensitivity)
        return max(1, Int((Double(max(resolution, 1)) / Double(steps)).rounded()))
    }

    /// SmartShift travels as one firmware threshold; 0xFF keeps the wheel
    /// in whichever mode it is, which is how SmartShift is switched off.
    static func smartShiftFirmwareThreshold(enabled: Bool, threshold: Int) -> UInt8 {
        enabled ? UInt8(sanitizedSmartShiftThreshold(threshold)) : HIDPP.smartShiftDisabledThreshold
    }

    static func smartShiftSetting(fromFirmware threshold: UInt8) -> (enabled: Bool, threshold: Int) {
        let enabled = threshold != HIDPP.smartShiftDisabledThreshold && threshold != 0
        return (enabled, sanitizedSmartShiftThreshold(enabled ? Int(threshold) : 10))
    }
}

// MARK: - Event state machines

/// Turns raw motion while a gesture button is held into at most one action
/// per direction, the way Options+ does: a vertical swipe fires once per
/// press, a horizontal one may repeat after a short beat so one long move
/// can cross several desktops. Releasing without a gesture is a click.
struct LogitechMXGestureTracker {
    static let horizontalRepeatInterval: TimeInterval = 0.4

    let threshold: Int
    private var dx = 0
    private var dy = 0
    private var fired: Set<LogitechMXGestureDirection> = []
    private var lastFire: TimeInterval = -.greatestFiniteMagnitude

    init(threshold: Int) {
        self.threshold = max(1, threshold)
    }

    var didFire: Bool { !fired.isEmpty }

    /// Adds one motion report; returns the direction that fired, if any.
    mutating func add(dx: Int, dy: Int, at time: TimeInterval) -> LogitechMXGestureDirection? {
        self.dx += dx
        self.dy += dy
        let horizontal = abs(self.dx) >= abs(self.dy)
        let distance = horizontal ? abs(self.dx) : abs(self.dy)
        guard distance >= threshold else { return nil }
        let direction: LogitechMXGestureDirection = horizontal
            ? (self.dx > 0 ? .right : .left)
            : (self.dy > 0 ? .down : .up)
        self.dx = 0
        self.dy = 0
        if fired.contains(direction) {
            guard horizontal, time - lastFire >= Self.horizontalRepeatInterval else { return nil }
        } else if !fired.isEmpty, !horizontal {
            // A vertical swipe after anything else would undo or stack on
            // what the first direction just opened.
            return nil
        }
        fired.insert(direction)
        lastFire = time
        return direction
    }

    /// The click a press without movement means.
    var releaseDirection: LogitechMXGestureDirection? { didFire ? nil : .click }
}

/// Collects thumb wheel rotation into whole steps, dropping steps that come
/// faster than the action can sensibly follow.
struct LogitechMXThumbWheelAccumulator {
    let countsPerStep: Int
    let minimumInterval: TimeInterval
    private var pending = 0
    private var lastStep: TimeInterval = -.greatestFiniteMagnitude

    init(countsPerStep: Int, minimumInterval: TimeInterval = 0) {
        self.countsPerStep = max(1, countsPerStep)
        self.minimumInterval = max(0, minimumInterval)
    }

    /// Positive steps are forward (away from the palm), negative backward.
    mutating func add(_ rotation: Int, at time: TimeInterval) -> Int {
        if pending != 0, (pending > 0) != (rotation > 0) { pending = 0 }
        pending += rotation
        let steps = pending / countsPerStep
        guard steps != 0 else { return 0 }
        pending -= steps * countsPerStep
        guard minimumInterval > 0 else { return steps }
        guard time - lastStep >= minimumInterval else { return 0 }
        lastStep = time
        return steps > 0 ? 1 : -1
    }

    mutating func reset() { pending = 0 }
}
