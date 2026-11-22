// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import Combine

/// Time Tracking's own menu bar item (plan E7): Tagwerk's glyph for the
/// state, today's working time beside it on request ("6:12", digits of equal
/// width so the neighbours do not move every minute) and a tooltip with the
/// state, the working time and the breaks of today. A click opens Barforge's
/// panel on the Time Tracking section.
///
/// The item exists only while recording runs and the option is on; like the
/// clipboard preview it is independent of the main item and separately
/// clickable. `StatusItemController` owns it.
final class TimeTrackingStatusItem {
    var onClick: ((NSStatusBarButton) -> Void)?
    var onRightClick: ((NSStatusBarButton?) -> Void)?

    private(set) var item: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    /// Last drawn icon (state, set, size) and title, so ticks that change
    /// nothing never redraw.
    private var shownIcon: (TTIconKind, TTIconSet, CGFloat)?
    private var shownTitle: String?
    private static let autosaveName = "BarforgeTimeTracking"

    init() {
        let service = TimeTrackingService.shared
        service.$snapshot.combineLatest(service.$databaseFault)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sync() }
            .store(in: &cancellables)
        L10n.shared.$language
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.shownIcon = nil
                self?.sync()
            }
            .store(in: &cancellables)
    }

    deinit {
        if let item { NSStatusBar.system.removeStatusItem(item) }
    }

    /// Creates, updates or removes the item. Runs on every state change and
    /// every settings change (the option, the icon set, the time beside it).
    func sync() {
        let defaults = UserDefaults.standard
        let service = TimeTrackingService.shared
        guard AppFeature.timeTracking.isAvailable, service.isActive,
              defaults.bool(forKey: DefaultsKey.timeTrackingStatusItem),
              let snapshot = service.snapshot else {
            remove()
            return
        }
        let item = self.item ?? install()
        guard let button = item.button else { return }
        let language = L10n.shared.language
        let menu = FeatureStrings.timeTrackingMenu(language)
        let kind = snapshot.menu.status.kind
        let settings = TTPreferences.read(from: defaults, into: snapshot.settings)
        let size = TimeTrackingGlyphs.menuBarSize(thickness: NSStatusBar.system.thickness)
        if shownIcon.map({ $0 != (kind, settings.iconSet, size) }) ?? true {
            button.image = TimeTrackingGlyphs.image(settings.iconSet, kind.glyph, size: size,
                                                     description: kind.description(menu))
            shownIcon = (kind, settings.iconSet, size)
        }
        let title = settings.showTime ? TTMenu.barTime(snapshot.today.workSecs) : ""
        if shownTitle != title {
            let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize,
                                                        weight: .regular)
            button.font = font
            button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
            button.title = title
            shownTitle = title
        }
        let error = service.databaseFault.map { fault -> String in
            let failure = TTMenu.dbFailure(fault.failure, menu)
            return TTMenu.dbErrorText(what: failure.what, detail: fault.message)
        }
        let tooltip = TTMenu.tooltip(kind: kind, status: snapshot.status, workSecs: snapshot.today.workSecs,
                                     pauseSecs: snapshot.today.pauseSecs, error: error,
                                     title: FeatureStrings.timeTracking(language).title, menu: menu)
        if button.toolTip != tooltip { button.toolTip = tooltip }
    }

    private func install() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = Self.autosaveName
        // Registered before it is shown: showing it writes and announces its
        // remembered position while this call is still on the stack.
        self.item = item
        item.isVisible = true
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        return item
    }

    private func remove() {
        guard let item else { return }
        self.item = nil
        shownIcon = nil
        shownTitle = nil
        NSStatusBar.system.removeStatusItem(item)
    }

    @objc private func clicked() {
        guard let button = item?.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            onRightClick?(button)
        } else {
            onClick?(button)
        }
    }
}
