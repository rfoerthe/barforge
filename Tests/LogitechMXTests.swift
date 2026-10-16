// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The Logitech MX extension's protocol decoders, persisted profiles and
/// event state machines. Device replies are the bytes an MX Master 4 on a
/// Bolt receiver actually returned, so a layout slip shows up here before it
/// reaches a mouse.
enum LogitechMXTests {
    static func run(_ suite: TestSuite) {
        packets(suite)
        decoders(suite)
        models(suite)
        profiles(suite)
        gestures(suite)
        thumbWheel(suite)
        catalog(suite)
        strings(suite)
    }

    private static func report(_ bytes: [UInt8]) -> [UInt8] {
        bytes + Array(repeating: 0, count: max(0, 20 - bytes.count))
    }

    private static func packets(_ suite: TestSuite) {
        let packet = HIDPP.request(deviceIndex: 2, featureIndex: 0x0D, function: 3,
                                   parameters: [0x00, 0xC3, 0x33, 0x00, 0x00])
        suite.expect(packet.count == 20 && Array(packet.prefix(9)) == [0x11, 0x02, 0x0D, 0x36, 0x00, 0xC3, 0x33, 0, 0],
                     "a request is a long report with the function and our software ID in one byte")
        suite.expect(HIDPP.request(deviceIndex: 1, featureIndex: 0, function: 0,
                                   parameters: Array(repeating: 1, count: 30)).count == 20,
                     "oversized parameters never grow a packet past the long report")

        let reply = report([0x11, 0x02, 0x0D, 0x16, 0x01, 0xA0])
        suite.expect(HIDPP.classify(reply) ==
                     .reply(deviceIndex: 2, featureIndex: 0x0D, function: 1, payload: Array(reply.dropFirst(4))),
                     "a reply carrying our software ID is ours")
        suite.expect(HIDPP.classify(report([0x11, 0x02, 0x0D, 0x1A, 0x01, 0xA0])) == .ignored,
                     "Options+ replies (software ID 0xA) on the same device are not mistaken for ours")
        suite.expect(HIDPP.classify([0x10, 0x01, 0x8F, 0x00, 0x16, 0x09, 0x00]) == .unreachable(deviceIndex: 1),
                     "the receiver's error for an empty slot answers our ping")
        suite.expect(HIDPP.classify([0x10, 0x01, 0x8F, 0x00, 0x1A, 0x09, 0x00]) == .ignored,
                     "another program's receiver error is not ours")
        suite.expect(HIDPP.classify(report([0x11, 0x02, 0xFF, 0x0D, 0x36, 0x05])) ==
                     .error(deviceIndex: 2, featureIndex: 0x0D, function: 3, code: 5),
                     "a HID++ 2.0 error names the request it answers")
        let buttons = HIDPP.classify(report([0x11, 0x02, 0x0D, 0x00, 0x00, 0xC3, 0x01, 0xA0]))
        if case let .event(index, feature, event, payload) = buttons {
            suite.expect(index == 2 && feature == 0x0D && event == 0
                         && HIDPP.pressedControls(payload) == [0x00C3, 0x01A0],
                         "a diverted-buttons event lists every held control")
        } else {
            suite.expect(false, "software ID 0 is an event")
        }
        let motion = HIDPP.classify(report([0x11, 0x02, 0x0D, 0x10, 0xFF, 0xF6, 0x00, 0x05]))
        if case let .event(_, _, event, payload) = motion, let delta = HIDPP.rawMotion(payload) {
            suite.expect(event == 1 && delta.dx == -10 && delta.dy == 5, "raw motion is two signed big-endian words")
        } else {
            suite.expect(false, "raw motion decodes")
        }
        suite.expect(HIDPP.classify([0x10, 0x02, 0x41, 0x10, 0x40, 0x42, 0xB0]) ==
                     .connection(deviceIndex: 2, linkEstablished: false)
                     && HIDPP.classify([0x10, 0x02, 0x41, 0x10, 0x00, 0x42, 0xB0]) ==
                     .connection(deviceIndex: 2, linkEstablished: true),
                     "bit 6 of a connection notice means the link dropped")
        suite.expect(HIDPP.classify([0x01, 0x02]) == .ignored && HIDPP.classify([0x02, 0, 0, 0, 0]) == .ignored,
                     "short or foreign reports are ignored")

        suite.expect(HIDPP.setControlReporting(controlID: 0x00C3, diverted: true, rawXY: true) == [0x00, 0xC3, 0x33, 0, 0],
                     "diverting with raw motion states both flags with their valid bits")
        suite.expect(HIDPP.setControlReporting(controlID: 0x0053, diverted: false, rawXY: true) == [0x00, 0x53, 0x22, 0, 0],
                     "handing a control back also clears raw motion another program left on")
        suite.expect(HIDPP.setSmartShift(mode: nil, threshold: 0xFF, torque: nil, enhanced: true) == [0, 0xFF, 0]
                     && HIDPP.setSmartShift(mode: .ratchet, threshold: nil, torque: 60, enhanced: false) == [2, 0, 0],
                     "zero leaves a SmartShift byte alone, and only 0x2111 takes a force")
        suite.expect(HIDPP.setDPI(1600) == [0, 0x06, 0x40] && HIDPP.setHaptic(enabled: true, level: 140) == [1, 100],
                     "pointer speed and haptic level encode with their limits")
    }

    private static func decoders(_ suite: TestSuite) {
        suite.expect(HIDPP.featureIndex(fromRootReply: [0x0D, 0x06]) == 0x0D
                     && HIDPP.featureIndex(fromRootReply: [0x00, 0x00]) == nil,
                     "feature index 0 means the page is absent")
        let haptic = HIDPP.controlInfo([0x01, 0xA0, 0x01, 0x09, 0x31, 0x00, 0x02, 0x03, 0x05])
        suite.expect(haptic?.controlID == 0x01A0 && haptic?.flags.contains(.divertable) == true
                     && haptic?.flags.contains(.rawXY) == true,
                     "the MX Master 4 haptic panel is divertable with raw motion")
        let left = HIDPP.controlInfo([0x00, 0x50, 0x00, 0x38, 0x01, 0x00, 0x01, 0x00, 0x04])
        suite.expect(left?.flags.contains(.divertable) == false, "the left button is never offered")
        let virtual = HIDPP.controlInfo([0x00, 0xD7, 0x00, 0xB4, 0xA0, 0x00, 0x03, 0x00, 0x03])
        suite.expect(virtual?.flags.contains(.virtual) == true && virtual?.flags.contains(.forceRawXY) == true,
                     "the additional flags byte supplies the high half")
        let reporting = HIDPP.controlReporting([0x00, 0xC3, 0x11, 0x00, 0xC3, 0x01])
        suite.expect(reporting == HIDPP.ControlReporting(controlID: 0xC3, diverted: true, rawXY: true),
                     "reporting state reads diversion and raw motion")

        suite.expect(HIDPP.smartShiftCapabilities([0x01, 0x0A, 0x4B, 0x0E]) ==
                     HIDPP.SmartShiftCapabilities(tunableTorque: true, defaultThreshold: 10, defaultTorque: 75),
                     "0x2111 capabilities report the tunable force")
        suite.expect(HIDPP.smartShiftState([0x01, 0x0C, 0x4B], enhanced: true) ==
                     HIDPP.SmartShiftState(mode: .freeSpin, threshold: 12, torque: 75)
                     && HIDPP.smartShiftState([0x02, 0x0C, 0x4B], enhanced: false)?.torque == nil,
                     "SmartShift state reads mode, threshold and, on 0x2111 only, force")
        let wheel = HIDPP.wheelCapabilities([0x0F, 0x1C, 0x18, 0x18])
        suite.expect(wheel?.multiplier == 15 && wheel?.canInvert == true && wheel?.hasRatchetSwitch == true,
                     "wheel capabilities decode")
        suite.expect(HIDPP.thumbWheelStatus([0x01, 0x00]) == HIDPP.ThumbWheelStatus(diverted: true, inverted: false),
                     "thumb wheel status decodes")
        suite.expect(HIDPP.thumbWheelRotation([0xFF, 0xF8, 0x00, 0x10, 0x02, 0x00]) == -8,
                     "thumb wheel rotation is signed")

        let range = HIDPP.dpiRange([0x00, 0x00, 0xC8, 0xE0, 0x32, 0x1F, 0x40, 0x00, 0x00])
        suite.expect(range == HIDPP.DPIRange(minimum: 200, maximum: 8000, step: 50, values: []),
                     "a step entry turns the list into 200…8000 in steps of 50")
        suite.expect(range?.sanitized(1013) == 1000 && range?.sanitized(1030) == 1050
                     && range?.sanitized(10) == 200 && range?.sanitized(99_999) == 8000,
                     "pointer speed snaps to the device's steps and limits")
        let list = HIDPP.dpiRange([0x00, 0x01, 0x90, 0x03, 0x20, 0x06, 0x40, 0x00, 0x00])
        suite.expect(list?.values == [400, 800, 1600] && list?.sanitized(1000) == 800,
                     "a plain list keeps its values and snaps to the nearest one")
        suite.expect(HIDPP.dpiRange([0x00, 0x00, 0x00]) == nil, "an empty list is no range")
        suite.expect(HIDPP.currentDPI([0x00, 0x03, 0xE8, 0x03, 0xE8]) == 1000, "current pointer speed decodes")

        suite.expect(HIDPP.hapticCapabilities([0x00, 0x01, 0x00, 0x3C, 0x00, 0x00, 0x7F, 0xFF]) ==
                     HIDPP.HapticCapabilities(fourLevelsOnly: false, waveforms: 0x7FFF),
                     "haptic capabilities read the level kind and waveform mask")
        suite.expect(HIDPP.hapticState([0x01, 0x3C]) == HIDPP.HapticState(enabled: true, level: 60),
                     "haptic state decodes")
        let force = HIDPP.forceButtonInfo([0x00, 0x01, 0x12, 0x4E, 0x18, 0x58, 0x0E, 0xA5])
        suite.expect(force == HIDPP.ForceButtonInfo(changeable: true, defaultValue: 4686, minimum: 3749, maximum: 6232),
                     "the haptic panel reports flags, default, maximum and minimum force")
        suite.expect(force?.sanitized(100) == 3749 && force?.sanitized(9000) == 6232
                     && force?.percent(3749) == 0 && force?.percent(6232) == 100 && force?.percent(4686) == 38,
                     "the pressure point stays inside the device's range and reads as a percentage")
        suite.expect(HIDPP.forceButtonCurrent([0x12, 0x4E, 0x00]) == 4686
                     && HIDPP.setForceButton(0, value: 6232) == [0x00, 0x18, 0x58],
                     "the pressure point reads and writes as button plus a big-endian word")
        suite.expect(HIDPP.forceButtonInfo([0x00, 0x01, 0x12, 0x4E, 0x00, 0x10, 0x0E, 0xA5]) == nil,
                     "a maximum below the minimum is no range")
        suite.expect(HIDPP.nameChunk(Array("MX Master 4".utf8) + [0, 0, 0, 0, 0], remaining: 11) == "MX Master 4",
                     "the name stops at its length and its padding")
        suite.expect(HIDPP.wantsReconfiguration([0x01, 0x01, 0x00]) && !HIDPP.wantsReconfiguration([0x01, 0x00]),
                     "only request 1 asks for settings again")
    }

    private static func models(_ suite: TestSuite) {
        suite.expect(LogitechMXModel.identify(name: "MX Master 4") == .mxMaster4
                     && LogitechMXModel.identify(name: "MX Master 3S") == .mxMaster3S
                     && LogitechMXModel.identify(name: "MX Master 3 Mac") == .mxMaster3
                     && LogitechMXModel.identify(name: "Wireless Mouse MX Master 3") == .mxMaster3,
                     "the device name decides the model")
        suite.expect(LogitechMXModel.identify(name: "MX Anywhere 3S") == nil
                     && LogitechMXModel.identify(name: "MX Master 2S") == nil,
                     "other Logitech mice are left alone")
        suite.expect(LogitechMXModel.identify(name: nil, modelID: 0xB034) == .mxMaster3S
                     && LogitechMXModel.identify(name: nil, modelID: 0xB042) == .mxMaster4
                     && LogitechMXModel.identify(name: nil, modelID: 0xB019) == nil,
                     "the model ID only stands in when there is no name")

        let none = LogitechMXAssignment(action: .native)
        suite.expect(LogitechMXSupport.reporting(for: none, control: .middleButton, supportsRawXY: true) == (false, false),
                     "a control left at its own job stays with the system")
        suite.expect(LogitechMXSupport.reporting(for: none, control: .hapticPanel, supportsRawXY: true) == (true, false),
                     "a control with no job of its own is diverted rather than lost")
        suite.expect(LogitechMXSupport.reporting(for: LogitechMXAssignment(action: .gestures), control: .gestureButton,
                                                 supportsRawXY: true) == (true, true)
                     && LogitechMXSupport.reporting(for: LogitechMXAssignment(action: .gestures), control: .gestureButton,
                                                    supportsRawXY: false) == (true, false),
                     "gestures ask for raw motion only where the control has it")
        suite.expect(LogitechMXSupport.reporting(for: LogitechMXAssignment(action: LogitechMXAction(.copy)),
                                                 control: .backButton, supportsRawXY: true) == (true, false),
                     "any other action diverts the control without freezing the pointer")
        suite.expect(LogitechMXSupport.reporting(for: LogitechMXAssignment(action: LogitechMXAction(.copy)),
                                                 control: .backButton, supportsRawXY: true,
                                                 accessibilityGranted: false) == (false, false)
                     && LogitechMXSupport.reporting(for: LogitechMXAssignment(action: LogitechMXAction(.modeShift)),
                                                    control: .backButton, supportsRawXY: true,
                                                    accessibilityGranted: false) == (true, false),
                     "without Accessibility a button keeps its own job unless its action needs none")
    }

    private static func profiles(_ suite: TestSuite) {
        var profile = LogitechMXProfile()
        suite.expect(profile.assignment(for: .gestureButton).action == .gestures
                     && profile.assignment(for: .gestureButton).gestures.preset == .windows
                     && profile.assignment(for: .hapticPanel).action == .radialMenu
                     && profile.assignment(for: .backButton).action == .native,
                     "defaults follow Options+: window gestures, the ring on the panel, side buttons native")
        profile.setAssignment(LogitechMXAssignment(action: LogitechMXAction(kind: .shortcut, payload: "command:8")),
                              for: .backButton)
        profile.setAssignment(LogitechMXControl.gestureButton.defaultAssignment, for: .gestureButton)
        suite.expect(profile.assignments.keys.sorted() == [0x0053], "a default is not stored as a choice")
        var custom = LogitechMXGestures(preset: .custom)
        custom.custom[.left] = LogitechMXAction(.previousTrack)
        custom.custom[.up] = .gestures
        profile.setAssignment(LogitechMXAssignment(action: .gestures, gestures: custom), for: .middleButton)
        profile.thumbWheel = .volume
        profile.smartShiftThreshold = 20
        profile.dpi = 1600
        profile.hapticLevel = 40
        profile.hapticPanelForce = 5200

        let data = LogitechMXSupport.encodeProfiles([.mxMaster4: profile])
        let decoded = LogitechMXSupport.decodeProfiles(data)[.mxMaster4]
        suite.expect(decoded == profile, "a profile survives the round trip")
        suite.expect(decoded?.assignment(for: .middleButton).gestures.action(for: .left).kind == .previousTrack
                     && decoded?.assignment(for: .middleButton).gestures.action(for: .up) == LogitechMXAction.none
                     && decoded?.assignment(for: .middleButton).gestures.action(for: .click) == LogitechMXAction.none,
                     "a custom gesture can never start another gesture")

        let hostile = """
        {"mxMaster3S":{"assignments":{"83":{"action":{"kind":"teleport"}},"86":{"action":{"kind":"copy"}},
        "999":{"action":{"kind":"copy"}}},"thumbWheel":"warp","thumbWheelSensitivity":99,
        "smartShiftThreshold":500,"scrollForce":-4,"hapticLevel":900},"mxMaster9":{}}
        """
        let parsed = LogitechMXSupport.decodeProfiles(Data(hostile.utf8))
        let s3 = parsed[.mxMaster3S]
        suite.expect(parsed.count == 1 && s3?.assignments.keys.sorted() == [0x0056],
                     "unknown models, controls and actions are dropped, the rest kept")
        suite.expect(s3?.thumbWheel == .horizontalScroll && s3?.thumbWheelSensitivity == 10
                     && s3?.smartShiftThreshold == 50 && s3?.scrollForce == 1 && s3?.hapticLevel == 100,
                     "out-of-range values come back to the nearest legal one")
        suite.expect(LogitechMXSupport.decodeProfiles(Data("nonsense".utf8)).isEmpty
                     && LogitechMXSupport.decodeProfiles(nil).isEmpty,
                     "an unreadable blob is no profile at all")

        suite.expect(LogitechMXSupport.smartShiftFirmwareThreshold(enabled: false, threshold: 20) == 0xFF
                     && LogitechMXSupport.smartShiftFirmwareThreshold(enabled: true, threshold: 0) == 1,
                     "SmartShift off is the firmware's never-switch threshold")
        let off = LogitechMXSupport.smartShiftSetting(fromFirmware: 0xFF)
        let on = LogitechMXSupport.smartShiftSetting(fromFirmware: 12)
        suite.expect(!off.enabled && on.enabled && on.threshold == 12, "the firmware threshold reads back")
        suite.expect(LogitechMXSupport.nextPointerSpeed(current: 1000, primary: 1000, alternate: 400) == 400
                     && LogitechMXSupport.nextPointerSpeed(current: 400, primary: 1000, alternate: 400) == 1000
                     && LogitechMXSupport.nextPointerSpeed(current: 3200, primary: 1000, alternate: 400) == 400,
                     "change pointer speed toggles between the two speeds")
        if let range = HIDPP.dpiRange([0x00, 0x00, 0xC8, 0xE0, 0x32, 0x1F, 0x40, 0x00]) {
            suite.expect(LogitechMXSupport.defaultAlternateDPI(primary: 1000, range: range) == 500
                         && LogitechMXSupport.defaultAlternateDPI(primary: 250, range: range) == 200,
                         "the suggested second speed is half, within the sensor's range")
        }
    }

    private static func gestures(_ suite: TestSuite) {
        suite.expect(LogitechMXSupport.gestureThreshold(dpi: 1000) == 120
                     && LogitechMXSupport.gestureThreshold(dpi: 100) == 30,
                     "the gesture distance follows the sensor resolution, with a floor")
        var tracker = LogitechMXGestureTracker(threshold: 100)
        suite.expect(tracker.releaseDirection == .click, "a press without movement is a click")
        suite.expect(tracker.add(dx: 60, dy: 10, at: 0) == nil, "short of the threshold nothing fires")
        suite.expect(tracker.add(dx: 50, dy: 0, at: 0.05) == .right, "crossing it fires the dominant direction")
        suite.expect(tracker.releaseDirection == nil, "a press that gestured is not also a click")
        suite.expect(tracker.add(dx: 150, dy: 0, at: 0.2) == nil, "a repeat comes only after a beat")
        suite.expect(tracker.add(dx: 150, dy: 0, at: 0.7) == .right, "a long move crosses one desktop per beat")
        suite.expect(tracker.add(dx: 0, dy: -150, at: 1.5) == nil,
                     "a vertical swipe after a horizontal one does not stack another overview")

        var vertical = LogitechMXGestureTracker(threshold: 100)
        suite.expect(vertical.add(dx: 10, dy: -150, at: 0) == .up, "upward motion is negative y")
        suite.expect(vertical.add(dx: 0, dy: -150, at: 2) == nil, "a vertical gesture fires once per press")
        suite.expect(vertical.add(dx: -200, dy: 0, at: 2.1) == .left, "a different horizontal direction still fires")

        suite.expect(LogitechMXGesturePreset.windows.action(for: .right).kind == .desktopRight
                     && LogitechMXGesturePreset.windows.action(for: .down).kind == .appExpose
                     && LogitechMXGesturePreset.media.action(for: .click).kind == .playPause
                     && LogitechMXGesturePreset.zoom.action(for: .up).kind == .zoomIn
                     && LogitechMXGesturePreset.pan.action(for: .click) == LogitechMXAction.none,
                     "presets carry the Options+ assignments")
    }

    private static func thumbWheel(_ suite: TestSuite) {
        suite.expect(LogitechMXSupport.thumbWheelCountsPerStep(sensitivity: 5) == 12
                     && LogitechMXSupport.thumbWheelCountsPerStep(sensitivity: 0) == 60
                     && LogitechMXSupport.thumbWheelCountsPerStep(sensitivity: 99) == 6,
                     "speed turns into counts per step, clamped to its range")
        var accumulator = LogitechMXThumbWheelAccumulator(countsPerStep: 12)
        suite.expect(accumulator.add(5, at: 0) == 0 && accumulator.add(8, at: 0.01) == 1,
                     "rotation collects into whole steps")
        suite.expect(accumulator.add(-12, at: 0.02) == -1, "turning back drops the forward remainder")
        suite.expect(accumulator.add(36, at: 0.03) == 3, "a fast turn yields several steps")
        var desktops = LogitechMXThumbWheelAccumulator(countsPerStep: 12,
                                                      minimumInterval: LogitechMXThumbWheelAction.desktops.minimumStepInterval)
        suite.expect(desktops.add(48, at: 0) == 1 && desktops.add(24, at: 0.1) == 0 && desktops.add(24, at: 0.5) == 1,
                     "desktop switching takes one step per beat")
        let shortcuts = LogitechMXThumbWheelAction.shortcuts.stepActions(
            forward: GlobalShortcut(keyCode: 30, modifiers: [.command]), backward: nil)
        suite.expect(shortcuts?.forward.kind == .shortcut && shortcuts?.backward == LogitechMXAction.none
                     && LogitechMXThumbWheelAction.horizontalScroll.stepActions(forward: nil, backward: nil) == nil
                     && !LogitechMXThumbWheelAction.horizontalScroll.divertsWheel
                     && LogitechMXThumbWheelAction.tabs.stepActions(forward: nil, backward: nil)?.forward.shortcut
                        == LogitechMXSupport.nextTab,
                     "only native horizontal scrolling leaves the thumb wheel with the system")
    }

    private static func catalog(_ suite: TestSuite) {
        let feature = AppFeature.logitechMX
        suite.expect(feature.group == .mouseKeyboard && feature.permissions == [.accessibility]
                     && feature.enabledKeys == [DefaultsKey.logitechMXEnabled] && !feature.installedByDefault,
                     "the extension is an opt-in mouse feature behind Accessibility")
        suite.expect(feature.settingsDestination == FeatureSettingsDestination(.mouse, sectionAnchor: .logitechMX)
                     && FeatureVisibilitySupport.features(for: .mouse).contains(.logitechMX),
                     "it lives on the Mouse page")
        suite.expect(feature.energyProfile == .idle, "nothing runs at rest")
        let exported = SettingsBackupSupport.exportKeys()
        suite.expect(exported.contains(DefaultsKey.logitechMXEnabled) && exported.contains(DefaultsKey.logitechMXProfiles),
                     "both preferences travel with a settings backup")
        let menuKinds = Set(LogitechMXAction.buttonMenu.flatMap { $0 })
        suite.expect(menuKinds == Set(LogitechMXAction.Kind.allCases),
                     "every action kind is reachable from the button menu")
        suite.expect(!LogitechMXAction.gestureMenu.flatMap { $0 }.contains(.gestures)
                     && !LogitechMXAction.gestureMenu.flatMap { $0 }.contains(.native),
                     "a gesture direction cannot start a gesture or fall back to a native job")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = FeatureStrings.logitechMX(language)
            let scalars = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(scalars.count > 30 && scalars.allSatisfy { !$0.isEmpty && !$0.contains("\u{2014}") },
                         "every Logitech MX label is present without an em dash (\(language.rawValue))")
            suite.expect(LogitechMXControl.allCases.allSatisfy { !(text.controls[$0] ?? "").isEmpty }
                         && LogitechMXAction.Kind.allCases.allSatisfy { !(text.actions[$0] ?? "").isEmpty }
                         && LogitechMXGesturePreset.allCases.allSatisfy { !(text.presets[$0] ?? "").isEmpty }
                         && LogitechMXGestureDirection.allCases.allSatisfy { !(text.directions[$0] ?? "").isEmpty }
                         && LogitechMXThumbWheelAction.allCases.allSatisfy { !(text.thumbActions[$0] ?? "").isEmpty },
                         "every control, action, preset, direction and wheel action is named (\(language.rawValue))")
            if language != .enUS {
                suite.expect(text.title != LogitechMXStrings.enUS.title
                             && text.caption != LogitechMXStrings.enUS.caption,
                             "the title and caption are translated (\(language.rawValue))")
            }
        }
    }
}
