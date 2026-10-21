// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import AppKit

extension FeedbackDiagnostics {
    static func current() -> FeedbackDiagnostics {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let isBeta = AppInfo.isBeta
        let channel = AppInfo.isDeveloperBuild ? "developer" : (isBeta ? "beta" : (UpdateService.shared.includeBetaUpdates ? "beta-opt-in" : "stable"))
        return FeedbackDiagnostics(
            appVersion: AppInfo.version,
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0",
            macOS: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            macModel: modelIdentifier,
            language: L10n.shared.language.rawValue,
            isBeta: isBeta,
            updateChannel: channel
        )
    }

    private static let modelIdentifier: String? = {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }()
}

/// Opens the filled-in issue form of the repository this build came from.
@MainActor
enum FeedbackService {
    enum Outcome {
        case opened
        /// The text was too long for the link and waits on the clipboard.
        case openedWithCopiedText
        case failed
    }

    static func open(kind: FeedbackKind,
                     message: String,
                     diagnostics: FeedbackDiagnostics?) -> Outcome {
        guard let link = FeedbackIssueLink.make(repository: AppInfo.repositoryURL,
                                                kind: kind,
                                                message: message,
                                                diagnostics: diagnostics)
        else { return .failed }
        if let text = link.textToPaste {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        guard NSWorkspace.shared.open(link.url) else { return .failed }
        return link.textToPaste == nil ? .opened : .openedWithCopiedText
    }
}
