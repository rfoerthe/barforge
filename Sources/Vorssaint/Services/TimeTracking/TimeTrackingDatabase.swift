// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation
import os

// The records in a local SQLite database plus daily backups (port of the
// storage part of Tagwerk's `store.rs`). The schema is Tagwerk's schema 3, so
// Tagwerk's database can be taken over as it is (`TimeTrackingTagwerkImport`).
//
// Tables (dates always `YYYY-MM-DD`, times in seconds since midnight):
// - `periods`: recorded automatically (Mac unlocked),
// - `breaks`: breaks entered by hand (`to_s` NULL is an open lunch break of
//   early Tagwerk versions and is skipped when loading),
// - `day_marks`: start and end of work set by hand,
// - `work_blocks`: work away from the Mac (call, meeting …) with a note,
// - `absences`: absences (vacation, sick …),
// - `auto_counting`: free days, what applies to automatic recording
//   (`counts`: 0 not counted, 1 counted, 2 not recorded, see `TTDay.freeDay`),
// - `settings`: key → integer. Here only the time account and, as Tagwerk
//   does for its older versions, the working-time rules that apply today; the
//   other settings live in UserDefaults (`TTPreferences`),
// - `work_rules`: working-time rules with the day they apply from
//   (`valid_from` empty: since always).
//
// A day is always written whole (delete, then insert); an empty day is only
// deleted.

/// Errors of the Time Tracking database beyond SQLite's own.
enum TimeTrackingDatabaseError: Error, Equatable, CustomStringConvertible {
    /// The database comes from a newer version (its schema).
    case newerSchema(Int)
    /// The data folder cannot be created.
    case directory(String)

    var description: String {
        switch self {
        case let .newerSchema(version): return "The database is from a newer version (schema \(version))."
        case let .directory(path): return "The folder \(path) cannot be created."
        }
    }
}

final class TimeTrackingDatabase {
    static let fileName = "timetracking.db"
    /// How many daily backups are kept.
    static let maxBackups = 15
    static let schemaVersion = 3
    /// `PRAGMA application_id` of Barforge's database ("BFTT"). Tagwerk never
    /// sets one; its test databases carry "TWKT".
    static let applicationID = 0x4246_5454
    static let backupPrefix = "timetracking-"

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "TimeTrackingDatabase")

    /// `PrivateFileStore.containerURL/TimeTracking` (nil outside a real bundle).
    static var defaultDirectory: URL? {
        PrivateFileStore.containerURL?.appendingPathComponent("TimeTracking", isDirectory: true)
    }

    /// Opens the app's own database.
    static func openDefault() throws -> TimeTrackingDatabase {
        guard let directory = defaultDirectory else { throw TimeTrackingDatabaseError.directory("Application Support") }
        return try TimeTrackingDatabase(directory: directory)
    }

    let directory: URL
    private let container: URL?
    let connection: TimeTrackingSQLite
    private var dataVersion = 0

    var fileURL: URL { directory.appendingPathComponent(Self.fileName) }
    var backupDirectory: URL { directory.appendingPathComponent("backups", isDirectory: true) }

    /// Opens (or creates) `timetracking.db` in `directory`, owner-only. Only
    /// tests pass a directory of their own; the app uses `openDefault()`.
    /// `container` bounds how far up `PrivateFileStore` tightens folders.
    init(directory: URL, container: URL? = PrivateFileStore.containerURL) throws {
        self.directory = directory
        self.container = container
        guard PrivateFileStore.createDirectory(at: directory, container: container) else {
            throw TimeTrackingDatabaseError.directory(directory.path)
        }
        let url = directory.appendingPathComponent(Self.fileName)
        // SQLite gives the -wal and -shm files the mode of the database file.
        Self.makePrivateFile(at: url)
        connection = try TimeTrackingSQLite(url: url)
        try connection.setBusyTimeout(seconds: 5)
        _ = try connection.text("PRAGMA journal_mode = WAL")
        try connection.execute("PRAGMA synchronous = NORMAL")
        try Self.initSchema(connection)
        dataVersion = try readDataVersion()
    }

    /// Creates an empty owner-only file at `url`, or makes an existing one owner-only.
    private static func makePrivateFile(at url: URL) {
        let manager = FileManager.default
        if manager.fileExists(atPath: url.path) {
            try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } else {
            manager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
    }

    // MARK: Schema

    private static let schema = """
        CREATE TABLE periods (
            date TEXT NOT NULL,
            idx INTEGER NOT NULL,
            from_s INTEGER NOT NULL,
            to_s INTEGER NOT NULL,
            PRIMARY KEY (date, idx)
        ) WITHOUT ROWID;
        CREATE TABLE breaks (
            date TEXT NOT NULL,
            idx INTEGER NOT NULL,
            from_s INTEGER NOT NULL,
            to_s INTEGER,
            PRIMARY KEY (date, idx)
        ) WITHOUT ROWID;
        CREATE TABLE day_marks (
            date TEXT PRIMARY KEY,
            start_s INTEGER,
            end_s INTEGER
        ) WITHOUT ROWID;
        """
    /// From schema 2.
    static let schemaSettings = """
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value INTEGER NOT NULL
        ) WITHOUT ROWID;
        """
    /// From schema 3.
    static let schemaWork = """
        CREATE TABLE IF NOT EXISTS work_blocks (
            date TEXT NOT NULL,
            idx INTEGER NOT NULL,
            from_s INTEGER NOT NULL,
            to_s INTEGER NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (date, idx)
        ) WITHOUT ROWID;
        """
    /// Came later without a new schema version: older Tagwerk versions open
    /// the database and leave the table alone.
    private static let schemaAbsences = """
        CREATE TABLE IF NOT EXISTS absences (
            date TEXT PRIMARY KEY,
            kind INTEGER NOT NULL,
            half INTEGER NOT NULL DEFAULT 0
        ) WITHOUT ROWID;
        """
    private static let schemaFreeDays = """
        CREATE TABLE IF NOT EXISTS auto_counting (
            date TEXT PRIMARY KEY,
            counts INTEGER NOT NULL
        ) WITHOUT ROWID;
        """
    private static let schemaWorkRules = """
        CREATE TABLE IF NOT EXISTS work_rules (
            valid_from TEXT PRIMARY KEY,
            min_pause_s INTEGER NOT NULL,
            weekly_target_s INTEGER NOT NULL,
            frame_from_s INTEGER NOT NULL,
            frame_to_s INTEGER NOT NULL,
            workdays INTEGER NOT NULL,
            free_days_count INTEGER NOT NULL DEFAULT 0
        ) WITHOUT ROWID;
        """
    /// Column added after the first version of `work_rules`.
    private static let workRulesFreeDays = "free_days_count"

    /// The table of schema 0 and 1 as tests build it (`schema`).
    static var schemaVersion1Tables: String { schema }

    /// Creates missing tables and columns and lifts the schema to version 3
    /// (`store.rs` `init_schema`, without the import of the old `tagwerk.md`).
    static func initSchema(_ db: TimeTrackingSQLite) throws {
        try db.transaction {
            let version = try db.integer("PRAGMA user_version") ?? 0
            if version > schemaVersion { throw TimeTrackingDatabaseError.newerSchema(version) }
            try db.execute(schemaAbsences)
            try db.execute(schemaFreeDays)
            try db.execute(schemaWorkRules)
            let hasFreeDays = try db.integer("SELECT count(*) FROM pragma_table_info('work_rules') WHERE name = ?1",
                                             [.text(workRulesFreeDays)]) ?? 0
            if hasFreeDays == 0 {
                try db.execute("ALTER TABLE work_rules ADD COLUMN \(workRulesFreeDays) INTEGER NOT NULL DEFAULT 0")
            }
            if version < schemaVersion {
                try db.execute(schemaSettings)
                try db.execute(schemaWork)
                try db.execute("PRAGMA user_version = \(schemaVersion)")
            }
            if version == 0 {
                try db.execute(schema)
            }
            if try db.integer("PRAGMA application_id") != applicationID {
                try db.execute("PRAGMA application_id = \(applicationID)")
            }
        }
    }

    // MARK: Changes from other connections

    private func readDataVersion() throws -> Int {
        try connection.integer("PRAGMA data_version") ?? 0
    }

    /// `true` when another connection saved something since the last call.
    /// Barforge has one connection; this only matters for a database shared
    /// with another process.
    func changedExternally() -> Bool {
        guard let version = try? readDataVersion(), version != dataVersion else { return false }
        dataVersion = version
        return true
    }

    // MARK: Days

    /// All days, sorted by date, without free-day marks that no longer apply
    /// by the rules (see `dropStaleFreeDays`).
    func load() throws -> [TTDay] {
        var days = try Self.loadBetween(connection, "", "~")
        Self.dropStaleFreeDays(&days, settings: try loadSettings())
        return days
    }

    /// The days from `from` to `to` inclusive (like `load()`).
    func load(from: TTDate, to: TTDate) throws -> [TTDay] {
        var days = try Self.loadBetween(connection, from.iso, to.iso)
        Self.dropStaleFreeDays(&days, settings: try loadSettings())
        return days
    }

    /// Takes over the days of an import (they replace what these days had).
    /// The database is backed up for it first, so the import can be undone.
    /// Returns the backup (`nil`: there was nothing to back up yet).
    @discardableResult
    func importDays(_ days: [TTDay], now: TTDateTime) throws -> URL? {
        let name = "\(Self.backupPrefix)\(now.date.iso)-vor-import-\(Self.compactTime(now.secs)).db"
        let backup = try backup(to: backupDirectory.appendingPathComponent(name))
        try saveDays(days, removed: [], now: now)
        return backup
    }

    /// Writes `days` (empty days are deleted) and deletes `removed`, in one
    /// transaction. Other days stay untouched.
    func saveDays(_ days: [TTDay], removed: [TTDate], now: TTDateTime) throws {
        if days.isEmpty && removed.isEmpty { return }
        dailyBackup(today: now.date)
        try connection.transaction {
            for day in days { try Self.writeDay(connection, day) }
            for date in removed { try Self.deleteDay(connection, date) }
        }
    }

    /// Reads a day, changes it and writes it back in the same transaction.
    func editDay(_ date: TTDate, now: TTDateTime, _ change: (inout TTDay) throws -> Void) throws {
        dailyBackup(today: now.date)
        try connection.transaction {
            var days = try Self.loadBetween(connection, date.iso, date.iso)
            let i = TTDay.index(of: date, in: &days)
            try change(&days[i])
            try Self.writeDay(connection, days[i])
        }
    }

    /// Drops free-day marks (`TTDay.freeDay`) on days that are workdays by the
    /// rules of `settings`. The mark comes with the first unlock on a free day;
    /// once the day becomes a workday (rules changed backwards) it has a target,
    /// and what was recorded on it must count, or the full target would stand
    /// against nothing. Days that were only the mark go. The database keeps the
    /// mark until the day is written again: undoing the rule change brings it
    /// back (`store.rs` `drop_stale_free_days`).
    static func dropStaleFreeDays(_ days: inout [TTDay], settings: TTSettings) {
        for i in days.indices where days[i].freeDay != nil && settings.isWorkday(days[i].date) {
            days[i].freeDay = nil
        }
        days.removeAll { $0.isEmpty }
    }

    private static func loadBetween(_ db: TimeTrackingSQLite, _ from: String, _ to: String) throws -> [TTDay] {
        var days: [TTDay] = []
        let range: [TimeTrackingSQLiteValue] = [.text(from), .text(to)]
        func day(_ text: String) -> Int? {
            TTDate(iso: text).map { TTDay.index(of: $0, in: &days) }
        }

        let periods = try db.query("SELECT date, from_s, to_s FROM periods WHERE date BETWEEN ?1 AND ?2 ORDER BY date, idx",
                                   range) { ($0.text(0), $0.int(1), $0.int(2)) }
        for (date, from, to) in periods {
            if let i = day(date) { days[i].periods.append(TTSpan(from, to)) }
        }

        let breaks = try db.query("SELECT date, from_s, to_s FROM breaks WHERE date BETWEEN ?1 AND ?2 ORDER BY date, idx",
                                  range) { ($0.text(0), $0.int(1), $0.optionalInt(2)) }
        // Open lunch breaks of early versions: breaks follow from the locks now.
        for (date, from, to) in breaks {
            if let to, let i = day(date) { days[i].breaks.append(TTBreak(from: from, to: Swift.max(to, from))) }
        }

        let work = try db.query(
            "SELECT date, from_s, to_s, note FROM work_blocks WHERE date BETWEEN ?1 AND ?2 ORDER BY date, idx",
            range) { ($0.text(0), $0.int(1), $0.int(2), $0.text(3)) }
        for (date, from, to, note) in work {
            if let i = day(date) { days[i].addWork(from: from, to: to, note: note) }
        }

        let marks = try db.query("SELECT date, start_s, end_s FROM day_marks WHERE date BETWEEN ?1 AND ?2 ORDER BY date",
                                 range) { ($0.text(0), $0.optionalInt(1), $0.optionalInt(2)) }
        for (date, start, end) in marks {
            if let i = day(date) {
                days[i].start = start
                days[i].end = end
            }
        }

        let absences = try db.query("SELECT date, kind, half FROM absences WHERE date BETWEEN ?1 AND ?2 ORDER BY date",
                                    range) { ($0.text(0), $0.int(1), $0.int(2)) }
        // An unknown kind (from a newer version): no absence.
        for (date, kind, half) in absences {
            if let kind = TTAbsenceKind.from(id: kind), let i = day(date) {
                days[i].absence = TTAbsence(kind, half: half != 0)
            }
        }

        let counting = try db.query("SELECT date, counts FROM auto_counting WHERE date BETWEEN ?1 AND ?2 ORDER BY date",
                                    range) { ($0.text(0), $0.int(1)) }
        // An unknown state (from a newer version): counts as always.
        for (date, state) in counting {
            if let state = TTFreeDay.from(id: state), let i = day(date) { days[i].freeDay = state }
        }

        return days.filter { !$0.isEmpty }
    }

    private static func deleteDay(_ db: TimeTrackingSQLite, _ date: TTDate) throws {
        for table in ["absences", "auto_counting", "periods", "breaks", "day_marks", "work_blocks"] {
            try db.run("DELETE FROM \(table) WHERE date = ?1", [.text(date.iso)])
        }
    }

    /// Replaces all rows of a day (an empty day is only deleted).
    private static func writeDay(_ db: TimeTrackingSQLite, _ d: TTDay) throws {
        try deleteDay(db, d.date)
        if d.isEmpty { return }
        let key = TimeTrackingSQLiteValue.text(d.date.iso)
        for (i, p) in d.periods.enumerated() {
            try db.run("INSERT INTO periods (date, idx, from_s, to_s) VALUES (?1, ?2, ?3, ?4)",
                       [key, .int(i), .int(p.from), .int(p.to)])
        }
        for (i, b) in d.breaks.enumerated() {
            try db.run("INSERT INTO breaks (date, idx, from_s, to_s) VALUES (?1, ?2, ?3, ?4)",
                       [key, .int(i), .int(b.from), .int(b.to)])
        }
        for (i, w) in d.work.enumerated() {
            try db.run("INSERT INTO work_blocks (date, idx, from_s, to_s, note) VALUES (?1, ?2, ?3, ?4, ?5)",
                       [key, .int(i), .int(w.from), .int(w.to), .text(w.note)])
        }
        if d.start != nil || d.end != nil {
            try db.run("INSERT INTO day_marks (date, start_s, end_s) VALUES (?1, ?2, ?3)",
                       [key, .optional(d.start), .optional(d.end)])
        }
        if let a = d.absence {
            try db.run("INSERT INTO absences (date, kind, half) VALUES (?1, ?2, ?3)",
                       [key, .int(a.kind.id), .int(a.half ? 1 : 0)])
        }
        if let f = d.freeDay {
            try db.run("INSERT INTO auto_counting (date, counts) VALUES (?1, ?2)", [key, .int(f.id)])
        }
    }

    // MARK: Settings

    /// Keys of the `settings` table this database still keeps (`store.rs` `KEY_*`):
    /// the rules that apply today, for older Tagwerk versions, and the time account.
    enum SettingsKey {
        static let minPause = "min_pause_s"
        static let weekly = "weekly_target_s"
        static let frameFrom = "frame_from_s"
        static let frameTo = "frame_to_s"
        static let workdays = "workdays"
        /// Start of the time account as days since 0001-01-01 (0: all recorded days).
        static let accountFrom = "account_from_day"
        static let accountCarry = "account_carry_s"
    }

    /// The settings: the working-time rules and the time account from the
    /// database, the rest from `preferences` (see `TTPreferences`). Missing
    /// values give the defaults. Without rows in `work_rules` (a database of an
    /// older Tagwerk) the rules in `settings` apply since always.
    func loadSettings(preferences: TTSettings = TTSettings()) throws -> TTSettings {
        var s = preferences
        s.accountFrom = nil
        s.accountCarry = 0
        var legacy = TTWorkRules.default
        let rows = try connection.query("SELECT key, value FROM settings") { ($0.text(0), $0.int(1)) }
        for (key, value) in rows {
            switch key {
            case SettingsKey.minPause: legacy.minPause = value
            case SettingsKey.weekly: legacy.weeklyTarget = value
            case SettingsKey.frameFrom: legacy.frameFrom = value
            case SettingsKey.frameTo: legacy.frameTo = value
            case SettingsKey.workdays: legacy.workdays = value.ttClamped(0, 255)
            case SettingsKey.accountFrom:
                s.accountFrom = value > 0 && value <= Int(Int32.max) ? TTDate(ordinal: value) : nil
            case SettingsKey.accountCarry: s.accountCarry = value
            default: break
            }
        }
        let periods = try connection.query(
            """
            SELECT valid_from, min_pause_s, weekly_target_s, frame_from_s, frame_to_s, workdays, free_days_count
            FROM work_rules ORDER BY valid_from
            """) { row -> (String, TTWorkRules) in
            (row.text(0), TTWorkRules(minPause: row.int(1), weeklyTarget: row.int(2), frameFrom: row.int(3),
                                      frameTo: row.int(4), workdays: row.int(5).ttClamped(0, 255),
                                      freeDaysCount: row.int(6) != 0))
        }
        var work: [TTRulesPeriod] = []
        for (from, rules) in periods {
            // Empty: since always; a date that does not read is skipped.
            if from.isEmpty {
                work.append(TTRulesPeriod(from: nil, rules: rules))
            } else if let date = TTImport.parseDate(from) {
                work.append(TTRulesPeriod(from: date, rules: rules))
            }
        }
        s.work = work.isEmpty ? [TTRulesPeriod(from: nil, rules: legacy)] : work
        return s.sanitized
    }

    /// Saves the database's part of the settings: the working-time rules and
    /// the time account. `today` decides which rules stand in `settings` for
    /// older Tagwerk versions.
    func saveSettings(_ settings: TTSettings, today: TTDate) throws {
        let s = settings.sanitized
        let now = s.rules(today)
        try connection.transaction {
            try connection.run("DELETE FROM work_rules")
            for p in s.work {
                let r = p.rules
                try connection.run(
                    """
                    INSERT INTO work_rules
                        (valid_from, min_pause_s, weekly_target_s, frame_from_s, frame_to_s, workdays, free_days_count)
                    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
                    """,
                    [.text(p.from?.iso ?? ""), .int(r.minPause), .int(r.weeklyTarget), .int(r.frameFrom),
                     .int(r.frameTo), .int(r.workdays), .int(r.freeDaysCount ? 1 : 0)])
            }
            let values: [(String, Int)] = [
                (SettingsKey.minPause, now.minPause),
                (SettingsKey.weekly, now.weeklyTarget),
                (SettingsKey.frameFrom, now.frameFrom),
                (SettingsKey.frameTo, now.frameTo),
                (SettingsKey.workdays, now.workdays),
                (SettingsKey.accountFrom, s.accountFrom?.ordinal ?? 0),
                (SettingsKey.accountCarry, s.accountCarry),
            ]
            for (key, value) in values {
                try connection.run(
                    "INSERT INTO settings (key, value) VALUES (?1, ?2) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                    [.text(key), .int(value)])
            }
        }
    }

    /// All settings: the preferences from `defaults`, rules and time account from the database.
    func loadSettings(defaults: UserDefaults) throws -> TTSettings {
        try loadSettings(preferences: TTPreferences.read(from: defaults))
    }

    /// Saves all settings: the preferences to `defaults`, rules and time
    /// account to the database.
    func saveSettings(_ settings: TTSettings, today: TTDate, defaults: UserDefaults) throws {
        try saveSettings(settings, today: today)
        TTPreferences.write(settings, to: defaults)
    }

    // MARK: Backups

    /// `100130` for 10:01:30.
    private static func compactTime(_ secs: Int) -> String {
        String(format: "%02d%02d%02d", secs / 3600, secs % 3600 / 60, secs % 60)
    }

    /// Backs the database up once a day, before the first change, as
    /// `backups/timetracking-YYYY-MM-DD.db`; the newest `maxBackups` stay.
    /// A failed backup does not stop saving.
    private func dailyBackup(today: TTDate) {
        let target = backupDirectory.appendingPathComponent("\(Self.backupPrefix)\(today.iso).db")
        if FileManager.default.fileExists(atPath: target.path) { return }
        do {
            try backup(to: target)
        } catch {
            Self.log.error("Time Tracking backup failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Backs the database up to `target` in the backup folder (older backups
    /// are pruned). `nil`: the database is still empty, nothing to back up.
    @discardableResult
    func backup(to target: URL) throws -> URL? {
        let rows = try connection.integer(
            """
            SELECT (SELECT count(*) FROM periods) + (SELECT count(*) FROM breaks)
                 + (SELECT count(*) FROM day_marks) + (SELECT count(*) FROM work_blocks)
                 + (SELECT count(*) FROM absences) + (SELECT count(*) FROM auto_counting)
            """) ?? 0
        if rows == 0 { return nil }
        guard PrivateFileStore.createDirectory(at: backupDirectory, container: container) else {
            throw TimeTrackingDatabaseError.directory(backupDirectory.path)
        }
        try connection.run("VACUUM INTO ?1", [.text(target.path)])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
        pruneBackups()
        return target
    }

    /// Deletes all but the newest `maxBackups` backups.
    private func pruneBackups() {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: backupDirectory.path) else { return }
        let backups = names.filter { $0.hasPrefix(Self.backupPrefix) && $0.hasSuffix(".db") }.sorted()
        for name in backups.dropLast(Self.maxBackups) {
            try? manager.removeItem(at: backupDirectory.appendingPathComponent(name))
        }
    }
}
