// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit

/// Draws the glyphs of `TTGlyphs` with AppKit (port of the drawing part of
/// Tagwerk's `glyphs.rs`). One-colour states are template images, so macOS
/// colours and dims them; "running" and "break" carry their accent and draw
/// the base parts in `textColor` anew on every draw, so they follow the
/// appearance of the menu bar.
enum TimeTrackingGlyphs {
    /// Image of a state at symbol size `size` (the image is `size` high, a
    /// bit more for narrow figures), at least `minWidth` wide with the figure
    /// in the middle (`glyphs.rs` `image`).
    static func image(_ set: TTIconSet, _ state: TTGlyphState, size: CGFloat, minWidth: CGFloat = 0,
                      description: String) -> NSImage {
        let layout = TTGlyphs.layout(set, size: Double(size))
        let width = max(layout.width, Double(minWidth).rounded(.up))
        let pen = Renderer(scale: layout.scale, strokeScale: layout.strokeScale,
                           originX: layout.originX(imageWidth: width), originY: layout.originY,
                           accent: state.hasAccent ? accent(state) : nil)
        let ops = TTGlyphs.ops(set, state)
        let image = NSImage(size: NSSize(width: width, height: layout.height), flipped: true) { _ in
            for op in ops { pen.draw(op) }
            return true
        }
        if state.hasAccent {
            // The base colour resolves on every draw (light or dark menu bar).
            image.cacheMode = .never
        } else {
            image.isTemplate = true
        }
        image.accessibilityDescription = description
        return image
    }

    /// Size of the menu bar icon, like the symbols of macOS (18 pt in the
    /// usual 24 pt menu bar) (`menubar.rs` `icon_height`).
    static func menuBarSize(thickness: CGFloat) -> CGFloat {
        min(max((thickness - 6).rounded(), 12), 20)
    }

    private static func accent(_ state: TTGlyphState) -> NSColor {
        state == .running ? .systemGreen : .systemOrange
    }

    /// Draws the shapes into the current (flipped) context.
    private struct Renderer {
        let scale: Double
        let strokeScale: Double
        let originX: Double
        let originY: Double
        /// Accent of the state; without it the image is a template drawn in black.
        let accent: NSColor?

        func point(_ p: TTGlyphPoint) -> NSPoint {
            NSPoint(x: originX + p.x * scale, y: originY + p.y * scale)
        }

        func setColor(_ ink: TTGlyphInk) {
            let color: NSColor
            switch (accent, ink) {
            case (nil, .base(let a)), (nil, .accent(let a)):
                // Template: only the opacity counts.
                color = NSColor(white: 0, alpha: a)
            case (_, .white):
                color = .white
            case (.some, .base(let a)):
                // Opaque like the template symbols (labelColor is slightly transparent).
                color = a >= 1 ? .textColor : NSColor.textColor.withAlphaComponent(a)
            case (.some(let accent), .accent(let a)):
                color = a >= 1 ? accent : accent.withAlphaComponent(a)
            }
            color.set()
        }

        func stroke(_ path: NSBezierPath, width: Double, dots: Double?, ink: TTGlyphInk) {
            path.lineWidth = width * strokeScale
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            if let dots {
                let pattern: [CGFloat] = [0.001, dots * scale]
                path.setLineDash(pattern, count: 2, phase: 0)
            }
            setColor(ink)
            path.stroke()
        }

        func fill(_ path: NSBezierPath, ink: TTGlyphInk) {
            setColor(ink)
            path.fill()
        }

        /// Arc from `a1` to `a2` (degrees) as cubic Bézier curves (`append_arc`).
        func appendArc(_ path: NSBezierPath, _ c: TTGlyphPoint, _ r: Double, _ a1: Double, _ a2: Double) {
            let n = max(Int((abs(a1 - a2) / 90).rounded(.up)), 1)
            let step = (a2 - a1) / Double(n)
            let t = 4.0 / 3.0 * tan(step * .pi / 180 / 4)
            for i in 0..<n {
                let a = a1 + step * Double(i)
                let b = a1 + step * Double(i + 1)
                let (ar, br) = (a * .pi / 180, b * .pi / 180)
                let pa = TTGlyphs.onCircle(c, r, a)
                let pb = TTGlyphs.onCircle(c, r, b)
                let c1 = (x: pa.x - t * r * sin(ar), y: pa.y - t * r * cos(ar))
                let c2 = (x: pb.x + t * r * sin(br), y: pb.y + t * r * cos(br))
                path.curve(to: point(pb), controlPoint1: point(c1), controlPoint2: point(c2))
            }
        }

        func draw(_ op: TTGlyphOp) {
            switch op.shape {
            case let .line(points, width):
                guard let first = points.first else { return }
                let path = NSBezierPath()
                path.move(to: point(first))
                for p in points.dropFirst() { path.line(to: point(p)) }
                stroke(path, width: width, dots: nil, ink: op.ink)
            case let .arc(c, r, a1, a2, width, dots):
                let path = NSBezierPath()
                path.move(to: point(TTGlyphs.onCircle(c, r, a1)))
                appendArc(path, c, r, a1, a2)
                stroke(path, width: width, dots: dots, ink: op.ink)
            case let .ring(c, r, width, dots):
                let path = NSBezierPath()
                path.move(to: point(TTGlyphs.onCircle(c, r, 90)))
                appendArc(path, c, r, 90, -270)
                if dots == nil { path.close() }
                stroke(path, width: width, dots: dots, ink: op.ink)
            case let .disc(c, r):
                let o = point((c.x - r, c.y - r))
                let d = 2 * r * scale
                fill(NSBezierPath(ovalIn: NSRect(x: o.x, y: o.y, width: d, height: d)), ink: op.ink)
            case let .halfDisc(c, r):
                let path = NSBezierPath()
                path.move(to: point((c.x - r, c.y)))
                appendArc(path, c, r, 180, 0)
                path.close()
                fill(path, ink: op.ink)
            case let .roundedRect(o, size, r, strokeWidth, dots):
                let origin = point(o)
                let rect = NSRect(x: origin.x, y: origin.y, width: size.x * scale, height: size.y * scale)
                let path = NSBezierPath(roundedRect: rect, xRadius: r * scale, yRadius: r * scale)
                if let strokeWidth {
                    stroke(path, width: strokeWidth, dots: dots, ink: op.ink)
                } else {
                    fill(path, ink: op.ink)
                }
            case let .polygon(points):
                guard let first = points.first else { return }
                let path = NSBezierPath()
                path.move(to: point(first))
                for p in points.dropFirst() { path.line(to: point(p)) }
                path.close()
                fill(path, ink: op.ink)
            }
        }
    }
}

/// Colours that mean the same in the menu and the windows (`palette.rs`):
/// green = in the plus or running, red = in the minus or an error, orange = a
/// break or a warning, indigo = end of work, teal = absence. The system
/// colours alone are too faint on a light background, so each takes a darker
/// tone in the light appearance and the light system tone in the dark one.
enum TimeTrackingPalette {
    static let green = adaptive(light: (0.09, 0.50, 0.20), dark: .systemGreen)
    static let orange = adaptive(light: (0.74, 0.36, 0.0), dark: .systemOrange)
    /// Indigo rather than blue, so the text stays readable on a highlight.
    static let indigo = adaptive(light: (0.30, 0.24, 0.78), dark: .systemIndigo)
    static let absence = adaptive(light: (0.0, 0.45, 0.52), dark: .systemTeal)
    static let red = adaptive(light: (0.78, 0.12, 0.12), dark: .systemRed)
    /// The day being edited in the week view: stands apart from blue (work,
    /// today), teal (absence), orange and red. A true magenta, as the
    /// system's pink looks reddish in the dark, close to the minus.
    static let selection = adaptive(light: (0.66, 0.13, 0.58), dark: NSColor(srgbRed: 0.89, green: 0.42, blue: 0.85, alpha: 1))

    /// Colour of a balance: green in the plus (and even), red in the minus.
    static func balance(_ secs: Int) -> NSColor {
        TTMenu.isMinus(secs) ? red : green
    }

    /// Colour of the status line and of its dot.
    static func status(_ tone: TTStatusTone) -> (text: NSColor, dot: NSColor) {
        switch tone {
        case .running: return (green, green)
        case .onBreak: return (orange, orange)
        case .closed: return (indigo, indigo)
        case .absent: return (absence, absence)
        case .neutral: return (.labelColor, .systemGray)
        }
    }

    private static func adaptive(light: (Double, Double, Double), dark: NSColor) -> NSColor {
        let lightColor = NSColor(srgbRed: light.0, green: light.1, blue: light.2, alpha: 1)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : lightColor
        }
    }
}
