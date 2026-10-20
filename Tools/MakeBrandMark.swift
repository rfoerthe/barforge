// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

// Draws the Barforge anvil and writes every brand source from that one shape:
// - Resources/Brand/logo.png, the mark MakeIcon.swift turns into the menu bar
//   glyph and the in-app BrandMark
// - Resources/Brand/AppIcon-Default.png, the finished app icon
// - Resources/Brand/AppIcon.icon/Assets/barforge-brandmark.svg for Icon Composer
// - the README logos and icon in docs/assets/readme
//
//     swift Tools/MakeBrandMark.swift
//
// A placeholder until a designed mark replaces it; MakeIcon.swift then keeps
// working unchanged from logo.png and AppIcon-Default.png.
import AppKit

enum Segment {
    case move(CGFloat, CGFloat)
    case line(CGFloat, CGFloat)
    case quad(CGFloat, CGFloat, CGFloat, CGFloat)  // control, end
    case close
}

/// The anvil in a 600 × 300 box, y down: horn to the left, heel to the right,
/// a narrow waist and a flared foot. Under 2:1 overall, so the menu bar glyph
/// keeps clear of its 26 × 20 pt canvas (SelfTest checks the edges).
let viewBox = CGSize(width: 600, height: 300)
let anvil: [Segment] = [
    .move(170, 22), .line(556, 22), .line(556, 96),
    .quad(466, 102, 452, 150), .line(452, 204),
    .quad(458, 232, 524, 242), .line(546, 280), .line(214, 280), .line(236, 242),
    .quad(302, 232, 308, 204), .line(308, 150),
    .quad(290, 106, 204, 96),
    .quad(140, 90, 68, 44),
    .quad(112, 24, 170, 22), .close,
]

let root = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().deletingLastPathComponent()

func svg(fill: String) -> String {
    var d = ""
    for segment in anvil {
        switch segment {
        case let .move(x, y): d += "M\(x) \(y) "
        case let .line(x, y): d += "L\(x) \(y) "
        case let .quad(cx, cy, x, y): d += "Q\(cx) \(cy) \(x) \(y) "
        case .close: d += "Z"
        }
    }
    return """
    <svg xmlns="http://www.w3.org/2000/svg" width="\(Int(viewBox.width))" height="\(Int(viewBox.height))" \
    viewBox="0 0 \(Int(viewBox.width)) \(Int(viewBox.height))">
      <path fill="\(fill)" d="\(d)"/>
    </svg>

    """
}

/// The anvil fitted into `rect` (AppKit coordinates, y up), aspect kept.
func path(in rect: CGRect) -> NSBezierPath {
    let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
    let origin = CGPoint(x: rect.midX - viewBox.width * scale / 2,
                         y: rect.midY + viewBox.height * scale / 2)
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + x * scale, y: origin.y - y * scale)
    }
    let bezier = NSBezierPath()
    var current = CGPoint.zero
    for segment in anvil {
        switch segment {
        case let .move(x, y):
            current = point(x, y); bezier.move(to: current)
        case let .line(x, y):
            current = point(x, y); bezier.line(to: current)
        case let .quad(cx, cy, x, y):
            let control = point(cx, cy), end = point(x, y)
            bezier.curve(to: end,
                         controlPoint1: CGPoint(x: current.x + 2 / 3 * (control.x - current.x),
                                                y: current.y + 2 / 3 * (control.y - current.y)),
                         controlPoint2: CGPoint(x: end.x + 2 / 3 * (control.x - end.x),
                                                y: end.y + 2 / 3 * (control.y - end.y)))
            current = end
        case .close:
            bezier.close()
        }
    }
    return bezier
}

func png(width: Int, height: Int, draw: (CGRect) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let ink = NSColor(srgbRed: 0.04, green: 0.05, blue: 0.06, alpha: 1)

func mark(_ color: NSColor, width: Int, height: Int, fill: CGFloat) -> Data {
    png(width: width, height: height) { canvas in
        color.setFill()
        path(in: canvas.insetBy(dx: canvas.width * (1 - fill) / 2, dy: canvas.height * (1 - fill) / 2)).fill()
    }
}

func appIcon(_ size: Int) -> Data {
    png(width: size, height: size) { canvas in
        let s = canvas.width / 1024
        let tile = NSBezierPath(roundedRect: canvas.insetBy(dx: 4 * s, dy: 4 * s), xRadius: 228 * s, yRadius: 228 * s)
        NSGradient(starting: NSColor(white: 1, alpha: 1), ending: NSColor(white: 0.9, alpha: 1))!
            .draw(in: tile, angle: -90)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.35)
        shadow.shadowBlurRadius = 26 * s
        shadow.shadowOffset = NSSize(width: 0, height: -16 * s)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        ink.setFill()
        path(in: CGRect(x: 132 * s, y: 300 * s, width: 760 * s, height: 400 * s)).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}

func write(_ data: Data, _ relative: String) throws {
    try data.write(to: root.appendingPathComponent(relative))
    print("wrote \(relative)")
}

try write(mark(ink, width: 1024, height: 1024, fill: 0.46), "Resources/Brand/logo.png")
try write(appIcon(1024), "Resources/Brand/AppIcon-Default.png")
try write(Data(svg(fill: "#000000").utf8), "Resources/Brand/AppIcon.icon/Assets/barforge-brandmark.svg")
try write(Data(svg(fill: "#0a0c10").utf8), "docs/assets/readme/logo.svg")
try write(Data(svg(fill: "#ffffff").utf8), "docs/assets/readme/logo-dark.svg")
try write(mark(ink, width: 640, height: 324, fill: 0.96), "docs/assets/readme/logo.png")
try write(mark(.white, width: 640, height: 324, fill: 0.96), "docs/assets/readme/logo-dark.png")
try write(appIcon(512), "docs/assets/readme/icon.png")
