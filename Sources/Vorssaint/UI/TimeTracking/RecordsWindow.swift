// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import Combine
import SwiftUI

/// The Records window of Time Tracking (Tagwerk's "Aufzeichnungen"): an
/// `NSWindow` with an AppKit toolbar around the SwiftUI content, after the
/// pattern of the Disk Analyzer. Barforge runs as an accessory app, so the
/// window's commands come as toolbar items and in-window shortcuts (`keyHandler`)
/// instead of a menu of their own; ⌘Z and ⇧⌘Z reach the history through the
/// window's undo manager, ⌘W closes through the standard Window menu.
final class RecordsWindow: NSWindow, NSWindowDelegate {
    var onClose: (() -> Void)?
    var keyHandler: ((NSEvent) -> Bool)?
    let recordsUndoManager = RecordsUndoManager()

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        delegate = self
    }

    /// Undo and redo of the corrections, not of single keystrokes.
    override var undoManager: UndoManager? { recordsUndoManager }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyHandler?(event) == true { return }
        super.sendEvent(event)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

/// Undo and redo of the window: the steps of `TTEditHistory` with the
/// three-way merge of `TTCorrections.rewind`, under the titles of the menu
/// ("Undo Remove Break"). Nothing is registered with it; it only answers
/// the Edit menu and ⌘Z.
final class RecordsUndoManager: UndoManager {
    weak var model: RecordsModel?

    override var canUndo: Bool { model?.canStep(redo: false) ?? false }
    override var canRedo: Bool { model?.canStep(redo: true) ?? false }
    override var undoMenuItemTitle: String { model?.historyTitle(redo: false) ?? super.undoMenuItemTitle }
    override var redoMenuItemTitle: String { model?.historyTitle(redo: true) ?? super.redoMenuItemTitle }

    override func undo() { model?.stepHistory(redo: false) }
    override func redo() { model?.stepHistory(redo: true) }
}

/// Opens, shows and closes the Records window; owns its toolbar.
final class RecordsWindowController: NSObject, NSToolbarDelegate, NSToolbarItemValidation, NSMenuItemValidation {
    static let shared = RecordsWindowController()

    private var window: RecordsWindow?
    private var model: RecordsModel?
    private var cancellables: Set<AnyCancellable> = []
    private var timer: Timer?
    private var switcher: NSSegmentedControl?
    private var filterItem: NSMenuToolbarItem?

    private enum Item {
        static let view = NSToolbarItem.Identifier("records.view")
        static let filter = NSToolbarItem.Identifier("records.filter")
        static let refresh = NSToolbarItem.Identifier("records.refresh")
        static let editDay = NSToolbarItem.Identifier("records.editDay")
        static let export = NSToolbarItem.Identifier("records.export")
        static let importRecords = NSToolbarItem.Identifier("records.import")
        static let inspector = NSToolbarItem.Identifier("records.inspector")
    }

    /// Tags of the filter menu.
    private enum FilterTag {
        static let warnings = 100
        static let corrected = 101
        static let reset = 102
    }

    /// Tagwerk reads again every 30 s, so a running day updates without events.
    private static let reloadInterval: TimeInterval = 30

    private var strings: TimeTrackingRecordsStrings { FeatureStrings.timeTrackingRecords(L10n.shared.language) }

    var isVisible: Bool { window?.isVisible == true }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        if !window.isVisible {
            model?.load()
            WindowActivationPolicy.retain()
            startUpdates()
            if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }) { window.center() }
        }
        window.title = strings.windowTitle
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Closes the window and lets go of it (feature uninstalled).
    func close() {
        guard let window else { return }
        if window.isVisible {
            window.close()
        }
        self.window = nil
        model = nil
    }

    private func makeWindow() -> RecordsWindow {
        let model = RecordsModel()
        self.model = model
        let host = NSHostingController(rootView: RecordsRootView(model: model))
        host.sizingOptions = []
        let window = RecordsWindow(contentViewController: host)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 1000, height: 640))
        // Narrower, the five cards no longer fit side by side.
        window.contentMinSize = NSSize(width: 940, height: 480)
        window.center()
        window.setFrameAutosaveName("BarforgeTimeTrackingRecords")
        window.onClose = { [weak self] in self?.windowDidClose() }
        window.keyHandler = { [weak self] event in self?.handleKey(event) ?? false }
        window.recordsUndoManager.model = model
        model.window = window

        let toolbar = NSToolbar(identifier: "BarforgeTimeTrackingRecordsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        return window
    }

    /// The window follows the service (ticks, menu bar actions, events) and
    /// reads again every 30 s; the subtitle, the switcher and the filter
    /// follow the model.
    private func startUpdates() {
        guard let model else { return }
        cancellables.removeAll()
        let service = TimeTrackingService.shared
        service.$snapshot.dropFirst().sink { [weak model] _ in model?.scheduleReload() }.store(in: &cancellables)
        service.$isActive.dropFirst().sink { [weak model] _ in model?.scheduleReload() }.store(in: &cancellables)
        model.$statusLine.sink { [weak self] line in self?.window?.subtitle = line }.store(in: &cancellables)
        model.$mode.sink { [weak self] mode in
            self?.switcher?.selectedSegment = mode.rawValue
            self?.window?.toolbar?.validateVisibleItems()
            if mode == .days { DispatchQueue.main.async { self?.focusTable() } }
        }.store(in: &cancellables)
        model.$filter.sink { [weak self] filter in self?.updateFilterItem(filter) }.store(in: &cancellables)
        L10n.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.languageChanged() }
        }.store(in: &cancellables)
        timer?.invalidate()
        let timer = Timer(timeInterval: Self.reloadInterval, repeats: true) { [weak model] _ in model?.load() }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// A closed window keeps nothing: the history goes, as in Tagwerk.
    private func windowDidClose() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
        WindowActivationPolicy.release()
        window?.recordsUndoManager.model = nil
        window = nil
        model = nil
        switcher = nil
        filterItem = nil
    }

    private func languageChanged() {
        guard let window else { return }
        window.title = strings.windowTitle
        // The toolbar is built anew with the new labels.
        let toolbar = NSToolbar(identifier: "BarforgeTimeTrackingRecordsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        model?.load()
    }

    private func focusTable() {
        guard let window, let table = Self.firstTable(in: window.contentView) else { return }
        window.makeFirstResponder(table)
    }

    private static func firstTable(in view: NSView?) -> NSTableView? {
        guard let view else { return nil }
        if let table = view as? NSTableView { return table }
        for sub in view.subviews {
            if let table = firstTable(in: sub) { return table }
        }
        return nil
    }

    // MARK: Shortcuts

    /// ⌘1/⌘2 view, ⌘N edit day, ⌘E export, ⇧⌘I import, ⌘T today, ⌘R refresh,
    /// ⌥⌘I inspector, and ⌘Z/⇧⌘Z when the Edit menu did not take them.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard let model, window?.attachedSheet == nil else { return false }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = (event.charactersIgnoringModifiers ?? "").lowercased()
        switch (key, flags) {
        case ("1", [.command]): model.setMode(.days)
        case ("2", [.command]): model.setMode(.week)
        case ("n", [.command]): model.askDay()
        case ("e", [.command]): model.showExport()
        case ("i", [.command, .shift]): model.showImport()
        case ("t", [.command]): model.goToday()
        case ("r", [.command]): model.load()
        case ("i", [.command, .option]): model.toggleInspector()
        case ("z", [.command]): model.stepHistory(redo: false)
        case ("z", [.command, .shift]): model.stepHistory(redo: true)
        default: return false
        }
        return true
    }

    // MARK: Toolbar

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Item.view, .flexibleSpace, Item.filter, Item.refresh, Item.editDay, Item.export, Item.importRecords,
         Item.inspector]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let s = strings
        switch id {
        case Item.view:
            let control = NSSegmentedControl(labels: [s.days, s.week], trackingMode: .selectOne, target: self,
                                             action: #selector(switchView(_:)))
            control.setToolTip(s.daysTip, forSegment: 0)
            control.setToolTip(s.weekTip, forSegment: 1)
            control.selectedSegment = model?.mode.rawValue ?? 0
            switcher = control
            let item = NSToolbarItem(itemIdentifier: id)
            item.label = s.viewLabel
            item.paletteLabel = s.viewLabel
            item.toolTip = s.viewTip
            item.view = control
            return item
        case Item.filter:
            let item = NSMenuToolbarItem(itemIdentifier: id)
            item.label = s.filter
            item.paletteLabel = s.filter
            item.menu = filterMenu()
            item.showsIndicator = true
            filterItem = item
            updateFilterItem(model?.filter ?? TTRecordsFilter())
            return item
        case Item.refresh:
            return button(id, s.refresh, s.refreshTip, "arrow.clockwise", #selector(refresh(_:)))
        case Item.editDay:
            return button(id, s.editDay, s.editDayTip, "calendar.badge.plus", #selector(editDay(_:)))
        case Item.export:
            return button(id, s.export, s.exportTip, "square.and.arrow.up", #selector(exportRecords(_:)))
        case Item.importRecords:
            return button(id, s.importLabel, s.importTip, "square.and.arrow.down", #selector(importRecords(_:)))
        case Item.inspector:
            return button(id, s.inspector, s.inspectorTip, "sidebar.right", #selector(toggleInspector(_:)))
        default:
            return nil
        }
    }

    private func button(_ id: NSToolbarItem.Identifier, _ label: String, _ tip: String, _ symbol: String,
                        _ action: Selector) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = label
        item.paletteLabel = label
        item.toolTip = tip
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.isBordered = true
        item.target = self
        item.action = action
        return item
    }

    /// The inspector only in "Days"; nothing while a sheet is open.
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        guard let model, window?.attachedSheet == nil else { return false }
        if item.itemIdentifier == Item.inspector { return model.mode == .days }
        return true
    }

    /// The filter menu: one period, and marks to combine.
    private func filterMenu() -> NSMenu {
        let s = strings
        let menu = NSMenu()
        for (i, period) in TTRecordsPeriod.allCases.enumerated() {
            let item = NSMenuItem(title: period.label(s), action: #selector(filterChosen(_:)), keyEquivalent: "")
            item.tag = i
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        for (title, tag) in [(s.filterWarnings, FilterTag.warnings), (s.filterCorrected, FilterTag.corrected)] {
            let item = NSMenuItem(title: title, action: #selector(filterChosen(_:)), keyEquivalent: "")
            item.tag = tag
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let reset = NSMenuItem(title: s.filterReset, action: #selector(filterChosen(_:)), keyEquivalent: "")
        reset.tag = FilterTag.reset
        reset.target = self
        menu.addItem(reset)
        return menu
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard let model, item.action == #selector(filterChosen(_:)) else { return true }
        let filter = model.filter
        switch item.tag {
        case FilterTag.warnings: item.state = filter.warnings ? .on : .off
        case FilterTag.corrected: item.state = filter.corrected ? .on : .off
        case FilterTag.reset: return model.mode == .days && filter.isActive
        default:
            let periods = TTRecordsPeriod.allCases
            item.state = periods.indices.contains(item.tag) && periods[item.tag] == filter.period ? .on : .off
        }
        return model.mode == .days
    }

    /// The filter symbol is filled while the table does not show every day.
    private func updateFilterItem(_ filter: TTRecordsFilter) {
        guard let item = filterItem else { return }
        let active = filter.isActive
        let symbol = active ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: strings.filter)
        item.toolTip = active ? strings.filterActiveTip : strings.filterTip
    }

    // MARK: Actions

    @objc private func switchView(_ sender: NSSegmentedControl) {
        model?.setMode(sender.selectedSegment == 1 ? .week : .days)
    }

    @objc private func filterChosen(_ sender: NSMenuItem) {
        guard let model else { return }
        var filter = model.filter
        switch sender.tag {
        case FilterTag.warnings: filter.warnings.toggle()
        case FilterTag.corrected: filter.corrected.toggle()
        case FilterTag.reset: filter = TTRecordsFilter()
        default:
            let periods = TTRecordsPeriod.allCases
            guard periods.indices.contains(sender.tag) else { return }
            filter.period = periods[sender.tag]
        }
        model.setFilter(filter)
    }

    @objc private func refresh(_ sender: Any?) { model?.load() }
    @objc private func editDay(_ sender: Any?) { model?.askDay() }
    @objc private func exportRecords(_ sender: Any?) { model?.showExport() }
    @objc private func importRecords(_ sender: Any?) { model?.showImport() }
    @objc private func toggleInspector(_ sender: Any?) { model?.toggleInspector() }
}
