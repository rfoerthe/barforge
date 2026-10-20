// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// A fork keeps its own changes in CHANGELOG-BARFORGE.md so CHANGELOG.md stays
/// identical to upstream. Barforge numbers its own versions (1.0.0 onwards),
/// so What's New and the release notes read this file alone; each release
/// names the Vorssaint version it is based on.
enum ForkChangelog {
    static func bundled() -> String? {
        guard let url = Bundle.main.url(forResource: "CHANGELOG-BARFORGE", withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
