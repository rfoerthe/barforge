// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// A build from a fork names its repository, links there and never takes an
/// official update that would replace it.
enum ForkBuildTests {
    static func run(_ suite: TestSuite) {
        suite.expect(AppInfoSupport.forkRepository("rfoerthe/vorssaint-utils") == "rfoerthe/vorssaint-utils"
                     && AppInfoSupport.forkRepository(" owner/repo.name ") == "owner/repo.name",
                     "a plain owner/name is a fork")
        for invalid in [nil, "", "rfoerthe", "a/b/c", "/repo", "owner/", "owner/re po",
                        "https://github.com/owner/repo", "owner/repo?x=1"] as [String?] {
            suite.expect(AppInfoSupport.forkRepository(invalid) == nil,
                         "\(invalid ?? "nil") is not taken as a fork repository")
        }

        let info = NSDictionary(contentsOfFile: "Resources/Info.plist") as? [String: Any]
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let fork = info?["VorssaintForkRepository"] as? String
        suite.expect(AppInfoSupport.forkRepository(fork) == "rfoerthe/vorssaint-utils",
                     "this fork stamps its repository into the bundle")
        let parsed = UpdateServiceSupport.SemanticVersion(raw: version)
        suite.expect(parsed != nil && !version.contains("+") && parsed?.isPrerelease == false,
                     "Barforge numbers its own releases with a plain version (\(version))")
        let upstream = info?["BarforgeUpstreamVersion"] as? String ?? ""
        suite.expect(UpdateServiceSupport.SemanticVersion(raw: upstream) != nil && !upstream.contains("+"),
                     "the bundle names the Vorssaint release it is made from (\(upstream))")
        let changelog = (try? String(contentsOfFile: "CHANGELOG-BARFORGE.md", encoding: .utf8)) ?? ""
        let upstreamChangelog = (try? String(contentsOfFile: "CHANGELOG.md", encoding: .utf8)) ?? ""
        suite.expect(ForkChangelog.base(of: version, in: changelog, fallback: nil) == upstream,
                     "the changelog entry for \(version) is based on the bundle's Vorssaint \(upstream)")
        let shipped = ForkChangelog.releaseNotes(for: version, fork: changelog, upstream: upstreamChangelog,
                                                 fallbackBase: upstream)
        suite.expect(shipped.sections.contains { !$0.title.hasPrefix("Vorssaint ") }
                     && shipped.sections.contains { $0.title.hasPrefix("Vorssaint \(upstream) · ") },
                     "the release notes for \(version) list Barforge's entries and Vorssaint \(upstream)'s")
        checkChangelogs(suite)

        for language in AppLanguage.allCases {
            let text = FeatureStrings.forkBuild(language)
            for format in [text.aboutFormat, text.updatesOffFormat, text.basedOnFormat] {
                suite.expect(format.components(separatedBy: "%@").count == 2 && !format.contains("\u{2014}"),
                             "fork notices take their value once (\(language.rawValue))")
            }
            suite.expect(text.attribution.contains("Vorssaint") && text.attribution.contains("GPL-3.0-or-later")
                         && !text.attribution.contains("%@"),
                         "the fork names the original project and its license (\(language.rawValue))")
        }
    }

    /// Each Barforge release names its Vorssaint base and brings the Vorssaint
    /// releases after the previous one's base; the first brings its base alone.
    private static func checkChangelogs(_ suite: TestSuite) {
        let fork = """
        # Barforge Changelog

        ## [Unreleased]

        Based on Vorssaint 3.5.0.

        ### Added
        - Barforge work in progress.

        ## [1.1.0] - 2026-11-15

        Based on Vorssaint 3.4.2.

        ### Added
        - Barforge mouse change.

        ## [1.0.0] - 2026-10-21

        Based on Vorssaint 3.4.1.

        ### Changed
        - Barforge first release.

        ## [3.4.1+mx.1] - 2026-10-19

        ### Added
        - Build before the rename.
        """
        let upstream = """
        # Changelog

        ## [Unreleased]

        ### Added
        - Upstream work in progress.

        ## [3.5.0] - 2026-11-10

        ### Added
        - Upstream 3.5.0 change.

        ## [3.5.0-beta.1] - 2026-11-01

        ### Added
        - Upstream beta change.

        ## [3.4.2] - 2026-10-30

        ### Fixed
        - Upstream 3.4.2 fix.

        ## [3.4.1] - 2026-10-08

        ### Added
        - Upstream 3.4.1 change.

        ## [3.4.0] - 2026-10-01

        ### Added
        - Upstream 3.4.0 change.
        """
        let blocks = ForkChangelog.blocks(in: fork)
        suite.expect(blocks.map(\.version) == ["Unreleased", "1.1.0", "1.0.0", "3.4.1+mx.1"]
                     && blocks.map(\.base) == ["3.5.0", "3.4.2", "3.4.1", nil],
                     "every release block reads its Based on line")
        suite.expect(ForkChangelog.base(inLine: "Based on Vorssaint 3.4.1.") == "3.4.1"
                     && ForkChangelog.base(inLine: "Based on Vorssaint soon.") == nil
                     && ForkChangelog.base(inLine: "Based on Vorssaint 3.4.1") == nil,
                     "only a full Based on line with a version counts")
        suite.expect(ForkChangelog.base(of: "1.2.0", in: fork, fallback: nil) == "3.5.0"
                     && ForkChangelog.base(of: "3.4.1+mx.1", in: fork, fallback: "3.4.1") == "3.4.1"
                     && ForkChangelog.previousBase(before: "1.2.0", in: fork) == "3.4.2"
                     && ForkChangelog.previousBase(before: "1.1.0", in: fork) == "3.4.1"
                     && ForkChangelog.previousBase(before: "1.0.0", in: fork) == nil,
                     "a build without its own entry reads the work in progress, and bases chain back")
        suite.expect(ForkChangelog.upstreamVersions(from: nil, to: "3.4.1", upstream: upstream) == ["3.4.1"]
                     && ForkChangelog.upstreamVersions(from: "3.4.2", to: "3.5.0", upstream: upstream) == ["3.5.0"]
                     && ForkChangelog.upstreamVersions(from: "3.4.1", to: "3.5.0", upstream: upstream)
                         == ["3.5.0", "3.4.2"],
                     "a release brings the stable Vorssaint releases after the previous base, the first its base")

        let first = ForkChangelog.releaseNotes(for: "1.0.0", fork: fork, upstream: upstream, fallbackBase: nil)
        suite.expect(first.sections.map(\.title) == ["Changed", "Vorssaint 3.4.1 · Added"]
                     && first.date == "2026-10-21",
                     "1.0.0 lists its own entries, then Vorssaint 3.4.1's")
        let second = ForkChangelog.releaseNotes(for: "1.1.0", fork: fork, upstream: upstream, fallbackBase: nil)
        suite.expect(second.sections.map(\.title) == ["Added", "Vorssaint 3.4.2 · Fixed"]
                     && !second.sections.contains { $0.title == "Summary" },
                     "the Based on line becomes Vorssaint sections, not a summary")

        let update = ForkChangelog.digest(from: "1.0.0", to: "1.1.0", fork: fork, upstream: upstream,
                                          fallbackBase: nil)
        suite.expect(update.changes.map(\.text) == ["Barforge mouse change.", "Upstream 3.4.2 fix."]
                     && update.versions == ["1.1.0", "Vorssaint 3.4.2"] && update.summary == nil,
                     "What's New after an update shows Barforge's changes, then Vorssaint's")
        let skipped = ForkChangelog.digest(from: "1.0.0", to: "1.2.0", fork: fork, upstream: upstream,
                                           fallbackBase: nil)
        suite.expect(skipped.changes.map(\.text) == ["Barforge mouse change.", "Upstream 3.5.0 change.",
                                                      "Upstream 3.4.2 fix."],
                     "skipping a release still brings every Vorssaint release since the old base")
        let unchanged = ForkChangelog.digest(from: "1.1.0", to: "1.1.1", fork: """
            ## [1.1.1] - 2026-11-20

            Based on Vorssaint 3.4.2.

            ### Fixed
            - Barforge fix.

            ## [1.1.0] - 2026-11-15

            Based on Vorssaint 3.4.2.
            """, upstream: upstream, fallbackBase: nil)
        suite.expect(unchanged.changes.map(\.text) == ["Barforge fix."],
                     "a release on the same base brings nothing from Vorssaint")
    }
}
