// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Barforge numbers its own releases and keeps its changes in
/// CHANGELOG-BARFORGE.md, while CHANGELOG.md stays identical to upstream.
/// Each Barforge release names the Vorssaint release it is made from on a line
/// of its own, "Based on Vorssaint 3.4.1.", and brings the Vorssaint releases
/// after the previous Barforge release's base up to its own. The first one
/// brings its base alone. Release notes and What's New show Barforge's
/// entries first and Vorssaint's after them, read from CHANGELOG.md.
enum ForkChangelog {
    static let upstreamName = "Vorssaint"

    static func bundled() -> String? {
        guard let url = Bundle.main.url(forResource: "CHANGELOG-BARFORGE", withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    // MARK: Based on

    /// The Vorssaint version a "Based on Vorssaint 3.4.1." line names.
    static func base(inLine line: String) -> String? {
        let prefix = "Based on \(upstreamName) "
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(prefix), trimmed.hasSuffix(".") else { return nil }
        let version = String(trimmed.dropFirst(prefix.count).dropLast())
        return UpdateServiceSupport.SemanticVersion(raw: version) == nil ? nil : version
    }

    /// The changelog without its "Based on" lines, which the app shows as
    /// Vorssaint sections instead of a paragraph.
    static func withoutBaseLines(_ changelog: String) -> String {
        changelog.components(separatedBy: .newlines)
            .filter { base(inLine: $0) == nil }
            .joined(separator: "\n")
    }

    /// Every version block in document order (newest first) with the base it
    /// names, if any. "Unreleased" counts as a block.
    static func blocks(in changelog: String) -> [(version: String, base: String?)] {
        var result: [(version: String, base: String?)] = []
        for line in changelog.components(separatedBy: .newlines) {
            if let version = version(inHeader: line) {
                result.append((version, nil))
            } else if let base = base(inLine: line), !result.isEmpty, result[result.count - 1].base == nil {
                result[result.count - 1].base = base
            }
        }
        return result
    }

    /// The block a running version reads: its own, or the work in progress
    /// while it has none yet.
    static func block(for version: String, in changelog: String) -> String? {
        let listed = blocks(in: changelog).map(\.version)
        if listed.contains(version) { return version }
        return listed.contains("Unreleased") ? "Unreleased" : nil
    }

    /// The Vorssaint base of `version`, falling back to `fallback` for a
    /// version whose block names none.
    static func base(of version: String, in changelog: String, fallback: String?) -> String? {
        guard let block = block(for: version, in: changelog) else { return fallback }
        return blocks(in: changelog).first { $0.version == block }?.base ?? fallback
    }

    /// The base named by the next older Barforge release, nil for the first.
    static func previousBase(before version: String, in changelog: String) -> String? {
        let all = blocks(in: changelog)
        guard let block = block(for: version, in: changelog),
              let index = all.firstIndex(where: { $0.version == block }) else { return nil }
        return all[(index + 1)...].lazy.compactMap(\.base).first
    }

    /// The Vorssaint versions a release brings, newest first: those after the
    /// previous base up to its own, or its base alone for the first release.
    static func upstreamVersions(from previousBase: String?, to base: String, upstream: String) -> [String] {
        let listed = blocks(in: upstream).map(\.version).filter { $0 != "Unreleased" }
        guard let previousBase else { return listed.contains(base) ? [base] : [] }
        return ReleaseDigest.versions(from: previousBase, to: base, among: listed)
    }

    // MARK: Release notes

    /// Barforge's notes for `version`, then each Vorssaint release it brings,
    /// its sections titled "Vorssaint 3.4.1 · Added".
    static func releaseNotes(for version: String, fork: String, upstream: String,
                             fallbackBase: String?) -> ReleaseNotes {
        let own = ReleaseNotes.notes(for: block(for: version, in: fork) ?? version,
                                     changelog: withoutBaseLines(fork))
        guard let base = base(of: version, in: fork, fallback: fallbackBase) else { return own }
        let brought = upstreamVersions(from: previousBase(before: version, in: fork), to: base, upstream: upstream)
        let sections = brought.flatMap { upstreamVersion in
            ReleaseNotes.notes(for: upstreamVersion, changelog: upstream).sections.map {
                ReleaseNoteSection(title: "\(upstreamName) \(upstreamVersion) · \($0.title)", items: $0.items)
            }
        }
        return ReleaseNotes(version: version, date: own.date, sections: own.sections + sections)
    }

    // MARK: What's New

    /// The changes between two Barforge versions: Barforge's own, then those
    /// of the Vorssaint releases that came with them.
    static func digest(from previous: String?, to current: String, fork: String, upstream: String,
                       fallbackBase: String?, includeUnreleased: Bool = false) -> ReleaseDigest {
        let own = ReleaseDigest.make(from: previous, to: current, changelog: withoutBaseLines(fork),
                                     includeUnreleased: includeUnreleased)
        guard let previous, let base = base(of: current, in: fork, fallback: fallbackBase) else { return own }
        let previousBase = self.base(of: previous, in: fork, fallback: nil)
        let brought = upstreamVersions(from: previousBase, to: base, upstream: upstream)
        guard !brought.isEmpty else { return own }
        let theirs = ReleaseDigest.make(from: previousBase ?? "0.0.0", to: base,
                                        changelog: subset(of: upstream, versions: Set(brought)))
        let theirChanges = theirs.changes.filter { change in !own.changes.contains { $0.text == change.text } }
        return ReleaseDigest(previousVersion: own.previousVersion, version: own.version,
                             versions: own.versions + theirs.versions.map { "\(upstreamName) \($0)" },
                             summary: own.summary, changes: own.changes + theirChanges)
    }

    /// Only the version blocks of `versions`, so a digest reads nothing else.
    private static func subset(of changelog: String, versions: Set<String>) -> String {
        var keep = false
        return changelog.components(separatedBy: .newlines).filter { line in
            if let version = version(inHeader: line) { keep = versions.contains(version) }
            return keep
        }.joined(separator: "\n")
    }

    private static func version(inHeader line: String) -> String? {
        guard line.hasPrefix("## ["), let end = line.dropFirst(4).firstIndex(of: "]") else { return nil }
        return String(line[line.index(line.startIndex, offsetBy: 4)..<end])
    }
}
