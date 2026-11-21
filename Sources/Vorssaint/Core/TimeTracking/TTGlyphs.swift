// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

// The menu bar glyphs of Time Tracking: nine icon sets with four states each,
// three plain (day arc, lock clock, day ring) and six playful (builder,
// craftswoman, coffee cup, hamster wheel, robot, rabbit) (port of Tagwerk's
// `glyphs.rs`).
//
// The shapes are designed in points for a reference size of 18 pt (stroke
// 2 pt, as strong as the other menu bar symbols). All sets share the stroke;
// the height of a figure follows an optical size per set (wide shapes look
// bigger and are drawn lower, as with SF Symbols). The width is the same for
// all states of a set, so nothing jumps.
//
// This file only describes the shapes and measures them; drawing them with
// AppKit is `TimeTrackingGlyphs` in UI/TimeTracking. One-colour states become
// template images; "running" (green) and "break" (orange) carry a solid
// colour area with white detail.

/// State the glyph shows (`glyphs.rs` `State`).
enum TTGlyphState: CaseIterable, Hashable, Sendable {
    case running, onBreak, outside, closed

    /// Has a colour accent (otherwise: template image).
    var hasAccent: Bool { self == .running || self == .onBreak }
}

/// What a shape is drawn with: the base colour or the accent, each with an
/// opacity, or white on the colour area (`glyphs.rs` `Ink`).
enum TTGlyphInk: Hashable, Sendable {
    case base(Double)
    case accent(Double)
    case white
}

typealias TTGlyphPoint = (x: Double, y: Double)

/// One shape in design coordinates (y downwards, angles in degrees,
/// mathematically counter-clockwise).
enum TTGlyphShape {
    /// Polyline with round ends.
    case line([TTGlyphPoint], width: Double)
    /// Arc clockwise from `from` to `to` (`from > to`); `dots` is the distance
    /// of the dots of a dotted line.
    case arc(center: TTGlyphPoint, radius: Double, from: Double, to: Double, width: Double, dots: Double?)
    case ring(center: TTGlyphPoint, radius: Double, width: Double, dots: Double?)
    case disc(center: TTGlyphPoint, radius: Double)
    /// Upper half of a disc (the sun on the horizon).
    case halfDisc(center: TTGlyphPoint, radius: Double)
    /// Rounded rectangle, filled (`stroke == nil`) or as a line.
    case roundedRect(origin: TTGlyphPoint, size: TTGlyphPoint, radius: Double, stroke: Double?, dots: Double?)
    /// Filled polygon.
    case polygon([TTGlyphPoint])
}

struct TTGlyphOp {
    let shape: TTGlyphShape
    let ink: TTGlyphInk
}

/// Where a figure lies in an image of a given symbol size (`glyphs.rs` `Layout`).
struct TTGlyphLayout: Hashable, Sendable {
    /// Scale of the geometry and of the strokes.
    let scale: Double
    let strokeScale: Double
    /// Width and height of the image (rounded up), width of the figure without stroke.
    let width: Double
    let height: Double
    let figureWidth: Double
    let minX: Double
    let originY: Double

    /// Horizontal offset in an image `width` wide (the figure in the middle).
    func originX(imageWidth: Double) -> Double {
        (imageWidth - figureWidth) / 2 - minX * scale
    }
}

enum TTGlyphs {
    /// Reference size of the design and the standard stroke in it.
    static let referenceHeight = 18.0
    static let stroke = 2.0
    /// Stroke of small details (hands, ticks, small rings).
    static let detailStroke = 1.8

    /// Optical size: height of the figure relative to the symbol size. Wide
    /// shapes (arc) are drawn lower, narrow ones (lock) a bit higher, so all
    /// look as big as the system symbols beside them (`glyphs.rs` `optical`).
    static func optical(_ set: TTIconSet) -> Double {
        switch set {
        case .tagbogen: return 0.71
        case .schlossuhr: return 1.06
        case .tagesring: return 1.0
        case .bauarbeiter, .handwerkerin: return 1.06
        case .kaffeetasse: return 1.08
        case .hamsterrad: return 1.0
        case .roboter: return 1.0
        case .kaninchen: return 1.06
        }
    }

    /// Point on a circle; angle mathematical (degrees, counter-clockwise), y downwards.
    static func onCircle(_ c: TTGlyphPoint, _ r: Double, _ deg: Double) -> TTGlyphPoint {
        let a = deg * .pi / 180
        return (c.x + r * cos(a), c.y - r * sin(a))
    }

    /// The shapes of a state, in drawing order.
    static func ops(_ set: TTIconSet, _ state: TTGlyphState) -> [TTGlyphOp] {
        var pen = Pen()
        switch set {
        case .tagbogen: tagbogen(&pen, state)
        case .schlossuhr: schlossuhr(&pen, state)
        case .tagesring: tagesring(&pen, state)
        case .bauarbeiter: figure(&pen, state, worker: true)
        case .handwerkerin: figure(&pen, state, worker: false)
        case .kaffeetasse: kaffeetasse(&pen, state)
        case .hamsterrad: hamsterrad(&pen, state)
        case .roboter: roboter(&pen, state)
        case .kaninchen: kaninchen(&pen, state)
        }
        return pen.ops
    }

    /// Common extent of all states of a set, without the stroke (`glyphs.rs` `bounds`).
    static func bounds(_ set: TTIconSet) -> (min: TTGlyphPoint, max: TTGlyphPoint) {
        var lo = (x: Double.greatestFiniteMagnitude, y: Double.greatestFiniteMagnitude)
        var hi = (x: -Double.greatestFiniteMagnitude, y: -Double.greatestFiniteMagnitude)
        func add(_ p: TTGlyphPoint) {
            lo = (Swift.min(lo.x, p.x), Swift.min(lo.y, p.y))
            hi = (Swift.max(hi.x, p.x), Swift.max(hi.y, p.y))
        }
        for state in TTGlyphState.allCases {
            for op in ops(set, state) {
                switch op.shape {
                case let .line(points, width):
                    // Strokes thicker than `stroke` reach beyond the margin the layout leaves.
                    let e = Swift.max((width - stroke) / 2, 0)
                    for p in points {
                        add((p.x - e, p.y - e))
                        add((p.x + e, p.y + e))
                    }
                case let .arc(c, r, a1, a2, _, _):
                    let n = Int(((a1 - a2) / 2).rounded(.up))
                    for i in 0...n {
                        add(onCircle(c, r, a1 + (a2 - a1) * Double(i) / Double(n)))
                    }
                case let .ring(c, r, _, _), let .disc(c, r):
                    add((c.x - r, c.y - r))
                    add((c.x + r, c.y + r))
                case let .halfDisc(c, r):
                    add((c.x - r, c.y - r))
                    add((c.x + r, c.y))
                case let .roundedRect(o, size, _, _, _):
                    add(o)
                    add((o.x + size.x, o.y + size.y))
                case let .polygon(points):
                    points.forEach(add)
                }
            }
        }
        return (lo, hi)
    }

    /// Where the figure lies in a symbol of size `size` (`glyphs.rs` `layout`).
    static func layout(_ set: TTIconSet, size: Double) -> TTGlyphLayout {
        let (lo, hi) = bounds(set)
        let k = size / referenceHeight
        let pad = stroke * k / 2
        let s = (size * optical(set) - 2 * pad) / (hi.y - lo.y)
        let figureWidth = (hi.x - lo.x) * s
        // Higher than `size` only when the figure asks for it.
        let height = (size * Swift.max(optical(set), 1)).rounded(.up)
        return TTGlyphLayout(scale: s, strokeScale: k, width: (figureWidth + 2 * pad).rounded(.up),
                             height: height, figureWidth: figureWidth, minX: lo.x,
                             // vertically centred in the image
                             originY: (height - (hi.y - lo.y) * s) / 2 - lo.y * s)
    }

    /// Width of the symbols of a set at symbol size `size`.
    static func width(_ set: TTIconSet, size: Double) -> Double {
        layout(set, size: size).width
    }

    // MARK: Pen

    /// Collects the shapes with the current ink.
    private struct Pen {
        var ink = TTGlyphInk.base(1)
        var ops: [TTGlyphOp] = []

        mutating func base() { ink = .base(1) }
        mutating func accent() { ink = .accent(1) }
        mutating func white() { ink = .white }

        mutating func add(_ shape: TTGlyphShape) { ops.append(TTGlyphOp(shape: shape, ink: ink)) }

        mutating func line(_ points: [TTGlyphPoint], _ w: Double) { add(.line(points, width: w)) }
        mutating func arc(_ c: TTGlyphPoint, _ r: Double, _ a1: Double, _ a2: Double, _ w: Double,
                          _ dots: Double? = nil) {
            add(.arc(center: c, radius: r, from: a1, to: a2, width: w, dots: dots))
        }
        mutating func ring(_ c: TTGlyphPoint, _ r: Double, _ w: Double, _ dots: Double? = nil) {
            add(.ring(center: c, radius: r, width: w, dots: dots))
        }
        mutating func disc(_ c: TTGlyphPoint, _ r: Double) { add(.disc(center: c, radius: r)) }
        mutating func halfDisc(_ c: TTGlyphPoint, _ r: Double) { add(.halfDisc(center: c, radius: r)) }
        mutating func rrect(_ o: TTGlyphPoint, _ size: TTGlyphPoint, _ r: Double, stroke: Double? = nil,
                            dots: Double? = nil) {
            add(.roundedRect(origin: o, size: size, radius: r, stroke: stroke, dots: dots))
        }
        mutating func poly(_ points: [TTGlyphPoint]) { add(.polygon(points)) }

        /// Steam: a small S curve, its top at `(x, y)`.
        mutating func steam(_ x: Double, _ y: Double, _ r: Double) {
            arc((x, y + r), r, 90, -90, TTGlyphs.detailStroke)
            arc((x, y + 3 * r), r, 270, 90, TTGlyphs.detailStroke)
        }

        /// "z" with its upper left corner at `(x, y)` and side `a`.
        mutating func zee(_ x: Double, _ y: Double, _ a: Double, _ w: Double) {
            line([(x, y), (x + a, y), (x, y + a), (x + a, y + a)], w)
        }

        /// Happy eye "^" around `(x, y)`.
        mutating func happyEye(_ x: Double, _ y: Double, _ a: Double) {
            line([(x - a, y + a * 0.8), (x, y - a * 0.2), (x + a, y + a * 0.8)], TTGlyphs.detailStroke)
        }
    }

    // MARK: Icon sets

    private static let w = stroke
    private static let wd = detailStroke

    /// A – Tagbogen: the working day as a sun arc above the horizon.
    private static func tagbogen(_ pen: inout Pen, _ state: TTGlyphState) {
        let r = 15.0
        let sunAngle = 52.0
        let c = (x: 0.0, y: 0.0)
        switch state {
        case .running, .onBreak:
            // Dome as a colour area, the sun in white inside.
            pen.accent()
            pen.halfDisc(c, r + w / 2)
            pen.white()
            let sun = onCircle((0, 0), r - 5.6, sunAngle)
            if state == .running {
                pen.disc(sun, 3.0)
            } else {
                pen.ring(sun, 2.4, wd)
            }
            pen.base()
        case .outside:
            pen.arc(c, r, 180, 0, w, .pi * r / 13)
        case .closed:
            // End of work: the sun sets on the horizon.
            pen.halfDisc(c, 8.0)
            for a in [30.0, 90.0, 150.0] {
                pen.line([onCircle((0, 0), 10.4, a), onCircle((0, 0), 13.8, a)], w)
            }
        }
        // The horizon last, above the dome.
        pen.line([(-r - 1.5, 0), (r + 1.5, 0)], w)
    }

    /// B – Schlossuhr: unlocked = working time, locked = break.
    private static func schlossuhr(_ pen: inout Pen, _ state: TTGlyphState) {
        let r = 6.4
        let leg = 3.7
        let legEnd = -5.0 // the legs end in the ring
        let c = (x: 0.0, y: 0.0)
        let open = state == .running || state == .outside
        let top = open ? -11.0 : -9.0
        pen.line([(-leg, legEnd), (-leg, top)], w)
        pen.arc((0, top), leg, 180, 0, w)
        pen.line([(leg, top), (leg, open ? -9.2 : legEnd)], w)
        switch state {
        case .running, .onBreak:
            // Case as a colour area, hands in white.
            pen.accent()
            pen.disc(c, r + w / 2)
            pen.white()
            pen.line([(0, -3.6), (0, 0), (2.9, 0)], wd)
            pen.base()
        case .outside:
            pen.ring(c, r, w, 2 * .pi * r / 12)
        case .closed:
            pen.ring(c, r, w)
            pen.line([(-2.9, 0.1), (-0.8, 2.2), (3.0, -1.9)], wd)
        }
    }

    /// C – Tagesring: progress towards the day's target.
    private static func tagesring(_ pen: inout Pen, _ state: TTGlyphState) {
        let r = 8.2
        let c = (x: 0.0, y: 0.0)
        switch state {
        case .running, .onBreak:
            // Progress in the accent, inside a colour area with a white core.
            pen.ink = .base(0.3)
            pen.ring(c, r, w)
            pen.accent()
            pen.arc(c, r, 90, 90 - 0.68 * 360, w)
            pen.disc(c, r - 2.9)
            pen.white()
            if state == .running {
                pen.disc(c, 1.9)
            } else {
                pen.ring(c, 1.9, 1.5)
            }
            pen.base()
        case .outside:
            pen.ring(c, r, w, 2 * .pi * r / 14)
        case .closed:
            pen.ring(c, r, w)
            pen.line([(-3.0, 0.1), (-0.9, 2.2), (3.1, -2.0)], w)
        }
    }

    /// D/E – figure (head and shoulders) with a tool, a cup, "Zz" or waving
    /// beside it. `worker`: builder with helmet and hammer, otherwise the
    /// craftswoman with bun, bow and spanner.
    private static func figure(_ pen: inout Pen, _ state: TTGlyphState, worker: Bool) {
        let colored = state.hasAccent
        // Shoulders (in the accent: the shirt).
        if colored { pen.accent() }
        pen.halfDisc((0, 10), 7.1)
        pen.base()
        // Head
        pen.disc((0, -1.8), 3.1)
        if worker {
            if colored { pen.accent() }
            pen.halfDisc((0, -6.6), 4.4)
            pen.line([(-6.0, -6.6), (6.0, -6.6)], w)
            if colored {
                pen.white()
                pen.line([(0, -10), (0, -7.8)], 1.3)
            }
            pen.base()
        } else {
            // Bun with a bow
            pen.disc((0, -7.2), 2.2)
            if colored { pen.accent() }
            pen.poly([(0, -7.6), (-4.6, -10.2), (-4.6, -5.2)])
            pen.poly([(0, -7.6), (4.6, -10.2), (4.6, -5.2)])
            pen.base()
        }
        switch state {
        case .running:
            if worker {
                // raised hammer
                pen.line([(6.8, 6.0), (10.2, -1.2)], wd)
                pen.line([(8.2, -3.0), (12.6, -0.9)], 2.8)
            } else {
                // spanner
                pen.line([(6.8, 6.0), (9.8, 0.0)], wd + 0.4)
                pen.arc((10.6, -1.8), 2.0, 380, 75, wd)
            }
        case .onBreak:
            // Mug with steam
            pen.rrect((6.6, 0.4), (4.4, 4.8), 1.2)
            pen.arc((11.0, 2.6), 1.4, 90, -90, 1.4)
            pen.steam(8.8, -4.6, 0.85)
        case .outside:
            pen.zee(7.0, -4.2, 3.2, wd)
            pen.zee(10.8, -9.6, 2.2, 1.5)
        case .closed:
            // Waving: done for the day!
            pen.line([(5.6, 3.6), (9.0, -3.2)], w)
            pen.disc((9.4, -4.4), 1.8)
            pen.arc((9.4, -4.4), 4.0, 75, 15, 1.4)
        }
    }

    /// F – coffee cup with a face.
    private static func kaffeetasse(_ pen: inout Pen, _ state: TTGlyphState) {
        // A big mug and short steam, or the cup looks small beside the system symbols.
        let (x0, y0, cw, ch) = (-7.0, -3.5, 12.0, 12.5)
        let cx = x0 + cw / 2
        let (el, er, ey) = (cx - 2.4, cx + 2.4, 1.7)
        // Handle
        pen.arc((5.0, 2.6), 3.0, 75, -75, w)
        switch state {
        case .running, .onBreak:
            pen.steam(cx - 2.2, -8.6, 0.75)
            pen.steam(cx + 2.2, -8.6, 0.75)
            pen.accent()
            pen.rrect((x0 - 0.5, y0 - 0.5), (cw + 1.0, ch + 1.0), 3.2)
            pen.white()
            if state == .running {
                pen.disc((el, ey), 1.1)
                pen.disc((er, ey), 1.1)
                pen.arc((cx, 3.9), 2.5, 340, 200, wd)
            } else {
                pen.happyEye(el, ey, 1.3)
                pen.happyEye(er, ey, 1.3)
                pen.arc((cx, 3.7), 2.7, 350, 190, wd)
            }
            pen.base()
        case .outside:
            pen.rrect((x0, y0), (cw, ch), 2.8, stroke: w)
            // tired eyes, a small mouth, "z"
            pen.line([(el - 1.2, ey + 0.4), (el + 1.2, ey + 0.4)], wd)
            pen.line([(er - 1.2, ey + 0.4), (er + 1.2, ey + 0.4)], wd)
            pen.line([(cx - 1.0, 5.4), (cx + 1.0, 5.4)], wd)
            pen.zee(3.2, -8.8, 2.4, 1.4)
        case .closed:
            pen.rrect((x0, y0), (cw, ch), 2.8, stroke: w)
            pen.line([(cx - 3.0, 3.2), (cx - 0.9, 5.4), (cx + 3.0, 1.2)], wd)
        }
    }

    /// G – hamster in a hamster wheel.
    private static func hamsterrad(_ pen: inout Pen, _ state: TTGlyphState) {
        let c = (x: 0.0, y: -1.0)
        let r = 7.5
        // Stand
        pen.line([(-2.8, 6.4), (-4.8, 9.6)], w)
        pen.line([(2.8, 6.4), (4.8, 9.6)], w)
        pen.line([(-6.6, 9.6), (6.6, 9.6)], w)
        // Wheel with spokes
        if state == .outside {
            pen.ring(c, r, w, 2 * .pi * r / 16)
        } else {
            pen.ring(c, r, w)
        }
        pen.disc(c, 0.9)
        switch state {
        case .running:
            // The hamster runs, speed lines behind it.
            pen.line([(-5.2, 0.0), (-3.6, 0.0)], 1.4)
            pen.line([(-5.0, 2.4), (-3.6, 2.4)], 1.4)
            pen.accent()
            pen.disc((0.2, 2.4), 3.2)
            pen.disc((3.2, 0.8), 2.3)
            pen.disc((2.3, -1.3), 1.0)
            pen.white()
            pen.disc((3.9, 0.4), 0.6)
            pen.base()
        case .onBreak:
            // The hamster curls up and sleeps.
            pen.accent()
            pen.disc((-0.4, 2.5), 3.3)
            pen.disc((2.4, 2.6), 2.2)
            pen.disc((1.8, 0.5), 0.9)
            pen.white()
            pen.line([(2.3, 2.3), (3.6, 2.3)], 1.0)
            pen.base()
        case .outside, .closed:
            // An empty wheel with spokes: dotted outside, solid after the end of work.
            pen.ink = .base(0.5)
            for a in [90.0, 210.0, 330.0] {
                pen.line([c, onCircle(c, r - 0.8, a)], 1.2)
            }
            pen.base()
        }
    }

    /// H – robot.
    private static func roboter(_ pen: inout Pen, _ state: TTGlyphState) {
        let (x0, y0, rw, rh) = (-6.5, -4.5, 13.0, 11.0)
        let (el, er, ey) = (-2.8, 2.8, 0.4)
        // Antenna and ears
        pen.line([(0, y0), (0, -7.4)], wd)
        pen.rrect((-8.6, -0.4), (1.6, 3.6), 0.7)
        pen.rrect((7.0, -0.4), (1.6, 3.6), 0.7)
        switch state {
        case .running, .onBreak:
            pen.accent()
            pen.disc((0, -8.6), 1.6)
            pen.rrect((x0 - 0.5, y0 - 0.5), (rw + 1.0, rh + 1.0), 3.4)
            pen.white()
            if state == .running {
                pen.disc((el, ey), 1.7)
                pen.disc((er, ey), 1.7)
                pen.line([(-2.6, 3.8), (2.6, 3.8)], wd)
            } else {
                // sleepy, yawning
                pen.line([(el - 1.4, ey + 0.6), (el + 1.4, ey + 0.6)], wd)
                pen.line([(er - 1.4, ey + 0.6), (er + 1.4, ey + 0.6)], wd)
                pen.ring((0, 3.8), 1.0, 1.3)
            }
            pen.base()
        case .outside:
            pen.ring((0, -8.6), 1.3, 1.3)
            pen.rrect((x0, y0), (rw, rh), 3.0, stroke: w, dots: 2.6)
            pen.line([(el - 1.0, ey + 0.4), (el + 1.0, ey + 0.4)], wd)
            pen.line([(er - 1.0, ey + 0.4), (er + 1.0, ey + 0.4)], wd)
        case .closed:
            pen.disc((0, -8.6), 1.6)
            pen.rrect((x0, y0), (rw, rh), 3.0, stroke: w)
            pen.happyEye(el, ey + 0.2, 1.4)
            pen.happyEye(er, ey + 0.2, 1.4)
            pen.arc((0, 2.4), 2.4, 340, 200, wd)
        }
    }

    /// J – rabbit: ears up at work, one folds over during a break.
    private static func kaninchen(_ pen: inout Pen, _ state: TTGlyphState) {
        let head = (x: 0.0, y: 3.4)
        let r = 5.6
        let ear = 3.0
        let earBase = -2.3 // where the ears start (they end at the head)
        let (el, er, ey) = (-2.2, 2.2, 2.6)
        func leftEar(_ pen: inout Pen) { pen.line([(-2.3, earBase), (-3.2, -9.0)], ear) }
        func rightEar(_ pen: inout Pen) { pen.line([(2.3, earBase), (3.2, -9.0)], ear) }
        func closedEyes(_ pen: inout Pen) {
            pen.line([(el - 0.9, ey + 0.3), (el + 0.9, ey + 0.3)], 1.4)
            pen.line([(er - 0.9, ey + 0.3), (er + 0.9, ey + 0.3)], 1.4)
        }
        switch state {
        case .running, .onBreak:
            pen.accent()
            leftEar(&pen)
            if state == .running {
                rightEar(&pen)
            } else {
                // a folded ear
                pen.line([(2.3, earBase), (3.0, -5.6), (5.8, -3.8)], ear)
            }
            pen.disc(head, r)
            pen.white()
            pen.line([(-2.5, -3.2), (-3.0, -7.6)], 1.0)
            if state == .running {
                pen.line([(2.5, -3.2), (3.0, -7.6)], 1.0)
                pen.disc((el, ey), 0.95)
                pen.disc((er, ey), 0.95)
            } else {
                closedEyes(&pen)
            }
            pen.disc((0, 4.9), 0.8)
            pen.base()
        case .outside:
            // asleep: eyes closed, a dotted head, "z"
            leftEar(&pen)
            rightEar(&pen)
            pen.ring(head, r, w, 2 * .pi * r / 12)
            closedEyes(&pen)
            pen.disc((0, 5.0), 0.8)
            pen.zee(5.9, -9.0, 2.2, 1.4)
        case .closed:
            leftEar(&pen)
            rightEar(&pen)
            pen.ring(head, r, w)
            pen.line([(-2.6, 3.4), (-0.8, 5.2), (2.8, 1.6)], wd)
        }
    }
}
