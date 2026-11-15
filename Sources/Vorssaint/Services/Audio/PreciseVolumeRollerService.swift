// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import AppKit
import Combine

/// Turns coarse hardware volume wheel bursts into macOS' fine volume step.
/// Active only while enabled and Accessibility is granted.
final class PreciseVolumeRollerService: ObservableObject {
    static let shared = PreciseVolumeRollerService()

    @Published private(set) var tapFailed = false

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var gate = PreciseVolumeRollerGate()
    private var keyOwnership = PreciseVolumeKeyOwnership()
    /// Monitor volume presses this tap claimed and has not yet seen released,
    /// so their key-ups are consumed too. Main thread only: the tap runs there.
    private var monitorVolumeKeysHeld: [BrightnessSupport.VolumeKeyAction: BrightnessSupport.SpeakerTarget] = [:]

    private init() {
        SessionActivity.shared.onChange { [weak self] _ in self?.syncWithPreferences() }
    }

    func syncWithPreferences() {
        let wanted = (AppFeature.mixer.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.preciseVolumeRollerEnabled))
            || BrightnessService.shared.wantsMonitorVolumeKeys
        if SessionActivitySupport.tapShouldRun(featureWanted: wanted,
                                               accessibilityGranted: AXIsProcessTrusted(),
                                               sessionIsActive: SessionActivity.shared.isActive) {
            start()
        } else {
            stop()
        }
    }

    func suspend() {
        stop()
    }

    func stop() {
        removeTap()
        tapFailed = false
    }

    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil
        source = nil
        gate.reset()
        keyOwnership = PreciseVolumeKeyOwnership()
        monitorVolumeKeysHeld = [:]
    }

    private func start() {
        guard AXIsProcessTrusted() else {
            removeTap()
            tapFailed = false
            return
        }
        if let tap, !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        guard tap == nil else { return }

        let systemDefined = CGEventType(rawValue: CleaningSystemKeyEvent.systemDefinedEventTypeRawValue)!
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let service = Unmanaged<PreciseVolumeRollerService>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            return service.handle(type: type, event: event)
        }
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << systemDefined.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            tapFailed = true
            return
        }

        tap = created
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: created, enable: true)
        tapFailed = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if SessionActivity.shared.isActive, AXIsProcessTrusted(), let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            } else {
                DispatchQueue.main.async { [weak self] in self?.syncWithPreferences() }
            }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == CleaningSystemKeyEvent.systemDefinedEventTypeRawValue,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }
        if PreciseVolumeKeyEvents.isPosted(event) {
            return Unmanaged.passUnretained(event)
        }
        if routeMonitorVolume(nsEvent, flags: event.flags) { return nil }
        guard AppFeature.mixer.isAvailable else { return Unmanaged.passUnretained(event) }
        guard UserDefaults.standard.bool(forKey: DefaultsKey.preciseVolumeRollerEnabled),
              let volumePress = Self.volumePress(fromData1: nsEvent.data1) else {
            return Unmanaged.passUnretained(event)
        }

        if keyOwnership.leavesToSystem(
            keyCode: volumePress.keyCode, isDown: volumePress.isDown, isRepeat: volumePress.isRepeat,
            option: event.flags.contains(.maskAlternate),
            commandOrControl: !event.flags.isDisjoint(with: [.maskCommand, .maskControl])) {
            return Unmanaged.passUnretained(event)
        }

        guard volumePress.isDown else { return nil }
        guard gate.accepts(volumePress.direction, at: ProcessInfo.processInfo.systemUptime) else {
            return nil
        }
        Self.postFineStep(volumePress.keyCode)
        return nil
    }

    /// Routes a volume press to the monitor the sound plays through, when macOS
    /// cannot set that output's volume. Every other press keeps its path. The
    /// tap only queues the change. All device I/O happens on the DDC queue.
    private func routeMonitorVolume(_ nsEvent: NSEvent, flags: CGEventFlags) -> Bool {
        guard let press = BrightnessSupport.volumeKeyEvent(
            subtype: Int(nsEvent.subtype.rawValue), data1: nsEvent.data1) else { return false }
        if !press.isKeyDown {
            return monitorVolumeKeysHeld.removeValue(forKey: press.action) != nil
        }
        let held = monitorVolumeKeysHeld[press.action]
        if !press.isRepeat { monitorVolumeKeysHeld[press.action] = nil }
        if press.isRepeat && held == nil { return false }
        guard let fine = BrightnessSupport.volumeKeyFineness(
            option: flags.contains(.maskAlternate), shift: flags.contains(.maskShift),
            commandOrControl: !flags.isDisjoint(with: [.maskCommand, .maskControl])),
              BrightnessService.shared.wantsMonitorVolumeKeys,
              let output = AppVolumeMixer.shared.monitorOutput,
              press.action != .toggleMute || output.muted != nil else {
            if !press.isRepeat {
                DispatchQueue.main.async { BrightnessService.shared.rescanForUnclaimedVolumeKey() }
            }
            return press.isRepeat && held != nil
        }
        if press.isRepeat, held != output.target || press.action == .toggleMute { return true }
        monitorVolumeKeysHeld[press.action] = output.target
        let action = press.action
        // The precise volume setting applies to the monitor as it does to any
        // other output: wheel bursts are thinned by the same gate and each
        // accepted click takes the fine step.
        let precise = AppFeature.mixer.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.preciseVolumeRollerEnabled)
        if precise, case let .step(direction) = action,
           !gate.accepts(direction > 0 ? .up : .down, at: ProcessInfo.processInfo.systemUptime) {
            return true
        }
        let target = output.target
        DispatchQueue.main.async {
            Self.applyMonitorVolumeKey(action, target: target, fine: fine || precise)
        }
        return true
    }

    /// Applies a press that routeMonitorVolume claimed. Main thread only, where
    /// the mixer's monitor output and its request path live.
    private static func applyMonitorVolumeKey(_ action: BrightnessSupport.VolumeKeyAction,
                                              target: BrightnessSupport.SpeakerTarget, fine: Bool) {
        let mixer = AppVolumeMixer.shared
        guard mixer.monitorOutput?.target == target else { return }
        func feedback(_ result: AppVolumeMixer.OutputKeyResult) {
            guard result == .applied, mixer.monitorOutput?.target == target else { return }
            Self.showMonitorFeedback()
        }
        switch action {
        case let .step(direction):
            let settings = BrightnessService.shared.monitorVolumeKeySettings
            mixer.requestOutputStep(level: {
                settings.requestedLevel(from: $0, direction: direction, fine: fine)
            }, raises: direction > 0, completion: feedback)
        case .toggleMute:
            mixer.requestOutputMuteToggle(completion: feedback)
        }
    }

    /// Shows the monitor's level after a key moved it in the brightness overlay.
    private static func showMonitorFeedback() {
        guard let output = AppVolumeMixer.shared.monitorOutput else { return }
        BrightnessOSD.show(displayID: output.target.displayID, level: output.volume,
                           kind: output.muted == true ? .mutedVolume : .volume)
    }

    private static func volumePress(fromData1 data1: Int) -> (keyCode: Int32,
                                                             direction: PreciseVolumeRollerDirection,
                                                             isDown: Bool,
                                                             isRepeat: Bool)? {
        let keyCode = Int32((data1 >> 16) & 0xffff)
        guard let mediaKey = PreciseVolumeMediaKey(rawValue: keyCode),
              let direction = mediaKey.rollerDirection else { return nil }
        let state = (data1 >> 8) & 0xff
        return (keyCode, direction, state == 0x0a, data1 & 1 != 0)
    }

    private static func postFineStep(_ keyCode: Int32) {
        PreciseVolumeKeyEvents.fineStep(keyCode).forEach { $0.post(tap: .cghidEventTap) }
    }
}
