// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import Foundation

enum FeedbackKind: String, CaseIterable {
    case bug
    case feature
}

struct FeedbackDiagnostics {
    let appVersion: String
    let appBuild: String
    let macOS: String
    let macModel: String?
    let language: String
    let isBeta: Bool
    let updateChannel: String
}

/// Feedback opens the repository's GitHub issue form, filled in through the
/// link. Nothing leaves the Mac until the person submits the issue there.
enum FeedbackIssueLink {
    /// GitHub turns away longer links, so a longer text goes on the clipboard.
    static let maximumLength = 8_000
    static let maximumTitleLength = 80

    struct Link: Equatable {
        let url: URL
        /// The text that did not fit into the link, to paste into the form.
        let textToPaste: String?
    }

    static func make(repository: URL,
                     kind: FeedbackKind,
                     message: String,
                     diagnostics: FeedbackDiagnostics?) -> Link? {
        var text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        var fields: [(String, String)]
        let textField: String
        switch kind {
        case .bug:
            fields = [("template", "bug_report.yml"), ("title", title(for: text))]
            textField = "description"
            if let diagnostics {
                let hardware = [diagnostics.macModel, "macOS \(diagnostics.macOS)"].compactMap { $0 }
                fields += [
                    ("vorssaint_version",
                     "\(diagnostics.appVersion) (\(diagnostics.appBuild)) · \(diagnostics.updateChannel)"),
                    ("language", diagnostics.language),
                    ("hardware", hardware.joined(separator: " · "))
                ]
            }
        case .feature:
            fields = [("template", "feature_request.yml"), ("title", title(for: text))]
            textField = "problem"
            // The feature form has no fields for these, so they follow the text.
            if let diagnostics { text += "\n\n---\n" + summary(of: diagnostics) }
        }

        guard let full = url(repository, fields + [(textField, text)]) else { return nil }
        if full.absoluteString.count <= maximumLength { return Link(url: full, textToPaste: nil) }
        guard let short = url(repository, fields) else { return nil }
        return Link(url: short, textToPaste: text)
    }

    /// The first line of the text, shortened to fit an issue title.
    static func title(for text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        guard line.count > maximumTitleLength else { return line }
        return line.prefix(maximumTitleLength - 1).trimmingCharacters(in: .whitespaces) + "…"
    }

    static func summary(of diagnostics: FeedbackDiagnostics) -> String {
        [
            "Barforge \(diagnostics.appVersion) (\(diagnostics.appBuild))",
            diagnostics.updateChannel,
            "macOS \(diagnostics.macOS)",
            diagnostics.macModel,
            diagnostics.language
        ].compactMap { $0 }.joined(separator: " · ")
    }

    // Only unreserved ASCII stays as it is. A bare "+" would read as a space.
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func url(_ repository: URL, _ fields: [(String, String)]) -> URL? {
        let query = fields.compactMap { name, value -> String? in
            guard let encoded = value.addingPercentEncoding(withAllowedCharacters: unreserved) else { return nil }
            return "\(name)=\(encoded)"
        }
        guard query.count == fields.count else { return nil }
        return URL(string: repository.absoluteString + "/issues/new?" + query.joined(separator: "&"))
    }
}
