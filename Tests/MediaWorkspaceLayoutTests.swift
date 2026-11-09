// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import AppKit
import SwiftUI

/// Exercises the production tool picker binding and native drop registration
/// without displaying a window, capturing pixels, or sending any input to the
/// user's session.
enum MediaWorkspaceLayoutTests {
    final class Fixture: ObservableObject {
        @Published var height: CGFloat = 180
        weak var pickerView: NSView?

        var pickerFrame: CGRect {
            guard let pickerView, let root = pickerView.window?.contentView else { return .zero }
            let frame = pickerView.convert(pickerView.bounds, to: root)
            return CGRect(x: frame.minX, y: root.isFlipped ? frame.minY : root.bounds.maxY - frame.maxY,
                          width: frame.width, height: frame.height)
        }
    }

    // SwiftUI's global space need not include native scroll offsets on macOS 15.
    struct PickerMarker: NSViewRepresentable {
        let fixture: Fixture
        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            fixture.pickerView = view
            return view
        }
        func updateNSView(_ view: NSView, context: Context) { fixture.pickerView = view }
    }

    final class PanelBudget: ObservableObject {
        @Published var height: CGFloat = 600
    }

    final class Selection {
        var events: [String] = []
        var tool = MediaTool.videoCompressor {
            didSet { events.append("content:\(tool.rawValue)") }
        }
    }

    static func run(_ suite: TestSuite) {
        func settle(_ condition: () -> Bool) -> Bool {
            let deadline = Date().addingTimeInterval(2)
            while !condition(), Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.01))
            }
            return condition()
        }

        func scrollViews(in view: NSView) -> [NSScrollView] {
            ((view as? NSScrollView).map { [$0] } ?? [])
                + view.subviews.flatMap { scrollViews(in: $0) }
        }
        func overflows(_ scroll: NSScrollView) -> Bool {
            (scroll.documentView?.frame.height ?? 0) > scroll.contentView.bounds.height + 1
        }
        let panelFixture = Fixture()
        panelFixture.height = 900
        let panel = NSScrollView(frame: CGRect(x: 0, y: 0, width: 380, height: 260))
        panel.hasVerticalScroller = true
        panel.scrollerStyle = .overlay
        panel.autohidesScrollers = true
        let document = NSHostingView(rootView: VStack(spacing: 8) {
            Color.clear.frame(height: 24)
            Workspace(fixture: panelFixture, scrollsContent: false)
        })
        document.translatesAutoresizingMaskIntoConstraints = false
        panel.documentView = document
        let panelWindow = NSWindow(contentRect: panel.frame, styleMask: .borderless, backing: .buffered, defer: false)
        panelWindow.isReleasedWhenClosed = false
        panelWindow.contentView = panel
        defer { panelWindow.close() }
        NSLayoutConstraint.activate([
            document.topAnchor.constraint(equalTo: panel.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor),
            document.widthAnchor.constraint(equalTo: panel.contentView.widthAnchor),
        ])
        for height: CGFloat in [260, 120, 80, 190, 340] {
            panelWindow.setContentSize(CGSize(width: 380, height: height))
            panel.layoutSubtreeIfNeeded()
            suite.expect(settle {
                panel.layoutSubtreeIfNeeded()
                return abs(document.frame.height - (panelFixture.height + 98)) <= 1
                    && scrollViews(in: panel).count == 1
                    && overflows(panel)
            }, "compact media keeps its natural height and uses only its host's scroll region at height \(height)")
            if let scroll = scrollViews(in: panel).first(where: overflows), let content = scroll.documentView {
                let bottom = content.frame.height - scroll.contentView.bounds.height
                scroll.contentView.scroll(to: CGPoint(x: 0, y: bottom))
                scroll.reflectScrolledClipView(scroll.contentView)
                suite.expect(abs(scroll.contentView.bounds.maxY - content.frame.height) <= 1,
                       "the bottom media settings remain reachable at viewport height \(height)")
                scroll.contentView.scroll(to: .zero)
                scroll.reflectScrolledClipView(scroll.contentView)
                _ = settle { panelFixture.pickerFrame.minY >= 0 }
            }
        }
        if let scroll = scrollViews(in: panel).first(where: overflows), let content = scroll.documentView {
            let picker = panelFixture.pickerFrame
            suite.expect(picker.height == 24, "the type picker marker is mounted at its actual native height")
            // Hidden test windows do not reliably route synthetic wheel events.
            let bottom = content.isFlipped ? content.frame.height - scroll.contentView.bounds.height : 0
            scroll.contentView.scroll(to: CGPoint(x: 0, y: bottom))
            scroll.reflectScrolledClipView(scroll.contentView)
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            suite.expect(abs(scroll.contentView.bounds.minY - bottom) <= 1 && panelFixture.pickerFrame.minY < picker.minY,
                   "even a small media workspace can reach its bottom settings by scrolling the whole page")
            scroll.contentView.scroll(to: .zero)
            scroll.reflectScrolledClipView(scroll.contentView)
            suite.expect(settle { abs(panelFixture.pickerFrame.minY - picker.minY) <= 1 },
                   "scrolling back to the top restores the type picker in the same scroll region")
        } else {
            suite.expect(false, "long media options have a reachable scroll view")
        }
        for height: CGFloat in [80, 1200] {
            panelFixture.height = height
            let expectedScrolls = height == 80 ? 0 : 1
            suite.expect(settle {
                panel.layoutSubtreeIfNeeded()
                return abs(document.frame.height - (height + 98)) <= 1
                    && scrollViews(in: panel).count == 1
                    && scrollViews(in: panel).filter(overflows).count == expectedScrolls
            }, "changing media content height to \(height) preserves the panel viewport and scrolling ownership")
        }

        // The floating menu sizes its viewport from the native document's
        // fittingSize. Run the production host and sizing rule, so feeding the
        // viewport height back as content cannot hide behind a fixed window.
        let floatingFixture = Fixture()
        floatingFixture.height = 900
        let budget = PanelBudget()
        let floatingHost = NSHostingView(rootView: FloatingPanel(fixture: floatingFixture, budget: budget))
        floatingHost.frame = CGRect(x: 0, y: 0, width: 308, height: 700)
        let floatingWindow = NSWindow(contentRect: floatingHost.frame, styleMask: .borderless, backing: .buffered, defer: false)
        floatingWindow.isReleasedWhenClosed = false
        floatingWindow.contentView = floatingHost
        defer { floatingWindow.close() }
        for height: CGFloat in [600, 180, 600] {
            budget.height = height
            suite.expect(settle {
                floatingHost.layoutSubtreeIfNeeded()
                let scrolls = scrollViews(in: floatingHost)
                guard scrolls.count == 1, let scroll = scrolls.first, let content = scroll.documentView else { return false }
                return abs(scroll.contentView.bounds.height - height) <= 1
                    && abs(content.fittingSize.height - 998) <= 1
                    && overflows(scroll)
            }, "the floating menu recovers its available height at \(height) without feeding the viewport back as content")
        }
        for height: CGFloat in [80, 1200] {
            floatingFixture.height = height
            suite.expect(settle {
                floatingHost.layoutSubtreeIfNeeded()
                guard let scroll = scrollViews(in: floatingHost).first, let content = scroll.documentView else { return false }
                return abs(content.fittingSize.height - (height + 98)) <= 1
                    && abs(scroll.contentView.bounds.height - min(height + 98, budget.height)) <= 1
                    && overflows(scroll) == (height == 1200)
            }, "the floating menu follows media content height \(height), capped only by the available space")
        }

        // Quick Launcher supplies a SwiftUI ScrollView rather than the menu's
        // native wrapper. It must also own the sole scroll region.
        let launcherFixture = Fixture()
        launcherFixture.height = 900
        let launcherHost = NSHostingView(rootView: ScrollView(showsIndicators: false) {
            Workspace(fixture: launcherFixture, scrollsContent: false)
        }.frame(width: 380, height: 120))
        launcherHost.frame = CGRect(x: 0, y: 0, width: 380, height: 120)
        let launcherWindow = NSWindow(contentRect: launcherHost.frame, styleMask: .borderless, backing: .buffered, defer: false)
        launcherWindow.isReleasedWhenClosed = false
        launcherWindow.contentView = launcherHost
        defer { launcherWindow.close() }
        suite.expect(settle {
            launcherHost.layoutSubtreeIfNeeded()
            let scrolls = scrollViews(in: launcherHost)
            return scrolls.count == 1 && scrolls.filter(overflows).count == 1 && launcherFixture.pickerFrame.height == 24
        }, "the launcher's SwiftUI host is the only scroll region for compact media")
        if let scroll = scrollViews(in: launcherHost).first, let content = scroll.documentView {
            let picker = launcherFixture.pickerFrame
            let bottom = content.isFlipped ? content.frame.height - scroll.contentView.bounds.height : 0
            scroll.contentView.scroll(to: CGPoint(x: 0, y: bottom))
            scroll.reflectScrolledClipView(scroll.contentView)
            suite.expect(settle { launcherFixture.pickerFrame.minY < picker.minY },
                   "launcher media scrolls the selector with its options")
            scroll.contentView.scroll(to: .zero)
            scroll.reflectScrolledClipView(scroll.contentView)
            suite.expect(settle { abs(launcherFixture.pickerFrame.minY - picker.minY) <= 1 },
                   "launcher media restores the selector when scrolled back to the top")
        }

        let selection = Selection()
        let picker = ToolPicker(fixture: selection)
        for tool in [MediaTool.gifMaker, .textExtractor, .imageCompressor, .videoCompressor] {
            selection.events = []
            picker.selectedToolBinding.wrappedValue = tool
            suite.expect(selection.events == ["content:\(tool.rawValue)"],
                   "each tool change replaces the controls once")
            selection.events = []
            picker.selectedToolBinding.wrappedValue = tool
            suite.expect(selection.events.isEmpty, "reselecting the current tool does not reset work")
        }

        func types(in view: NSView) -> Set<NSPasteboard.PasteboardType> {
            view.subviews.reduce(into: Set(view.registeredDraggedTypes)) { $0.formUnion(types(in: $1)) }
        }
        let input = NSHostingView(rootView: Input())
        input.frame = CGRect(x: 0, y: 0, width: 300, height: 70)
        input.layoutSubtreeIfNeeded()
        _ = input.fittingSize
        // SwiftUI registers broad transport types and filters the requested
        // file URL type in its own drop coordinator.
        suite.expect(settle { !types(in: input).isEmpty },
               "media retains its native direct file drop target")
    }
}
