// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import CoreGraphics
import Foundation

/// The WindowServer reads the switcher's exclusive full screen check needs.
/// Upstream keeps these in the Dynamic Island's NotchAppFullscreen, which
/// Barforge does not ship.
enum AppFullscreenWindows {
    struct WindowInfo: Equatable {
        let number: CGWindowID
        let ownerPID: pid_t
        let layer: Int
        let alpha: Double
        let bounds: CGRect
    }

    /// Allows a point of rounding on each edge.
    static func covers(_ window: CGRect, _ display: CGRect) -> Bool {
        guard !display.isEmpty else { return false }
        return window.insetBy(dx: -1, dy: -1).contains(display)
    }

    /// The windows on screen, front to back, or nil when the window server
    /// did not answer.
    static func onScreenWindows(ownerPID: pid_t? = nil) -> [WindowInfo]? {
        guard let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        return entries.compactMap { entry in
            guard let pid = (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  ownerPID == nil || ownerPID == pid,
                  let number = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let layer = (entry[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
            else { return nil }
            let alpha = (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            return WindowInfo(number: number, ownerPID: pid, layer: layer, alpha: alpha, bounds: rect)
        }
    }

    static func activeDisplays() -> [CGDirectDisplayID: CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [:] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [:] }
        var frames: [CGDirectDisplayID: CGRect] = [:]
        for id in ids.prefix(Int(count)) { frames[id] = CGDisplayBounds(id) }
        return frames
    }
}
