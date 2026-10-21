// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Feedback opens the repository's issue form with the fields filled in, and a
/// text too long for the link waits on the clipboard instead.
enum FeedbackIssueLinkTests {
    static func run(_ suite: TestSuite) {
        let repository = URL(string: "https://github.com/rfoerthe/barforge")!
        let diagnostics = FeedbackDiagnostics(appVersion: "1.0.3-beta.1", appBuild: "42", macOS: "26.1.0",
                                              macModel: "Mac16,1", language: "de", isBeta: true,
                                              updateChannel: "beta")

        let bug = FeedbackIssueLink.make(repository: repository, kind: .bug,
                                         message: "  Größe springt + Fenster flackert\nZweite Zeile & mehr  ",
                                         diagnostics: diagnostics)
        let bugFields = fields(of: bug?.url)
        suite.expect(bug?.url.absoluteString.hasPrefix("https://github.com/rfoerthe/barforge/issues/new?") == true
                     && bug?.textToPaste == nil,
                     "a bug report opens the repository's new issue page with the text in the link")
        suite.expect(bugFields["template"] == "bug_report.yml"
                     && bugFields["title"] == "Größe springt + Fenster flackert"
                     && bugFields["description"] == "Größe springt + Fenster flackert\nZweite Zeile & mehr",
                     "a bug report fills the bug form's title and description")
        suite.expect(bugFields["vorssaint_version"] == "1.0.3-beta.1 (42) · beta"
                     && bugFields["language"] == "de"
                     && bugFields["hardware"] == "Mac16,1 · macOS 26.1.0",
                     "selected technical details fill the bug form's version, language and hardware")
        suite.expect(bug?.url.absoluteString.contains("+") == false
                     && bug?.url.absoluteString.contains("%2B") == true,
                     "a plus in the text is encoded, so GitHub does not read it as a space")

        let plain = FeedbackIssueLink.make(repository: repository, kind: .bug,
                                           message: "Something broke here", diagnostics: nil)
        suite.expect(Set(fields(of: plain?.url).keys) == ["template", "title", "description"],
                     "without technical details the link carries only the text")

        let feature = FeedbackIssueLink.make(repository: repository, kind: .feature,
                                             message: "Please add a dark icon", diagnostics: diagnostics)
        let featureFields = fields(of: feature?.url)
        suite.expect(featureFields["template"] == "feature_request.yml"
                     && featureFields["problem"] == "Please add a dark icon\n\n---\n"
                        + "Barforge 1.0.3-beta.1 (42) · beta · macOS 26.1.0 · Mac16,1 · de"
                     && featureFields["vorssaint_version"] == nil,
                     "a feature idea fills the feature form, with technical details after the text")

        let long = String(repeating: "界", count: 2_000)
        let tooLong = FeedbackIssueLink.make(repository: repository, kind: .bug,
                                             message: long, diagnostics: diagnostics)
        let tooLongFields = fields(of: tooLong?.url)
        suite.expect(tooLong?.textToPaste == long && tooLongFields["description"] == nil
                     && tooLongFields["vorssaint_version"] != nil
                     && (tooLong?.url.absoluteString.count ?? .max) <= FeedbackIssueLink.maximumLength,
                     "a text too long for the link is left out of it and handed over for the clipboard")
        let longFeature = FeedbackIssueLink.make(repository: repository, kind: .feature,
                                                 message: long, diagnostics: diagnostics)
        suite.expect(longFeature?.textToPaste?.hasPrefix(long) == true
                     && longFeature?.textToPaste?.hasSuffix(FeedbackIssueLink.summary(of: diagnostics)) == true,
                     "a long feature idea keeps its technical details in the text to paste")

        let title = FeedbackIssueLink.title(for: String(repeating: "a", count: 120))
        suite.expect(title.count == FeedbackIssueLink.maximumTitleLength && title.hasSuffix("…"),
                     "a long first line is shortened to fit the issue title")

        // The link names forms and fields by id, so they must stay in the repository.
        for (form, ids) in [("bug_report.yml", ["description", "vorssaint_version", "language", "hardware"]),
                            ("feature_request.yml", ["problem"])] {
            let yaml = (try? String(contentsOfFile: ".github/ISSUE_TEMPLATE/\(form)", encoding: .utf8)) ?? ""
            for id in ids {
                suite.expect(yaml.contains("id: \(id)\n"), "\(form) still has the field \(id)")
            }
        }

        for language in AppLanguage.allCases {
            let strings = FeatureStrings.feedback(language)
            suite.expect(strings.sendButton.contains("GitHub") && !strings.copiedCaption.isEmpty
                         && !strings.privacyNote.contains("IP"),
                         "the feedback window says it continues on GitHub (\(language.rawValue))")
        }
    }

    private static func fields(of url: URL?) -> [String: String] {
        guard let url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }
}
