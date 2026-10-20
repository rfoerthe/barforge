// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Production hover handlers and dismissal scheduling run with a controlled
/// clock. Pointer crossings are supplied explicitly; no native UI is exercised.
enum ScreenshotPreviewHoverTests {
    typealias DispatchQueue = ManualScheduler.DispatchQueue

    enum Action: Hashable { case edit, copy, save }

    final class Model {
        var disabledActions: Set<Action> = []
        var sharing = false
        var deletingShare = false
    }

    class State {
        var pointerInside = false
        var systemSharing = false
        var dismissWork: DispatchWorkItem?
        var autoDismissDuration: TimeInterval? = 12
        var closed = false
        let model = Model()
        var action: (Action) -> Set<Action> = { [$0] }
        func close() { closed = true }
    }

    static func run(_ suite: TestSuite) {
        defer { DispatchQueue.main = ManualScheduler.Scheduler() }
        DispatchQueue.main = ManualScheduler.Scheduler()
        let editorPreview = Controller()
        var editorOpened = false
        editorPreview.action = { action in
            suite.expect(editorPreview.closed, "Edit releases preview focus before opening the editor")
            editorOpened = true
            return [action]
        }
        editorPreview.perform(.edit)
        suite.expect(editorPreview.closed && !editorOpened,
                     "Edit dismisses immediately and defers window creation beyond the button update")
        editorPreview.perform(.edit)
        DispatchQueue.main.advance(0)
        suite.expect(editorOpened && DispatchQueue.main.pending == 0,
                     "Edit opens exactly once on the next main-queue turn")
        let failedCopy = Controller()
        failedCopy.action = { _ in [] }
        failedCopy.perform(.copy)
        suite.expect(!failedCopy.closed, "failed Copy still leaves the preview available for retry")
        DispatchQueue.main = ManualScheduler.Scheduler()

        for duration in [3.0, 12.0] {
            DispatchQueue.main = ManualScheduler.Scheduler()
            let controller = Controller()
            controller.autoDismissDuration = duration
            controller.scheduleAutoDismiss()
            controller.hoverChanged(true)
            DispatchQueue.main.advance(duration)
            suite.expect(controller.pointerInside && !controller.closed,
                         "the preview cancels dismissal while hovered")
            controller.hoverChanged(false)
            DispatchQueue.main.advance(duration - 0.5)
            suite.expect(!controller.closed, "leaving the preview keeps the configured dismissal delay")
            controller.hoverChanged(true) // Return before the deadline.
            DispatchQueue.main.advance(duration)
            suite.expect(!controller.closed, "returning to the preview cancels an outstanding dismissal")
            controller.hoverChanged(false)
            DispatchQueue.main.advance(duration)
            suite.expect(controller.closed, "leaving the preview still dismisses an unused capture")

            // The system share sheet opens outside the preview, so the pointer
            // leaves it while a target is being picked.
            DispatchQueue.main = ManualScheduler.Scheduler()
            let sharingController = Controller()
            sharingController.autoDismissDuration = duration
            sharingController.systemSharing = true
            sharingController.hoverChanged(true)
            sharingController.hoverChanged(false)
            DispatchQueue.main.advance(duration)
            suite.expect(!sharingController.closed && DispatchQueue.main.pending == 0,
                         "an open share sheet keeps the preview from dismissing")
            sharingController.systemSharing = false
            sharingController.scheduleAutoDismiss()
            DispatchQueue.main.advance(duration)
            suite.expect(sharingController.closed, "a cancelled share sheet resumes the dismissal delay")
        }

        DispatchQueue.main = ManualScheduler.Scheduler()
        let persistentController = Controller()
        persistentController.autoDismissDuration = nil
        persistentController.scheduleAutoDismiss()
        DispatchQueue.main.advance(60)
        suite.expect(!persistentController.closed && DispatchQueue.main.pending == 0,
                     "a persistent confirmation preview does not schedule automatic dismissal")
    }
}
