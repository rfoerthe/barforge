// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import CoreGraphics

/// Carries out what a Logitech MX control is set to, the way the matching
/// key or click would: system commands go through the shortcut the system
/// has registered for them, media and brightness through the aux keys the
/// keyboard sends, editing through the usual command combinations. The two
/// device actions (mode shift, pointer speed) belong to the service, which
/// owns the device.
enum LogitechMXActionRunner {
    /// Marks clicks and scrolls this runner posts, so Vorssaint's own mouse
    /// taps can tell them from a real button.
    static let syntheticTag: Int64 = 0x4C4F4749

    private static var promptedForAccessibility = false

    /// Main thread. Device actions and "native" are filtered out before this.
    static func perform(_ action: LogitechMXAction) {
        switch action.kind {
        case .native, .none, .gestures, .modeShift, .cyclePointerSpeed:
            return
        case .launchpad:
            openLaunchpad()
            return
        case .openApp:
            let url = URL(fileURLWithPath: (action.payload as NSString).expandingTildeInPath)
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if error != nil { DispatchQueue.main.async { NSSound.beep() } }
            }
            return
        case .radialMenu:
            RadialMenuService.shared.toggleFromLogitechControl()
            return
        case .tool:
            if let tool = action.tool, tool.isRunnable() {
                RadialMenuService.shared.run(tool)
            } else {
                NSSound.beep()
            }
            return
        default:
            break
        }
        guard ensureAccessibility() else { return }
        switch action.kind {
        case .middleClick: click(button: 2)
        case .back: click(button: 3)
        case .forward: click(button: 4)
        case .missionControl: pressSystem(SpaceWindowBridge.overviewShortcut(.missionControl))
        case .appExpose: pressSystem(SpaceWindowBridge.overviewShortcut(.appExpose))
        case .desktopLeft: pressSystem(SpaceWindowBridge.spaceShortcut(.left))
        case .desktopRight: pressSystem(SpaceWindowBridge.spaceShortcut(.right))
        case .showDesktop: pressSymbolicHotKey(36)
        case .spotlight: pressSymbolicHotKey(64)
        case .playPause: postAuxKey(16)
        case .nextTrack: postAuxKey(17)
        case .previousTrack: postAuxKey(18)
        case .volumeUp: postAuxKey(0)
        case .volumeDown: postAuxKey(1)
        case .mute: postAuxKey(7)
        case .brightnessUp: postAuxKey(2)
        case .brightnessDown: postAuxKey(3)
        case .copy: press(8, [.command])
        case .cut: press(7, [.command])
        case .paste: press(9, [.command])
        case .undo: press(6, [.command])
        case .redo: press(6, [.command, .shift])
        case .newTab: press(17, [.command])
        case .closeTab: press(13, [.command])
        case .zoomIn: press(24, [.command])
        case .zoomOut: press(27, [.command])
        case .zoomReset: press(29, [.command])
        case .emoji: press(49, [.control, .command])
        case .lockScreen: press(12, [.control, .command])
        case .shortcut:
            if let shortcut = action.shortcut { post(shortcut) } else { NSSound.beep() }
        default:
            break
        }
    }

    // MARK: - Mouse

    /// Posts one half of a click on the extra button `button` (2 middle,
    /// 3 back, 4 forward) at the pointer. Any thread.
    static func postMouseButton(_ button: Int, down: Bool) {
        guard AXIsProcessTrusted() else { return }
        let location = CGEvent(source: nil)?.location ?? .zero
        guard let event = CGEvent(mouseEventSource: nil,
                                  mouseType: down ? .otherMouseDown : .otherMouseUp,
                                  mouseCursorPosition: location,
                                  mouseButton: CGMouseButton(rawValue: UInt32(button)) ?? .center) else { return }
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
        event.post(tap: .cghidEventTap)
    }

    private static func click(button: Int) {
        postMouseButton(button, down: true)
        postMouseButton(button, down: false)
    }

    /// Pan: the content follows the hand, in pixels. Any thread.
    static func postPan(dx: Int, dy: Int) {
        guard AXIsProcessTrusted(), dx != 0 || dy != 0,
              let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                  wheel1: Int32(clamping: dy * 2), wheel2: Int32(clamping: dx * 2),
                                  wheel3: 0) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: syntheticTag)
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Keys

    private static func press(_ keyCode: Int64, _ modifiers: GlobalShortcutModifiers) {
        post(GlobalShortcut(keyCode: keyCode, modifiers: modifiers))
    }

    /// The combination the system registered for that command, honoring the
    /// user's remaps; nothing happens when it is switched off.
    private static func pressSystem(_ shortcut: SpaceWindowBridge.SpaceShortcut?) {
        guard let shortcut else { NSSound.beep(); return }
        SpaceWindowBridge.pressSpaceShortcut(shortcut)
    }

    private static func pressSymbolicHotKey(_ id: Int32) {
        guard let entry = SymbolicHotKeys.entries(for: [id])?.first, entry.enabled else {
            NSSound.beep()
            return
        }
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(entry.shortcut.keyCode),
                                 keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(entry.shortcut.keyCode),
                               keyDown: false) else { return }
        var flags = entry.shortcut.modifiers.cgFlags
        if entry.requiresFunctionKey { flags.insert(.maskSecondaryFn) }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Entered where the keyboard's own presses enter, with the flags a real
    /// press carries, so system and app shortcuts both react (issue #401).
    private static func post(_ shortcut: GlobalShortcut) {
        guard shortcut.hasUsableKeyCode else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(shortcut.keyCode), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(shortcut.keyCode), keyDown: false)
        else { return }
        down.flags = shortcut.syntheticEventFlags
        up.flags = shortcut.syntheticEventFlags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// The aux-button pair the physical media and brightness keys produce.
    private static func postAuxKey(_ type: Int32) {
        for down in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
            let data1 = (Int(type) << 16) | ((down ? 0xA : 0xB) << 8)
            NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags,
                               timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0,
                               context: nil, subtype: 8, data1: data1, data2: -1)?
                .cgEvent?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Apps

    /// Launchpad, or the Apps view that replaced it on newer macOS.
    private static func openLaunchpad() {
        let candidates = ["/System/Applications/Launchpad.app", "/System/Applications/Apps.app"]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path),
                                           configuration: NSWorkspace.OpenConfiguration())
    }

    private static func ensureAccessibility() -> Bool {
        guard AXIsProcessTrusted() else {
            if promptedForAccessibility {
                NSSound.beep()
            } else {
                promptedForAccessibility = true
                Permissions.shared.requestAccessibility()
            }
            return false
        }
        return true
    }
}
