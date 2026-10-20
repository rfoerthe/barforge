// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import AppKit
import SwiftUI

/// Exercises the production tool picker binding and native drop registration
/// without displaying a window, capturing pixels, or sending any input to the
/// user's session.
enum MediaWorkspaceLayoutTests {
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
