// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

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
        suite.expect(version.contains("+") && parsed?.isPrerelease == false
                     && parsed == UpdateServiceSupport.SemanticVersion(raw: version.components(separatedBy: "+")[0]),
                     "the fork marks its version with build metadata, so it is neither a beta nor a newer release")

        for language in AppLanguage.allCases {
            let text = FeatureStrings.forkBuild(language)
            for format in [text.aboutFormat, text.updatesOffFormat] {
                suite.expect(format.components(separatedBy: "%@").count == 2 && !format.contains("\u{2014}"),
                             "fork notices take the repository once (\(language.rawValue))")
            }
        }
    }
}
