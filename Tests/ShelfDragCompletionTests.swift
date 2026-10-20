// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Production drag completion runs with isolated windows and preferences.
enum ShelfDragCompletionContract {
    final class Window {}
    typealias NSWindow = Window

    enum UserDefaults {
        static var standard = Store()
        struct Store {
            var closeAfterDrop = true
            var removeAfterDrop = true
            func bool(forKey key: String) -> Bool {
                key == DefaultsKey.shelfCloseAfterDrop ? closeAfterDrop
                    : key == DefaultsKey.shelfRemoveAfterDrop && removeAfterDrop
            }
        }
    }

    static func reset() {
        UserDefaults.standard = UserDefaults.Store()
    }
}

enum ShelfDragCompletionTests {
    private typealias Context = ShelfDragCompletionContract

    static func run(_ suite: TestSuite) {
        for docked in [false, true] {
            Context.reset()
            let service = Context.Service()
            let source = Context.Window()
            if docked { service.dockedPanel = source } else { service.panel = source }
            service.isVisible = !docked
            service.dockedVisible = docked
            Context.UserDefaults.standard.removeAfterDrop = false
            service.beginInternalDrag(ids: [UUID()], from: source)
            service.completeInternalDrag(dropAccepted: true)
            suite.expect(service.floatingClosures == (docked ? 0 : 1) && service.dockedClosures == (docked ? 1 : 0)
                   && service.removed.isEmpty && service.internalDragWindow == nil
                   && service.activeInternalDragIDs.isEmpty,
                   "shelf completion retains its own close, pin and removal behavior and releases the drag")
        }

        Context.reset()
        let pinnedService = Context.Service()
        let pinnedID = UUID(), looseID = UUID()
        pinnedService.protectedIDs = [pinnedID]
        pinnedService.beginInternalDrag(ids: [pinnedID, looseID], from: Context.Window())
        pinnedService.completeInternalDrag(dropAccepted: true)
        suite.expect(pinnedService.removed == [looseID],
               "a pinned shelf item survives a drag-out that removes the rest")
    }
}
