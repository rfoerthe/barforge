// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import Combine

/// What Settings shows about one connected MX Master: what it can do and
/// what it is set to right now, read back from the device.
struct LogitechMXDeviceSnapshot: Identifiable, Equatable {
    let id: String
    let model: LogitechMXModel
    let name: String
    let viaReceiver: Bool
    let controls: [LogitechMXControl]
    let gestureControls: Set<LogitechMXControl>
    let hasThumbWheel: Bool
    let wheelCanInvert: Bool
    let hasSmartShift: Bool
    let tunableTorque: Bool
    let dpiRange: HIDPP.DPIRange?
    let haptics: HIDPP.HapticCapabilities?
    let panelForce: HIDPP.ForceButtonInfo?
    var wheelMode: HIDPP.WheelMode?
    var smartShiftThreshold: UInt8?
    var scrollForce: UInt8?
    var dpi: Int?
    var haptic: HIDPP.HapticState?
    var panelForceValue: Int?
    var battery: HIDPP.BatteryState?
}

/// Talks HID++ to MX Master 3, 3S and 4 mice on a receiver or Bluetooth,
/// the way Logi Options+ does: controls set to something other than their
/// own job are diverted to this app and their presses become actions, held
/// gesture buttons report raw motion instead of moving the pointer, and the
/// wheel, pointer speed and haptic settings are written to the device.
///
/// Nothing is diverted while the feature is off, and turning it off (or
/// quitting) hands every control back to the mouse. Device work happens on
/// the transport's worker thread; only snapshots cross to the main thread.
final class LogitechMXService: ObservableObject {
    static let shared = LogitechMXService()

    @Published private(set) var devices: [LogitechMXDeviceSnapshot] = []
    @Published private(set) var isRunning = false
    /// Options+ diverts the same controls; with both running, each press
    /// would do two things.
    @Published private(set) var optionsPlusRunning = false

    private static let optionsPlusBundleIDs: Set<String> = ["com.logi.cp-dev-mgr", "com.logi.optionsplus"]

    private let transport = HIDPPTransport()
    private var workspaceObservers: [NSObjectProtocol] = []

    // Worker thread only.
    private var sessions: [Session] = []
    private var workerProfiles: [LogitechMXModel: LogitechMXProfile] = [:]

    private final class Session {
        let device: HIDPPTransport.Device
        let index: UInt8
        let model: LogitechMXModel
        let name: String
        var features: [HIDPP.Feature: UInt8] = [:]
        var controls: [UInt16: HIDPP.ControlInfo] = [:]
        var smartShiftEnhanced = false
        var smartShiftCapabilities: HIDPP.SmartShiftCapabilities?
        var smartShift: HIDPP.SmartShiftState?
        var wheelCapabilities: HIDPP.WheelCapabilities?
        var dpiRange: HIDPP.DPIRange?
        var dpi: Int?
        var hapticCapabilities: HIDPP.HapticCapabilities?
        var haptic: HIDPP.HapticState?
        var panelForce: HIDPP.ForceButtonInfo?
        var panelForceValue: Int?
        var batteryReportsPercent = false
        var battery: HIDPP.BatteryState?
        var pressed: Set<UInt16> = []
        var gestures: [UInt16: LogitechMXGestureTracker] = [:]
        var heldMouseButtons: [UInt16: Int] = [:]
        var thumbWheel = LogitechMXThumbWheelAccumulator(countsPerStep: 12)

        init(device: HIDPPTransport.Device, index: UInt8, model: LogitechMXModel, name: String) {
            self.device = device
            self.index = index
            self.model = model
            self.name = name
        }

        var id: String { "\(ObjectIdentifier(device).hashValue)-\(index)" }

        func featureIndex(_ feature: HIDPP.Feature) -> UInt8? { features[feature] }
    }

    private init() {
        transport.onDeviceAdded = { [weak self] device in self?.deviceAdded(device) }
        transport.onDeviceRemoved = { [weak self] device in self?.deviceRemoved(device) }
        transport.onMessage = { [weak self] device, message in self?.handle(message, from: device) }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                guard let bundleID = app?.bundleIdentifier, Self.optionsPlusBundleIDs.contains(bundleID) else { return }
                self?.refreshOptionsPlusState()
            })
        }
        // A switched-away session must not keep the mouse's buttons diverted
        // to a process that no longer sees the screen.
        SessionActivity.shared.onChange { [weak self] active in
            guard let self else { return }
            if active {
                self.syncWithPreferences()
            } else {
                self.stopTransport()
            }
        }
    }

    // MARK: - Main thread API

    var isEnabled: Bool {
        AppFeature.logitechMX.isAvailable && UserDefaults.standard.bool(forKey: DefaultsKey.logitechMXEnabled)
    }

    func syncWithPreferences() {
        refreshOptionsPlusState()
        guard isEnabled, SessionActivity.shared.isActive else {
            stopTransport()
            return
        }
        let profiles = Self.storedProfiles()
        if !transport.isRunning {
            transport.start()
            isRunning = true
        }
        transport.perform { [weak self] in
            guard let self else { return }
            self.workerProfiles = profiles
            self.sessions.forEach(self.apply)
            self.publish()
        }
    }

    /// App quit: every control goes back to the mouse before the process ends.
    func suspend() {
        stopTransport()
    }

    func profile(for model: LogitechMXModel) -> LogitechMXProfile {
        Self.storedProfiles()[model] ?? LogitechMXProfile()
    }

    func save(_ profile: LogitechMXProfile, for model: LogitechMXModel) {
        var profiles = Self.storedProfiles()
        profiles[model] = profile
        UserDefaults.standard.set(LogitechMXSupport.encodeProfiles(profiles), forKey: DefaultsKey.logitechMXProfiles)
        guard transport.isRunning else { return }
        transport.perform { [weak self] in
            guard let self else { return }
            self.workerProfiles = profiles
            self.sessions.filter { $0.model == model }.forEach(self.apply)
            self.publish()
        }
    }

    /// Settings' try-it button for the haptic motor.
    func playHapticSample(deviceID: String) {
        transport.perform { [weak self] in
            guard let self, let session = self.sessions.first(where: { $0.id == deviceID }) else { return }
            self.playHaptic(session, force: true)
        }
    }

    private func stopTransport() {
        guard transport.isRunning else { return }
        transport.stop { [weak self] in
            guard let self else { return }
            self.sessions.forEach(self.restore)
            self.sessions.removeAll()
        }
        isRunning = false
        devices = []
    }

    private func refreshOptionsPlusState() {
        let running = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier.map(Self.optionsPlusBundleIDs.contains) ?? false
        }
        if optionsPlusRunning != running { optionsPlusRunning = running }
    }

    private static func storedProfiles() -> [LogitechMXModel: LogitechMXProfile] {
        LogitechMXSupport.decodeProfiles(UserDefaults.standard.data(forKey: DefaultsKey.logitechMXProfiles))
    }

    // MARK: - Discovery (worker)

    private func deviceAdded(_ device: HIDPPTransport.Device) {
        if device.isReceiver { enableConnectionNotifications(device) }
        for index in device.candidateIndices {
            probe(device, index: index)
        }
    }

    private func deviceRemoved(_ device: HIDPPTransport.Device) {
        sessions.removeAll { $0.device === device }
        publish()
    }

    /// A receiver only reports mice that wake up or connect later when its
    /// wireless notifications are on. The flags are read first so nothing
    /// another program switched on is turned off.
    private func enableConnectionNotifications(_ device: HIDPPTransport.Device) {
        guard let current = transport.receiverRegister(device, write: false, register: 0x00),
              current.count >= 3 else { return }
        let wanted: UInt8 = 0x01 | 0x08
        guard current[1] & wanted != wanted else { return }
        _ = transport.receiverRegister(device, write: true, register: 0x00,
                                       parameters: [current[0], current[1] | wanted, current[2]])
    }

    private func probe(_ device: HIDPPTransport.Device, index: UInt8) {
        guard case let .success(version) = transport.request(
            device, deviceIndex: index, featureIndex: 0, function: 1, parameters: [0, 0, 0x5A], timeout: 3),
            let major = version.first, major >= 2 else { return }
        var features: [HIDPP.Feature: UInt8] = [:]
        for feature in HIDPP.Feature.allCases where feature != .root {
            if case let .success(reply) = transport.request(device, deviceIndex: index, featureIndex: 0,
                                                            function: 0, parameters: HIDPP.bytes(feature.rawValue)),
               let featureIndex = HIDPP.featureIndex(fromRootReply: reply) {
                features[feature] = featureIndex
            }
        }
        let name = readName(device, index: index, featureIndex: features[.deviceName])
        guard let model = LogitechMXModel.identify(name: name, modelID: device.isReceiver ? nil : UInt16(device.productID))
        else { return }
        let session = Session(device: device, index: index, model: model, name: name ?? model.displayName)
        session.features = features
        readCapabilities(session)
        sessions.removeAll { $0.device === device && $0.index == index }
        sessions.append(session)
        apply(session)
        publish()
    }

    private func readName(_ device: HIDPPTransport.Device, index: UInt8, featureIndex: UInt8?) -> String? {
        guard let featureIndex,
              case let .success(count) = transport.request(device, deviceIndex: index,
                                                           featureIndex: featureIndex, function: 0),
              let length = count.first, length > 0 else { return nil }
        var name = ""
        var offset = 0
        while offset < Int(length) {
            guard case let .success(chunk) = transport.request(device, deviceIndex: index, featureIndex: featureIndex,
                                                               function: 1, parameters: [UInt8(offset)]) else { break }
            name += HIDPP.nameChunk(chunk, remaining: Int(length) - offset)
            offset += 16
        }
        return name.isEmpty ? nil : name
    }

    private func readCapabilities(_ session: Session) {
        if let rc = session.featureIndex(.reprogControls),
           case let .success(count) = request(session, rc, 0), let total = count.first {
            for position in 0..<total {
                if case let .success(reply) = request(session, rc, 1, [position]),
                   let info = HIDPP.controlInfo(reply) {
                    session.controls[info.controlID] = info
                }
            }
        }
        if let ss = session.featureIndex(.smartShiftEnhanced) {
            session.smartShiftEnhanced = true
            if case let .success(reply) = request(session, ss, 0) {
                session.smartShiftCapabilities = HIDPP.smartShiftCapabilities(reply)
            }
        }
        if let wheel = session.featureIndex(.hiResWheel), case let .success(reply) = request(session, wheel, 0) {
            session.wheelCapabilities = HIDPP.wheelCapabilities(reply)
        }
        if let dpi = session.featureIndex(.adjustableDPI), case let .success(reply) = request(session, dpi, 1, [0]) {
            session.dpiRange = HIDPP.dpiRange(reply)
        }
        if let haptic = session.featureIndex(.haptic), case let .success(reply) = request(session, haptic, 0) {
            session.hapticCapabilities = HIDPP.hapticCapabilities(reply)
        }
        // The MX Master 4 has one pressure-sensitive control: its haptic panel.
        if let force = session.featureIndex(.forceSensingButton),
           case let .success(count) = request(session, force, 0), (count.first ?? 0) > 0,
           case let .success(reply) = request(session, force, 1, [0]) {
            session.panelForce = HIDPP.forceButtonInfo(reply)
        }
        if let battery = session.featureIndex(.unifiedBattery), case let .success(reply) = request(session, battery, 0) {
            session.batteryReportsPercent = HIDPP.unifiedBatteryReportsPercent(reply)
        }
        readBattery(session)
        readState(session)
    }

    /// The mouse broadcasts every change afterwards; this is the first look.
    private func readBattery(_ session: Session) {
        if let battery = session.featureIndex(.unifiedBattery), case let .success(reply) = request(session, battery, 1) {
            session.battery = HIDPP.unifiedBattery(reply, reportsPercent: session.batteryReportsPercent)
        } else if let battery = session.featureIndex(.batteryStatus),
                  case let .success(reply) = request(session, battery, 0) {
            session.battery = HIDPP.batteryStatus(reply)
        }
    }

    private func readState(_ session: Session) {
        if let ss = smartShiftIndex(session),
           case let .success(reply) = request(session, ss, session.smartShiftEnhanced ? 1 : 0) {
            session.smartShift = HIDPP.smartShiftState(reply, enhanced: session.smartShiftEnhanced)
        }
        if let dpi = session.featureIndex(.adjustableDPI), case let .success(reply) = request(session, dpi, 2, [0]) {
            session.dpi = HIDPP.currentDPI(reply)
        }
        if let haptic = session.featureIndex(.haptic), case let .success(reply) = request(session, haptic, 1) {
            session.haptic = HIDPP.hapticState(reply)
        }
        if session.panelForce != nil, let force = session.featureIndex(.forceSensingButton),
           case let .success(reply) = request(session, force, 2, [0]) {
            session.panelForceValue = HIDPP.forceButtonCurrent(reply)
        }
    }

    private func smartShiftIndex(_ session: Session) -> UInt8? {
        session.featureIndex(.smartShiftEnhanced) ?? session.featureIndex(.smartShift)
    }

    @discardableResult
    private func request(_ session: Session, _ featureIndex: UInt8, _ function: UInt8,
                         _ parameters: [UInt8] = []) -> Result<[UInt8], HIDPPTransport.RequestError> {
        transport.request(session.device, deviceIndex: session.index, featureIndex: featureIndex,
                          function: function, parameters: parameters)
    }

    // MARK: - Applying a profile (worker)

    private func profile(of session: Session) -> LogitechMXProfile {
        workerProfiles[session.model] ?? LogitechMXProfile()
    }

    private func apply(_ session: Session) {
        let profile = profile(of: session)
        let trusted = AXIsProcessTrusted()
        if let rc = session.featureIndex(.reprogControls) {
            for control in LogitechMXControl.allCases {
                guard let info = session.controls[control.rawValue], info.flags.contains(.divertable) else { continue }
                let reporting = LogitechMXSupport.reporting(for: profile.assignment(for: control), control: control,
                                                            supportsRawXY: info.flags.contains(.rawXY),
                                                            accessibilityGranted: trusted)
                request(session, rc, 3, HIDPP.setControlReporting(controlID: control.rawValue,
                                                                  diverted: reporting.diverted,
                                                                  rawXY: reporting.rawXY))
            }
        }
        session.pressed = []
        session.gestures = [:]
        releaseHeldButtons(session)
        if let thumb = session.featureIndex(.thumbWheel) {
            let diverted = profile.thumbWheel.divertsWheel
            request(session, thumb, 2, HIDPP.setThumbWheel(diverted: diverted,
                                                           inverted: !diverted && profile.thumbWheelInverted))
            session.thumbWheel = LogitechMXThumbWheelAccumulator(
                countsPerStep: LogitechMXSupport.thumbWheelCountsPerStep(sensitivity: profile.thumbWheelSensitivity),
                minimumInterval: profile.thumbWheel.minimumStepInterval)
        }
        if let wheel = session.featureIndex(.hiResWheel) {
            // Standard resolution, reported to the system: Vorssaint's own
            // smooth and linear scrolling then treat it like any mouse wheel.
            var mode: HIDPP.WheelReportingMode = []
            if profile.wheelInverted, session.wheelCapabilities?.canInvert == true { mode.insert(.inverted) }
            request(session, wheel, 2, [mode.rawValue])
        }
        if let ss = smartShiftIndex(session),
           profile.smartShiftEnabled != nil || profile.smartShiftThreshold != nil || profile.scrollForce != nil {
            let current = LogitechMXSupport.smartShiftSetting(fromFirmware: session.smartShift?.threshold ?? 0)
            let threshold = LogitechMXSupport.smartShiftFirmwareThreshold(
                enabled: profile.smartShiftEnabled ?? current.enabled,
                threshold: profile.smartShiftThreshold ?? current.threshold)
            let torque = session.smartShiftCapabilities?.tunableTorque == true
                ? profile.scrollForce.map { UInt8(LogitechMXSupport.sanitizedScrollForce($0)) } : nil
            // The MX Master 4 only takes a new force together with its mode.
            request(session, ss, session.smartShiftEnhanced ? 2 : 1,
                    HIDPP.setSmartShift(mode: session.smartShift?.mode, threshold: threshold, torque: torque,
                                        enhanced: session.smartShiftEnhanced))
        }
        if let dpiIndex = session.featureIndex(.adjustableDPI), let range = session.dpiRange, let dpi = profile.dpi {
            request(session, dpiIndex, 3, HIDPP.setDPI(range.sanitized(dpi)))
        }
        if let haptic = session.featureIndex(.haptic), profile.hapticEnabled != nil || profile.hapticLevel != nil {
            let enabled = profile.hapticEnabled ?? session.haptic?.enabled ?? true
            let level = profile.hapticLevel ?? session.haptic?.level ?? 50
            request(session, haptic, 2, HIDPP.setHaptic(enabled: enabled, level: enabled ? level : max(level, 1)))
        }
        if let force = session.featureIndex(.forceSensingButton), let info = session.panelForce, info.changeable,
           let value = profile.hapticPanelForce {
            request(session, force, 3, HIDPP.setForceButton(0, value: info.sanitized(value)))
        }
        readState(session)
    }

    /// Hands every control back to the mouse: nothing diverted, both wheels
    /// reporting to the system as they do without any software.
    private func restore(_ session: Session) {
        releaseHeldButtons(session)
        if let rc = session.featureIndex(.reprogControls) {
            for control in LogitechMXControl.allCases {
                guard let info = session.controls[control.rawValue], info.flags.contains(.divertable) else { continue }
                request(session, rc, 3, HIDPP.setControlReporting(controlID: control.rawValue, diverted: false,
                                                                  rawXY: false))
            }
        }
        if let thumb = session.featureIndex(.thumbWheel) {
            request(session, thumb, 2, HIDPP.setThumbWheel(diverted: false, inverted: false))
        }
        if let wheel = session.featureIndex(.hiResWheel) {
            request(session, wheel, 2, [0])
        }
    }

    private func releaseHeldButtons(_ session: Session) {
        for button in session.heldMouseButtons.values {
            LogitechMXActionRunner.postMouseButton(button, down: false)
        }
        session.heldMouseButtons = [:]
    }

    // MARK: - Events (worker)

    private func handle(_ message: HIDPP.Message, from device: HIDPPTransport.Device) {
        switch message {
        case let .connection(index, linkEstablished):
            if linkEstablished {
                // The mouse needs a moment after linking before it answers.
                transport.perform(after: 0.5) { [weak self] in
                    guard !device.isRemoved else { return }
                    self?.probe(device, index: index)
                }
            } else {
                sessions.removeAll { $0.device === device && $0.index == index }
                publish()
            }
        case let .event(index, featureIndex, event, payload):
            guard let session = sessions.first(where: { $0.device === device && $0.index == index }) else { return }
            handleEvent(session, featureIndex: featureIndex, event: event, payload: payload)
        default:
            break
        }
    }

    private func handleEvent(_ session: Session, featureIndex: UInt8, event: UInt8, payload: [UInt8]) {
        let now = ProcessInfo.processInfo.systemUptime
        switch featureIndex {
        case session.featureIndex(.reprogControls):
            if event == 0 {
                buttonsChanged(session, pressed: HIDPP.pressedControls(payload))
            } else if event == 1, let motion = HIDPP.rawMotion(payload) {
                rawMotion(session, dx: motion.dx, dy: motion.dy, at: now)
            }
        case session.featureIndex(.thumbWheel):
            if event == 0, let rotation = HIDPP.thumbWheelRotation(payload) {
                thumbWheelTurned(session, rotation: rotation, at: now)
            }
        case session.featureIndex(.unifiedBattery):
            if event == 0, let state = HIDPP.unifiedBattery(payload, reportsPercent: session.batteryReportsPercent) {
                session.battery = state
                publish()
            }
        case session.featureIndex(.batteryStatus):
            if event == 0, let state = HIDPP.batteryStatus(payload) {
                session.battery = state
                publish()
            }
        case session.featureIndex(.hiResWheel):
            if event == 1, let state = payload.first {
                session.smartShift?.mode = state == 1 ? .ratchet : .freeSpin
                publish()
            }
        case session.featureIndex(.wirelessDeviceStatus):
            if event == 0, HIDPP.wantsReconfiguration(payload) {
                // A mouse back from sleep or another host forgot everything.
                transport.perform(after: 0.3) { [weak self] in
                    guard let self, !session.device.isRemoved,
                          self.sessions.contains(where: { $0 === session }) else { return }
                    self.apply(session)
                    self.readBattery(session)
                    self.publish()
                }
            }
        default:
            break
        }
    }

    private func buttonsChanged(_ session: Session, pressed: Set<UInt16>) {
        let released = session.pressed.subtracting(pressed)
        let newlyPressed = pressed.subtracting(session.pressed)
        session.pressed = pressed
        for cid in released { buttonUp(session, cid: cid) }
        for cid in newlyPressed { buttonDown(session, cid: cid) }
    }

    private func buttonDown(_ session: Session, cid: UInt16) {
        guard let control = LogitechMXControl(rawValue: cid) else { return }
        let assignment = profile(of: session).assignment(for: control)
        switch assignment.action.kind {
        case .gestures:
            session.gestures[cid] = LogitechMXGestureTracker(
                threshold: LogitechMXSupport.gestureThreshold(dpi: session.dpi ?? 1000))
        case .middleClick, .back, .forward:
            let button = assignment.action.kind == .middleClick ? 2 : (assignment.action.kind == .back ? 3 : 4)
            session.heldMouseButtons[cid] = button
            LogitechMXActionRunner.postMouseButton(button, down: true)
        default:
            fire(session, assignment.action)
        }
    }

    private func buttonUp(_ session: Session, cid: UInt16) {
        if let button = session.heldMouseButtons.removeValue(forKey: cid) {
            LogitechMXActionRunner.postMouseButton(button, down: false)
        }
        guard let tracker = session.gestures.removeValue(forKey: cid),
              let control = LogitechMXControl(rawValue: cid),
              let direction = tracker.releaseDirection else { return }
        let gestures = profile(of: session).assignment(for: control).gestures
        fire(session, gestures.action(for: direction))
    }

    private func rawMotion(_ session: Session, dx: Int, dy: Int, at time: TimeInterval) {
        let profile = profile(of: session)
        for (cid, var tracker) in session.gestures {
            guard let control = LogitechMXControl(rawValue: cid) else { continue }
            let gestures = profile.assignment(for: control).gestures
            if gestures.preset == .pan {
                LogitechMXActionRunner.postPan(dx: dx, dy: dy)
                // Panning is the gesture; no click on release afterwards.
                _ = tracker.add(dx: dx, dy: dy, at: time)
                session.gestures[cid] = tracker
                continue
            }
            let direction = tracker.add(dx: dx, dy: dy, at: time)
            session.gestures[cid] = tracker
            if let direction {
                fire(session, gestures.action(for: direction))
                if profile.hapticOnGestures { playHaptic(session, force: false) }
            }
        }
    }

    private func thumbWheelTurned(_ session: Session, rotation: Int, at time: TimeInterval) {
        let profile = profile(of: session)
        let shortcuts = profile.thumbWheelShortcuts
        guard let actions = profile.thumbWheel.stepActions(forward: shortcuts.forward,
                                                           backward: shortcuts.backward) else { return }
        let steps = session.thumbWheel.add(profile.thumbWheelInverted ? -rotation : rotation, at: time)
        guard steps != 0 else { return }
        for _ in 0..<min(abs(steps), 6) {
            fire(session, steps > 0 ? actions.forward : actions.backward)
        }
    }

    /// Device actions stay on the worker, which owns the device; everything
    /// else is carried out on the main thread.
    private func fire(_ session: Session, _ action: LogitechMXAction) {
        switch action.kind {
        case .native, .none, .gestures:
            return
        case .modeShift:
            toggleWheelMode(session)
        case .cyclePointerSpeed:
            cyclePointerSpeed(session)
        default:
            DispatchQueue.main.async { LogitechMXActionRunner.perform(action) }
        }
    }

    private func toggleWheelMode(_ session: Session) {
        guard let ss = smartShiftIndex(session) else { return }
        if case let .success(reply) = request(session, ss, session.smartShiftEnhanced ? 1 : 0) {
            session.smartShift = HIDPP.smartShiftState(reply, enhanced: session.smartShiftEnhanced)
        }
        let next: HIDPP.WheelMode = session.smartShift?.mode == .ratchet ? .freeSpin : .ratchet
        request(session, ss, session.smartShiftEnhanced ? 2 : 1,
                HIDPP.setSmartShift(mode: next, threshold: nil, torque: nil, enhanced: session.smartShiftEnhanced))
        session.smartShift?.mode = next
        publish()
    }

    private func cyclePointerSpeed(_ session: Session) {
        guard let dpiIndex = session.featureIndex(.adjustableDPI), let range = session.dpiRange else { return }
        let profile = profile(of: session)
        let primary = range.sanitized(profile.dpi ?? session.dpi ?? 1000)
        let alternate = range.sanitized(profile.alternateDPI
            ?? LogitechMXSupport.defaultAlternateDPI(primary: primary, range: range))
        let next = LogitechMXSupport.nextPointerSpeed(current: session.dpi ?? primary,
                                                      primary: primary, alternate: alternate)
        if case .success = request(session, dpiIndex, 3, HIDPP.setDPI(next)) {
            session.dpi = next
            playHaptic(session, force: false)
            publish()
        }
    }

    private func playHaptic(_ session: Session, force: Bool) {
        guard let haptic = session.featureIndex(.haptic), session.hapticCapabilities != nil,
              force || session.haptic?.enabled == true else { return }
        request(session, haptic, 4, [HIDPP.gestureWaveform])
    }

    // MARK: - Publishing

    private func publish() {
        let snapshots = sessions.map { session -> LogitechMXDeviceSnapshot in
            let controls = LogitechMXControl.allCases.filter {
                session.controls[$0.rawValue]?.flags.contains(.divertable) == true
            }
            return LogitechMXDeviceSnapshot(
                id: session.id, model: session.model, name: session.name,
                viaReceiver: session.device.isReceiver, controls: controls,
                gestureControls: Set(controls.filter { session.controls[$0.rawValue]?.flags.contains(.rawXY) == true }),
                hasThumbWheel: session.featureIndex(.thumbWheel) != nil,
                wheelCanInvert: session.wheelCapabilities?.canInvert == true,
                hasSmartShift: smartShiftIndex(session) != nil,
                tunableTorque: session.smartShiftCapabilities?.tunableTorque == true,
                dpiRange: session.dpiRange, haptics: session.hapticCapabilities,
                panelForce: session.panelForce?.changeable == true ? session.panelForce : nil,
                wheelMode: session.smartShift?.mode, smartShiftThreshold: session.smartShift?.threshold,
                scrollForce: session.smartShift?.torque, dpi: session.dpi, haptic: session.haptic,
                panelForceValue: session.panelForceValue, battery: session.battery)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRunning else { return }
            if self.devices != snapshots { self.devices = snapshots }
        }
    }
}
