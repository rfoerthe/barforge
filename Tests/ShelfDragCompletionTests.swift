// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import AppKit

/// Production drag completion runs with isolated windows and preferences.
enum ShelfDragCompletionContract {
    final class Window {}
    typealias NSWindow = Window
    typealias ShelfService = Service
    struct NSEvent {}

    /// The production tile builds native pasteboard items. Only starting the
    /// interactive drag is replaced, so tests need no window or mouse gesture.
    class TileState {
        let item: Service.Item
        var window: Window? = Window()
        let bounds = CGRect(x: 0, y: 0, width: 40, height: 40)
        var draggedIDs: [UUID] = []
        var draggingItems: [NSDraggingItem] = []
        init(item: Service.Item) { self.item = item }
        func beginDraggingSession(with items: [NSDraggingItem], event: NSEvent, source: AnyObject) {
            draggingItems = items
        }
    }

    static func dragItems(_ ids: [UUID]) -> [Service.Item] {
        ids.map { Service.Item(id: $0, payload: .text("note"), title: "note", icon: NSImage(), isImage: false) }
    }

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
        Service.shared = Service()
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
            service.beginInternalDrag(items: Context.dragItems([UUID()]), from: source)
            service.completeInternalDrag(dropAccepted: true)
            suite.expect(service.floatingClosures == (docked ? 0 : 1) && service.dockedClosures == (docked ? 1 : 0)
                   && service.removed.isEmpty && service.internalDragWindow == nil
                   && service.activeInternalDragIDs.isEmpty && !service.internalDragHoldsPackageContent,
                   "shelf completion retains its own close, pin and removal behavior and releases the drag")
        }

        Context.reset()
        let pinnedService = Context.Service()
        let pinnedID = UUID(), looseID = UUID()
        pinnedService.protectedIDs = [pinnedID]
        pinnedService.beginInternalDrag(items: Context.dragItems([pinnedID, looseID]), from: Context.Window())
        pinnedService.completeInternalDrag(dropAccepted: true)
        suite.expect(pinnedService.removed == [looseID],
               "a pinned shelf item survives a drag-out that removes the rest")
        fileDragProtection(suite)
    }

    private static func fileDragProtection(_ suite: TestSuite) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("vorss-shelf-drag-tests-\(UUID())")
        defer { try? fm.removeItem(at: root) }
        do {
            let package = root.appendingPathComponent("Library.app", isDirectory: true)
            let resources = package.appendingPathComponent("Contents/Resources", isDirectory: true)
            try fm.createDirectory(at: resources, withIntermediateDirectories: true)
            let inside = resources.appendingPathComponent("photo.jpeg")
            let plain = root.appendingPathComponent("plain.jpeg")
            try Data("package content".utf8).write(to: inside)
            try Data("ordinary file".utf8).write(to: plain)
            let directoryLink = root.appendingPathComponent("exports", isDirectory: true)
            let fileLink = root.appendingPathComponent("photo-link")
            let packageLink = root.appendingPathComponent("package-link")
            try fm.createSymbolicLink(at: directoryLink, withDestinationURL: resources)
            try fm.createSymbolicLink(at: fileLink, withDestinationURL: inside)
            try fm.createSymbolicLink(at: packageLink, withDestinationURL: package)

            func item(_ url: URL, bookmark: Data? = nil) -> Context.Service.Item {
                Context.Service.Item(payload: .file(url), title: url.lastPathComponent,
                                     icon: NSImage(), isImage: false, bookmark: bookmark)
            }
            let cases: [(URL, Bool, String)] = [
                (inside, true, "package content"),
                (resources, true, "a directory inside a package"),
                (directoryLink.appendingPathComponent("photo.jpeg"), true, "content through a directory symlink"),
                (plain, false, "an ordinary file"),
                (package, false, "a whole package"),
                (fileLink, false, "a symlink to a package file"),
                (packageLink, false, "a symlink to a whole package"),
            ]
            for (url, protected, label) in cases {
                Context.reset()
                let service = Context.Service.shared
                let entry = item(url)
                service.items = [entry]
                let tile = Context.Tile(item: entry)
                tile.beginItemDrag(with: Context.NSEvent())
                let writer = tile.draggingItems.first?.item as? NSURL
                suite.expect(writer?.path == url.path && service.activeInternalDragIDs == [entry.id],
                       "the production tile keeps the selected payload and identity for \(label)")
                let operations = service.sourceOperationMask(for: .outsideApplication)
                suite.expect(operations == (protected ? .copy : [.copy, .move]),
                       "the production drag only protects package contents for \(label)")
                // Exercise a same-volume destination using only the offered
                // operation. Everything here belongs to this temporary fixture.
                let destination = root.appendingPathComponent("drop-\(UUID())")
                if operations.contains(.move) {
                    try fm.moveItem(at: url, to: destination)
                } else {
                    try fm.copyItem(at: url, to: destination)
                }
                suite.expect(fm.fileExists(atPath: destination.path)
                        && fm.fileExists(atPath: url.path) == protected,
                       "the offered transfer leaves package contents in place and permits legitimate moves for \(label)")
                if url == fileLink || url == packageLink {
                    suite.expect(fm.fileExists(atPath: inside.path),
                           "moving the symlink itself leaves its package target untouched")
                }
                if operations.contains(.move) {
                    try fm.moveItem(at: destination, to: url)
                } else {
                    try fm.removeItem(at: destination)
                }
                suite.expect(service.sourceOperationMask(for: .withinApplication) == .move,
                       "internal Shelf stacking remains a move for \(label)")
                service.completeInternalDrag(dropAccepted: false)
                suite.expect(!service.internalDragHoldsPackageContent && service.removed.isEmpty,
                       "cancelling \(label) clears the protection without removing its tile")
            }

            // The bookmark follows the inode into a package, but the stored
            // tile still has its old URL during the production drag callback.
            Context.reset()
            let recovered = resources.appendingPathComponent("recovered.jpeg")
            let saved = item(plain, bookmark: try plain.bookmarkData())
            try fm.moveItem(at: plain, to: recovered)
            let service = Context.Service.shared
            service.items = [saved]
            let healedTile = Context.Tile(item: saved)
            healedTile.beginItemDrag(with: Context.NSEvent())
            let writer = healedTile.draggingItems.first?.item as? NSURL
            suite.expect(writer.map { ($0 as URL).standardizedFileURL.path } == recovered.standardizedFileURL.path
                    && service.items.first?.payload == .file(plain)
                    && service.replacements.isEmpty,
                   "the bookmark reaches the actual drag before the deferred saved-item replacement")
            suite.expect(service.sourceOperationMask(for: .outsideApplication) == .copy,
                   "a healed bookmark moved into a package cannot offer Finder a move")
            service.completeInternalDrag(dropAccepted: true)
            suite.expect(service.removed == [saved.id] && !service.internalDragHoldsPackageContent
                    && fm.fileExists(atPath: recovered.path),
                   "an accepted protected drag retires its tile and resets the drag state")

            Context.reset()
            let exported = root.appendingPathComponent("exported.jpeg")
            let savedInside = item(recovered, bookmark: try recovered.bookmarkData())
            try fm.moveItem(at: recovered, to: exported)
            let exportedService = Context.Service.shared
            exportedService.items = [savedInside]
            let exportedTile = Context.Tile(item: savedInside)
            exportedTile.beginItemDrag(with: Context.NSEvent())
            let exportedWriter = exportedTile.draggingItems.first?.item as? NSURL
            suite.expect(exportedWriter.map { ($0 as URL).standardizedFileURL.path } == exported.standardizedFileURL.path
                    && exportedService.sourceOperationMask(for: .outsideApplication) == [.copy, .move],
                   "a bookmark moved out of a package regains ordinary move behavior")
            exportedService.completeInternalDrag(dropAccepted: false)

            // Batch flattening and mixed selections use the same copy-only
            // decision, while pinned and retained files remain copy-only too.
            Context.reset()
            let note = Context.dragItems([UUID()])[0]
            let entry = item(inside)
            let batch = Context.Service.Item(payload: .batch([note, entry]), title: "batch",
                                            icon: NSImage(), isImage: false)
            let batchService = Context.Service.shared
            batchService.items = [batch]
            batchService.selection = [batch.id]
            let batchTile = Context.Tile(item: batch)
            batchTile.beginItemDrag(with: Context.NSEvent())
            suite.expect(batchTile.draggedIDs == [note.id, entry.id]
                    && batchService.sourceOperationMask(for: .outsideApplication) == .copy,
                   "a mixed batch protects its package content while retaining every leaf")
            batchService.completeInternalDrag(dropAccepted: false)
            let link = item(fileLink)
            batchService.beginInternalDrag(items: [link], from: Context.Window())
            suite.expect(batchService.sourceOperationMask(for: .outsideApplication) == [.copy, .move],
                   "a subsequent ordinary drag does not retain the previous package protection")
            batchService.protectedIDs = [link.id]
            suite.expect(batchService.sourceOperationMask(for: .outsideApplication) == .copy,
                   "a pinned item remains copy-only")
            batchService.protectedIDs = []
            Context.UserDefaults.standard.removeAfterDrop = false
            suite.expect(batchService.sourceOperationMask(for: .outsideApplication) == .copy,
                   "turning off removal keeps ordinary payloads copy-only")
            batchService.completeInternalDrag(dropAccepted: true)
        } catch {
            suite.expect(false, "shelf drag protection fixture failed: \(error)")
        }
    }
}
