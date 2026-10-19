// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// A fork keeps its own changes in CHANGELOG-BARFORGE.md so CHANGELOG.md stays
/// identical to upstream. The app reads both as one changelog: each fork
/// release ("3.4.1+mx.2") is a version block of its own, placed right before
/// the upstream release it builds on, and the fork's unreleased entries join
/// upstream's.
enum ForkChangelog {
    static func merged(_ changelog: String, fork: String?) -> String {
        guard let fork else { return changelog }
        let forkBlocks = blocks(in: fork)
        guard !forkBlocks.isEmpty else { return changelog }

        var lines = changelog.components(separatedBy: .newlines)
        var pending = forkBlocks
        if let unreleased = pending.firstIndex(where: { $0.version == "Unreleased" }) {
            let body = pending.remove(at: unreleased).lines.dropFirst()
            if let start = lines.firstIndex(where: { version(in: $0) == "Unreleased" }) {
                let end = lines[(start + 1)...].firstIndex(where: { version(in: $0) != nil }) ?? lines.count
                lines.insert(contentsOf: body, at: end)
            } else if let first = lines.firstIndex(where: { version(in: $0) != nil }) {
                lines.insert(contentsOf: ["## [Unreleased]"] + body, at: first)
            } else {
                lines.append(contentsOf: ["## [Unreleased]"] + body)
            }
        }
        // Newest first, like the rest of the file: a fork release goes before
        // the first upstream release that is not newer than it.
        for block in pending {
            guard let order = ReleaseOrder(raw: block.version) else { continue }
            let index = lines.firstIndex { line in
                guard let listed = version(in: line), listed != "Unreleased",
                      let other = ReleaseOrder(raw: listed) else { return false }
                return other <= order
            } ?? lines.count
            lines.insert(contentsOf: block.lines, at: index)
        }
        return lines.joined(separator: "\n")
    }

    static func bundled() -> String? {
        guard let url = Bundle.main.url(forResource: "CHANGELOG-BARFORGE", withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// The upstream release a fork build is made from: "3.4.1+mx.2" → "3.4.1".
    /// Nil for a version without build metadata.
    static func baseVersion(of version: String) -> String? {
        guard let plus = version.firstIndex(of: "+") else { return nil }
        let base = String(version[..<plus])
        return base.isEmpty ? nil : base
    }

    /// A fork build's notes followed by those of the release it builds on,
    /// sections of the same name joined with the fork's entries first.
    static func combined(_ fork: ReleaseNotes, base: ReleaseNotes) -> ReleaseNotes {
        guard !fork.sections.isEmpty else { return base }
        guard !base.sections.isEmpty else { return fork }
        func key(_ title: String) -> String { title.trimmingCharacters(in: .whitespaces).lowercased() }
        var sections = base.sections
        var extra: [ReleaseNoteSection] = []
        for section in fork.sections {
            if let index = sections.firstIndex(where: { key($0.title) == key(section.title) }) {
                sections[index] = ReleaseNoteSection(title: sections[index].title,
                                                     items: section.items + sections[index].items)
            } else {
                extra.append(section)
            }
        }
        return ReleaseNotes(version: fork.version, date: fork.date ?? base.date, sections: extra + sections)
    }

    private static func blocks(in text: String) -> [(version: String, lines: [String])] {
        var result: [(version: String, lines: [String])] = []
        for line in text.components(separatedBy: .newlines) {
            if let version = version(in: line) {
                result.append((version, [line]))
            } else if !result.isEmpty {
                result[result.count - 1].lines.append(line)
            }
        }
        return result
    }

    private static func version(in line: String) -> String? {
        guard line.hasPrefix("## ["), let end = line.dropFirst(4).firstIndex(of: "]") else { return nil }
        return String(line[line.index(line.startIndex, offsetBy: 4)..<end])
    }
}

/// How What's New orders versions. Updates ignore build metadata, as semantic
/// versioning does, so a fork build is never taken for a newer release. What's
/// New instead orders a fork's builds after the release they build on and
/// after each other: "3.4.1" < "3.4.1+mx.1" < "3.4.1+mx.2" < "3.4.2-beta.1".
struct ReleaseOrder: Comparable {
    typealias Version = UpdateServiceSupport.SemanticVersion
    let version: Version
    let build: [UpdateServiceSupport.PrereleaseIdentifier]

    init?(raw: String) {
        guard let version = Version(raw: raw) else { return nil }
        self.version = version
        let metadata = raw.split(separator: "+", maxSplits: 1).dropFirst().first.map(String.init) ?? ""
        build = metadata.components(separatedBy: ".").filter { !$0.isEmpty }.map(UpdateServiceSupport.PrereleaseIdentifier.init)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.version != rhs.version { return lhs.version < rhs.version }
        for (l, r) in zip(lhs.build, rhs.build) where l != r { return l < r }
        return lhs.build.count < rhs.build.count
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.version == rhs.version && lhs.build == rhs.build
    }
}
