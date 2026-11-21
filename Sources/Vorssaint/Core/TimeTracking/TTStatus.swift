// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// What recording is doing right now (`store.rs` `Status`).
///
/// Tagwerk wrote it to a status file so a restarted menu bar app could resume
/// an open break. Barforge runs in one process and keeps that restart state as
/// machine state in UserDefaults; `line` and `init(line:)` are its encoding.
enum TTStatus: Hashable, Sendable {
    case running
    /// Stopped (locked, for example) without the user choosing "Pause work".
    case paused
    /// The user chose "Pause work", at this moment.
    case onBreak(since: TTDateTime)
    /// The user keeps working away from the Mac (meeting, call …) since this moment.
    case away(since: TTDateTime, activity: TTActivity)
    /// Outside the working-time frame: nothing counts.
    case outside
    /// Free day without "Record today": recorded, but not counted.
    case freeDay
    case closed
    /// Absent all day today (vacation, sick …): nothing is recorded.
    case absent

    /// `running`, `break 2026-11-17T12:03:09`, `away 2026-11-17T12:03:09 call` …
    var line: String {
        switch self {
        case .running: return "running"
        case .paused: return "paused"
        case let .onBreak(since): return "break \(since.iso)"
        case let .away(since, activity): return "away \(since.iso) \(activity.key)"
        case .outside: return "outside"
        case .freeDay: return "free"
        case .closed: return "closed"
        case .absent: return "absent"
        }
    }

    /// Reads `line` back; `nil` for anything else.
    init?(line: String) {
        let words = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = words.first else { return nil }
        switch first {
        case "running": self = .running
        case "paused": self = .paused
        case "break":
            guard words.count > 1, let since = TTDateTime(iso: words[1]) else { return nil }
            self = .onBreak(since: since)
        case "away":
            guard words.count > 1, let since = TTDateTime(iso: words[1]) else { return nil }
            self = .away(since: since, activity: TTActivity.from(key: words.count > 2 ? words[2] : ""))
        case "outside": self = .outside
        case "free": self = .freeDay
        case "closed": self = .closed
        case "absent": self = .absent
        default: return nil
        }
    }
}
