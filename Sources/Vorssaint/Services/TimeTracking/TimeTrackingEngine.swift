// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation
import os

// The runtime of Time Tracking without AppKit: what Tagwerk's `menubar.rs`
// does on its events, its 15 s tick, at startup and for the menu actions,
// around one `TTTracker`. `TimeTrackingService` feeds it the system events and
// publishes its state; the clock, the system state (lock, idle input,
// assertions) and the database come in through small protocols so the tests
// can drive it without real events.

// MARK: Clock

/// Where "now" comes from: the local wall-clock time, like Tagwerk's naive
/// local time, and a monotonic clock for how long ago the last save was.
protocol TimeTrackingClock {
    func now() -> TTDateTime
    /// Seconds on a monotonic clock (only differences matter).
    func uptime() -> TimeInterval
}

/// The real clock: the only place where Time Tracking reads `Date()`.
struct TimeTrackingSystemClock: TimeTrackingClock {
    func now() -> TTDateTime {
        TTDateTime(local: Date(), timeZone: .autoupdatingCurrent)
    }

    func uptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}

extension TTDateTime {
    /// The wall-clock time of `instant` in `timeZone`, always as a Gregorian
    /// date whatever calendar the user chose. Daylight saving time is not
    /// handled, as in Tagwerk (plan E6): the clock simply jumps.
    init(local instant: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: instant)
        let date = TTDate(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
            ?? TTDate(year: 1970, month: 1, day: 1)!
        let secs = (c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0)
        self.init(date, secs.ttClamped(0, TTLimits.dayEnd - 1))
    }
}

// MARK: System state

/// What the runtime asks the system: is the screen locked, how long since the
/// last input, does something keep the display awake.
protocol TimeTrackingSystemProbe {
    /// Locked, or this session is not the one on screen (`menubar.rs` `screen_locked`).
    var isScreenLocked: Bool { get }
    /// Seconds since the last keyboard, mouse or trackpad input in this session.
    var secondsSinceInput: Int { get }
    /// An app keeps the display awake (video call, presentation, film).
    var displayKeptAwake: Bool { get }
}

/// The decisions about the system state, as pure functions.
enum TimeTrackingSystemState {
    /// The power assertions that mean someone is probably watching the screen.
    static let displayAssertions = ["PreventUserIdleDisplaySleep", "NoDisplaySleepAssertion"]

    /// Locked when the session says so, or when it is not on the console (fast
    /// user switching); a missing value counts as unlocked and on the console.
    static func isLocked(session: [String: Any]?) -> Bool {
        KeepAwakeAutomationSupport.isScreenLocked(sessionDictionary: session)
            || !SessionActivitySupport.isOnConsole(session)
    }

    /// Does `IOPMCopyAssertionsStatus` report a display assertion above zero?
    static func displayKeptAwake(assertions: [String: Any]?) -> Bool {
        guard let assertions else { return false }
        return displayAssertions.contains { (assertions[$0] as? NSNumber).map { $0.intValue > 0 } ?? false }
    }

    /// Whole seconds from `CGEventSource.secondsSinceLastEventType` (never negative).
    static func seconds(sinceInput raw: Double) -> Int {
        raw.isFinite ? Int(Swift.max(raw, 0)) : 0
    }

    /// Idle seconds that count against `limit` (0: idle detection off). None
    /// while locked (the lock handles it) or while something keeps the
    /// display awake (someone is probably watching). The system is only asked
    /// what is needed.
    static func idleSeconds(limit: Int, locked: Bool, displayKeptAwake: () -> Bool,
                            secondsSinceInput: () -> Int) -> Int {
        limit > 0 && !locked && !displayKeptAwake() ? secondsSinceInput() : 0
    }
}

// MARK: Storage

/// The part of `TimeTrackingDatabase` the runtime uses.
protocol TimeTrackingStore: AnyObject {
    func load() throws -> [TTDay]
    func loadSettings(defaults: UserDefaults) throws -> TTSettings
    func saveDays(_ days: [TTDay], removed: [TTDate], now: TTDateTime) throws
    func editDay(_ date: TTDate, now: TTDateTime, _ change: (inout TTDay) throws -> Void) throws
}

extension TimeTrackingDatabase: TimeTrackingStore {}

/// The database failed. It stays until exactly that works again.
struct TimeTrackingDatabaseFault: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        /// The database cannot be opened (recording does not start).
        case open
        /// Reading failed (changes from the records window are missing).
        case read
        /// Saving failed (the time keeps counting, saved once it works again).
        case write
    }

    let kind: Kind
    let message: String

    /// The same for the pure texts of `TTMenu`.
    var failure: TTDatabaseFailure {
        switch kind {
        case .open: return .open
        case .read: return .read
        case .write: return .write
        }
    }
}

// MARK: Events and state

/// Something the user should hear about; M4 turns these into notifications.
enum TimeTrackingEvent: Equatable {
    /// Where a start or end of work cut work away from the Mac.
    enum Place: Equatable { case beforeStart, afterEnd }
    /// Which entry was refused.
    enum Entry: Equatable { case start, end }

    /// Work away from the Mac ran unended until midnight and now ends with the
    /// frame (`menubar.rs` `report_forgotten_away`); reported when someone is
    /// at the Mac again.
    case forgottenAway(TTForgottenAway)
    /// A start or end of work cut work away from the Mac (the latest entry wins).
    case workCut([TTWorkBlock], Place)
    /// A start or end of work was refused.
    case entryRefused(Entry, TTRefused)
    /// Recording resumed after the Mac was locked or asleep since `from`; the
    /// question after a long lock (`menubar.rs` `ask_about_lock`) decides on it.
    case resumedAfterLock(from: TTDateTime, to: TTDateTime)
    /// The database failed; `first` when no error stood before (Tagwerk
    /// notifies only then).
    case databaseError(TimeTrackingDatabaseFault, first: Bool)
}

/// What the menu bar section shows (state after the last event or tick).
struct TimeTrackingSnapshot: Equatable {
    /// Today.
    var date: TTDate
    var status: TTStatus
    var today: TTTodayInfo
    /// Today's breaks, for "Count a break as working time".
    var pausesToday: [TTSpan]
    var isRunning: Bool
    var onBreak: Bool
    var onAway: Bool
    var onIdle: Bool
    /// Free day: does the recorded time count (`nil`: no free day)?
    var counting: Bool?
    var settings: TTSettings
    /// Status line, actions and time choices of the menu bar section.
    var menu: TTMenuModel
}

// MARK: Engine

/// Tagwerk's menu bar app without the menu bar: startup, events, tick,
/// actions and saving around one tracker. Main thread only.
final class TimeTrackingEngine {
    /// How often the tick runs (`menubar.rs`: 15 s).
    static let tickInterval: TimeInterval = 15
    /// Running time or work away from the Mac is saved at least this often.
    static let saveInterval: TimeInterval = 60

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "TimeTracking")

    private(set) var tracker: TTTracker
    private(set) var databaseFault: TimeTrackingDatabaseFault?
    private let store: TimeTrackingStore
    private let defaults: UserDefaults
    private let clock: TimeTrackingClock
    private let probe: TimeTrackingSystemProbe
    private let texts: () -> TimeTrackingTexts
    private let menuTexts: () -> TimeTrackingMenuTexts
    private let onEvent: (TimeTrackingEvent) -> Void
    private var lastSave: TimeInterval

    /// Loads the days and settings, restores what ran before the restart and
    /// saves (`menubar.rs` startup). A failed read leaves an empty state and
    /// the fault, as in Tagwerk.
    init(store: TimeTrackingStore, defaults: UserDefaults, clock: TimeTrackingClock,
         probe: TimeTrackingSystemProbe, texts: @escaping () -> TimeTrackingTexts,
         menuTexts: @escaping () -> TimeTrackingMenuTexts = { .enUS },
         onEvent: @escaping (TimeTrackingEvent) -> Void = { _ in }) {
        self.store = store
        self.defaults = defaults
        self.clock = clock
        self.probe = probe
        self.texts = texts
        self.menuTexts = menuTexts
        self.onEvent = onEvent
        var fault: TimeTrackingDatabaseFault?
        let days: [TTDay]
        do {
            days = try store.load()
        } catch {
            fault = TimeTrackingDatabaseFault(kind: .read, message: String(describing: error))
            days = []
        }
        let settings: TTSettings
        do {
            settings = try store.loadSettings(defaults: defaults)
        } catch {
            fault = fault ?? TimeTrackingDatabaseFault(kind: .read, message: String(describing: error))
            settings = TTPreferences.read(from: defaults)
        }
        databaseFault = fault
        if let fault {
            Self.log.error("Time Tracking could not read its data: \(fault.message, privacy: .public)")
        }
        tracker = TTTracker(days: days, settings: settings, texts: texts())
        lastSave = clock.uptime()
        let t = clock.now()
        tracker.rollOver(t)
        let restart = defaults.string(forKey: DefaultsKey.timeTrackingRestartState).flatMap(TTStatus.init(line:))
        Self.restore(&tracker, status: restart, now: t, locked: probe.isScreenLocked)
        persist(t)
    }

    /// What ran before the restart (`menubar.rs` startup): a break through
    /// "Pause work" on the same day comes back only while unlocked, work away
    /// from the Mac on the same day also while locked. Otherwise recording
    /// starts, or pauses as locked, or as manual when it cannot start.
    static func restore(_ tracker: inout TTTracker, status: TTStatus?, now: TTDateTime, locked: Bool) {
        if case let .away(since, activity) = status, since <= now, since.date == now.date {
            tracker.restoreAway(since: since, activity: activity)
        } else if case let .onBreak(since) = status, !locked, since <= now, since.date == now.date {
            tracker.restoreBreak(since: since)
        } else if locked || !tracker.start(now) {
            tracker.pauseReason = locked ? .locked : .manual
            tracker.pausedSince = now
        }
    }

    /// The state for the display.
    func snapshot() -> TimeTrackingSnapshot {
        let t = begin()
        let today = tracker.today(t)
        let pauses = tracker.pausesToday(t)
        return TimeTrackingSnapshot(date: t.date, status: tracker.status(t), today: today,
                                    pausesToday: pauses, isRunning: tracker.isRunning,
                                    onBreak: tracker.onBreak, onAway: tracker.onAway, onIdle: tracker.onIdle,
                                    counting: tracker.counting(t.date), settings: tracker.settings,
                                    menu: TTMenu.model(tracker, now: t, info: today, pauses: pauses,
                                                       texts: tracker.texts, menu: menuTexts()))
    }

    /// The question after the lock from `from` to `to`, if one is due
    /// (`menubar.rs` `ask_about_lock`); asked right after recording resumed.
    func lockQuestion(from: TTDateTime, to: TTDateTime) -> TTLockQuestion? {
        TTLockQuestion.ask(tracker, from: from, to: to)
    }

    func now() -> TTDateTime { clock.now() }

    // MARK: Tick

    /// Every 15 s (`menubar.rs` `tick`): day change, safety net for a missed
    /// lock, idle detection, restart after idle, saving when something
    /// changed or at least every minute while time is running, and the
    /// forgotten "Back at the Mac".
    func tick() {
        let t = begin()
        var dirty = tracker.rollOver(t)
        let locked = probe.isScreenLocked
        let limit = tracker.settings.idleSecs
        let probe = self.probe
        let idle = TimeTrackingSystemState.idleSeconds(limit: limit, locked: locked,
                                                       displayKeptAwake: { probe.displayKeptAwake },
                                                       secondsSinceInput: { probe.secondsSinceInput })
        let leftAlone = limit > 0 && idle >= limit
        if tracker.isRunning && locked {
            // Safety net in case a lock event was missed.
            dirty = tracker.stop(t, reason: .locked) || dirty
        } else if tracker.isRunning && leftAlone {
            // Backwards from the last input, like a lock.
            dirty = tracker.goIdle(lastInput: t.adding(seconds: -idle)) || dirty
        } else if !tracker.isRunning && !locked && !tracker.onBreak && !tracker.onAway
                    && !(tracker.onIdle && leftAlone) && tracker.pausedSince != nil {
            // Unlocked but not recording (back after idle, say, also when it
            // began yesterday and the Mac was never locked overnight).
            dirty = tracker.start(t) || dirty
        }
        // Work away from the Mac is saved regularly too, not only at its end.
        let ongoing = tracker.isRunning || tracker.onAway
        if dirty || (ongoing && clock.uptime() - lastSave >= Self.saveInterval) {
            persist(t)
        }
        if !locked { reportForgottenAway() }
    }

    // MARK: System events

    func screenLocked() { pause(for: .locked) }
    func willSleep() { pause(for: .sleep) }
    func sessionResigned() { pause(for: .sessionInactive) }

    func screenUnlocked() { resume() }

    /// Without a password prompt no unlock event comes after waking: resume here.
    func didWake() {
        if !probe.isScreenLocked { resume() }
    }

    func sessionBecameActive() {
        if !probe.isScreenLocked { resume() }
    }

    /// Log out, restart, shut down: a break through "Pause work" and work away
    /// from the Mac end with it (after logging in recording starts again).
    /// Quitting the app alone keeps them.
    func willPowerOff() {
        let t = begin()
        if tracker.onBreak { tracker.pauseReason = .manual }
        // Work away from the Mac ends as well (it counts until now).
        tracker.endAway(t)
        shutdown()
    }

    /// Before the app quits or the feature turns off: the running period ends
    /// now and is saved. A break and work away from the Mac stay (restart state).
    func shutdown() {
        let t = begin()
        tracker.stop(t, reason: .manual)
        persist(t)
    }

    private func pause(for reason: TTPauseReason) {
        let t = begin()
        tracker.stop(t, reason: reason)
        persist(t)
    }

    /// Resumes after an unlock or wake. Also after the end of work recording
    /// goes on (nothing of it counts while the end stands).
    private func resume() {
        let t = begin()
        tracker.rollOver(t)
        let lockedSince = tracker.lockedSince
        if tracker.start(t) {
            persist(t)
            if let from = lockedSince { onEvent(.resumedAfterLock(from: from, to: t)) }
        }
        reportForgottenAway()
    }

    // MARK: Actions

    /// "Pause work" ↔ "Resume work"; while away from the Mac "Back at the Mac".
    /// On a free day that does not count there is nothing to pause, only to
    /// end what already runs; after the end of work neither.
    func togglePause() {
        act { tracker, t, _ in
            let endsSomething = tracker.onAway || tracker.onBreak
            if (tracker.counting(t.date) == false && !endsSomething) || tracker.mode(t) != .auto { return }
            if tracker.isRunning {
                tracker.takeBreak(t)
            } else {
                tracker.start(t)
            }
        }
    }

    /// "Keep working away from the Mac".
    func goAway(_ activity: TTActivity) {
        act { tracker, t, _ in tracker.goAway(t, activity: activity) }
    }

    /// Counts one of today's breaks (the one starting at `pause.from`) as work
    /// away from the Mac.
    func countPauseAsWork(_ pause: TTSpan, activity: TTActivity) {
        act { tracker, t, _ in
            guard let p = tracker.pausesToday(t).first(where: { $0.from == pause.from }) else { return }
            tracker.addWork(t.date, from: p.from, to: p.to, note: activity.note(tracker.texts))
        }
    }

    /// Sets today's start of work (`nil`: the first unlock again).
    @discardableResult
    func setStart(at: Int?) -> Result<[TTWorkBlock], TTRefused> {
        var result: Result<[TTWorkBlock], TTRefused> = .success([])
        act { tracker, t, _ in result = tracker.setStart(t, at: at) }
        report(result, place: .beforeStart, entry: .start)
        return result
    }

    /// Ends today's work at `at` (seconds since midnight, at most now).
    @discardableResult
    func closeDay(at: Int) -> Result<[TTWorkBlock], TTRefused> {
        var result: Result<[TTWorkBlock], TTRefused> = .success([])
        act { tracker, t, _ in result = tracker.closeDay(t, at: at) }
        report(result, place: .afterEnd, entry: .end)
        return result
    }

    /// Takes today's end of work back and records again if unlocked.
    func reopenDay() {
        act { tracker, t, locked in
            tracker.reopenDay(t)
            if !locked { tracker.start(t) }
        }
    }

    /// "Record today" on a free day. After all entries were deleted recording
    /// was off: from now on again.
    func setCounting(_ on: Bool) {
        act { tracker, t, locked in
            tracker.setCounting(t.date, on: on)
            if on && !locked { tracker.start(t) }
        }
    }

    /// Enters work away from the Mac (week view, the answer to the lock question).
    func addWork(date: TTDate, from: Int, to: Int, activity: TTActivity) {
        act { tracker, _, _ in tracker.addWork(date, from: from, to: to, note: activity.note(tracker.texts)) }
    }

    /// Deletes work away from the Mac; if it was the running one, recording
    /// starts again from now (if unlocked).
    func removeWork(date: TTDate, from: Int, to: Int) {
        act { tracker, t, locked in
            if tracker.removeWork(date, from: from, to: to, now: t) && !locked { tracker.start(t) }
        }
    }

    /// Changes a day in the database (records window) and takes it over: the
    /// running state is saved first, then the day is edited, read back and
    /// merged with what runs (`tracker.rs` `replace_days`). Errors of the edit
    /// itself are thrown; nothing changed then.
    func editDay(_ date: TTDate, _ change: (inout TTDay) throws -> Void) throws {
        let t = begin()
        tracker.rollOver(t)
        persist(t)
        try store.editDay(date, now: t, change)
        reload(t)
        persist(t)
    }

    /// Reads days and settings again after the settings or the database
    /// changed (settings window, import), so a changed free day applies at once.
    func reload() {
        let t = begin()
        tracker.rollOver(t)
        persist(t)
        reload(t)
        persist(t)
    }

    // MARK: Internals

    /// "Now", with the notes in the app's current language.
    private func begin() -> TTDateTime {
        tracker.texts = texts()
        return clock.now()
    }

    /// A manual action (`menubar.rs` `act`): roll over, change, save.
    private func act(_ change: (inout TTTracker, TTDateTime, Bool) -> Void) {
        let t = begin()
        tracker.rollOver(t)
        change(&tracker, t, probe.isScreenLocked)
        persist(t)
    }

    private func report(_ result: Result<[TTWorkBlock], TTRefused>, place: TimeTrackingEvent.Place,
                        entry: TimeTrackingEvent.Entry) {
        switch result {
        case let .success(cut) where !cut.isEmpty: onEvent(.workCut(cut, place))
        case let .failure(why): onEvent(.entryRefused(entry, why))
        case .success: break
        }
    }

    @discardableResult
    private func reload(_ t: TTDateTime) -> Bool {
        do {
            let days = try store.load()
            let settings = try store.loadSettings(defaults: defaults)
            tracker.replaceDays(days, settings: settings, now: t)
            clearFault(.read)
            return true
        } catch {
            reportFault(.read, error)
            return false
        }
    }

    /// Saves the changed days and the restart state (`menubar.rs` `persist`).
    private func persist(_ t: TTDateTime) {
        let store = self.store
        do {
            try tracker.save(t) { try store.saveDays($0, removed: $1, now: t) }
            // The whole state is saved each time: nothing was lost.
            clearFault(.write)
        } catch {
            reportFault(.write, error)
        }
        defaults.set(tracker.status(t).line, forKey: DefaultsKey.timeTrackingRestartState)
        lastSave = clock.uptime()
    }

    private func reportForgottenAway() {
        guard let forgotten = tracker.forgotten else { return }
        tracker.forgotten = nil
        onEvent(.forgottenAway(forgotten))
    }

    private func reportFault(_ kind: TimeTrackingDatabaseFault.Kind, _ error: Error) {
        let fault = TimeTrackingDatabaseFault(kind: kind, message: String(describing: error))
        let first = databaseFault == nil
        databaseFault = fault
        Self.log.error("Time Tracking database failed: \(fault.message, privacy: .public)")
        onEvent(.databaseError(fault, first: first))
    }

    private func clearFault(_ kind: TimeTrackingDatabaseFault.Kind) {
        if databaseFault?.kind == kind { databaseFault = nil }
    }
}
