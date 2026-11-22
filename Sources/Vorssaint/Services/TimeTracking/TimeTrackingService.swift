// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import Combine
import CoreGraphics
import IOKit.pwr_mgt
import os

/// Automatic work time tracking, ported from Tagwerk. Time counts while the
/// Mac is unlocked; locks, sleep, session switches and idle time end a period.
///
/// The service runs only while the feature is installed and its switch is on:
/// then it holds the database, a `TimeTrackingEngine` with the tracker, the
/// observers of lock, sleep and session, and the 15 s timer. Off, it keeps
/// nothing resident. Main thread only, like the rest of the services.
final class TimeTrackingService: ObservableObject {
    static let shared = TimeTrackingService()

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "TimeTracking")
    private static let screenLockNotification = Notification.Name("com.apple.screenIsLocked")
    private static let screenUnlockNotification = Notification.Name("com.apple.screenIsUnlocked")

    /// Whether recording runs (feature installed, switch on, database open).
    @Published private(set) var isActive = false
    /// State for the menu bar section; `nil` while inactive.
    @Published private(set) var snapshot: TimeTrackingSnapshot?
    /// The database failed (open, read or write). While saving fails the time
    /// keeps counting and is saved once it works again.
    @Published private(set) var databaseFault: TimeTrackingDatabaseFault?

    /// The global shortcuts are on but macOS refused one of them (taken by
    /// another app).
    @Published private(set) var shortcutRegistrationFailed = false

    /// Forgotten "Back at the Mac", cut work away from the Mac, refused
    /// entries, the end of a lock and database errors. Delivered on the main
    /// thread, after the notification for it went out.
    let events = PassthroughSubject<TimeTrackingEvent, Never>()

    var status: TTStatus? { snapshot?.status }
    var today: TTTodayInfo? { snapshot?.today }
    var settings: TTSettings? { snapshot?.settings }
    var pausesToday: [TTSpan] { snapshot?.pausesToday ?? [] }

    private let clock: TimeTrackingClock = TimeTrackingSystemClock()
    private let probe: TimeTrackingSystemProbe = TimeTrackingLiveProbe()
    private var database: TimeTrackingDatabase?
    private var engine: TimeTrackingEngine?
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var timer: Timer?
    private var notifications: TimeTrackingNotifications?
    /// Global shortcuts (ids from the free range 30–56 of `QuickToolHotkey`).
    private let pauseHotkey = QuickToolHotkey(id: 30)
    private let recordsHotkey = QuickToolHotkey(id: 31)

    private init() {
        pauseHotkey.onPress = { [weak self] in self?.togglePause() }
        recordsHotkey.onPress = { [weak self] in self?.showRecords() }
    }

    private var language: AppLanguage { L10n.shared.language }
    private var texts: TimeTrackingTexts { FeatureStrings.timeTrackingTexts(language) }
    private var menuTexts: TimeTrackingMenuTexts { FeatureStrings.timeTrackingMenu(language) }

    /// Called by the hub, by the settings switch and at launch. Active iff
    /// the feature is installed and its switch is on.
    func syncWithPreferences() {
        let active = AppFeature.timeTracking.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.timeTrackingEnabled)
        if active {
            if engine == nil {
                activate()
                if engine != nil, Self.wantsNotifications(.standard) { Notifier.requestPermission() }
            }
        } else if engine != nil || databaseFault != nil {
            deactivate()
        }
        // Uninstalled: the Records window closes and lets go of its state.
        if !AppFeature.timeTracking.isAvailable { RecordsWindowController.shared.close() }
        syncHotkeys()
    }

    /// A reminder or the lock question is on: asked for the permission when
    /// recording starts with one of them (the Settings page asks when one is
    /// switched on). The reminders only count while the hints of the Working
    /// Hours Act are on.
    static func wantsNotifications(_ defaults: UserDefaults) -> Bool {
        (defaults.bool(forKey: DefaultsKey.timeTrackingNotifyLimit)
            || defaults.bool(forKey: DefaultsKey.timeTrackingNotifyBreak))
            && defaults.bool(forKey: DefaultsKey.timeTrackingLegalHints)
            || defaults.bool(forKey: DefaultsKey.timeTrackingAskAfterLock)
    }

    /// ⌃⌥⌘B (pause) and ⌃⌥⌘A (records) by default, while recording runs and
    /// "Global shortcuts" is on. Also re-registers after a shortcut field
    /// released every key.
    func syncHotkeys() {
        let defaults = UserDefaults.standard
        let on = engine != nil
        var failed = false
        for (role, hotkey) in [(GlobalShortcutRole.timeTrackingPause, pauseHotkey),
                               (.timeTrackingRecords, recordsHotkey)] {
            let enabled = on && role.requiredEnableKeys.allSatisfy { defaults.bool(forKey: $0) }
            if !hotkey.sync(enabled: enabled, shortcut: role.savedShortcut, storageKey: role.storageKey) {
                failed = true
            }
        }
        if shortcutRegistrationFailed != failed { shortcutRegistrationFailed = failed }
    }

    /// Saves what is running before the app quits. A break and work away from
    /// the Mac survive a plain quit (restart state).
    func shutdown() {
        perform { $0.shutdown() }
    }

    /// "Now" as the logic sees it (local wall-clock time).
    func now() -> TTDateTime { clock.now() }

    // MARK: Actions for the menu bar section, shortcuts and windows

    /// "Pause work" ↔ "Resume work"; while away from the Mac "Back at the Mac".
    func togglePause() { perform { $0.togglePause() } }

    /// "Keep working away from the Mac".
    func goAway(_ activity: TTActivity) { perform { $0.goAway(activity) } }

    /// Counts one of today's breaks as work away from the Mac.
    func countPauseAsWork(_ pause: TTSpan, activity: TTActivity) {
        perform { $0.countPauseAsWork(pause, activity: activity) }
    }

    /// Today's start of work in seconds since midnight (`nil`: the first
    /// unlock again). `nil` result: recording is off.
    @discardableResult
    func setStart(at: Int?) -> Result<[TTWorkBlock], TTRefused>? {
        perform { $0.setStart(at: at) }
    }

    /// Today's end of work in seconds since midnight. `nil` result: recording is off.
    @discardableResult
    func closeDay(at: Int) -> Result<[TTWorkBlock], TTRefused>? {
        perform { $0.closeDay(at: at) }
    }

    func reopenDay() { perform { $0.reopenDay() } }

    /// "Record today" on a free day.
    func setCounting(_ on: Bool) { perform { $0.setCounting(on) } }

    func addWork(date: TTDate, from: Int, to: Int, activity: TTActivity) {
        perform { $0.addWork(date: date, from: from, to: to, activity: activity) }
    }

    func removeWork(date: TTDate, from: Int, to: Int) {
        perform { $0.removeWork(date: date, from: from, to: to) }
    }

    /// Changes a day for the records window. While recording runs the change
    /// goes through the tracker, so a running period and running work away
    /// from the Mac stay consistent; while it is off, straight to the database.
    func editDay(_ date: TTDate, _ change: (inout TTDay) throws -> Void) throws {
        if let engine {
            defer { refresh() }
            try engine.editDay(date, change)
        } else {
            try TimeTrackingDatabase.openDefault().editDay(date, now: clock.now(), change)
        }
    }

    /// Takes changed settings over (workdays, free days, idle time …).
    func reloadSettings() { perform { $0.reload() } }

    /// All days (with what runs right now), the settings and "now" for the
    /// records window. Works while recording is off too (then straight from
    /// the database, like `editDay`).
    func recordsState() throws -> (days: [TTDay], settings: TTSettings, now: TTDateTime) {
        if let engine { return engine.recordsState() }
        let database = try TimeTrackingDatabase.openDefault()
        return (try database.load(), try database.loadSettings(defaults: .standard), clock.now())
    }

    /// Takes over the days of an import (they replace what these days had),
    /// after a backup of the database. While recording runs it goes through
    /// the engine, so the running period stays and the tracker reads the new
    /// days. Returns the backup (`nil`: there was nothing to back up yet).
    @discardableResult
    func importDays(_ days: [TTDay]) throws -> URL? {
        if let engine, let database {
            defer { refresh() }
            return try engine.changeStore { _, t in try database.importDays(days, now: t) }
        }
        return try TimeTrackingDatabase.openDefault().importDays(days, now: clock.now())
    }

    // MARK: Settings page

    /// All settings: the preferences from UserDefaults, the working-time rules
    /// and the time account from the database. Works while recording is off
    /// too (then straight from the database, like `editDay`).
    func loadSettings() throws -> TTSettings {
        try withDatabase { try $0.loadSettings(defaults: .standard) }
    }

    /// Saves the database's part of `settings` (the dated working-time rules
    /// and the time account) and lets recording take them over.
    func saveRulesAndAccount(_ settings: TTSettings) throws {
        let today = now().date
        try withDatabase { try $0.saveSettings(settings, today: today) }
        reloadSettings()
    }

    /// "Restore defaults": every setting of the page as at the beginning, the
    /// working-time rules from today on (`TTSettingsModel.withDefaults`). The
    /// recording switch and the records stay. Returns the new settings.
    @discardableResult
    func restoreDefaults() throws -> TTSettings {
        let defaults = UserDefaults.standard
        let today = now().date
        let fresh = TTSettingsModel.withDefaults(try loadSettings(), today: today)
        try withDatabase { try $0.saveSettings(fresh, today: today, defaults: defaults) }
        // Barforge's own options go back to their registered defaults.
        for key in [DefaultsKey.timeTrackingStatusItem, DefaultsKey.timeTrackingPauseShortcut,
                    DefaultsKey.timeTrackingRecordsShortcut] {
            defaults.removeObject(forKey: key)
        }
        reloadSettings()
        syncHotkeys()
        return fresh
    }

    /// Tagwerk's database at its usual place (`nil`: there is none).
    var tagwerkDatabaseURL: URL? {
        TimeTrackingTagwerkImport.defaultSourceURL.flatMap {
            FileManager.default.fileExists(atPath: $0.path) ? $0 : nil
        }
    }

    /// Takes the data over from Tagwerk (plan E3). Recording stops for it, so
    /// nothing of the running period mixes into the copy, and starts again
    /// with the new days and settings.
    func takeOverTagwerk() throws -> TimeTrackingTagwerkImport.Result {
        guard let source = TimeTrackingTagwerkImport.defaultSourceURL else {
            throw TimeTrackingTagwerkImport.Failure.missing("Tagwerk/tagwerk.db")
        }
        let wasActive = engine != nil
        if wasActive { deactivate() }
        defer {
            if wasActive { syncWithPreferences() }
        }
        let database = try TimeTrackingDatabase.openDefault()
        return try TimeTrackingTagwerkImport.takeOver(from: source, into: database, defaults: .standard,
                                                      now: now())
    }

    /// Runs `body` on the open database, or on a database opened for it while
    /// recording is off.
    private func withDatabase<T>(_ body: (TimeTrackingDatabase) throws -> T) throws -> T {
        if let database { return try body(database) }
        return try body(TimeTrackingDatabase.openDefault())
    }

    /// The state as of now, when the panel opens (`menuWillOpen`): the tick
    /// may be up to 15 s old.
    func refreshDisplay() { refresh() }

    /// "Records…" in the panel, its shortcut, the Command Bar and the
    /// context menu: opens the Records window or brings it to the front. It
    /// also works while recording is off (then on the database alone).
    func showRecords() {
        guard AppFeature.timeTracking.isAvailable else { return }
        RecordsWindowController.shared.show()
    }

    /// Whether "Records…" has a window to open.
    static let recordsAvailable = true

    /// The answer to the question after a long lock (`menubar.rs`
    /// `lock_answered`): the lock was work away from the Mac, or the end of
    /// work came with it (only for a lock of today; then recording stops
    /// counting). Without recording the answer has nowhere to go.
    func answerLock(_ question: TTLockQuestion, _ answer: TTLockAnswer) {
        guard engine != nil else { return }
        switch answer {
        case let .work(activity):
            addWork(date: question.date, from: question.from, to: question.to, activity: activity)
        case .closeDay:
            guard question.date == now().date else { return }
            closeDay(at: question.from)
        }
    }

    // MARK: Lifecycle

    private func activate() {
        let database: TimeTrackingDatabase
        do {
            database = try TimeTrackingDatabase.openDefault()
        } catch {
            let fault = TimeTrackingDatabaseFault(kind: .open, message: String(describing: error))
            Self.log.error("Time Tracking cannot open its database: \(fault.message, privacy: .public)")
            databaseFault = fault
            handle(.databaseError(fault, first: true))
            return
        }
        self.database = database
        notifications = TimeTrackingNotifications()
        TimeTrackingNotifications.registerCategory(texts: texts, menu: menuTexts)
        engine = TimeTrackingEngine(store: database, defaults: .standard, clock: clock, probe: probe,
                                    texts: { FeatureStrings.timeTrackingTexts(L10n.shared.language) },
                                    menuTexts: { FeatureStrings.timeTrackingMenu(L10n.shared.language) },
                                    onEvent: { [weak self] in self?.handle($0) })
        startObservers()
        startTimer()
        isActive = true
        refresh()
    }

    /// Stops recording and saves, then lets go of everything.
    private func deactivate() {
        engine?.shutdown()
        stopObservers()
        timer?.invalidate()
        timer = nil
        engine = nil
        database = nil
        notifications = nil
        isActive = false
        snapshot = nil
        databaseFault = nil
    }

    private func startObservers() {
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Self.screenLockNotification) { $0.screenLocked() }
        observe(distributed, Self.screenUnlockNotification) { $0.screenUnlocked() }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { $0.willSleep() }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.didWake() }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.sessionResigned() }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.sessionBecameActive() }
        observe(workspace, NSWorkspace.willPowerOffNotification) { $0.willPowerOff() }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ action: @escaping (TimeTrackingEngine) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            self?.perform(action)
        }
        observers.append((center, token))
    }

    private func stopObservers() {
        for observer in observers { observer.center.removeObserver(observer.token) }
        observers.removeAll()
    }

    private func startTimer() {
        let timer = Timer(timeInterval: TimeTrackingEngine.tickInterval, repeats: true) { [weak self] _ in
            self?.perform { $0.tick() }
        }
        timer.tolerance = 3
        // Common modes: the tick also runs while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Runs `body` on the engine (if recording runs) and publishes the new state.
    @discardableResult
    private func perform<T>(_ body: (TimeTrackingEngine) -> T) -> T? {
        guard let engine else { return nil }
        let result = body(engine)
        refresh()
        return result
    }

    private func refresh() {
        guard let engine else { return }
        let snapshot = engine.snapshot()
        notifications?.update(snapshot, texts: texts)
        if snapshot != self.snapshot { self.snapshot = snapshot }
        if engine.databaseFault != databaseFault { databaseFault = engine.databaseFault }
    }

    /// An event of the engine: its notification first (the lock question is
    /// decided now, right after recording resumed, like Tagwerk), then the
    /// event for whoever listens.
    private func handle(_ event: TimeTrackingEvent) {
        var question: TTLockQuestion?
        if case let .resumedAfterLock(from, to) = event {
            question = engine?.lockQuestion(from: from, to: to)
        }
        let notifications = self.notifications ?? TimeTrackingNotifications()
        notifications.handle(event, question: question, texts: texts, menu: menuTexts,
                             title: FeatureStrings.timeTracking(language).title)
        events.send(event)
    }
}

/// The real system state: session dictionary, input idle time, power assertions.
private struct TimeTrackingLiveProbe: TimeTrackingSystemProbe {
    var isScreenLocked: Bool {
        TimeTrackingSystemState.isLocked(session: CGSessionCopyCurrentDictionary() as? [String: Any])
    }

    /// Needs no permission: only the time of the last input is read, never the input.
    var secondsSinceInput: Int {
        // kCGAnyInputEventType
        let anyInput = CGEventType(rawValue: ~0)!
        return TimeTrackingSystemState.seconds(
            sinceInput: CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput))
    }

    var displayKeptAwake: Bool {
        var status: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsStatus(&status) == kIOReturnSuccess,
              let assertions = status?.takeRetainedValue() as? [String: Any] else { return false }
        return TimeTrackingSystemState.displayKeptAwake(assertions: assertions)
    }
}
