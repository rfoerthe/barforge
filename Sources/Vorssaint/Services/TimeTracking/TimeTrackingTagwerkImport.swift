// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import Foundation

/// Taking over the data of Tagwerk (plan E3): its database has the same
/// schema, so the copy is lossless. Its preferences move into Barforge's
/// UserDefaults keys.
enum TimeTrackingTagwerkImport {
    static let bundleIdentifier = "de.foerther.tagwerk"

    /// `~/Library/Application Support/Tagwerk/tagwerk.db`.
    static var defaultSourceURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Tagwerk", isDirectory: true)
            .appendingPathComponent("tagwerk.db")
    }

    enum Failure: Error, Equatable, CustomStringConvertible {
        case missing(String)
        /// Tagwerk's database has another schema: older than Tagwerk 1.2
        /// (below 3) or newer than this port knows.
        case unsupportedSchema(Int)

        var description: String {
            switch self {
            case let .missing(path): return "There is no Tagwerk database at \(path)."
            case let .unsupportedSchema(version): return "The Tagwerk database has schema \(version); only schema 3 can be taken over."
            }
        }
    }

    struct Result: Equatable {
        /// Recorded days now in Barforge's database.
        var days: Int
        /// Backup of Barforge's database before the takeover (`nil`: it was empty).
        var backup: URL?
        /// Preferences moved from Tagwerk (its keys).
        var movedPreferences: [String]
    }

    /// Is Tagwerk running? Then both would record at the same time.
    static var isTagwerkRunning: Bool {
        isRunning(bundleIdentifiers: NSWorkspace.shared.runningApplications.map(\.bundleIdentifier))
    }

    static func isRunning(bundleIdentifiers: [String?]) -> Bool {
        bundleIdentifiers.contains(bundleIdentifier)
    }

    /// Replaces the content of `database` with Tagwerk's database at `source`
    /// (online backup API, consistent even while Tagwerk writes) and moves
    /// Tagwerk's preferences into `defaults`. A non-empty database is backed
    /// up first as `timetracking-YYYY-MM-DD-vor-tagwerk-HHMMSS.db`.
    static func takeOver(from source: URL, into database: TimeTrackingDatabase, defaults: UserDefaults,
                         now: TTDateTime) throws -> Result {
        guard FileManager.default.fileExists(atPath: source.path) else { throw Failure.missing(source.path) }
        let tagwerk = try TimeTrackingSQLite(url: source, readOnly: true)
        try tagwerk.setBusyTimeout(seconds: 5)
        let version = try tagwerk.integer("PRAGMA user_version") ?? 0
        guard version == TimeTrackingDatabase.schemaVersion else { throw Failure.unsupportedSchema(version) }

        let time = String(format: "%02d%02d%02d", now.secs / 3600, now.secs % 3600 / 60, now.secs % 60)
        let name = "\(TimeTrackingDatabase.backupPrefix)\(now.date.iso)-vor-tagwerk-\(time).db"
        let backup = try database.backup(to: database.backupDirectory.appendingPathComponent(name))

        let db = database.connection
        try db.restore(from: tagwerk)
        // The copy brings Tagwerk's header; the connection stays in WAL mode.
        _ = try db.text("PRAGMA journal_mode = WAL")
        // Tables and columns of later Tagwerk versions, and Barforge's application id.
        try TimeTrackingDatabase.initSchema(db)

        // The preferences move: into UserDefaults, out of the database.
        let stored = try db.query("SELECT key, value FROM settings") { ($0.text(0), $0.int(1)) }
        var settings = TTPreferences.read(from: defaults)
        var moved: [String] = []
        for (key, value) in stored {
            guard let entry = TTPreferences.tagwerkKeys.first(where: { $0.key == key }) else { continue }
            entry.apply(&settings, value)
            moved.append(key)
        }
        TTPreferences.write(settings, to: defaults)
        try db.transaction {
            for key in moved { try db.run("DELETE FROM settings WHERE key = ?1", [.text(key)]) }
        }
        return Result(days: try database.load().count, backup: backup, movedPreferences: moved)
    }
}
