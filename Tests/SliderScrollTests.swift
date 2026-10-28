// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Scroll-wheel and trackpad steps over a level slider, and the slider's
/// priority over an enclosing horizontal strip. No window is shown.
enum SliderScrollTests {
    final class Bar: NSView, SliderScrollTarget {
        var isEnabled = true
        var acceptsSliderScroll: Bool { isEnabled }
    }

    static func run(_ suite: TestSuite) {
        let range = 0.0...1.0
        var wheel = SliderScroll()
        suite.expect(wheel.handle(.none, dx: 0, dy: 1, precise: false, inverted: false,
                                  timestamp: 0, current: 0.5, range: range) == .move(0.55)
                     && wheel.handle(.none, dx: 0, dy: -3, precise: false, inverted: false,
                                     timestamp: 1, current: 0.55, range: range) == .move(0.5)
                     && wheel.handle(.none, dx: 0, dy: -1, precise: false, inverted: true,
                                     timestamp: 2, current: 0.5, range: range) == .move(0.55),
               "a wheel notch moves the level one step up or down, whatever the wheel's acceleration or natural scrolling")
        suite.expect(wheel.handle(.none, dx: 0, dy: 1, precise: false, inverted: false,
                                  timestamp: 3, current: 0.98, range: range) == .move(1)
                     && wheel.handle(.none, dx: 0, dy: 1, precise: false, inverted: false,
                                     timestamp: 4, current: 2, range: 0...4) == .move(2.2),
               "a scrolled level stops at the end of its range and steps by the range it spans")
        suite.expect(SliderScroll.step(dx: 10, dy: 0, precise: true, inverted: true) > 0
                     && SliderScroll.step(dx: -10, dy: 0, precise: true, inverted: false) > 0
                     && SliderScroll.step(dx: 0, dy: -10, precise: true, inverted: true) > 0
                     && SliderScroll.step(dx: 2, dy: -10, precise: true, inverted: true) == 10 * SliderScroll.pointStep,
               "fingers moving up or right raise the level along the gesture's main axis")

        var pad = SliderScroll()
        suite.expect(pad.handle(.changed, dx: 0, dy: -40, precise: true, inverted: true,
                                timestamp: 0, current: 0.5, range: range) == .pass,
               "a trackpad scroll that began elsewhere keeps scrolling the list when a bar slides under the pointer")
        suite.expect(pad.handle(.began, dx: 0, dy: -20, precise: true, inverted: true,
                                timestamp: 1, current: 0.5, range: range) == .move(0.6)
                     && pad.handle(.changed, dx: 0, dy: -20, precise: true, inverted: true,
                                   timestamp: 1.1, current: 0.5, range: range) == .move(0.7),
               "a gesture that starts on the bar follows the fingers from where it is heading, ahead of a level that settles late")
        suite.expect(pad.handle(.ended, dx: 0, dy: 0, precise: true, inverted: true,
                                timestamp: 1.2, current: 0.7, range: range) == .hold
                     && pad.handle(.none, dx: 0, dy: -30, precise: true, inverted: true,
                                   timestamp: 1.3, current: 0.7, range: range) == .hold
                     && pad.handle(.momentum, dx: 0, dy: -30, precise: true, inverted: true,
                                   timestamp: 1.4, current: 0.7, range: range) == .hold,
               "the flick after a gesture on the bar neither moves the level nor scrolls the list")
        suite.expect(pad.handle(.changed, dx: 0, dy: -30, precise: true, inverted: true,
                                timestamp: 5, current: 0.7, range: range) == .pass
                     && pad.handle(.momentum, dx: 0, dy: -30, precise: true, inverted: true,
                                   timestamp: 5.1, current: 0.7, range: range) == .pass,
               "once another gesture scrolls past the bar, its momentum goes back to the list")

        let strip = NSScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let document = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 50))
        strip.documentView = document
        let bar = Bar(frame: NSRect(x: 0, y: 0, width: 28, height: 80))
        document.addSubview(bar)
        let child = NSView(frame: .zero)
        bar.addSubview(child)
        suite.expect(HorizontalWheelScrolling.sidewaysStrip(at: bar) == nil
                     && HorizontalWheelScrolling.sidewaysStrip(at: child) == nil,
                     "an enabled slider and its descendants retain the wheel in an overflowing horizontal strip")
        bar.isEnabled = false
        suite.expect(HorizontalWheelScrolling.sidewaysStrip(at: bar) === strip,
                     "a disabled slider leaves horizontal wheel navigation available")
        bar.isEnabled = true
        suite.expect(HorizontalWheelScrolling.sidewaysStrip(at: document) === strip,
                     "scrolling the surrounding app list still navigates the strip")
    }
}
