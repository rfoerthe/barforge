// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import Foundation
import Security

/// Static identity of the app, shared by UI, notifications and tooling.
enum AppInfo {
    static let name = "Barforge"
    static let copyright = "© 2026 Vorssaint · © 2026 Roland Foerther"
    static let licenseURL = URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!
    static var websiteURL: URL { isForkBuild ? repositoryURL : URL(string: "https://vorssaint.com")! }
    static let upstreamRepository = "vorssaint/vorssaint-utils"

    /// "owner/name" of the fork this build came from, stamped into Info.plist
    /// as `VorssaintForkRepository`. Nil in the official app.
    static var forkRepository: String? {
        AppInfoSupport.forkRepository(Bundle.main.object(forInfoDictionaryKey: "VorssaintForkRepository") as? String)
    }

    static var isForkBuild: Bool { forkRepository != nil }

    /// The upstream release a fork build is made from, stamped into Info.plist
    /// as `BarforgeUpstreamVersion`, since the fork numbers its own versions.
    static var upstreamVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "BarforgeUpstreamVersion") as? String
    }

    /// A fork build links to its own repository.
    static var repositoryURL: URL {
        URL(string: "https://github.com/\(forkRepository ?? upstreamRepository)")!
    }

    /// Where updates come from: a fork build follows its own releases, so an
    /// official release never replaces it and drops its changes.
    static var updateRepository: String { forkRepository ?? upstreamRepository }

    /// The Developer ID this app is signed with. The installer accepts only an
    /// update signed by the same team under the same bundle identifier.
    /// Nil for an ad-hoc or self-signed build, which cannot update itself.
    static let updateSigner: UpdateSigner? = {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation),
                                            &info) == errSecSuccess,
              let info = info as? [String: Any],
              let signer = UpdateSigner(bundleID: info[kSecCodeInfoIdentifier as String] as? String,
                                        teamID: info[kSecCodeInfoTeamIdentifier as String] as? String)
        else { return nil }
        // The team in the signature counts only when Apple issued it.
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(signer.appRequirement as CFString, [], &requirement) == errSecSuccess,
              let requirement,
              SecCodeCheckValidity(code, [], requirement) == errSecSuccess
        else { return nil }
        return signer
    }()

    /// The local dev build never updates itself; any other build does when it
    /// carries a Developer ID signature the installer can hold the update to.
    static var receivesUpdates: Bool { !isDeveloperBuild && updateSigner != nil }
    static let coffeeURL = URL(string: "https://buymeacoffee.com/vorssaint")!
    static let discordURL = URL(string: "https://discord.gg/M6BwWH4BJp")!
    static let socialURL = URL(string: "https://x.com/vorssaint")!

    /// The bundle version. The fallback only applies to the bare binary
    /// (e.g. `--selftest`), never the shipped app, which reads its Info.plist.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// True for the local "Vorssaint (Developer)" build (bundle id ends in `.dev`).
    /// It is never published and never auto-updates; all work is tested here first.
    static var isDeveloperBuild: Bool {
        (Bundle.main.bundleIdentifier ?? "").hasSuffix(".dev")
    }

    /// True when the current version is a pre-release (e.g. 3.3.4-beta.1 or 3.3.4-rc.1).
    static var isBeta: Bool {
        if isDeveloperBuild && UserDefaults.standard.bool(forKey: DefaultsKey.simulateBetaUI) {
            return true
        }
        let v = version.lowercased()
        return v.contains("-beta") || v.contains("-rc") || v.contains("-alpha")
    }

    /// The git commit a Developer build was compiled from, e.g. "ed2ebba · 2026-06-15 21:30"
    /// (or with a "-dirty" suffix on the SHA for uncommitted changes). build.sh stamps
    /// this into the Developer bundle only, so you can confirm at a glance that the
    /// running dev app matches the source you are about to change. nil in the official app.
    static var buildCommit: String? {
        Bundle.main.object(forInfoDictionaryKey: "VorssaintBuildCommit") as? String
    }
}

enum AppInfoSupport {
    /// Accepts only a plain GitHub "owner/name"; anything else is no fork.
    static func forkRepository(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.unicodeScalars.allSatisfy(allowed.contains) })
        else { return nil }
        return raw
    }
}
