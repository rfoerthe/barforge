// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import CoreGraphics
import Foundation

/// The runtime around the tracker (Barforge's counterpart of the event, tick
/// and startup parts of Tagwerk's `menubar.rs`), driven by a manual clock, a
/// fake system state and a store in memory instead of real system events.
enum TimeTrackingEngineTests {
    static func run(_ suite: TestSuite) {
        systemStateDecisions(suite)
        localClockIsGregorianWallTime(suite)
        restartStateRestoreDecisions(suite)
        restartStateIsMachineState(suite)
        startupRecordsAndSavesEveryMinute(suite)
        lockAndUnlockEvents(suite)
        tickSafetyNetStopsWhenLocked(suite)
        idleStopsAtLastInputAndRestarts(suite)
        displayAssertionSuspendsIdle(suite)
        breakSurvivesQuitButNotPowerOff(suite)
        awaySurvivesQuitEvenWhenLocked(suite)
        forgottenAwayIsReportedWhenBackAtTheMac(suite)
        refusedAndCutEntriesAreReported(suite)
        writeFailuresKeepCountingAndRetry(suite)
        readFailureAtStartupIsKept(suite)
        editDayMergesWithWhatRuns(suite)
        reloadAppliesChangedSettings(suite)
        actionsFollowTheMenu(suite)
    }

    static func dt(_ d: Int, _ hh: Int, _ mm: Int) -> TTDateTime { TimeTrackingTrackerTests.dt(d, hh, mm) }
    static func date(_ d: Int) -> TTDate { TimeTrackingTrackerTests.date(d) }
    static func hm(_ hh: Int, _ mm: Int) -> Int { hh * 3600 + mm * 60 }

    /// Wall-clock time and uptime advance together.
    final class Clock: TimeTrackingClock {
        var current: TTDateTime
        var up: TimeInterval = 1000

        init(_ start: TTDateTime) { current = start }

        func now() -> TTDateTime { current }
        func uptime() -> TimeInterval { up }

        func set(_ time: TTDateTime) {
            let seconds = (time.date.ordinal - current.date.ordinal) * TTLimits.dayEnd + time.secs - current.secs
            up += TimeInterval(Swift.max(seconds, 0))
            current = time
        }
    }

    final class Probe: TimeTrackingSystemProbe {
        var locked = false
        var idle = 0
        var keptAwake = false
        private(set) var idleQueries = 0

        var isScreenLocked: Bool { locked }
        var secondsSinceInput: Int {
            idleQueries += 1
            return idle
        }
        var displayKeptAwake: Bool { keptAwake }
    }

    struct Failure: Error, CustomStringConvertible {
        var description: String { "disk full" }
    }

    /// The database in memory, written whole days at a time like the real one.
    final class Store: TimeTrackingStore {
        var days: [TTDay]
        var settings: TTSettings
        var failWrites = false
        var failReads = false
        private(set) var writes = 0

        init(_ days: [TTDay] = [], settings: TTSettings = TTSettings()) {
            self.days = days
            self.settings = settings
        }

        func load() throws -> [TTDay] {
            if failReads { throw Failure() }
            return days
        }

        func loadSettings(defaults: UserDefaults) throws -> TTSettings {
            if failReads { throw Failure() }
            return settings
        }

        func saveDays(_ changed: [TTDay], removed: [TTDate], now: TTDateTime) throws {
            if failWrites { throw Failure() }
            if changed.isEmpty && removed.isEmpty { return }
            writes += 1
            for day in changed {
                days.removeAll { $0.date == day.date }
                if !day.isEmpty { days.append(day) }
            }
            days.removeAll { removed.contains($0.date) }
            days.sort { $0.date < $1.date }
        }

        func editDay(_ date: TTDate, now: TTDateTime, _ change: (inout TTDay) throws -> Void) throws {
            if failWrites { throw Failure() }
            var copy = days
            let i = TTDay.index(of: date, in: &copy)
            try change(&copy[i])
            copy.removeAll { $0.isEmpty }
            days = copy
            writes += 1
        }

        func day(_ date: TTDate) -> TTDay? { days.first { $0.date == date } }
    }

    /// One engine with its fakes and the events it sent.
    final class Rig {
        let clock: Clock
        let probe = Probe()
        let store: Store
        let defaults: UserDefaults
        private(set) var engine: TimeTrackingEngine!
        var events: [TimeTrackingEvent] = []

        init(_ start: TTDateTime, store: Store = Store(), defaults: UserDefaults, locked: Bool = false) {
            clock = Clock(start)
            self.store = store
            self.defaults = defaults
            probe.locked = locked
            restart()
        }

        /// A new engine on the same store and defaults, as after a restart of the app.
        func restart() {
            engine = TimeTrackingEngine(store: store, defaults: defaults, clock: clock, probe: probe,
                                        texts: { .de }, onEvent: { [unowned self] in events.append($0) })
        }

        var restartLine: String? { defaults.string(forKey: DefaultsKey.timeTrackingRestartState) }
        var status: TTStatus { engine.tracker.status(clock.current) }
        var workToday: Int { engine.tracker.today(clock.current).workSecs }
        var pauseToday: Int { engine.tracker.today(clock.current).pauseSecs }
    }

    static func withRig(_ start: TTDateTime, store: Store = Store(), locked: Bool = false,
                        _ body: (Rig) -> Void) {
        TimeTrackingStoreTests.withDefaults { defaults in
            body(Rig(start, store: store, defaults: defaults, locked: locked))
        }
    }

    static func idleSettings(_ seconds: Int) -> TTSettings {
        var s = TTSettings()
        s.idleSecs = seconds
        return s
    }

    // MARK: Pure decisions

    private static func systemStateDecisions(_ suite: TestSuite) {
        typealias S = TimeTrackingSystemState
        suite.expect(!S.isLocked(session: nil), "system: no session dictionary counts as unlocked")
        suite.expect(S.isLocked(session: ["CGSSessionScreenIsLocked": true]), "system: locked screen")
        suite.expect(S.isLocked(session: ["CGSSessionScreenIsLocked": NSNumber(value: 1)]), "system: locked as number")
        suite.expect(S.isLocked(session: [kCGSessionOnConsoleKey as String: false]),
                     "system: a session off the console counts as locked")
        suite.expect(!S.isLocked(session: [kCGSessionOnConsoleKey as String: true,
                                           "CGSSessionScreenIsLocked": false]), "system: on the console, unlocked")

        suite.expect(!S.displayKeptAwake(assertions: nil), "assertions: none")
        suite.expect(S.displayKeptAwake(assertions: ["PreventUserIdleDisplaySleep": 1]), "assertions: video call")
        suite.expect(S.displayKeptAwake(assertions: ["NoDisplaySleepAssertion": NSNumber(value: 2)]),
                     "assertions: the old name")
        suite.expect(!S.displayKeptAwake(assertions: ["PreventUserIdleDisplaySleep": 0,
                                                      "PreventUserIdleSystemSleep": 1]),
                     "assertions: only display assertions above zero count")

        suite.expect(S.seconds(sinceInput: .nan) == 0 && S.seconds(sinceInput: .infinity) == 0
                     && S.seconds(sinceInput: -3) == 0 && S.seconds(sinceInput: 12.7) == 12,
                     "idle: whole, finite, never negative seconds")

        var asked = (awake: 0, input: 0)
        func idle(limit: Int, locked: Bool, awake: Bool, input: Int) -> Int {
            S.idleSeconds(limit: limit, locked: locked,
                          displayKeptAwake: { asked.awake += 1; return awake },
                          secondsSinceInput: { asked.input += 1; return input })
        }
        suite.expect(idle(limit: 0, locked: false, awake: false, input: 900) == 0 && asked == (0, 0),
                     "idle: off asks nothing")
        suite.expect(idle(limit: 600, locked: true, awake: false, input: 900) == 0 && asked == (0, 0),
                     "idle: locked asks nothing")
        suite.expect(idle(limit: 600, locked: false, awake: true, input: 900) == 0 && asked == (1, 0),
                     "idle: a display assertion means nobody left")
        suite.expect(idle(limit: 600, locked: false, awake: false, input: 900) == 900 && asked == (2, 1),
                     "idle: the seconds since the last input")
    }

    private static func localClockIsGregorianWallTime(_ suite: TestSuite) {
        // 2026-11-16 07:30:15 UTC; 16:00 UTC is already the 17th in Tokyo.
        let instant = Date(timeIntervalSince1970: 1_794_814_215)
        let utc = TTDateTime(local: instant, timeZone: TimeZone(identifier: "UTC")!)
        suite.expect(utc == TTDateTime(date(16), hour: 7, minute: 30, second: 15), "clock: UTC wall time, got \(utc)")
        let berlin = TTDateTime(local: instant, timeZone: TimeZone(identifier: "Europe/Berlin")!)
        suite.expect(berlin == TTDateTime(date(16), hour: 8, minute: 30, second: 15), "clock: Berlin wall time")
        let tokyo = TTDateTime(local: Date(timeIntervalSince1970: 1_794_844_800), timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        suite.expect(tokyo.date == date(17), "clock: the local date, not the UTC date")
    }

    private static func restartStateRestoreDecisions(_ suite: TestSuite) {
        func tracker(_ days: [TTDay] = []) -> TTTracker { TTTracker(days: days, settings: TTSettings(), texts: .de) }
        let now = dt(16, 13, 0)
        // Break on the same day: only while unlocked.
        var t = tracker()
        TimeTrackingEngine.restore(&t, status: .onBreak(since: dt(16, 12, 0)), now: now, locked: false)
        suite.expect(t.onBreak && t.pausedSince == dt(16, 12, 0), "restore: same-day break, unlocked")
        t = tracker()
        TimeTrackingEngine.restore(&t, status: .onBreak(since: dt(16, 12, 0)), now: now, locked: true)
        suite.expect(!t.onBreak && t.pauseReason == .locked && t.pausedSince == now, "restore: break while locked")
        // A break of yesterday is over: recording starts.
        t = tracker()
        TimeTrackingEngine.restore(&t, status: .onBreak(since: dt(15, 18, 0)), now: now, locked: false)
        suite.expect(t.isRunning && t.runningSince == now, "restore: yesterday's break is over")
        // Work away from the Mac on the same day: also while locked.
        t = tracker()
        TimeTrackingEngine.restore(&t, status: .away(since: dt(16, 12, 0), activity: .call), now: now, locked: true)
        suite.expect(t.onAway && t.away == .call && t.pausedSince == dt(16, 12, 0), "restore: away while locked")
        t = tracker()
        TimeTrackingEngine.restore(&t, status: .away(since: dt(15, 17, 0), activity: .call), now: now, locked: false)
        suite.expect(t.isRunning, "restore: yesterday's away is not restored")
        // A moment in the future (clock set back) is not trusted.
        t = tracker()
        TimeTrackingEngine.restore(&t, status: .away(since: dt(16, 14, 0), activity: .meeting), now: now, locked: false)
        suite.expect(t.isRunning, "restore: away from the future")
        // Nothing to restore: start, or pause as locked, or as manual when start refuses.
        t = tracker()
        TimeTrackingEngine.restore(&t, status: .running, now: now, locked: false)
        suite.expect(t.isRunning, "restore: running")
        t = tracker()
        TimeTrackingEngine.restore(&t, status: nil, now: now, locked: true)
        suite.expect(!t.isRunning && t.pauseReason == .locked && t.pausedSince == now, "restore: locked")
        var vacation = TTDay(date: date(16))
        vacation.absence = TTAbsence(.vacation, half: false)
        t = tracker([vacation])
        TimeTrackingEngine.restore(&t, status: nil, now: now, locked: false)
        suite.expect(!t.isRunning && t.pauseReason == .manual && t.pausedSince == now, "restore: start refused")
    }

    private static func restartStateIsMachineState(_ suite: TestSuite) {
        let key = DefaultsKey.timeTrackingRestartState
        suite.expect(SettingsBackupSupport.machineStateKeys.contains(key)
                     && !SettingsBackupSupport.exportKeys().contains(key)
                     && Defaults.registeredDefaults[key] == nil,
                     "restart state: unregistered machine state, never exported")
    }

    // MARK: Engine

    private static func startupRecordsAndSavesEveryMinute(_ suite: TestSuite) {
        withRig(dt(16, 8, 0)) { rig in
            suite.expect(rig.status == .running && rig.restartLine == "running", "startup: records at once")
            let writes = rig.store.writes
            rig.clock.set(dt(16, 8, 0).adding(seconds: 15))
            rig.engine.tick()
            suite.expect(rig.store.writes == writes, "startup: no save within the minute")
            rig.clock.set(dt(16, 8, 1).adding(seconds: 15))
            rig.engine.tick()
            suite.expect(rig.store.writes == writes + 1, "startup: saved after a minute")
            suite.expect(rig.store.day(date(16))?.periods == [TTSpan(hm(8, 0), hm(8, 1) + 15)],
                         "startup: the running period up to now")
            // Nothing running: no save every minute.
            rig.engine.screenLocked()
            let locked = rig.store.writes
            rig.probe.locked = true
            rig.clock.set(dt(16, 9, 0))
            rig.engine.tick()
            suite.expect(rig.store.writes == locked, "startup: no regular save while nothing runs")
        }
    }

    private static func lockAndUnlockEvents(_ suite: TestSuite) {
        withRig(dt(16, 8, 0)) { rig in
            rig.clock.set(dt(16, 12, 0))
            rig.probe.locked = true
            rig.engine.screenLocked()
            suite.expect(rig.store.day(date(16))?.periods == [TTSpan(hm(8, 0), hm(12, 0))], "lock: saved at once")
            suite.expect(rig.restartLine == "paused", "lock: restart state")
            rig.clock.set(dt(16, 12, 40))
            rig.probe.locked = false
            rig.engine.screenUnlocked()
            suite.expect(rig.status == .running, "unlock: records again")
            suite.expect(rig.events == [.resumedAfterLock(from: dt(16, 12, 0), to: dt(16, 12, 40))],
                         "unlock: the lock is reported for the question")
            rig.clock.set(dt(16, 13, 0))
            suite.expect(rig.pauseToday == hm(0, 40), "unlock: the lock is a break")
            // Sleep, then waking without a password prompt resumes; still locked it waits.
            rig.clock.set(dt(16, 14, 0))
            rig.engine.willSleep()
            suite.expect(rig.engine.tracker.pauseReason == .sleep, "sleep: stopped")
            rig.probe.locked = true
            rig.clock.set(dt(16, 14, 30))
            rig.engine.didWake()
            suite.expect(!rig.engine.tracker.isRunning, "wake: waits for the unlock")
            rig.probe.locked = false
            rig.engine.didWake()
            suite.expect(rig.engine.tracker.isRunning, "wake: resumes when unlocked")
            // Fast user switching.
            rig.clock.set(dt(16, 15, 0))
            rig.engine.sessionResigned()
            suite.expect(rig.engine.tracker.pauseReason == .sessionInactive, "session: stopped")
            rig.engine.sessionBecameActive()
            suite.expect(rig.engine.tracker.isRunning, "session: resumed")
        }
    }

    private static func tickSafetyNetStopsWhenLocked(_ suite: TestSuite) {
        withRig(dt(16, 8, 0)) { rig in
            // The lock event was missed.
            rig.probe.locked = true
            rig.clock.set(dt(16, 10, 0))
            rig.engine.tick()
            suite.expect(!rig.engine.tracker.isRunning && rig.engine.tracker.pauseReason == .locked,
                         "safety net: stopped as locked")
            suite.expect(rig.store.day(date(16))?.periods == [TTSpan(hm(8, 0), hm(10, 0))], "safety net: saved")
            // Unlocked without an event: the tick starts again.
            rig.probe.locked = false
            rig.clock.set(dt(16, 10, 30))
            rig.engine.tick()
            suite.expect(rig.engine.tracker.isRunning, "safety net: restarted by the tick")
        }
    }

    private static func idleStopsAtLastInputAndRestarts(_ suite: TestSuite) {
        withRig(dt(16, 8, 0), store: Store(settings: idleSettings(600))) { rig in
            rig.clock.set(dt(16, 10, 12))
            rig.probe.idle = 12 * 60
            rig.engine.tick()
            suite.expect(rig.engine.tracker.onIdle && rig.engine.tracker.pausedSince == dt(16, 10, 0),
                         "idle: stopped at the last input")
            // Still nobody there: no restart.
            rig.clock.set(dt(16, 10, 30))
            rig.probe.idle = 30 * 60
            rig.engine.tick()
            suite.expect(rig.engine.tracker.onIdle, "idle: stays stopped while nobody is there")
            // Input again: recording restarts, the time away is a break.
            rig.clock.set(dt(16, 10, 40))
            rig.probe.idle = 2
            rig.engine.tick()
            suite.expect(rig.engine.tracker.isRunning, "idle: restarted at the next input")
            rig.clock.set(dt(16, 11, 0))
            suite.expect(rig.workToday == hm(2, 20) && rig.pauseToday == hm(0, 40), "idle: a break from the last input")
            suite.expect(rig.engine.tracker.lockedSince == nil && rig.events.isEmpty, "idle: no lock question")
        }
        // Idle detection off: never asked.
        withRig(dt(16, 8, 0)) { rig in
            rig.probe.idle = 5 * 3600
            rig.clock.set(dt(16, 13, 0))
            rig.engine.tick()
            suite.expect(rig.engine.tracker.isRunning && rig.probe.idleQueries == 0, "idle: off by default")
        }
    }

    private static func displayAssertionSuspendsIdle(_ suite: TestSuite) {
        withRig(dt(16, 8, 0), store: Store(settings: idleSettings(600))) { rig in
            rig.probe.keptAwake = true
            rig.probe.idle = 3600
            rig.clock.set(dt(16, 9, 0))
            rig.engine.tick()
            suite.expect(rig.engine.tracker.isRunning && rig.probe.idleQueries == 0,
                         "assertion: a video call keeps recording without input")
            rig.probe.keptAwake = false
            rig.engine.tick()
            suite.expect(rig.engine.tracker.onIdle && rig.engine.tracker.pausedSince == dt(16, 8, 0),
                         "assertion: once it ends, idle counts back to the last input")
        }
    }

    private static func breakSurvivesQuitButNotPowerOff(_ suite: TestSuite) {
        withRig(dt(16, 8, 0)) { rig in
            rig.clock.set(dt(16, 12, 0))
            rig.engine.togglePause()
            suite.expect(rig.engine.tracker.onBreak, "break: taken")
            rig.clock.set(dt(16, 12, 5))
            rig.engine.shutdown()
            suite.expect(rig.restartLine == "break 2026-11-16T12:00:00", "break: kept for the restart")
            rig.clock.set(dt(16, 12, 10))
            rig.restart()
            suite.expect(rig.status == .onBreak(since: dt(16, 12, 0)), "break: restored after the restart")
            // Back: the whole break counts as a break.
            rig.clock.set(dt(16, 12, 45))
            rig.engine.togglePause()
            rig.clock.set(dt(16, 13, 0))
            suite.expect(rig.engine.tracker.isRunning && rig.pauseToday == hm(0, 45), "break: resumed")
            // Log out during a break: it ends; after logging in recording starts.
            rig.clock.set(dt(16, 15, 0))
            rig.engine.togglePause()
            rig.engine.willPowerOff()
            suite.expect(rig.restartLine == "paused", "power off: the break ends")
            rig.clock.set(dt(16, 15, 30))
            rig.restart()
            suite.expect(rig.engine.tracker.isRunning, "power off: recording after logging in")
        }
        // Restarted while locked: the break is not restored.
        withRig(dt(16, 8, 0)) { rig in
            rig.clock.set(dt(16, 12, 0))
            rig.engine.togglePause()
            rig.engine.shutdown()
            rig.probe.locked = true
            rig.restart()
            suite.expect(!rig.engine.tracker.onBreak && rig.engine.tracker.pauseReason == .locked,
                         "break: not restored while locked")
        }
    }

    private static func awaySurvivesQuitEvenWhenLocked(_ suite: TestSuite) {
        withRig(dt(16, 8, 0)) { rig in
            rig.clock.set(dt(16, 12, 0))
            rig.engine.goAway(.meeting)
            rig.probe.locked = true
            rig.engine.screenLocked()
            suite.expect(rig.engine.tracker.onAway, "away: the lock changes nothing")
            // Saved regularly while away, even locked.
            rig.clock.set(dt(16, 12, 30))
            rig.engine.tick()
            suite.expect(rig.store.day(date(16))?.work == [TTWorkBlock(from: hm(12, 0), to: hm(12, 30), note: "Meeting")],
                         "away: saved while locked")
            rig.clock.set(dt(16, 13, 0))
            rig.engine.shutdown()
            suite.expect(rig.restartLine == "away 2026-11-16T12:00:00 meeting", "away: kept for the restart")
            rig.clock.set(dt(16, 13, 10))
            rig.restart()
            suite.expect(rig.status == .away(since: dt(16, 12, 0), activity: .meeting), "away: restored while locked")
            // Shut down while away: it ends now and is entered.
            rig.clock.set(dt(16, 14, 0))
            rig.engine.willPowerOff()
            suite.expect(rig.store.day(date(16))?.work == [TTWorkBlock(from: hm(12, 0), to: hm(14, 0), note: "Meeting")],
                         "power off: away entered until now")
            suite.expect(!rig.engine.tracker.onAway, "power off: away ended")
        }
    }

    private static func forgottenAwayIsReportedWhenBackAtTheMac(_ suite: TestSuite) {
        withRig(dt(16, 8, 0)) { rig in
            rig.clock.set(dt(16, 17, 0))
            rig.engine.goAway(.meeting)
            rig.probe.locked = true
            rig.engine.screenLocked()
            // Midnight passes while locked: ended, but not reported yet.
            rig.clock.set(dt(17, 0, 0).adding(seconds: 10))
            rig.engine.tick()
            suite.expect(!rig.engine.tracker.onAway && rig.events.isEmpty, "forgotten: nobody there to tell")
            suite.expect(rig.store.day(date(16))?.work.first?.to == hm(22, 0), "forgotten: ends with the frame")
            rig.clock.set(dt(17, 7, 30))
            rig.probe.locked = false
            rig.engine.screenUnlocked()
            let block = TTWorkBlock(from: hm(17, 0), to: hm(22, 0), note: "Meeting")
            suite.expect(rig.events == [.forgottenAway(TTForgottenAway(date: date(16), block: block))],
                         "forgotten: reported once at the unlock")
            rig.engine.tick()
            suite.expect(rig.events.count == 1, "forgotten: only once")
        }
    }

    private static func refusedAndCutEntriesAreReported(_ suite: TestSuite) {
        withRig(dt(16, 8, 0)) { rig in
            rig.clock.set(dt(16, 8, 5))
            rig.engine.goAway(.meeting)
            rig.clock.set(dt(16, 9, 0))
            rig.engine.screenUnlocked()
            rig.clock.set(dt(16, 10, 0))
            let cut = rig.engine.setStart(at: hm(9, 20))
            let blocks = [TTWorkBlock(from: hm(8, 5), to: hm(9, 0), note: "Meeting")]
            suite.expect(cut == .success(blocks) && rig.events == [.workCut(blocks, .beforeStart)],
                         "entries: cut work away from the Mac is reported")
            rig.events.removeAll()
            let refused = rig.engine.closeDay(at: hm(9, 0))
            suite.expect(refused == .failure(.endNotAfterStart(hm(9, 20)))
                         && rig.events == [.entryRefused(.end, .endNotAfterStart(hm(9, 20)))],
                         "entries: a refused end of work is reported")
            rig.events.removeAll()
            rig.engine.setStart(at: nil)
            suite.expect(rig.events.isEmpty, "entries: resetting the start reports nothing")
        }
    }

    private static func writeFailuresKeepCountingAndRetry(_ suite: TestSuite) {
        withRig(dt(16, 8, 0)) { rig in
            rig.store.failWrites = true
            rig.clock.set(dt(16, 10, 0))
            rig.engine.screenLocked()
            suite.expect(rig.engine.databaseFault?.kind == .write, "write failure: kept")
            suite.expect(rig.events == [.databaseError(TimeTrackingDatabaseFault(kind: .write, message: "disk full"),
                                                       first: true)],
                         "write failure: reported as the first")
            rig.clock.set(dt(16, 10, 30))
            rig.engine.screenUnlocked()
            suite.expect(rig.events.contains(.databaseError(TimeTrackingDatabaseFault(kind: .write, message: "disk full"),
                                                            first: false)),
                         "write failure: not the first any more")
            suite.expect(rig.engine.tracker.isRunning && rig.workToday == hm(2, 0), "write failure: keeps counting")
            rig.store.failWrites = false
            rig.clock.set(dt(16, 11, 0))
            rig.engine.screenLocked()
            suite.expect(rig.engine.databaseFault == nil, "write failure: cleared once saving works")
            suite.expect(rig.store.day(date(16))?.periods == [TTSpan(hm(8, 0), hm(10, 0)), TTSpan(hm(10, 30), hm(11, 0))],
                         "write failure: nothing lost")
        }
    }

    private static func readFailureAtStartupIsKept(_ suite: TestSuite) {
        let store = Store()
        store.failReads = true
        withRig(dt(16, 8, 0), store: store) { rig in
            suite.expect(rig.engine.databaseFault?.kind == .read, "read failure: kept at startup")
            suite.expect(rig.engine.tracker.isRunning, "read failure: recording runs anyway")
            store.failReads = false
            rig.engine.reload()
            suite.expect(rig.engine.databaseFault == nil, "read failure: cleared by reading again")
        }
    }

    private static func editDayMergesWithWhatRuns(_ suite: TestSuite) {
        withRig(dt(16, 8, 0)) { rig in
            rig.clock.set(dt(16, 9, 0))
            do {
                try rig.engine.editDay(date(16)) { $0.start = hm(7, 30) }
            } catch {
                suite.expect(false, "edit: \(error)")
            }
            rig.clock.set(dt(16, 10, 0))
            suite.expect(rig.workToday == hm(2, 30), "edit: the start counts with the running period")
            suite.expect(rig.store.day(date(16))?.start == hm(7, 30), "edit: in the database")
            // All entries of today deleted: what runs counts only from now.
            do {
                try rig.engine.editDay(date(16)) { $0 = TTDay(date: $0.date) }
            } catch {
                suite.expect(false, "edit: \(error)")
            }
            rig.clock.set(dt(16, 11, 0))
            suite.expect(rig.engine.tracker.isRunning && rig.workToday == hm(1, 0), "edit: deleted day counts from now")
            // A failing edit changes nothing.
            rig.store.failWrites = true
            var threw = false
            do { try rig.engine.editDay(date(16)) { $0.end = hm(10, 0) } } catch { threw = true }
            suite.expect(threw && rig.engine.tracker.mode(rig.clock.current) == .auto, "edit: failure is thrown")
        }
    }

    private static func reloadAppliesChangedSettings(_ suite: TestSuite) {
        // Saturday: not counted until "Record today" …
        withRig(dt(21, 10, 0)) { rig in
            suite.expect(rig.status == .freeDay, "reload: free day")
            // … or until "only on workdays" is switched off.
            var all = TTSettings()
            all.autoWorkdaysOnly = false
            rig.store.settings = all
            rig.clock.set(dt(21, 11, 0))
            rig.engine.reload()
            suite.expect(rig.status == .running && rig.workToday == hm(1, 0), "reload: counts at once")
        }
    }

    private static func actionsFollowTheMenu(_ suite: TestSuite) {
        withRig(dt(21, 10, 0)) { rig in
            // Free day that does not count: nothing to pause.
            rig.engine.togglePause()
            suite.expect(rig.engine.tracker.isRunning, "actions: no break on an uncounted free day")
            rig.engine.setCounting(true)
            suite.expect(rig.status == .running, "actions: record today")
            rig.clock.set(dt(21, 12, 0))
            rig.engine.togglePause()
            rig.clock.set(dt(21, 12, 45))
            rig.engine.togglePause()
            rig.clock.set(dt(21, 13, 0))
            let pause = rig.engine.tracker.pausesToday(rig.clock.current)
            suite.expect(pause == [TTSpan(hm(12, 0), hm(12, 45))], "actions: the break")
            rig.engine.countPauseAsWork(TTSpan(hm(12, 0), hm(12, 45)), activity: .call)
            suite.expect(rig.store.day(date(21))?.work == [TTWorkBlock(from: hm(12, 0), to: hm(12, 45), note: "Telefonat")],
                         "actions: break counted as a call")
            rig.engine.closeDay(at: hm(13, 0))
            rig.clock.set(dt(21, 14, 0))
            rig.engine.togglePause()
            suite.expect(rig.engine.tracker.isRunning && rig.status == .closed, "actions: nothing to pause after the end")
            rig.probe.locked = true
            rig.engine.screenLocked()
            rig.engine.reopenDay()
            suite.expect(!rig.engine.tracker.isRunning, "actions: reopening while locked does not record")
            rig.probe.locked = false
            rig.engine.screenUnlocked()
            rig.engine.removeWork(date: date(21), from: hm(12, 0), to: hm(12, 45))
            suite.expect(rig.store.day(date(21))?.work.isEmpty == true, "actions: work away from the Mac removed")
            rig.engine.addWork(date: date(21), from: hm(9, 0), to: hm(9, 30), activity: .other)
            suite.expect(rig.store.day(date(21))?.work == [TTWorkBlock(from: hm(9, 0), to: hm(9, 30), note: "")],
                         "actions: work entered without a note")
        }
    }
}
