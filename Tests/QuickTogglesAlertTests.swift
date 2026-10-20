// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import AppKit

/// The production confirmation and alert helper run with an inert Trash action.
/// The modal double reproduces AppKit's level resets without showing a window.
enum QuickTogglesAlertTests {
    enum Action { case emptyTrash }
    enum RunState { case running }
    class Fixture {
        var available = true
        var states: [Action: RunState] = [:]
        var confirmations = 0
        func emptyTrashConfirmed() { confirmations += 1 }
    }
    enum FeatureStrings {
        struct Strings {
            let emptyTrashConfirmTitle = "Empty the Trash?"
            let emptyTrashConfirmMessage = "This cannot be undone."
            let emptyTrashConfirmButton = "Empty the Trash"
        }
        static func quickToggles(_ language: Int) -> Strings { Strings() }
    }
    enum L10n {
        struct Strings { let uninstallerCancel = "Cancel" }
        struct Localized {
            let language = 0
            let s = Strings()
        }
        static let shared = Localized()
    }
    struct Application {
        var activations = 0
        mutating func activate(ignoringOtherApps: Bool) { activations += 1 }
    }
    static var NSApp = Application()
    final class Alert: AppKit.NSAlert {
        static var latest: Alert?
        static var response = NSApplication.ModalResponse.alertSecondButtonReturn
        var modalLevels: [NSWindow.Level] = []
        override func runModal() -> NSApplication.ModalResponse {
            Self.latest = self
            layout()
            for name in [NSWindow.didBecomeKeyNotification, NSApplication.didBecomeActiveNotification] {
                window.level = .modalPanel
                NotificationCenter.default.post(name: name, object: window)
                modalLevels.append(window.level)
            }
            return Self.response
        }
    }
    typealias NSAlert = Alert

    static func run(_ suite: TestSuite) {
        _ = NSApplication.shared
        let policy = AppKit.NSApp.activationPolicy()
        AppKit.NSApp.setActivationPolicy(.prohibited)
        defer {
            Alert.latest = nil
            NSApp = Application()
            AppKit.NSApp.setActivationPolicy(policy)
        }
        for response in [NSApplication.ModalResponse.alertFirstButtonReturn, .alertSecondButtonReturn, .abort] {
            NSApp = Application()
            Alert.latest = nil
            Alert.response = response
            let host = Host()
            host.emptyTrash()
            guard let alert = Alert.latest else {
                suite.expect(false, "the Trash action presents its confirmation")
                continue
            }
            defer { alert.window.close() }
            suite.expect(alert.modalLevels.count == 2 && alert.modalLevels.allSatisfy { $0 == .modalPanel },
                   "the Trash confirmation keeps the native modal level")
            suite.expect(NSApp.activations == 1, "the app comes forward once so the confirmation is in front")
            suite.expect(host.confirmations == (response == .alertFirstButtonReturn ? 1 : 0),
                   "only the primary confirmation allows emptying, never Cancel or an aborted dialog")
            suite.expect(alert.buttons.map(\.keyEquivalent) == ["\r", "\u{1b}"],
                   "Return confirms the alert and Escape cancels it")
            drainMainQueue()
        }
        for unavailable in [true, false] {
            Alert.latest = nil
            let host = Host()
            host.available = !unavailable
            if !unavailable { host.states[.emptyTrash] = .running }
            host.emptyTrash()
            suite.expect(Alert.latest == nil && host.confirmations == 0,
                   "an unavailable or already-running Trash action opens no confirmation and does no work")
        }
    }

    private static func drainMainQueue() {
        var drained = false
        DispatchQueue.main.async { drained = true }
        let deadline = Date(timeIntervalSinceNow: 2)
        while !drained && Date() < deadline {
            _ = RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
    }
}
