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

    /// Forgotten "Back at the Mac", cut work away from the Mac, refused
    /// entries, the end of a lock and database errors, for the notifications
    /// of M4. Delivered on the main thread.
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

    private init() {}

    /// Called by the hub, by the settings switch and at launch. Active iff
    /// the feature is installed and its switch is on.
    func syncWithPreferences() {
        let active = AppFeature.timeTracking.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.timeTrackingEnabled)
        if active {
            if engine == nil { activate() }
        } else if engine != nil || databaseFault != nil {
            deactivate()
        }
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

    // MARK: Lifecycle

    private func activate() {
        let database: TimeTrackingDatabase
        do {
            database = try TimeTrackingDatabase.openDefault()
        } catch {
            let fault = TimeTrackingDatabaseFault(kind: .open, message: String(describing: error))
            Self.log.error("Time Tracking cannot open its database: \(fault.message, privacy: .public)")
            databaseFault = fault
            events.send(.databaseError(fault, first: true))
            return
        }
        self.database = database
        engine = TimeTrackingEngine(store: database, defaults: .standard, clock: clock, probe: probe,
                                    texts: { FeatureStrings.timeTrackingTexts(L10n.shared.language) },
                                    onEvent: { [weak self] in self?.events.send($0) })
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
        if snapshot != self.snapshot { self.snapshot = snapshot }
        if engine.databaseFault != databaseFault { databaseFault = engine.databaseFault }
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
