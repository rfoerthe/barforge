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
    private var nativeOutputKeysHeld: [Int32: NativeVolumeKeyPress] = [:]
    private var drainingNativeKeys = false
    private var nativeDrainWork: DispatchWorkItem?
    /// Monitor volume presses this tap claimed and has not yet seen released,
    /// so their key-ups are consumed too. Main thread only: the tap runs there.
    private var monitorVolumeKeysHeld: [BrightnessSupport.VolumeKeyAction: BrightnessSupport.SpeakerTarget] = [:]
    /// Monitor speaker steps bypass the system, so their volume click plays
    /// on release here. Waits for both the release and the step's adjustment,
    /// so a step that did not land plays no click.
    private var feedback: (key: Int32, step: Int, applied: Bool, released: Bool)?
    private var feedbackStep = 0
    private static let volumeFeedback = NSSound(
        contentsOfFile: "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff",
        byReference: true)

    private init() {
        SessionActivity.shared.onChange { [weak self] _ in self?.syncWithPreferences() }
    }

    func syncWithPreferences() {
        let wanted = (AppFeature.mixer.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.preciseVolumeRollerEnabled))
            || (AppFeature.brightness.isAvailable && BrightnessService.shared.wantsMonitorVolumeKeys)
        let wasDraining = drainingNativeKeys
        drainingNativeKeys = !wanted && nativeOutputKeysHeld.values.contains { $0 != .unchanged }
        if drainingNativeKeys && !wasDraining {
            renewNativeKeyDrain()
        } else if !drainingNativeKeys {
            nativeDrainWork?.cancel()
            nativeDrainWork = nil
        }
        if SessionActivitySupport.tapShouldRun(featureWanted: wanted || drainingNativeKeys,
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

    /// A keyboard can disappear without releasing its volume key. While the
    /// features are off, only repeats from a held key renew this deadline.
    private func renewNativeKeyDrain() {
        nativeDrainWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.drainingNativeKeys else { return }
            self.nativeOutputKeysHeld.removeAll()
            self.syncWithPreferences()
        }
        nativeDrainWork = work
        scheduleNativeDrainExpiry(work)
    }

    private func scheduleNativeDrainExpiry(_ work: DispatchWorkItem) {
        let repeatDelay = max(NSEvent.keyRepeatDelay, NSEvent.keyRepeatInterval)
        let quietInterval = min(10, max(2, repeatDelay + 1))
        DispatchQueue.main.asyncAfter(deadline: .now() + quietInterval, execute: work)
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
        feedback = nil
        keyOwnership = PreciseVolumeKeyOwnership()
        nativeOutputKeysHeld.removeAll()
        drainingNativeKeys = false
        nativeDrainWork?.cancel()
        nativeDrainWork = nil
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
            if drainingNativeKeys {
                // A release may have passed while the tap was disabled.
                nativeOutputKeysHeld.removeAll()
                DispatchQueue.main.async { [weak self] in self?.syncWithPreferences() }
            } else if SessionActivity.shared.isActive, AXIsProcessTrusted(), let tap {
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
        let consumed = routeVolumeKey(nsEvent, event: event)
        if drainingNativeKeys, nativeOutputKeysHeld.values.allSatisfy({ $0 == .unchanged }) {
            drainingNativeKeys = false
            DispatchQueue.main.async { [weak self] in self?.syncWithPreferences() }
        }
        return consumed ? nil : Unmanaged.passUnretained(event)
    }

    private func routeVolumeKey(_ nsEvent: NSEvent, event: CGEvent) -> Bool {
        if routeMonitorVolume(nsEvent, flags: event.flags) {
            nativeOutputKeysHeld[Int32((nsEvent.data1 >> 16) & 0xffff)] = nil
            return true
        }
        if let consumed = routeNativeOutputKey(nsEvent, event: event) { return consumed }
        guard AppFeature.mixer.isAvailable else { return false }
        guard UserDefaults.standard.bool(forKey: DefaultsKey.preciseVolumeRollerEnabled),
              let volumePress = Self.volumePress(fromData1: nsEvent.data1) else {
            return false
        }

        if keyOwnership.leavesToSystem(
            keyCode: volumePress.keyCode, isDown: volumePress.isDown, isRepeat: volumePress.isRepeat,
            option: event.flags.contains(.maskAlternate),
            commandOrControl: !event.flags.isDisjoint(with: [.maskCommand, .maskControl])) {
            return false
        }

        guard volumePress.isDown else { return true }
        guard gate.accepts(volumePress.direction, at: ProcessInfo.processInfo.systemUptime) else {
            return true
        }
        Self.postFineStep(volumePress.keyCode)
        return true
    }

    /// Keep the original HID press together. Only a fresh down can choose this
    /// route; repeats and releases from the roller return to their owner.
    private func routeNativeOutputKey(_ nsEvent: NSEvent, event: CGEvent,
                                      at time: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool? {
        let code = Int32((nsEvent.data1 >> 16) & 0xffff)
        guard let key = PreciseVolumeMediaKey(rawValue: code), key != .play else { return nil }
        let state = (nsEvent.data1 >> 8) & 0xff
        guard state == 0x0a || state == 0x0b else { return nil }
        let startsPress = state == 0x0a && nsEvent.data1 & 1 == 0
        if startsPress {
            nativeOutputKeysHeld[code] = nil
            guard AppFeature.mixer.isAvailable else { return nil }
            let precise = key.rollerDirection != nil
                && UserDefaults.standard.bool(forKey: DefaultsKey.preciseVolumeRollerEnabled)
            guard precise, AppVolumeMixer.shared.prefersNativeOutputKey(key) else { return nil }
            let addsFine = event.flags.isDisjoint(with: [.maskAlternate, .maskCommand, .maskControl])
            nativeOutputKeysHeld[code] = addsFine ? .fine : .unchanged
        }
        guard let press = nativeOutputKeysHeld[code] else { return nil }
        if state == 0x0b { nativeOutputKeysHeld[code] = nil }
        if drainingNativeKeys && state == 0x0a && !startsPress && press != .unchanged {
            renewNativeKeyDrain()
        }
        switch press {
        case .unchanged: break
        case .suppressed:
            guard state == 0x0a, !drainingNativeKeys, let direction = key.rollerDirection,
                  gate.accepts(direction, at: time) else { return true }
            // The original down was filtered. Give each accepted repeat a
            // complete fine step; its real release still belongs to this tap.
            event.flags.formUnion([.maskAlternate, .maskShift])
            guard Self.postFineStep(code, preserving: event.flags) else { return true }
        case .fine:
            if state == 0x0a, let direction = key.rollerDirection,
               !gate.accepts(direction, at: time) {
                if startsPress { nativeOutputKeysHeld[code] = .suppressed }
                return true
            }
            event.flags.formUnion([.maskAlternate, .maskShift])
        }
        if state == 0x0a, key != .mute || startsPress { noteNativeVolumeKey(key, flags: event.flags) }
        return press == .suppressed
    }

    private func noteNativeVolumeKey(_ key: PreciseVolumeMediaKey, flags: CGEventFlags) {
        guard AppFeature.mixer.isAvailable, flags.isDisjoint(with: [.maskCommand, .maskControl]),
              !flags.contains(.maskAlternate) || flags.contains(.maskShift) else { return }
        AppVolumeMixer.shared.refreshNativeKeyLevelIfUnobserved(key)
    }

    /// Routes a volume press to the monitor the sound plays through, when macOS
    /// cannot set that output's volume. Every other press keeps its path. The
    /// tap only queues the change. All device I/O happens on the DDC queue.
    private func routeMonitorVolume(_ nsEvent: NSEvent, flags: CGEventFlags) -> Bool {
        guard let press = BrightnessSupport.volumeKeyEvent(
            subtype: Int(nsEvent.subtype.rawValue), data1: nsEvent.data1) else { return false }
        let code = Int32((nsEvent.data1 >> 16) & 0xffff)
        if !press.isKeyDown {
            guard monitorVolumeKeysHeld.removeValue(forKey: press.action) != nil else { return false }
            if feedback?.key == code {
                feedback?.released = true
                playFeedbackIfReady()
            }
            return true
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
        // The monitor's speakers click like the system's own outputs: on
        // release, once the step landed, under the same feedback setting.
        feedbackStep &+= 1
        let step = feedbackStep
        feedback = PreciseVolumeKeyEvents.playsFeedback(
            setting: UserDefaults.standard.bool(forKey: "com.apple.sound.beep.feedback"),
            option: flags.contains(.maskAlternate), shift: flags.contains(.maskShift))
            ? (code, step, false, false) : nil
        DispatchQueue.main.async { [weak self] in
            self?.applyMonitorVolumeKey(action, target: target, fine: fine || precise, step: step)
        }
        return true
    }

    /// Applies a press that routeMonitorVolume claimed. Main thread only, where
    /// the mixer's monitor output and its request path live.
    private func applyMonitorVolumeKey(_ action: BrightnessSupport.VolumeKeyAction,
                                       target: BrightnessSupport.SpeakerTarget, fine: Bool, step: Int) {
        let mixer = AppVolumeMixer.shared
        guard mixer.monitorOutput?.target == target else {
            if feedback?.step == step { feedback = nil }
            return
        }
        func landed(_ result: AppVolumeMixer.OutputKeyResult) {
            let applied = result == .applied && mixer.monitorOutput?.target == target
            if applied { Self.showMonitorFeedback() }
            guard feedback?.step == step else { return }
            // Like macOS, the mute key clicks only when it unmutes.
            if applied, action != .toggleMute || mixer.monitorOutput?.muted == false {
                feedback?.applied = true
            } else {
                feedback = nil
            }
            playFeedbackIfReady()
        }
        switch action {
        case let .step(direction):
            let settings = BrightnessService.shared.monitorVolumeKeySettings
            mixer.requestOutputStep(level: {
                settings.requestedLevel(from: $0, direction: direction, fine: fine)
            }, raises: direction > 0, completion: landed)
        case .toggleMute:
            mixer.requestOutputMuteToggle(completion: landed)
        }
    }

    /// The click macOS plays after a volume change, under its "Play feedback
    /// when volume is changed" setting.
    static func playVolumeFeedback() {
        guard UserDefaults.standard.bool(forKey: "com.apple.sound.beep.feedback") else { return }
        volumeFeedback?.stop()
        volumeFeedback?.play()
    }

    private func playFeedbackIfReady() {
        guard let feedback, feedback.applied, feedback.released else { return }
        self.feedback = nil
        Self.volumeFeedback?.stop()
        Self.volumeFeedback?.play()
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

    @discardableResult
    private static func postFineStep(_ keyCode: Int32, preserving flags: CGEventFlags = []) -> Bool {
        let pair = PreciseVolumeKeyEvents.fineStep(keyCode, preserving: flags)
        guard !pair.isEmpty else { return false }
        pair.forEach { $0.post(tap: .cghidEventTap) }
        return true
    }
}
