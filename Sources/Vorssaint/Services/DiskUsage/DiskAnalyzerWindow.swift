// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import AppKit
import Quartz

/// The Disk Analyzer window. It hands its shortcuts to the service before
/// the content sees them, and drives the system Quick Look panel for the
/// item under the pointer or the selected one.
final class DiskAnalyzerWindow: NSWindow, NSWindowDelegate, QLPreviewPanelDataSource {
    var onClose: (() -> Void)?
    var keyHandler: ((NSEvent) -> Bool)?
    var previewItems: (() -> [URL])?
    private var shownItems: [URL] = []

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        delegate = self
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, !(firstResponder is NSText), keyHandler?(event) == true { return }
        super.sendEvent(event)
    }

    func windowWillClose(_ notification: Notification) {
        if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().orderOut(nil)
        }
        onClose?()
    }

    // MARK: Quick Look

    func toggleQuickLook() {
        let panel = QLPreviewPanel.shared()!
        if panel.isVisible, (panel.currentController as AnyObject?) === self {
            panel.orderOut(nil)
            return
        }
        shownItems = previewItems?() ?? []
        guard !shownItems.isEmpty else { return }
        makeKey()
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        if shownItems.isEmpty { shownItems = previewItems?() ?? [] }
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        shownItems = []
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { shownItems.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        shownItems[index] as NSURL
    }
}
