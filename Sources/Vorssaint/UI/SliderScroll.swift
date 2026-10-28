// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

/// Enabled level controls receive the wheel before an enclosing horizontal strip.
protocol SliderScrollTarget: AnyObject {
    var acceptsSliderScroll: Bool { get }
}

/// A scroll over a level bar moves it, so it can be set without dragging.
/// Up and right raise it whichever way content scrolls. A wheel notch is one
/// step, like a volume key; a trackpad moves it with the fingers. A trackpad
/// gesture belongs to the bar only when it starts there: a list scrolling
/// under a still pointer keeps scrolling, and the momentum of a flick that
/// moved the bar is swallowed rather than moving the bar or the list.
struct SliderScroll {
    enum Phase { case none, began, changed, ended, momentum }
    enum Outcome: Equatable { case pass, hold, move(Double) }

    static let wheelStep = 0.05
    /// Two hundred points of finger travel cross the whole range.
    static let pointStep = 0.005
    /// Trackpads may send one phaseless event between the lift and momentum.
    static let liftGap = 0.35

    /// Where the gesture on the bar is heading, ahead of a level that settles late.
    private var level: Double?
    private var coasting = false
    private var liftedAt: Double?

    static func step(dx: Double, dy: Double, precise: Bool, inverted: Bool) -> Double {
        let up = dy * (inverted ? -1 : 1)
        let right = dx * (inverted ? 1 : -1)
        let amount = abs(dx) > abs(dy) ? right : up
        guard amount.isFinite, amount != 0 else { return 0 }
        return precise ? amount * pointStep : (amount > 0 ? wheelStep : -wheelStep)
    }

    mutating func handle(_ phase: Phase, dx: Double, dy: Double, precise: Bool, inverted: Bool,
                         timestamp: Double, current: Double, range: ClosedRange<Double>) -> Outcome {
        switch phase {
        case .began:
            level = current
            coasting = false
        case .changed:
            guard level != nil else { coasting = false; return .pass }
        case .ended:
            guard level != nil else { return .pass }
            level = nil
            coasting = true
            liftedAt = timestamp
            return .hold
        case .momentum:
            return coasting ? .hold : .pass
        case .none:
            if coasting, precise, let liftedAt, timestamp >= liftedAt, timestamp - liftedAt <= Self.liftGap {
                return .hold
            }
            coasting = false
        }
        let span = range.upperBound - range.lowerBound
        let step = Self.step(dx: dx, dy: dy, precise: precise, inverted: inverted)
        guard span.isFinite, span > 0, step != 0 else { return .hold }
        let base = (level ?? current).isFinite ? (level ?? current) : range.lowerBound
        let next = min(range.upperBound, max(range.lowerBound, base + step * span))
        if level != nil { level = next }
        return .move(next)
    }
}
