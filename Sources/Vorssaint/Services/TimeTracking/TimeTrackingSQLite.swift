// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation
import SQLite3

/// A failed SQLite call: the result code and SQLite's message.
struct TimeTrackingSQLiteError: Error, CustomStringConvertible, Equatable {
    let code: Int32
    let message: String

    var description: String { "SQLite \(code): \(message)" }
}

/// A value bound to a statement parameter.
enum TimeTrackingSQLiteValue: Equatable {
    case int(Int)
    case text(String)
    case null

    static func optional(_ value: Int?) -> TimeTrackingSQLiteValue {
        value.map { .int($0) } ?? .null
    }
}

/// A small, safe layer over the SQLite C API for Time Tracking: one
/// connection, prepared statements that bind by position and finalize
/// themselves, transactions that roll back on error. Not thread-safe; the
/// owner uses it from one thread at a time.
final class TimeTrackingSQLite {
    private let handle: OpaquePointer

    /// Opens the database at `url`: read-only, read-write, or read-write and
    /// created when missing (the default).
    ///
    /// A read-only connection cannot read a database in WAL mode whose
    /// `-shm` file is gone, which is how SQLite leaves it after the last
    /// connection closed (SQLITE_CANTOPEN on the first query). To read
    /// another app's WAL database, open it read-write without `create`.
    init(url: URL, readOnly: Bool = false, create: Bool = true) throws {
        var db: OpaquePointer?
        let access = readOnly ? SQLITE_OPEN_READONLY
            : create ? SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE : SQLITE_OPEN_READWRITE
        let flags = access | SQLITE_OPEN_NOMUTEX
        let rc = sqlite3_open_v2(url.path, &db, flags, nil)
        guard rc == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? String(cString: sqlite3_errstr(rc))
            if let db { sqlite3_close_v2(db) }
            throw TimeTrackingSQLiteError(code: rc, message: message)
        }
        handle = db
        sqlite3_extended_result_codes(db, 1)
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    private func error(_ rc: Int32) -> TimeTrackingSQLiteError {
        TimeTrackingSQLiteError(code: rc, message: String(cString: sqlite3_errmsg(handle)))
    }

    private func check(_ rc: Int32) throws {
        guard rc == SQLITE_OK else { throw error(rc) }
    }

    /// Waits up to `seconds` for a lock another connection holds.
    func setBusyTimeout(seconds: Double) throws {
        try check(sqlite3_busy_timeout(handle, Int32(seconds * 1000)))
    }

    /// Runs one or more statements without parameters or results.
    func execute(_ sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(handle, sql, nil, nil, &message)
        guard rc == SQLITE_OK else {
            let text = message.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(handle))
            sqlite3_free(message)
            throw TimeTrackingSQLiteError(code: rc, message: text)
        }
    }

    func prepare(_ sql: String) throws -> Statement {
        var statement: OpaquePointer?
        let rc = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard rc == SQLITE_OK, let statement else { throw error(rc) }
        return Statement(statement, connection: self)
    }

    /// Runs one statement with `values` bound to its parameters `?1`, `?2` …
    func run(_ sql: String, _ values: [TimeTrackingSQLiteValue] = []) throws {
        let statement = try prepare(sql)
        try statement.bind(values)
        while try statement.step() {}
    }

    /// The rows of a query, each read by `row`.
    func query<T>(_ sql: String, _ values: [TimeTrackingSQLiteValue] = [],
                  row: (Statement) throws -> T) throws -> [T] {
        let statement = try prepare(sql)
        try statement.bind(values)
        var out: [T] = []
        while try statement.step() {
            out.append(try row(statement))
        }
        return out
    }

    /// The first column of the first row as an integer (`nil`: no row or NULL).
    func integer(_ sql: String, _ values: [TimeTrackingSQLiteValue] = []) throws -> Int? {
        try query(sql, values) { $0.optionalInt(0) }.first ?? nil
    }

    /// The first column of the first row as text (`nil`: no row or NULL).
    func text(_ sql: String, _ values: [TimeTrackingSQLiteValue] = []) throws -> String? {
        try query(sql, values) { $0.optionalText(0) }.first ?? nil
    }

    /// Runs `body` in a transaction (`IMMEDIATE` takes the write lock at once)
    /// and commits; an error rolls everything back and is passed on.
    func transaction<T>(immediate: Bool = true, _ body: () throws -> T) throws -> T {
        try execute(immediate ? "BEGIN IMMEDIATE" : "BEGIN")
        do {
            let result = try body()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    /// Replaces the whole content of this database with `source` through the
    /// online backup API (the copy is consistent even while another process
    /// writes to `source`).
    func restore(from source: TimeTrackingSQLite) throws {
        guard let backup = sqlite3_backup_init(handle, "main", source.handle, "main") else {
            throw error(sqlite3_errcode(handle))
        }
        let step = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE else { throw error(step) }
        try check(finish)
    }

    /// A prepared statement. Parameters bind by position, columns read by index.
    final class Statement {
        private let handle: OpaquePointer
        /// Keeps the connection open while the statement lives.
        private let connection: TimeTrackingSQLite

        fileprivate init(_ handle: OpaquePointer, connection: TimeTrackingSQLite) {
            self.handle = handle
            self.connection = connection
        }

        deinit {
            sqlite3_finalize(handle)
        }

        /// SQLite copies bound text right away.
        private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        func bind(_ values: [TimeTrackingSQLiteValue]) throws {
            try connection.check(sqlite3_reset(handle))
            try connection.check(sqlite3_clear_bindings(handle))
            for (i, value) in values.enumerated() {
                let index = Int32(i + 1)
                let rc: Int32
                switch value {
                case let .int(n): rc = sqlite3_bind_int64(handle, index, Int64(n))
                case let .text(s): rc = sqlite3_bind_text(handle, index, s, -1, Statement.transient)
                case .null: rc = sqlite3_bind_null(handle, index)
                }
                try connection.check(rc)
            }
        }

        /// Steps once: `true` while there is a row to read, `false` when done.
        func step() throws -> Bool {
            switch sqlite3_step(handle) {
            case SQLITE_ROW: return true
            case SQLITE_DONE: return false
            case let rc: throw connection.error(rc)
            }
        }

        func isNull(_ column: Int32) -> Bool {
            sqlite3_column_type(handle, column) == SQLITE_NULL
        }

        func int(_ column: Int32) -> Int {
            Int(sqlite3_column_int64(handle, column))
        }

        func optionalInt(_ column: Int32) -> Int? {
            isNull(column) ? nil : int(column)
        }

        func text(_ column: Int32) -> String {
            optionalText(column) ?? ""
        }

        func optionalText(_ column: Int32) -> String? {
            guard let text = sqlite3_column_text(handle, column) else { return nil }
            return String(cString: text)
        }
    }
}
