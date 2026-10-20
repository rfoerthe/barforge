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
        let listed = ReleaseNotes.notes(for: version, changelog: changelog).sections.isEmpty
            ? ReleaseNotes.notes(for: "Unreleased", changelog: changelog) : ReleaseNotes.notes(for: version, changelog: changelog)
        suite.expect(!listed.sections.isEmpty, "What's New has Barforge notes for \(version)")

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
}
