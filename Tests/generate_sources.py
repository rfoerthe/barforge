#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

"""Compile selected production methods against test doubles, without an app.

Bodies are read verbatim on every build, never copied into a maintained fixture.
The narrow declaration/indentation contract fails closed if a method moves or
changes shape; the Swift compiler then checks the generated source normally.
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/generated-tests"


def declaration(path, prefix, scope=None):
    lines = (ROOT / path).read_text().splitlines(keepends=True)
    lower, upper = 0, len(lines)
    if scope is not None:
        scopes = [i for i, line in enumerate(lines) if line.startswith(scope)]
        if len(scopes) != 1:
            raise ValueError(f"Expected one scope {scope!r} in {path}")
        lower = scopes[0] + 1
        upper = next(i for i in range(lower, len(lines)) if lines[i].rstrip() == "}")
    starts = [i for i in range(lower, upper) if lines[i].startswith(prefix)]
    if len(starts) != 1:
        raise ValueError(f"Expected one declaration {prefix!r} in {path}")
    start = starts[0]
    indent = prefix[:len(prefix) - len(prefix.lstrip())]
    end = next(i for i in range(start + 1, len(lines)) if lines[i].rstrip() == indent + "}")
    body = "".join(lines[start:end + 1])
    return f'#sourceLocation(file: {json.dumps(path)}, line: {start + 1})\n{body}\n#sourceLocation()\n'


def write(name, text):
    path = OUTPUT / name
    if not path.exists() or path.read_text() != text:
        path.write_text(text)


def availability_declaration(path, prefix):
    return declaration(path, prefix).replace(".feature.isAvailable", ".feature.isAvailable(in: ReviewDefaults.current)")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    write("SettingsCommandDispatch.swift", "import Foundation\n"
          + "extension SettingsFeatureTests.CommandDispatchHost {\nstatic func run() {\n"
          # Both app entry points are named main.swift. Keep diagnostics in
          # this generated file to avoid ambiguous #fileID source locations.
          + "\n".join(line for line in declaration(
              "Sources/Vorssaint/main.swift", "if let command = SettingsBackupSupport.command(")
              .splitlines() if not line.startswith("#sourceLocation")) + "\n"
          + "}\n}\n")
    recent_captures = "Sources/Vorssaint/Services/QuickTools/RecentCaptureService.swift"
    write("RecentCapturePanel.swift", "import Foundation\nimport Carbon.HIToolbox\n"
          + "extension RecentCapturePanelTests {\nfinal class Service: Fixture {\n"
          + "".join(declaration(recent_captures, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func installPanelMonitors(",
                                   "    private func removePanelMonitors()", "    func hideHistoryWindow()"])
          + "}\n}\n")
    resolver = "Sources/Vorssaint/Services/Switcher/AXWindowResolver.swift"
    resolver_lines = (ROOT / resolver).read_text().splitlines()
    resolver_constants = "".join(
        next(line for line in resolver_lines if line.startswith(prefix))
        .replace("private static", "static", 1) + "\n"
        for prefix in ["    private static let remoteElementIDLimit:",
                       "    static let remoteLookupBudget:"])
    write("AXHiddenSpaceLookup.swift", "import ApplicationServices\nimport CoreGraphics\nimport Foundation\n"
          + "extension AXHiddenSpaceLookupTests.Resolver {\n"
          + resolver_constants
          + "".join(declaration(resolver, prefix).replace("private static", "static", 1)
                    for prefix in ["    static func elementsOnHiddenSpace(",
                                   "    static func prepareForRequest("])
          + "}\n")
    recorder = "Sources/Vorssaint/Services/Recorder/ScreenRecorderService.swift"
    write("RecorderPreparation.swift", "import Foundation\nextension RecorderPreparationTests {\n"
          + "final class Service: Fixture {\n"
          + "".join(declaration(recorder, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func beginRecording(", "    private func pendingStartIsAuthorized(",
                                   "    private func invalidatePendingStart()", "    var hasActiveCapture:",
                                   "    func stopOrCancelActiveCapture()", "    func prepareForSelection()"])
          + "}\n}\n")
    write("SwitcherFullscreenScope.swift", "import AppKit\nimport ApplicationServices\nimport CoreGraphics\n"
          + "extension SwitcherFullscreenScopeTests.Enumerator {\n"
          + "".join(declaration("Sources/Vorssaint/Services/Switcher/WindowEnumerator.swift", prefix)
                    .replace("private ", "", 1) for prefix in [
                        "    struct DisplayScope:", "    struct WindowList {", "    struct AppSnapshot:",
                        "    struct Snapshot:", "    static func enumerateSwitcherWindows(",
                        "    static func listWindowsForCommandBar(",
                        "    private static func listWindows(appRules:",
                        "    private static func listWindows(filterPID:",
                        "    private struct AccessibilityWindowSnapshot {",
                        "    private struct AccessibilityWindowSnapshotList {",
                        "    private static func appendAccessibilityOnlyWindows(",
                        "    private static func appendWindowlessApps(",
                        "    private static func switchableFrame(", "    private static func frameIsSwitchable(",
                        "    private static func frameLooksFullscreen("])
          + "}\nextension SwitcherFullscreenScopeTests.Bridge {\n"
          + "".join(declaration("Sources/Vorssaint/Services/Switcher/SpaceWindowBridge.swift", prefix)
                    .replace("private ", "", 1) for prefix in [
                        "    private static func windowTags(of", "    static func isExcludedFromWindowCycle("])
          + "}\n")
    write("RecorderSystemAudioTapLifecycle.swift", "import CoreAudio\nimport Foundation\n"
          + "extension RecorderSystemAudioTapLifecycleTests {\nfinal class Tap: Fixture, @unchecked Sendable {\n"
          + declaration("Sources/Vorssaint/Services/Recorder/RecorderSystemAudioTap.swift", "    func stop() async")
          + "}\n}\n")
    tap = "Sources/Vorssaint/Services/Recorder/RecorderSystemAudioTap.swift"
    write("RecorderSystemAudioTrust.swift", "import Accelerate\nimport AVFoundation\nimport Darwin\n"
          + "extension RecorderSystemAudioTrustTests {\n"
          + declaration(tap, "final class RecorderAudioFlag {")
          + declaration(tap, "final class RecorderAudioHostTime {")
          + declaration(tap, "enum RecorderAudioProbe {")
          + "final class Session: Fixture {\n"
          + declaration(recorder, "    private func streamHeardSound(against").replace("private func", "func", 1)
          # The first line alone tells it from the one-line didStopWith callback.
          + declaration(recorder, "    func captureEngine(_ engine: RecorderCaptureEngine,\n")
          + "}\n}\n")
    write("SwitcherAccessibilitySnapshot.swift", "import ApplicationServices\nimport CoreGraphics\nimport Foundation\n"
          + "extension SwitcherAccessibilitySnapshotTests.Reader {\n"
          + "".join(declaration("Sources/Vorssaint/Services/Switcher/WindowEnumerator.swift", prefix)
                    .replace("private ", "", 1) for prefix in [
                        "    private struct AccessibilityWindowSnapshot {",
                        "    private struct AccessibilityWindowSnapshotList {",
                        "    private struct AccessibilityWindowAttributes {",
                        "    private enum WindowReading {",
                        "    private static func accessibilityWindows(for pid: pid_t,",
                        "    private static func userFacingReading(",
                        "    private static func frameLooksFullscreen(",
                        "    private static func hasWorkingMinimizeButton(",
                        "    private static func accessibilityWindowAttribute(",
                        "    private static func boolAttribute(",
                        "    private static func appendUnique(", "    private static func contains("])
          + "}\n")
    write("TransientPasteRuntime.swift", "import AppKit\nimport Carbon.HIToolbox\nimport CoreGraphics\n"
          + "extension TransientPasteTests {\n"
          + declaration("Sources/Vorssaint/Services/TransientPaste.swift", "final class TransientPaste {")
              .replace("NSPasteboard.general", "TransientPasteTests.pasteboard")
          + "}\n")
    write("TextSnippetExpansion.swift", "import AppKit\nimport Carbon.HIToolbox\nimport CoreGraphics\n"
          + "extension TextSnippetExpansionTests {\n"
          + declaration("Sources/Vorssaint/Services/Snippets/TextSnippetService.swift",
                        "    static func postExpansion(")
          + "}\n")
    general = "Sources/Vorssaint/UI/Settings/GeneralSettings.swift"
    write("LaunchAtLoginSettings.swift", "import Foundation\n"
          + "extension LaunchAtLoginSettingsTests.View {\n"
          + "".join(declaration(general, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func refreshLaunchAtLogin()",
                                   "    private func setLaunchAtLogin("])
          + "}\n")
    cleaner_view = "Sources/Vorssaint/UI/Cleaner/CleanerView.swift"
    feature_hub = "Sources/Vorssaint/UI/Settings/FeatureHubSettings.swift"
    write("FeatureHubLayout.swift", "import AppKit\nimport SwiftUI\nextension FeatureHubLayoutTests.Page {\n"
          + "".join(declaration(feature_hub, prefix).replace("    private var", "    var", 1)
                    for prefix in ["    private var content:", "    private var restartCard:"])
          + "}\nextension FeatureHubLayoutTests {\n"
          + declaration("Sources/Vorssaint/UI/Settings/SettingsCard.swift", "struct SettingsCard<")
          + "}\n"
          + declaration(feature_hub, "private struct FeatureHubScrollAnchor:"))
    write("CleanerLayout.swift", "import SwiftUI\nextension CleanerLayoutTests.Results {\n"
          + "".join(declaration(cleaner_view, prefix).replace("    private ", "    @ViewBuilder\n    ", 1)
                    for prefix in ["    private var resultsState:", "    private var resultsGroups:",
                                   "    private func section("])
          + "}\n")
    write("ScrollingCaptureLoop.swift", "import AppKit\nimport CoreGraphics\n"
          + "extension ScreenshotScrollingCaptureTests {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/ScreenshotScrollingCapture.swift",
                        "enum ScreenshotScrollingCapture {").replace(
                            "    private static func stitch(", "    static func stitch(")
          + "}\n")
    write("ClipboardHistoryImageEditor.swift", "import AppKit\nimport UniformTypeIdentifiers\n"
          + "extension ClipboardHistoryImageEditorTests {\nfinal class Host: Fixture {\n"
          + declaration("Sources/Vorssaint/Services/Clipboard/ClipboardHistoryService.swift",
                        "    func editImage(")
          + "}\n}\nextension ClipboardHistoryImageEditorTests.ScreenshotService {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/ScreenshotService.swift",
                        "    static func imageCapture(")
          + declaration("Sources/Vorssaint/Services/QuickTools/ScreenshotService.swift",
                        "    static func clipboardImage(")
          + "}\n")
    editor = "Sources/Vorssaint/Services/QuickTools/ScreenshotEditorController.swift"
    write("ScreenshotClipboard.swift", "import AppKit\nextension ScreenshotClipboardTests {\n"
          + "final class Editor: State {\n"
          + "".join(declaration(editor, prefix).replace(
              "ScreenshotSupport.copiedFilesDirectory()", "ScreenshotClipboardTests.copyDirectory")
              for prefix in [
              "    func copyToClipboard()", "    static func copyImage(", "    static func copyFile(",
              "    struct ClipboardPayload:",
              "    static func clipboardPayload(from export: ScreenshotRenderer.Export) ->",
              "    static func clipboardPayload(from export: ScreenshotRenderer.Export,",
              "    static func copyClipboardPayload("])
          + "}\n}\n")
    write("ScreenshotCanvasModel.swift",
          "import AppKit\nextension ScreenshotCanvasModelTests {\nfinal class Host: Fixture {\n"
          + "".join(declaration(editor, prefix) for prefix in [
              "    func pasteImage(", "    func commitCanvasExpansion(",
              "    private func registerUndo()", "    func undo()", "    func redo()",
              "    private func restore(", "    private func refreshUndoFlags()",
              "    func cancelCanvasExpansion()", "    func leaveCanvasExpansion()", "    func hitTest("])
          + declaration(editor, "    private func continueSelectDrag(").replace("private func", "func", 1)
          + "}\n}\n")
    write("ScreenshotEditorPaste.swift",
          "import AppKit\nextension ScreenshotCanvasModelTests.Paste {\nfinal class Host: Fixture {\n"
          + declaration(editor, "    private func pasteImageFromClipboard()").replace("private func", "func", 1)
          + "}\n}\n")
    expansion_preview = "Sources/Vorssaint/UI/Screenshot/ScreenshotCanvasExpansionPreview.swift"
    write("ScreenshotExpansionPreviewChrome.swift", "import SwiftUI\n"
          + "extension ScreenshotCanvasSupportTests {\nenum ExpansionPreview {\n"
          + declaration(expansion_preview, "    struct Layout {")
          + declaration(expansion_preview, "    static func cardHole(")
          + "}\n}\n")
    panel = "Sources/Vorssaint/App/AppDelegate.swift"
    write("UpdateIntroFlow.swift", "import AppKit\nimport Foundation\n"
          + "extension UpdateIntroFlowTests {\nfinal class Host: Fixture {\n"
          + "".join(declaration(panel, prefix).replace("    private ", "    ", 1) for prefix in [
              "    private func presentUpdateIntros()", "    private func showSupportUpdateIntroIfNeeded()",
              "    func windowShouldClose(", "    func windowWillClose(", "    private func markOnboardingComplete()",
              "    private func markSupportUpdateIntroSeenIfCurrentUpdate()", "    private func markSupportUpdateIntroSeen()",
              "    private func queueWhatsNewIfNeeded(", "    private func showWhatsNewIfNeeded()",
              "    private func markWhatsNewSeen()", "    private func keepUpdateWindowReachable(",
              "    private func restoreSettingsLevelAfterWhatsNew()"])
          + "}\n}\n")
    write("PostUpdateStatusItemRecovery.swift", "import AppKit\nimport Foundation\n"
          + "extension PostUpdateStatusItemRecoveryTests {\nfinal class Host: Fixture {\n"
          + "".join(declaration(panel, prefix).replace("private ", "") for prefix in [
              "    private func recoverStatusItemAfterUpdate(",
              "    private func verifyPostUpdateStatusItem(",
              "    private func iconIsOnScreen("])
          + "}\n}\n")
    write("MenuPanelRecovery.swift", "import AppKit\nimport Foundation\n"
          + "extension MenuPanelRecoveryTests {\nfinal class Host: Fixture {\n"
          + "".join(declaration(panel, prefix).replace("private ", "") for prefix in [
              "    private struct PanelAnchor", "    private func statusButtonMidX(",
              "    private func statusScreen(", "    private func positionSettingsWindow(",
              "    private var freshStatusClick:", "    private func captureStatusClick(",
              "    private func correctedPopoverMidX(", "    private func resolvePanelAnchor(",
              "    private func frameStillDescribesMenuBar(", "    private func statusFrameNeedsAnchorOverride(",
              "    private func anchorVisibleFrame(", "    private func applyPopoverDriftFrame(",
              "    private func beginPopoverDriftCorrection(window: NSWindow, anchor: PanelAnchor) {",
              "    private func armPopoverDriftCorrection(", "    private func endPopoverDriftCorrection(",
              "    private func showPopover(", "    func popoverWillClose(", "    func popoverDidClose(",
              "    private func finishPopoverClose(",
              "    private func releasePanelResources(", "    private func anchorAfterForeignClose(",
              "    private func reopenPanelAfterForeignClose(", "    private func shouldDismissPopover(",
              "    private var popoverIsOpen:", "    private func showMetricPanel(",
              "    private func reanchorMetricPopover(", "    private func switchMetricPopover(",
              "    private func beginPanelActivationTracking(", "    private func updatePanelActivationSource(",
              "    private func endPanelActivationTracking(", "    private func returnActivation(",
              "    private func runPopoverCloseCompletions(",
              "    private struct PanelPresentation", "    private func beginPanelPresentationWatch(",
              "    private func logPanelPresentation(", "    private func endPanelPresentationWatch(",
              "    private static func milliseconds(",
              "    private func closePopoverNow(", "    private func fadeOutPopover(",
              "    private func finishPopoverFadeOut(", "    private func closePopoverWithoutAnimation("])
          .replace(", privacy: .public", "")
          .replace("func endPanelActivationTracking()", "@discardableResult func endPanelActivationTracking()")
          + "func closePopover(animated: Bool = true, reason: PanelCloseReason) { closePopoverNow(animated: animated, reason: reason, completion: nil) }\n"
          + "var popoverAnchor: PanelAnchor?\nvar lastGoodPanelAnchor: PanelAnchor?\n"
          + "var panelPresentation: PanelPresentation?\nvar panelPresentationSerial = 0\nvar panelPresentationObservers: [NSObjectProtocol] = []\n"
          + "}\n}\n")
    write("MenuPanelKey.swift", "import Foundation\nimport Carbon.HIToolbox\n"
          + "extension MenuPanelKeyTests {\nfinal class Host: Fixture {\n"
          + "".join(declaration(panel, prefix).replace("private ", "", 1) for prefix in [
              "    private func handlePopoverKeyDown(", "    private func isPlainPopoverHoldKey(",
              "    private func isTextEditingActive("])
          + "}\n}\n")
    brightness = "Sources/Vorssaint/Services/Display/BrightnessService.swift"
    write("DisplayRestoration.swift", "import CoreGraphics\nimport Foundation\n"
          + "extension DisplayRestorationTests {\nfinal class BrightnessService: Fixture {\n"
          + declaration(brightness, "    enum DisplayControlFailure:")
          + "".join(declaration(brightness, prefix).replace("private ", "", 1) for prefix in [
              "    private static func restorationDisplayFingerprint(",
              "    private static func rememberDisplaySwitchedOff(",
              "    private static func forgetDisplaySwitchedOff(",
              "    private static func configureDisplay(", "    private func restoreDisplay(",
              "    private func canRestoreDisplay(",
              "    private func syncLidObserver(", "    private func restoreDeferredDisplays(",
              "    private func restoreManagedDisplays(", "    func restoreDisplaysLeftOff(",
              "    private func commitDisplayToggle(", "    private func finishDisplayToggle(",
              "    private func restoreManagedDisplayIfHeadless(",
              "    private func recordDiscoveredTopology(", "    private func discardReplacedDisplay(",
              "    private func displaysWokeUp(", "    private func screensChanged("])
          + "}\n}\n")
    write("BrightnessStep.swift", "import CoreGraphics\nimport Foundation\nimport os\n"
          + "extension BrightnessStepTests {\n"
          + "".join(declaration(brightness, prefix).replace("private ", "", 1) for prefix in [
              "    private struct Route", "    private enum DDCProbe"])
          + "final class Service: Fixture {\n"
          + declaration(brightness, "    private func step(").replace("private ", "", 1)
          + declaration(brightness, "    private func writeExtendedBrightness(").replace("private ", "", 1)
          + declaration(brightness, "    private static func writeSystemBrightness(").replace("private ", "", 1)
          + "}\n}\n")
    write("BrightnessKeyRouting.swift", "import AppKit\nimport os\n"
          + "extension BrightnessKeyRoutingTests {\nfinal class Service: Fixture {\n"
          + "".join(declaration(brightness, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func handleKeyEvent(",
                                   "    private func routeFunctionKey("])
          + "}\n}\n")
    activator = "Sources/Vorssaint/Services/Switcher/WindowActivator.swift"
    resolver = "Sources/Vorssaint/Services/Switcher/AXWindowResolver.swift"
    (OUTPUT / "AXWindowResolver.swift").unlink(missing_ok=True)
    write("AXWindowResolverContract.swift", "import ApplicationServices\nimport CoreGraphics\nimport Foundation\n"
          + "extension AXWindowResolverTests.Resolver {\n"
          + resolver_constants
          + "".join(declaration(resolver, prefix).replace("private static", "static", 1)
                    for prefix in ["    static func windowID(", "    static func element(",
                                   "    private static func actionElement(",
                                   "    private static func resolveRemoteElement(",
                                   "    static func elementsOnHiddenSpace(",
                                   "    static func prepareForRequest(", "    private static func isWindow("])
          + "}\n")
    write("SwitcherActivationBodies.swift", "import AppKit\nimport ApplicationServices\n"
          + "extension SwitcherActivationTests.Activator {\n"
          + "".join(declaration(activator, prefix).replace("private static", "static", 1)
                    for prefix in ["    private static func activateApp(",
                                   "    static func activateAppCooperatively(",
                                   "    private static func activateSource("])
          + "}\nextension SwitcherActivationTests.HiddenSpaceActivator {\n"
          + "".join(declaration(activator, prefix).replace("private static", "static", 1)
                    for prefix in ["    static func raiseWindowOnHiddenSpace(",
                                   "    private static func stageSourceBehindTargetIfNeeded("])
          + "}\nextension SwitcherActivationTests.Bridge {\n"
          + "".join(declaration("Sources/Vorssaint/Services/Switcher/SpaceWindowBridge.swift", prefix)
                    .replace("private static", "static", 1) for prefix in [
                        "    static func frontWindow(", "    static func focusWithoutRaise(",
                        "    private static func makeKeyWithoutRaise("])
          + declaration("Sources/Vorssaint/Services/Switcher/SpaceWindowBridge.swift",
                        "    private static func postFocusRecord(")
          .replace("private static", "@discardableResult static", 1)
          + "}\n")
    write("SwitcherWindowClose.swift", "import AppKit\nimport ApplicationServices\n"
          + "extension SwitcherWindowCloseTests.Activator {\n"
          + "".join(declaration(activator, prefix)
                    .replace("fileprivate static", "static", 1)
                    .replace("private static", "static", 1)
                    .replace("    static func finishPendingWindowClose(",
                             "    @discardableResult\n    static func finishPendingWindowClose(", 1)
                    for prefix in ["    static func closeWindow(", "    private static func closableElement(",
                                   "    private static func leaveFullscreenToClose(",
                                   "    static func closeWindowIncludingHiddenState(",
                                   "    fileprivate static func finishPendingWindowClose(",
                                   "    fileprivate static func windowExistsForClose("])
          + "}\nextension SwitcherWindowCloseTests {\n"
          + declaration(activator, "fileprivate final class SwitcherPendingWindowClose")
              .replace("fileprivate final class", "final class", 1)
          + "}\n")
    write("WindowServerCapture.swift", "import CoreGraphics\nimport Foundation\n"
          + "extension WindowServerCaptureContract.Provider {\n"
          + declaration("Sources/Vorssaint/Services/Switcher/WindowPreviewProvider.swift",
                        "    static func captureViaWindowServer(")
          + "}\n")
    write("ScreenshotAttachedCapture.swift", "import AppKit\nimport ScreenCaptureKit\n"
          + "extension ScreenshotAttachedCaptureTests {\nenum Engine {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/ScreenshotCaptureEngine.swift",
                        "    private static func composeAttached(").replace("private static", "static", 1)
          + "}\n}\n")
    write("ScratchpadExport.swift", "import AppKit\nimport Foundation\n"
          + "extension ScratchpadExportContract {\nfinal class Service: Fixture {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/ScratchpadService.swift",
                        "    func exportText(")
          + "}\n}\n")
    write("ScratchpadSave.swift", "import Foundation\n"
          + "extension ScratchpadSaveContract {\nfinal class Service: Fixture {\n"
          + "".join(declaration("Sources/Vorssaint/Services/QuickTools/ScratchpadService.swift", prefix)
                    .replace("private func", "func", 1) for prefix in [
                        "    func commitEdits(", "    private func flushSave(", "    private func save(",
                        "    func createPad("])
          + "}\n}\n")
    write("WallpaperPicker.swift", "import AppKit\nimport Foundation\nimport UniformTypeIdentifiers\n"
          + "extension WallpaperPickerContract {\nfinal class Service: Fixture {\n"
          + "".join(declaration("Sources/Vorssaint/Services/Wallpaper/WallpaperService.swift", prefix)
                    .replace("private func", "func", 1) for prefix in [
                        "    func addImages(", "    func addFolder(", "    private func present(",
                        "    private func bringForward("])
          + "}\n}\n")
    write("MusicLaunchBlockerLifecycle.swift", "import AppKit\nimport Foundation\n"
          + "extension MusicLaunchBlockerContract {\nfinal class Service: Fixture {\n"
          + "".join(declaration("Sources/Vorssaint/Services/Audio/MusicLaunchBlocker.swift", prefix)
                    .replace("private ", "", 1) for prefix in [
                        "    func syncWithPreferences(", "    private func start(", "    func stop(",
                        "    private func handleLaunch(", "    private func handleMediaKeyEvent("])
          + "}\n}\n")
    middle_click_lifecycle = "".join(
        declaration("Sources/Vorssaint/Services/MiddleClick/MiddleClickService.swift", prefix)
        .replace("private ", "", 1) for prefix in [
            "    private func startMultitouch(", "    private func stopMultitouch(",
            "    private func restartMultitouch(", "    private func installHotplugObserver(",
            "    private func removeObservers(", "    private func stop("])
    for function in ["IONotificationPortCreate", "IONotificationPortSetDispatchQueue",
                     "IOServiceAddMatchingNotification", "IOServiceMatching", "IOIteratorNext",
                     "IOObjectRelease", "IONotificationPortDestroy"]:
        middle_click_lifecycle = middle_click_lifecycle.replace(function + "(", "IO." + function + "(")
    write("MiddleClickTrackpad.swift", "import CoreGraphics\nimport Foundation\nimport IOKit\n"
          + "extension MiddleClickTrackpadContract {\nfinal class Service: Fixture {\n"
          + middle_click_lifecycle
          + "}\n}\n")
    menu_panel = "Sources/Vorssaint/UI/MenuPanel/MenuPanelView.swift"
    write("MiddleClickPanelCaption.swift", "import Foundation\n"
          + "extension MiddleClickTrackpadContract {\nfinal class Panel: PanelFixture {\n"
          + "".join(declaration(menu_panel, prefix).replace("private ", "", 1) for prefix in [
                "    private var middleClickCaption:", "    private func missingPermission("])
          + "}\n}\n")
    write("RadialMenuProfileDeletion.swift", "import Foundation\n"
          + "extension RadialMenuProfileDeletionContract {\nfinal class Settings: Fixture {\n"
          + declaration("Sources/Vorssaint/UI/Settings/RadialMenuSettings.swift",
                        "    private func deleteProfile(").replace("private ", "", 1)
          + "}\n}\n")
    write("RadialFilePicker.swift", "import Foundation\n"
          + "extension RadialFilePickerTests {\nstruct Editor {\n"
          + "let state: ItemState\nvar item: RadialMenuItem {\n"
          + "get { state.item }\nnonmutating set { state.item = newValue }\n}\n"
          + "".join(declaration("Sources/Vorssaint/UI/Settings/RadialMenuSettings.swift", prefix)
                    .replace("private func", "func", 1) for prefix in [
                        "    private func choose(applications:", "    private func applyChosen("])
          + "}\n}\n")
    clipboard = "Sources/Vorssaint/Services/Clipboard/ClipboardHistoryService.swift"
    pending_restore = [line for line in (ROOT / clipboard).read_text().splitlines(keepends=True)
                       if line.startswith("    private var pendingRestore:")]
    if len(pending_restore) != 1:
        raise ValueError("Expected one pending clipboard restore declaration")
    write("ClipboardCaptureRestore.swift", "import AppKit\nimport Foundation\nimport Combine\n"
          + "extension ClipboardCaptureRestoreTests {\nfinal class Service: Fixture {\n"
          + pending_restore[0].replace("private ", "", 1)
          + declaration(clipboard, "    @Published private(set) var entries:")
          + "".join(declaration(clipboard, prefix).replace("private ", "", 1) for prefix in [
              "    private enum CapturedContent", "    private func captureIfChanged(",
              "    private static func readPasteboard(", "    private func matchingEntry(",
              "    private func stop()", "    private func promote(", "    private func touch(",
              "    private var firstRecentIndex:", "    private func normalizeEntryOrder(",
              "    private func insertPromoted("])
          + "func setEntries(_ values: [ClipboardHistoryEntry]) { entries = values }\n"
          + "}\n}\n")
    write("ClipboardPreview.swift", "import Foundation\nimport Combine\n"
          + "extension ClipboardPreviewContract {\nfinal class Service: Fixture {\n"
          + declaration(clipboard, "    @Published private(set) var entries:")
          + declaration(clipboard, "    func updateText(")
          + "".join(declaration(clipboard, prefix).replace("private ", "", 1) for prefix in [
              "    func togglePin(", "    func clearRecent(", "    var recentEntries:", "    var recentEntriesSnapshot:",
              "    func copy(_ entry:", "    func copy(_ selectedEntries:", "    private func touch(",
              "    private var firstRecentIndex:", "    private func normalizeEntryOrder(",
              "    func filteredEntries(", "    var filteredQuickEntries:", "    var selectedQuickEntry:",
              "    func moveQuickSelection(", "    func removeSelectedQuickEntries(",
              "    private var quickBatchEntries:", "    private func quickEntriesForPrimaryAction(",
              "    private func selectedQuickIndex(", "    private func promote(",
              "    private func insertPromoted("])
          + "func setEntries(_ values: [ClipboardHistoryEntry]) { entries = values }\n"
          + "}\n}\n")
    write("CommandBarInputSource.swift", "import Foundation\n"
          + "extension CommandBarInputSourceContract {\nfinal class Service: Fixture {\n"
          + "".join(declaration("Sources/Vorssaint/Services/CommandBar/CommandBarService.swift", prefix)
                    .replace("private func", "func", 1) for prefix in [
                        "    private func adoptASCIIInputSource(",
                        "    private func restoreSuspendedInputSource(",
                        "    func restoreBorrowedInputSource(",
                        "    var hasBorrowedInputSource:"])
          + "}\n}\n")
    write("CommandBarKillProcessOrder.swift", "import Foundation\n"
          + "extension CommandBarKillProcessOrderContract {\nfinal class Service: Fixture {\n"
          + declaration("Sources/Vorssaint/Services/CommandBar/CommandBarService.swift",
                        "    private func loadKillProcessEntries(").replace("private func", "func", 1)
          + "}\n}\nextension CommandBarKillProcessOrderContract.Processes {\n"
          + declaration("Sources/Vorssaint/Services/KillProcess/KillProcessService.swift",
                        "    var sortedEntries:")
          + "}\n")
    write("CommandBarTermination.swift", "import AppKit\nimport Foundation\n"
          + "extension CommandBarTerminationContract {\nfinal class Host: Fixture {\n"
          + declaration("Sources/Vorssaint/App/AppDelegate.swift", "    func applicationShouldTerminate(")
          + "}\n}\n")
    ports = "Sources/Vorssaint/Services/PortManager/PortManagerService.swift"
    write("PortManagerRefresh.swift", "import Darwin\nimport Foundation\n"
          + "extension PortManagerRefreshTests {\nfinal class Service: Fixture {\n"
          + declaration(ports, "    func refresh(")
          + declaration(ports, "    private static func snapshot(").replace("private static", "static", 1)
          + declaration(ports, "    private static func startTimes(").replace("private static", "static", 1)
          + "}\n}\n")
    write("URLCleanerPoll.swift", "import Foundation\n"
          + "extension RepositoryFeatureTests.URLCleanerPollHost {\n"
          + declaration("Sources/Vorssaint/Services/URLCleanerService.swift",
                        "    private static func pollPasteboard(").replace("private static", "static", 1)
          + "}\n")
    write("ProcessName.swift", "import Foundation\n"
          + "extension ProcessNameContract {\nfinal class Lookup: Fixture {\n"
          + declaration("Sources/Vorssaint/Services/ResponsibleProcess.swift", "    static func displayName(")
          + "}\n}\n")
    disk_sampler = "Sources/Vorssaint/Services/Metrics/DiskSampler.swift"
    write("DiskCapacity.swift", "import Foundation\nextension DiskCapacityTests {\n"
          + "final class Sampler: Fixture {\n"
          + "".join(declaration(disk_sampler, prefix).replace("    private ", "    ", 1)
                    for prefix in ["    private struct DiskMetadata {", "    private struct MountedVolume {",
                                   "    func sample(", "    private static func bestCounter(",
                                   "    private func metadata(", "    private func sortVolumes(",
                                   "    private static func mountedVolumes(", "    private static func importantFree(",
                                   "    private static func positiveUInt(_ value: Int?)",
                                   "    private static func positiveUInt(_ value: Int64?)"])
          + "}\nfinal class Alerts {\n"
          + declaration("Sources/Vorssaint/Services/SystemMonitor/MonitorAlertService.swift",
                        "    private func lowDisk(").replace("private func", "func", 1)
          + "}\n}\n")
    write("SystemMonitorCPU.swift", "import Darwin\nimport Foundation\n"
          + "extension SystemMonitorCPUTests {\nfinal class Monitor: Fixture {\n"
          + declaration("Sources/Vorssaint/Services/SystemMonitor/SystemMonitor.swift",
                        "    private func readCPUUsage(").replace("private func", "func", 1)
          + "}\n}\n")
    monitor = "Sources/Vorssaint/Services/SystemMonitor/SystemMonitor.swift"
    write("SystemMonitorPlan.swift", "import Foundation\n"
          + "extension SystemMonitorPlanTests {\n"
          + declaration(monitor, "struct SystemMonitorPanelNeeds")
          + "final class Monitor: Fixture {\n"
          + declaration(monitor, "    private struct SamplingPlan").replace("private struct", "struct", 1)
          + declaration(monitor, "    private func currentPlan(").replace("private func", "func", 1)
          + "}\n"
          # What the panel and its details ask the monitor for, as shipped.
          + "enum MetricDetailKind {\n"
          + "\n".join(line for line in declaration("Sources/Vorssaint/UI/MenuPanel/MetricDetailView.swift",
                                                   "enum MetricDetailKind:").splitlines()
                      if line.startswith("    case "))
          + "\n" + declaration("Sources/Vorssaint/UI/MenuPanel/MetricDetailView.swift", "    var monitorNeeds:",
                               scope="enum MetricDetailKind:")
          + "}\nfinal class Panel: PanelFixture {\n"
          + declaration("Sources/Vorssaint/UI/MenuPanel/MenuPanelView.swift",
                        "    private var monitorNeeds:").replace("private var", "var", 1)
          + "}\n}\n")
    write("SystemSectionBreakdown.swift", "import Foundation\n"
          + "extension SystemSectionBreakdownTests {\nfinal class Section: Fixture {\n"
          + declaration("Sources/Vorssaint/UI/MenuPanel/SystemSection.swift",
                        "    private func refreshBreakdown(").replace("private func", "func", 1)
          + declaration("Sources/Vorssaint/UI/MenuPanel/SystemSection.swift",
                        "    private func toggleCPUApps(").replace("private func", "func", 1)
          + "}\n}\n")
    uninstall = "Sources/Vorssaint/Services/Uninstall/AppUninstaller.swift"
    bar = "Sources/Vorssaint/Services/CommandBar/CommandBarService.swift"
    for host, path in [("Settings", "Sources/Vorssaint/UI/Settings/URLCleanerSettings.swift"),
                       ("Panel", "Sources/Vorssaint/UI/MenuPanel/PanelURLCleanerView.swift")]:
        write(f"URLCleanerManual{host}.swift", "import Foundation\n"
              + f"extension RepositoryFeatureTests.URLCleanerManual{host} {{\n"
              + "".join(declaration(path, prefix).replace("private ", "", 1)
                        for prefix in ["    private var result:", "    private func copy("])
              + "}\n")
    write("QuickPaste.swift", "import Foundation\n"
          + "extension ClipboardFeatureTests.QuickPasteHost {\n"
          + declaration("Sources/Vorssaint/Services/Clipboard/ClipboardHistoryService.swift",
                        "    private func pasteIntoPreviousApp(").replace("private func", "func", 1)
          + "}\n")
    write("ClipboardPanelPlacement.swift", "import AppKit\n"
          + "extension ClipboardFeatureTests.PanelPlacementHost {\n"
          + "".join(declaration(clipboard, prefix).replace("private func", "func", 1) for prefix in [
              "    private func refreshQuickLayout(", "    private func panelMinimumContentSize(",
              "    private func preferredPanelSize(", "    private func savePanelSize(",
              "    private func position("])
          + "}\nextension ClipboardFeatureTests {\n"
          + declaration(clipboard, "private final class ClipboardPanelSizeLimit").replace(
              "private final class", "final class", 1)
          + "}\n")
    paste_plain = "Sources/Vorssaint/Services/QuickTools/PastePlainService.swift"
    write("PastePlain.swift", "import AppKit\nimport UniformTypeIdentifiers\n"
          + "extension PastePlainTests {\nfinal class Service: Fixture {\n"
          + "".join(declaration(paste_plain, prefix).replace("private func", "func", 1)
                    for prefix in ["    func performPastePlain()", "    private func pastePlain(",
                                   "    static func plainText("])
          + "}\n}\nextension PastePlainTests.OriginalPasteHost {\n"
          + declaration("Sources/Vorssaint/Services/TransientPaste.swift", "    func pasteCurrentContents(")
          + "}\n")
    write("URLCleanerSiteSwitch.swift", "import Foundation\n"
          + "extension RepositoryFeatureTests.URLCleanerSiteSwitchHost {\n"
          + "".join(declaration("Sources/Vorssaint/UI/Settings/URLCleanerSettings.swift",
                                prefix).replace("private ", "", 1)
                    for prefix in ["    private func setSite(", "    private func remove("])
          + "}\n")
    write("ClipboardSource.swift", "import Foundation\n"
          + "extension ClipboardFeatureTests.SourceHost {\n"
          + declaration("Sources/Vorssaint/Services/Clipboard/ClipboardIgnoredApps.swift",
                        "    func sourceSinceLastCheck(")
          + "}\n")
    disk_image = "Sources/Vorssaint/Services/DiskImageInstaller/DiskImageInstallerService.swift"
    write("DiskImageHomebrew.swift", "import Foundation\nimport Darwin\nextension DiskImageHomebrewTests {\n"
          + "".join(declaration(disk_image, prefix).replace("private struct", "struct", 1)
                    for prefix in ["    private struct FileIdentity:", "    private struct Candidate {",
                                   "    private struct CommandResult {"])
          + "final class Service: Fixture {\n"
          + "".join(declaration(disk_image, prefix).replace("private ", "", 1)
                    for prefix in ["    private func inspect(", "    private func candidate(",
                                   "    private static func isHomebrewImage(",
                                   "    private static func fileIdentity(", "    private static func validBundle("])
          + "}\n}\n")
    cleaner = "Sources/Vorssaint/Services/URLCleanerService.swift"
    write("URLCleanerRewrite.swift", "import AppKit\n"
          + "extension ClipboardFeatureTests.URLCleanerHost {\n"
          + "".join(declaration(cleaner, prefix).replace("private static", "static", 1) for prefix in [
              "    private static func pollPasteboard(", "    private static func writeToPasteboard("])
          + "}\n")
    write("CommandBarFeatureNames.swift", "import Foundation\nextension AppFeature {\n"
          + declaration("Sources/Vorssaint/UI/Settings/FeatureHubSettings.swift", "    func hubTitle(")
          + "}\n")
    write("CommandBarCatalogBuild.swift", "import Foundation\n"
          + "extension CommandBarFeatureTests.CatalogBuildHost {\n"
          + declaration("Sources/Vorssaint/Services/CommandBar/CommandBarCatalog.swift",
                        "    static func build(")
          + "}\n")
    write("CommandBarCatalogSearch.swift", "import AppKit\n"
          + declaration("Sources/Vorssaint/Services/CommandBar/CommandBarCatalog.swift",
                        "struct CommandBarEntry:")
          + "enum CommandBarCatalogSearch {\n"
          + declaration("Sources/Vorssaint/Services/CommandBar/CommandBarCatalog.swift",
                        "    static func includingEnglishNames(")
          + "}\n")
    write("CommandBarCopyAnswer.swift", "import Foundation\n"
          + "extension CommandBarFeatureTests.CopyAnswerHost {\n"
          + declaration("Sources/Vorssaint/Services/CommandBar/CommandBarCatalog.swift",
                        "    private static func copyAnswer(").replace("private static", "static", 1)
          + "}\n")
    write("CommandBarRunScript.swift", "import Foundation\n"
          + "extension CommandBarFeatureTests.ScriptRunHost {\n"
          + declaration("Sources/Vorssaint/Services/CommandBar/CommandBarCatalog.swift",
                        "    private static func runScript(").replace("private static", "static", 1)
          + declaration("Sources/Vorssaint/Services/CommandBar/CommandBarScriptRunner.swift",
                        "final class CommandBarScriptRunner {")
          + "}\n")
    write("CommandBarSelection.swift", "import Foundation\nextension CommandBarSelectionTests {\n"
          + declaration("Sources/Vorssaint/Services/CommandBar/CommandBarSupport.swift", "enum CommandBarText {")
          + "final class Catalog: Fixture {\n"
          + declaration("Sources/Vorssaint/Services/CommandBar/CommandBarCatalog.swift",
                        "    static func selectionEntries(")
          + "}\n}\n")
    write("CommandBarBrightness.swift", "import AppKit\n"
          + "extension CommandBarFeatureTests.BrightnessHost {\n"
          + declaration("Sources/Vorssaint/Services/CommandBar/CommandBarCatalog.swift",
                        "    private static func applyBrightness(").replace("private static", "static", 1)
          + "}\n")
    write("PointerScreen.swift", "import AppKit\n"
          + "extension PointerScreenContract.Screen {\n"
          + declaration("Sources/Vorssaint/Core/AppKitExtensions.swift", "    static var withMouse:")
          + "}\n")
    write("CommandBarEmojiBodies.swift", "import Foundation\n"
          + "extension CommandBarEmojiContract.Catalog {\n"
          + declaration("Sources/Vorssaint/Services/CommandBar/CommandBarCatalog.swift",
                        "    static func emojiEntries(")
          + "}\nextension CommandBarEmojiContract.Service {\n"
          + "".join(declaration(bar, prefix).replace("private func", "func", 1)
                    for prefix in ["    struct RowAction:", "    private func skinToneActions(",
                                   "    private func recordUsage(", "    private func finish("])
          + "}\n")
    write("UninstallerFlow.swift", "import AppKit\nimport Carbon.HIToolbox\nimport Combine\n"
          + "extension UninstallerFlowTests {\n"
          + declaration(uninstall, "    enum Phase:")
          + declaration(bar, "    enum Mode:")
          + "final class Uninstaller: UninstallerState {\nstatic let shared = Uninstaller()\n"
          + "".join(declaration(uninstall, prefix) for prefix in [
              "    var isRemoving: Bool", "    func select(appURL:",
              "    func reset()", "    func setInclude(", "    struct HomebrewRemovalConfirmation",
              "    var homebrewRemovalConfirmation:", "    func removeSelectedWithHomebrew("])
          + "}\nfinal class Service: ServiceState {\n"
          + "".join(declaration(bar, prefix).replace("private func", "func", 1) for prefix in [
              "    @Published var query", "    private func beginUninstallReview(",
              "    private func handleUninstallKey(", "    func stepBack()",
              "    private func finishUninstallReview()"])
          + "}\n}\nextension UninstallerFlowTests.Finder {\n"
          + declaration("Sources/Vorssaint/Services/Finder/FinderCutPaste.swift", "    static func selectionURLs(")
          + "}\n")
    write("UninstallerCommandBarCleanup.swift", "import Foundation\n"
          + "extension UninstallerCommandBarCleanupTests {\n"
          + declaration(uninstall, "    enum Phase:")
          + "final class Uninstaller: UninstallerState {\n"
          + "".join(declaration(uninstall, prefix).replace("private func", "func", 1)
                    .replace("private static func", "static func", 1) for prefix in [
                        "    var selectedHomebrewPackage:", "    var isRemovingWithHomebrew:",
                        "    var isRemoving: Bool",
                        "    func setInclude(", "    private func finishRemovalAfterHomebrew(",
                        "    private static func removeCommandBarState("])
          + "}\nfinal class Service: ServiceState {\nstatic let shared = Service()\n"
          + "".join(declaration(bar, prefix).replace("private var", "var", 1)
                    .replace("private func", "func", 1) for prefix in [
                        "    var rowShortcuts:", "    private var storedAliases:",
                        "    private var storedPins:", "    private var storedHiddenKeys:",
                        "    private func syncRowHotkeys(", "    func hasStoredApplicationState(",
                        "    func removeApplicationState("])
          + "}\n}\n")
    dock = "Sources/Vorssaint/Services/DockPreview/DockPreviewService.swift"
    write("DockPreviewScroll.swift", "import AppKit\nimport SwiftUI\n"
          + "extension DockPreviewScrollTests {\n"
          + declaration("Sources/Vorssaint/UI/Switcher/DockPreviewPanelView.swift",
                        "private struct DockPreviewPanelContent:").replace("private struct", "struct", 1)
          + "}\n")
    write("DockPreviewPosition.swift", "import CoreGraphics\nimport Foundation\n"
          + "extension DockPreviewPositionTests.Service {\n"
          + "".join(declaration(dock, prefix, scope="final class DockPreviewService:")
                    .replace("private func", "func", 1)
                    for prefix in ["    private func handleMouseMoved(",
                                   "    private func currentZone(",
                                   "    private func showPanel(",
                                   "    private func resizePanelForCurrentWindows()",
                                   "    private func clampedPanelFrame("])
          + "}\n")
    write("DockPreviewFrameRetry.swift", "import Foundation\nextension DockPreviewFrameRestorationTests {\n"
          + declaration("Sources/Vorssaint/Services/DockPreview/DockPreviewFrameRestoration.swift",
                        "    private static func restore(").replace("private static func", "static func", 1)
          + "}\n")
    write("DockPreviewScope.swift", "import Foundation\nextension DockPreviewScopeTests.Service {\n"
          + "".join(declaration(dock, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func syncSpaceObservation()",
                                   "    private func stopSpaceObservation()"])
          + "}\nextension DockPreviewScopeTests.WindowEnumerator {\n"
          + declaration("Sources/Vorssaint/Services/Switcher/WindowEnumerator.swift",
                        "    static func dockPreviewMayActivate(")
          + "}\n")
    write("PreviewCapturePause.swift", "import Foundation\n"
          + "extension SwitcherModelFeatureTests.PreviewProvider {\n"
          + declaration("Sources/Vorssaint/Services/Switcher/WindowPreviewProvider.swift",
                        "    private static func captureIsPaused(").replace("private static", "static", 1)
          + "}\n")
    write("DockAutohideInput.swift", "import CoreGraphics\nimport Foundation\nextension DockAutohideHoldTests.Service {\n"
          + "".join(declaration(dock, prefix, scope="final class DockPreviewService:")
                    .replace("private func", "func", 1)
                    for prefix in ["    private func beginDockAutohideHold()",
                                   "    private func releaseDockAutohideHold()",
                                   "    private func handleDockHoldInput(type:",
                                   "    private func handle(type:",
                                   "    func commit("])
          + "}\n")
    # The raw wheel tap runs as shipped: linear scrolling's cap, carry and
    # write-back, then the direction change. Only the services it asks and
    # the defaults it reads are fixtures.
    write("ZoomSettingsDirectory.swift", "import Foundation\n"
          + declaration("Sources/Vorssaint/UI/Settings/SettingsDirectory.swift", "struct SettingsDirectoryItem:")
          + "enum SettingsDirectory {\n"
          + declaration("Sources/Vorssaint/UI/Settings/SettingsDirectory.swift", "    static func sections(")
              .replace("SuperKeyService.shared.source", ".capsLock")
              .replace("$0.hubTitle(s, hub: FeatureStrings.hub(language))", "$0.rawValue")
          + "}\n")
    wheel_tap = declaration("Sources/Vorssaint/Services/ScrollInverter.swift", "    private func handle(type:",
                            scope="final class ScrollInverter:")
    if wheel_tap.count("AppFeature.linearScroll.isAvailable") != 1:
        raise ValueError("Expected one linear scrolling availability read in ScrollInverter.handle")
    write("LinearScrollTap.swift", "import CoreGraphics\nimport Foundation\nextension LinearScrollTapTests.Inverter {\n"
          + wheel_tap.replace("private func", "func", 1)
                     .replace("AppFeature.linearScroll.isAvailable", "AppFeature.linearScroll.isAvailable(in: defaults)")
          + declaration("Sources/Vorssaint/Services/ScrollInverter.swift", "    func consumeZoom(")
          + "".join(declaration("Sources/Vorssaint/Services/ScrollInverter.swift", prefix)
                    .replace("private func", "func", 1) for prefix in [
                        "    private func postPinchZoomLocked(", "    private func endPinchZoomLocked()"])
          + declaration("Sources/Vorssaint/Services/ScrollInverter.swift", "    static func directionApplied(to event:",
                        scope="final class ScrollInverter:")
          + "}\nextension LinearScrollTapTests.SideWheel {\n"
          + declaration("Sources/Vorssaint/Services/MouseButtons/MouseButtonShortcutService.swift",
                        "    private func sideWheelInput(for event:").replace("private func", "func", 1)
          + "}\n")
    mouse_buttons = "Sources/Vorssaint/Services/MouseButtons/MouseButtonShortcutService.swift"
    spaces_replay = declaration(mouse_buttons, "    private func replaySpacesPress(").replace("private func", "func", 1)
    write("MouseSpacesGestureTap.swift", "import AppKit\nimport ApplicationServices\nimport CoreGraphics\n"
          + "extension MouseSpacesGestureTapTests.Service {\n"
          + "".join(declaration(mouse_buttons, prefix).replace("private ", "", 1)
                    .replace("AppFeature.mouseButtonShortcuts.isAvailable",
                             "AppFeature.mouseButtonShortcuts.isAvailable(in: UserDefaults.standard)")
                    for prefix in ["    private struct SpacesGesturePress {", "    func setCapturing(",
                                   "    private func handle(proxy:", "    private func armSpacesGesture(",
                                   "    private func advanceSpacesGesture("])
          + spaces_replay.replace("down.tapPostEvent(proxy)", "recordReplay(down)")
                         .replace("down.post(tap: .cgSessionEventTap)", "recordReplay(down)")
                         .replace("if let proxy {", "if proxy != nil {")
          + "}\n")
    write("ZoomTargetRefresh.swift", "import CoreGraphics\nimport Foundation\n"
          + "extension LinearScrollTapTests.Refresher {\n"
          + "".join(declaration("Sources/Vorssaint/Services/ScrollInverter.swift", prefix)
                    .replace("private func", "func", 1)
                    .replace("AXIsProcessTrusted()", "self.AXIsProcessTrusted()") for prefix in [
                        "    private func startZoomTargetTimerLocked()",
                        "    private func stopZoomTargetTimerLocked()"])
          + "}\n")
    zoom_post = declaration("Sources/Vorssaint/Services/ScrollInverter.swift", "    private func postKeyboardZoom(")
    write("ZoomTargetRequest.swift", "import CoreGraphics\nimport Foundation\n"
          + "extension LinearScrollTapTests.TargetResolver {\n"
          + "".join(declaration("Sources/Vorssaint/Services/ScrollInverter.swift", prefix)
                    .replace("private func", "func", 1) for prefix in [
                        "    private func invalidateZoomTargetLocked()",
                        "    private func requestZoomTargetLocked("])
          + "}\n")
    for name in ["down", "up", "restore"]:
        zoom_post = zoom_post.replace(f"{name}.postToPid(targetProcessID)", f"recordZoomEvent({name}, to: targetProcessID)")
    write("ZoomKeyboardPost.swift", "import CoreGraphics\nimport Carbon.HIToolbox\n"
          + "extension LinearScrollTapTests.Inverter {\n"
          + zoom_post.replace("private func", "func", 1) + "}\n")
    smooth = "Sources/Vorssaint/Services/SmoothScrollService.swift"
    write("ScrollZoomFocus.swift", "import AppKit\nimport ApplicationServices\n"
          + "extension ScrollZoomFocusTests {\n"
          + declaration("Sources/Vorssaint/Services/Switcher/WindowActivator.swift", "    static func focusWindow(")
          + "}\n")
    smooth_handler = declaration(smooth, "    private func handle(type:").replace("private func", "func", 1)
    smooth_handler = smooth_handler.replace("AppFeature.smoothScroll.isAvailable", "AppFeature.smoothScroll.isAvailable(in: UserDefaults.standard)")
    smooth_handler = smooth_handler.replace("AppFeature.linearScroll.isAvailable", "AppFeature.linearScroll.isAvailable(in: defaults)")
    smooth_post = declaration(smooth, "    private func post(vertical:").replace("private func", "func", 1)
    if smooth_post.count("event.postToPid(target.processID)") != 1:
        raise ValueError("Expected one targeted smooth-scroll post")
    write("SmoothScrollRouting.swift", "import AppKit\nimport ApplicationServices\nimport CoreGraphics\n"
          + "extension SmoothScrollRoutingTests.Service {\n"
          + smooth_handler
          + declaration(smooth, "    private func stopGlide()").replace("private func", "func", 1)
          + declaration(smooth, "    private func emitFrame(at timestamp:").replace("private func", "func", 1)
          + declaration(smooth, "    private static func pixelField(").replace("private static", "static", 1)
          + smooth_post.replace("event.postToPid(target.processID)", "SmoothScrollRoutingTests.record(event, to: target.processID)")
          + "}\n")
    write("KeyboardDebounceTap.swift", "import ApplicationServices\nimport CoreGraphics\nimport Foundation\n"
          + "extension KeyboardDebounceTapTests.Service {\n"
          + declaration("Sources/Vorssaint/Services/KeyboardDebounce/KeyboardDebounceService.swift",
                        "    private func handle(type:").replace("private func", "func", 1)
          + "}\n")
    # Entire input/mute services retain their production control flow. Only
    # visibility, scheduling, defaults and HAL transport are replaced by fixtures.
    input_source = "Sources/Vorssaint/Services/Audio/AudioInputDeviceManager.swift"
    mute_source = "Sources/Vorssaint/Services/QuickTools/MicMuteService.swift"
    input_bodies = (declaration(input_source, "struct MixerInputDevice:")
                    + declaration(input_source, "final class AudioInputDeviceManager:")
                    + declaration(mute_source, "final class MicMuteService:"))
    input_bodies = (input_bodies.replace("fileprivate ", "")
                   .replace("private(set) ", "").replace("private ", "")
                   .replace("static let shared =", "static var shared ="))
    for operation in ("HasProperty", "IsPropertySettable", "GetPropertyDataSize",
                      "GetPropertyData", "SetPropertyData", "AddPropertyListener",
                      "RemovePropertyListener"):
        input_bodies = input_bodies.replace("AudioObject" + operation + "(", "HAL." + operation + "(")
    write("MixerInputVolume.swift", "import Foundation\nimport Combine\nimport CoreAudio\nimport AudioToolbox\n"
          + "extension MixerInputVolumeContract {\n" + input_bodies + "}\n")
    mixer = "Sources/Vorssaint/Services/Audio/AppVolumeMixer.swift"
    tap_scope = "private final class TapGainEngine:"
    tap_init = declaration(mixer, "    init?(objects:", scope=tap_scope)
    callback_start = "guard AudioDeviceCreateIOProcIDWithBlock(&ioProc, aggregateID, nil, { now, input, _, output, _ in\n"
    _, callback_found, callback_tail = tap_init.partition(callback_start)
    callback, callback_end, _ = callback_tail.partition("        }) == noErr else {")
    if not callback_found or not callback_end:
        raise ValueError("Expected the device mixer's audio callback")
    write("MixerRenderContinuity.swift", "import CoreAudio\nimport Foundation\n"
          + "extension MixerRenderContinuityTests.Renderer {\n"
          + declaration(mixer, "    private final class LimiterBox", scope=tap_scope)
            .replace("private final class", "final class", 1)
          + "func process(now: UnsafePointer<AudioTimeStamp>, input: UnsafePointer<AudioBufferList>, "
            "output: UnsafeMutablePointer<AudioBufferList>) {\n" + callback + "}\n}\n")
    write("MixerUniversalRouting.swift", "import CoreAudio\nimport Foundation\n"
          + "extension MixerUniversalRoutingContract {\n"
          + declaration(mixer, "struct MixerApp:") + "}\n"
          + "extension MixerUniversalRoutingContract.Mixer {\n"
          + "".join(declaration(mixer, prefix).replace("private ", "", 1) for prefix in [
              "    private var universalOutputDeviceUID:",
              "    private static func applyingUniversalOutputRoute(",
              "    private static func coalescingAppsWithDuplicateIDs(",
              "    private static func runningAddress(",
              "    private static func storedVolume(", "    private static func storedRoute(",
              "    private func storedVolume(", "    private func storedRoute(",
              "    private func applyingCurrentVolumes(",
              "    private func savedCallAppVolumeEnabled(", "    func setCallAppVolumeControl(",
              "    private func appNeedsEngine(", "    private func rowMayBeTapped(",
              "    private func applyOutputRoute(", "    func setOutputDeviceUID(",
              "    func switchToNextSoundOutput(", "    func setUniversalOutputDeviceUID(",
              "    private func setDefaultOutputDeviceUID("])
          + "}\n")
    level_watch = declaration(mixer, "final class LevelCompensationWatch {").replace("private ", "")
    for operation in ("AddPropertyListener", "RemovePropertyListener"):
        level_watch = level_watch.replace("AudioObject" + operation + "(", "HAL." + operation + "(")
    write("MixerLevelCompensation.swift", "import CoreAudio\nimport Foundation\n"
          + "extension MixerLevelCompensationContract {\n" + level_watch + "}\n")
    configuration = declaration(mixer, "private final class MixerTapConfiguration {").replace("private ", "")
    for operation in ("AddPropertyListener", "RemovePropertyListener"):
        configuration = configuration.replace("AudioObject" + operation + "(", "HAL." + operation + "(")
    write("MixerTapConfiguration.swift", "import CoreAudio\nimport Foundation\n"
          + "extension MixerTapConfigurationTests {\n" + configuration + "}\n"
          + "extension MixerTapConfigurationTests.Recovery {\n"
          + declaration(mixer, "    private func retryInvalidatedEngine(for id:")
            .replace("private func", "func", 1)
          + declaration(mixer, "    private func configurationRepairDelay(for id:")
            .replace("private func", "func", 1)
          + "}\n")
    write("SoundOutputSwitch.swift", "import Foundation\n"
          + "extension SoundOutputSwitchContract {\nfinal class Mixer {\n"
          + "var outputDevices: [Device] = []\nvar currentOutputDeviceUID: String?\nvar switchedTo: [String] = []\n"
          + "func setUniversalOutputDeviceUID(_ uid: String) -> Bool { switchedTo.append(uid); return true }\n"
          + declaration(mixer, "    func switchToNextSoundOutput(") + "}\n}\n")
    write("MixerOutputAdjustment.swift", "import CoreAudio\nimport Foundation\n"
          + "extension MixerOutputAdjustmentContract {\nfinal class Mixer {\n"
          + "var systemOutputVolume: Double?\nvar systemOutputMuted: Bool?\n"
          + "var outputControlListenerDevice: AudioObjectID?\n"
          + "var outputControlListenerAddresses: [AudioObjectPropertyAddress] = []\n"
          + "var outputControlRefreshGeneration = 0\nvar listenerRefreshes = 0\n"
          + "static let outputControlListenerCallback: AudioObjectPropertyListenerProc = { _, _, _, _ in noErr }\n"
          + "var listenerClient: UnsafeMutableRawPointer? { nil }\n"
          + "static func defaultOutputDeviceID() -> AudioObjectID? { Hardware.device }\n"
          + "static func setOutputVolume(_ value: Float, for device: AudioObjectID) -> Bool {\n"
          + "Hardware.writes.append(.init(device: device, volume: value, muted: nil)); return Hardware.succeeds\n}\n"
          + "@discardableResult static func setOutputMuted(_ value: Bool, for device: AudioObjectID) -> Bool {\n"
          + "guard Hardware.muted != nil else { return false }\n"
          + "Hardware.writes.append(.init(device: device, volume: nil, muted: value)); if Hardware.succeeds { Hardware.muted = value }; return Hardware.succeeds\n}\n"
          + "func scheduleListenerRefresh() { listenerRefreshes += 1 }\n"
          + "func selectOutput(_ device: AudioObjectID?, volume: Double?, muted: Bool?) {\n"
          + "removeOutputControlListeners(); outputControlListenerDevice = device; applyOutputControls(volume: volume, muted: muted)\n}\n"
          + "".join(declaration(mixer, prefix) for prefix in [
              "    private func removeOutputControlListeners(", "    private func applyOutputControls(",
              "    func setCurrentOutputVolume(", "    static func setSystemOutputVolume("])
          + "}\n}\n")
    write("MixerHeadphonesDisconnect.swift", "import CoreAudio\nimport Foundation\n"
          + "extension MixerHeadphonesDisconnectContract.Mixer {\n"
          + "".join(declaration(mixer, prefix).replace("private ", "", 1) for prefix in [
              "    private struct LoweredOutput {", "    private struct LoweredOutputState {",
              "    private static func loweringOutputVolumeIfHeadphonesDisconnected(",
              "    private static func restoringLoweredOutputVolume("])
          + "}\n")
    mixer_section = "Sources/Vorssaint/UI/MenuPanel/MixerSection.swift"
    write("MixerPercentKey.swift", "import Foundation\nextension MixerPercentKeyTests {\nfinal class Coordinator: Fixture {\n"
          + "".join(declaration(mixer_section, prefix).replace("private func", "func", 1) for prefix in [
              "        private func startMonitoringEscape()", "        private func finish("])
          + "}\n}\n")
    cleaner = "Sources/Vorssaint/Services/Cleaner/JunkCleaner.swift"
    write("CleanerEligibilityBodies.swift", "import Foundation\nextension CleanerEligibilityTests {\n"
          + "".join(declaration(cleaner, "    private static func " + name)
                    .replace("private static func", "static func", 1)
                    for name in ["appendLeftovers(", "scanCaches(", "scanLogs(",
                                 "directorySize(", "fileSize(", "sorted(",
                                 "scanScreenshots(", "isScreenCapture(", "extendedAttribute("])
          + declaration(cleaner, "    private static func leftoverOwner(")
          + declaration(cleaner, "    private static func containerOwner(")
          + declaration(cleaner, "    private static func mayRemove(")
          + "static func owner(_ url: URL, metadata: Bool = false) -> String? {\n"
          + "leftoverOwner(entry: url.lastPathComponent, url: url, usesContainerMetadata: metadata)\n}\n"
          + "static func canRemove(_ item: Item, installed: Set<String> = []) -> Bool {\n"
          + "mayRemove(item, installed: installed)\n}\n}\n")
    write("CleanerScanFlow.swift", "import Foundation\nextension CleanerScanFlowTests {\n"
          + declaration(cleaner, "    enum Phase:")
          + "final class Scanner: ScannerState {\nstatic let shared = Scanner()\n"
          + "".join(declaration(cleaner, prefix) for prefix in ["    func reset()", "    func scan("])
          + "}\n}\n")

    super_key = "Sources/Vorssaint/Services/SuperKey/SuperKeyService.swift"
    write("SuperKeyTap.swift", "import CoreGraphics\nimport Foundation\n"
          + "extension SuperKeyTapContract {\nfinal class SuperKeyService: State {\n"
          + "".join(declaration(super_key, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func runEventTap()", "    private func setMappingFailure("])
            .replace("CGEvent.tapCreate(", "Tap.create(")
          + "}\n}\n")

    write("CleanerLastRun.swift", "import Foundation\nextension CleanerLastRunContract {\n"
          + "final class Scheduler: SchedulerState {\n"
          + declaration("Sources/Vorssaint/Services/Cleaner/CleanerScheduler.swift", "    private func finishRun(")
            .replace("private func", "func", 1)
          + "}\nfinal class Card: CardState {\n"
          + declaration("Sources/Vorssaint/UI/Cleaner/CleanerView.swift", "    private var lastRunLine:")
            .replace("private var", "var", 1)
          + "}\n}\n")

    updates = "Sources/Vorssaint/Services/AppUpdates/AppUpdatesService.swift"
    write("AppUpdateHandoff.swift", "import Foundation\nextension AppUpdateHandoffTests {\n"
          + "final class Service: State {\n"
          + "".join(declaration(updates, prefix).replace("private func", "func", 1)
                    for prefix in ["    var updateHandoffPending:", "    private func handOff(",
                                   "    func applicationBecameActive()", "    func consumeUpdateHandoffReturn()"])
          + "}\n}\n")
    loader = "Sources/Vorssaint/Services/AppUpdates/AppUpdateFeedLoader.swift"
    # Only the network configuration, clock and declaration visibility change.
    # The loader, batch loop, catalog matching and fallback resolution stay verbatim.
    write("AppUpdates.swift", "import Foundation\nimport Darwin\nextension AppUpdatesContract {\n"
          + declaration(loader, "final class AppUpdateFeedLoader:")
          + "final class Service {\nlet workQueue = DispatchQueue(label: \"app-updates.contract\")\n"
          + "let clock = Clock()\nstatic let ownPackageTokens: Set<String> = [\"vorssaint\", \"vorssaint@beta\", \"vorssaint-beta\"]\n"
          + "static let onlineCatalogCacheLifetime: TimeInterval = 60 * 60\n"
          + "var onlineCatalogCache: (loadedAt: Foundation.Date, entries: [AppUpdatesSupport.CatalogEntry])?\n"
          + "lazy var catalogSession = URLSession(configuration: URLSessionConfiguration.ephemeral)\n"
          + declaration(updates, "    private struct SourceResult {").replace("private struct", "struct", 1)
          + declaration(updates, "    private func publisherFindings(").replace("private func", "func", 1).replace("Date()", "self.clock.now()")
          + declaration(updates, "    private func onlineCatalogFindings(").replace("private func", "func", 1).replace("Date()", "self.clock.now()")
          + declaration(updates, "    private func onlineResult(").replace("private func", "func", 1)
          + "}\n}\n")
    # Rule mutations and completion stay verbatim; only declaration visibility changes.
    write("AppUpdateRules.swift", "import CoreServices\nimport Foundation\nextension AppUpdateRulesContract {\n"
          + "final class Service: State {\n"
          + "".join(declaration(updates, prefix).replace("private func", "func", 1)
                    .replace("private static func scannedApp(", "static func scannedApp(", 1)
                    for prefix in ["    func skipVersion(", "    func excludeApp(", "    func addExclusion(",
                                   "    private func setRule(", "    private func storeRule(",
                                   "    func removeRule(",
                                   "    private func saveRules(", "    private func reloadRules(",
                                   "    private func applyRules(", "    private func finishCheck(",
                                   "    private static func announcedIDs(", "    private static func saveAnnouncedIDs(",
                                   "    private static func scannedApp(", "    private static func isOwnBundle("])
          + "}\n}\n")
    usage = "Sources/Vorssaint/Services/SystemMonitor/ProcessUsageService.swift"
    write("ProcessForceQuit.swift", "import Darwin\nimport Foundation\n"
          + "extension ProcessForceQuitTests {\n"
          + declaration(usage, "struct ProcessUsage:")
          + "final class Service {\nprivate let maximumCachedRows = 60\n"
          + declaration(usage, "    func canForceQuit(")
          + declaration(usage, "    private static func executableName(")
          + declaration(usage, "    private func withForceQuitIdentity(").replace("private func", "func", 1)
          + declaration(usage, "    private static func processExisted(")
          + declaration(usage, "    private func groupedByApp(").replace("private func", "func", 1)
          + declaration(usage, "    private func groupedNetworkByApp(").replace("private func", "func", 1)
          + "}\n}\n")
    write("QuickTogglesAlert.swift", "import AppKit\nextension QuickTogglesAlertTests {\nfinal class Host: Fixture {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/QuickTogglesService.swift", "    func emptyTrash()")
          + "}\n}\n")
    quit_panel = "Sources/Vorssaint/Services/QuickTools/QuitAppsPanelController.swift"
    quit_service = "Sources/Vorssaint/Services/QuickTools/QuickTogglesService.swift"
    write("QuitAppsRuntime.swift", "import AppKit\nimport Carbon.HIToolbox\nimport Combine\nimport SwiftUI\n"
          + "extension QuitAppsRuntimeTests {\n"
          + declaration(quit_panel, "final class QuitAppsPanelController {")
              .replace("private ", "")
          + declaration(quit_panel, "final class QuitAppsModel:")
          + declaration(quit_panel, "private struct QuitAppsView:").replace("private struct", "struct", 1)
          + declaration(quit_panel, "private struct QuitAppsRowView:").replace("private struct", "struct", 1)
          + "final class QuickTogglesService: ServiceState {\nstatic let shared = QuickTogglesService()\n"
          + "".join(declaration(quit_service, prefix)
                    for prefix in ["    func showQuitApps(", "    func quitAllApps(", "    func quitApp(",
                                   "    private static func candidate(", "    func frontmostAppPID()"])
          + "}\nfinal class AppDelegate {\nvar panelActivationSource: NSRunningApplication?\n"
          + declaration("Sources/Vorssaint/App/AppDelegate.swift", "    var panelActivationSourcePID:")
          + "}\nstruct Editor {\n"
          + availability_declaration("Sources/Vorssaint/UI/Settings/RadialMenuSettings.swift",
                                     "    private var availableQuickToggles:").replace("private var", "var", 1)
          + "}\n}\n")
    write("OverlayPanelDeclaration.swift", "import AppKit\n"
          + declaration("Sources/Vorssaint/UI/OverlayPanel.swift", "class OverlayPanel:"))
    shelf = "Sources/Vorssaint/Services/Shelf/ShelfService.swift"
    write("ShelfDragCompletion.swift", "import Foundation\n\nextension ShelfDragCompletionContract {\n"
          + "final class Service {\nvar activeInternalDragIDs: [UUID] = []\n"
          + "weak var internalDragWindow: NSWindow?\nvar internalDragWasMerged = false\n"
          + "var panel: NSWindow?\nvar dockedPanel: NSWindow?\n"
          + "var isPinned = false\nvar isVisible = false\nvar dockedVisible = false\n"
          + "var removed: [UUID] = []\nvar protectedIDs: Set<UUID> = []\n"
          + "var floatingClosures = 0\nvar dockedClosures = 0\n"
          + "func endInteraction() {}\nfunc removeItems(_ ids: [UUID]) { removed += ids }\n"
          + "func hide() { floatingClosures += 1; isVisible = false }\n"
          + "func collapseDocked() { dockedClosures += 1; dockedVisible = false }\n"
          + declaration(shelf, "    func beginInternalDrag(")
          + declaration(shelf, "    func finishInternalDrag(")
          + declaration(shelf, "    func completeInternalDrag(")
          + "}\n}\n")
    recorder = "Sources/Vorssaint/Services/Recorder/RecorderEditorController.swift"
    write("RecorderZoomAiming.swift", "import Foundation\nimport Combine\n"
          + "extension RecorderZoomAimingTests {\nfinal class Model: State {\n"
          + declaration(recorder, "    @Published var document:").replace("@Published var", "override var", 1)
          + declaration(recorder, "    @Published var selectedZoomID:")
          + "".join(declaration(recorder, prefix) for prefix in [
              "    private func documentDidChange(", "    func undo()", "    func redo()",
              "    private func apply(_ next:", "    func zoom(_ id:",
              "    func beginAiming(", "    func endAiming(", "    func aim(",
              "    func setSelectedZoomFocus(", "    private func applyDuringInteraction(",
              "    func beginPickingBlurArea(", "    func endPickingBlurArea("])
          + "}\n}\n")
    scratchpad_service = "Sources/Vorssaint/Services/QuickTools/ScratchpadService.swift"
    scratchpad_reading = "Sources/Vorssaint/UI/Scratchpad/ScratchpadView.swift"
    update = "Sources/Vorssaint/Services/Update/UpdateService.swift"
    write("UpdateAdminInstall.swift", "import Foundation\n\nextension UpdateAdminInstallContract {\n"
          + "final class Service: Fixture {\n"
          + declaration(update, "    private func launchAdminInstaller(").replace("private ", "", 1)
          + "}\n}\n")
    write("ShortcutsExpansion.swift", "import SwiftUI\n\nextension FeatureCatalogTests {\n"
          + "final class Expansion { var features: [FeatureGroup: Set<AppFeature>] = [:] }\n"
          + "struct ShortcutsPage {\nlet state: Expansion\n"
          + "var expandedFeatures: [FeatureGroup: Set<AppFeature>] { get { state.features } nonmutating set { state.features = newValue } }\n"
          + declaration("Sources/Vorssaint/UI/Settings/ShortcutsSettings.swift", "    private func expansionBinding(").replace("private func", "func", 1)
          + "}\n}\n")
    media_workspace = "Sources/Vorssaint/UI/Media/MediaWorkspaceView.swift"
    write("MediaDialogHost.swift", "import AppKit\n\nextension MediaDialogHostContract {\nenum Dialogs {\n"
          + "static var panelModalActive = false\n"
          + declaration(media_workspace, "    private static func runPanelModal(").replace("private static", "static", 1)
          + "}\n}\n")
    write("MediaWorkspaceLayout.swift", "import AppKit\nimport SwiftUI\nimport UniformTypeIdentifiers\n"
          + "extension MediaWorkspaceLayoutTests {\n"
          + "struct Input: View {\n@State var isDropTargeted = false\n"
          + "var inputSelector: some View { Color.clear.frame(width: 300, height: 70) }\n"
          + "func acceptDrop(_ providers: [NSItemProvider]) -> Bool { false }\n"
          + "var body: some View { inputDropTarget }\n"
          + declaration(media_workspace, "    private var inputDropTarget:")
          + "}\nstruct ToolPicker {\nlet fixture: Selection\n"
          + "var selectedTool: MediaTool { get { fixture.tool } nonmutating set { fixture.tool = newValue } }\n"
          + declaration(media_workspace, "    private var selectedToolBinding:").replace("private var", "var", 1)
          + "}\n}\n")
    write("RecorderExportChip.swift", "import AppKit\nimport SwiftUI\n\nextension RecorderExportChipTests {\n"
          + "struct Chip: View {\n@ObservedObject var model: Model\nlet strings = Strings()\n"
          + "var exportProgressLabel: String { strings.exportingLabel }\n"
          + "var body: some View { exportProgressChip }\n"
          + declaration("Sources/Vorssaint/UI/Recorder/RecorderEditorView.swift", "    private var exportProgressChip:")
          + "}\n}\n")
    switcher = "Sources/Vorssaint/UI/Switcher/SwitcherView.swift"
    switcher_service = "Sources/Vorssaint/Services/Switcher/AppSwitcher.swift"
    write("SwitcherScroll.swift", "import AppKit\nimport SwiftUI\n"
          + "extension SwitcherScrollContract {\nstruct Strip: View {\n"
          + "@ObservedObject var switcher: Model\n"
          + "var instantSelection = false\n"
          + "var iconRowContentWidth: CGFloat { switcher.iconRowLayout.contentWidth(simpleMode: true, windowRow: false) }\n"
          + "var body: some View {\nif selectedWindow != nil {\nlet appWindows = selectedAppWindows\n"
          + "if switcher.simple {\nGroup {\n"
          + declaration(switcher, "                ScrollViewReader { proxy in")
          + "}\n.frame(width: iconRowContentWidth - 2 * SwitcherIconRowLayout.simpleTitlePanelPadding, "
          + "height: 25 * SwitcherIconRowLayout.scale)\n} else {\n"
          + declaration(switcher, "                    ScrollViewReader { proxy in")
          + "}\n}\n}\n"
          + declaration(switcher, "    private var selectedWindow:")
          + declaration(switcher, "    private var selectedAppWindows:")
          + declaration(switcher, "    private func revealSelection(")
          + "}\n}\nextension SwitcherScrollContract.Model {\n"
          + "func search(_ query: String) { searchQuery = query; applySearchFilter(preferredItemID: selectedItemID) }\n"
          + declaration(switcher_service, "    private var selectedItemID:")
          + declaration(switcher_service, "    private func applySearchFilter(")
          + "}\n")
    write("SwitcherSearchLayout.swift", "import AppKit\nimport SwiftUI\n"
          + "extension SwitcherSearchLayoutTests {\n"
          + declaration(switcher_service, "struct SwitcherGrid:")
          + declaration(switcher, "private enum SwitcherIconStyle {").replace("private enum", "enum", 1)
          + "}\nextension SwitcherSearchLayoutTests.Model {\n"
          + "typealias SwitcherGrid = SwitcherSearchLayoutTests.SwitcherGrid\n"
          + "".join(declaration(switcher_service, prefix).replace("private ", "", 1)
                    for prefix in ["    private var currentPanelSize:", "    var searchTopInset:",
                                   "    private func pinSearch()"])
          + "}\nextension SwitcherSearchLayoutTests.Host {\n"
          + "".join(f"typealias {name} = SwitcherSearchLayoutTests.{name}\n"
                    for name in ["SwitcherGrid", "HUDBackdrop", "SwitcherIconStyle", "SwitcherIconRowSurface"])
          + declaration(switcher, "    var body: some View {", scope="struct SwitcherView: View {")
              .replace("    var body:", "    @ViewBuilder var body:", 1)
          + "".join(declaration(switcher, prefix).replace("private ", "", 1)
                    for prefix in ["    private var standardPanel:", "    private var iconRowPanel:",
                                   "    private var iconRowPanelSize:"])
          + declaration(switcher, "    private var searchChip:").replace("    private var", "    @ViewBuilder var", 1)
          + "}\n")
    service = "Sources/Vorssaint/Services/QuickTools/QuickLauncherService.swift"
    view = "Sources/Vorssaint/UI/QuickLauncher/QuickLauncherView.swift"
    panel_layout = (ROOT / "Sources/Vorssaint/UI/MenuPanel/PanelLayout.swift").read_text()
    protocol = next(line for line in panel_layout.splitlines() if line.startswith("protocol PanelOrderItem:"))
    write("QuickLauncherBodies.swift", "import Foundation\nimport Carbon.HIToolbox\n" + protocol + "\n\nextension QuickLauncherContract {\n"
          + declaration(service, "enum QuickLauncherItem:")
          + "final class Launcher {\nvar isEditing = false\nvar activeUtility: QuickLauncherItem?\n"
          + "var editingOptionsItem: QuickLauncherItem?\nvar selectedIndex: Int?\nvar presentationID = UUID()\n"
          + "var candidates: [QuickLauncherItem] = QuickLauncherItem.allCases\n"
          + "var visibleItems: [QuickLauncherItem] { candidates.filter { $0.feature.isAvailable(in: ReviewDefaults.current) } }\n"
          + 'func hide() { events.append("hide") }\n'
          + availability_declaration(service, "    func run(_ item: QuickLauncherItem)")
          + declaration(service, "    func prepareForPresentation()")
          + availability_declaration(service, "    func refreshAvailability()")
          + declaration(service, "    private func clampSelection()")
          + declaration(service, "    func activateSelection()")
          + declaration(service, "    func activate(at index:")
          + declaration(service, "    func moveSelection(")
          + declaration(service, "    func select(")
          + declaration(service, "    func handlePanelKey(")
          + declaration(service, "    private static func digitIndex(")
          + "}\nstruct Tile {\nvar keepAwake = State()\nvar micMute = State()\nvar recorder = State()\n"
          + declaration(view, "    private func icon(for item: QuickLauncherItem)")
          + declaration(view, "    private func isActive(_ item: QuickLauncherItem)")
          + "func display(_ item: QuickLauncherItem) -> (String, Bool) { (icon(for: item), isActive(item)) }\n}\n}\n")
    # The panel's tabs and the rows they hold, as shipped. PanelOrderItem is
    # declared once, in QuickLauncherBodies.swift above.
    menu_panel = "Sources/Vorssaint/UI/MenuPanel/MenuPanelView.swift"
    write("MenuPanelSectionGates.swift", "import Foundation\n\nextension MenuPanelSectionGateContract {\n"
          + declaration("Sources/Vorssaint/UI/MenuPanel/PanelLayout.swift", "enum PanelSectionID:")
          + "".join(declaration(menu_panel, prefix).replace("private enum", "enum", 1)
                    for prefix in ["private enum UtilityPanelItem:", "private enum ControlPanelItem:"])
          + declaration("Sources/Vorssaint/Services/QuickTools/QuickTogglesService.swift", "enum QuickToggleAction:")
          + "}\n")


    preview = "Sources/Vorssaint/Services/QuickTools/ScreenshotQuickPreviewController.swift"
    screen_text = "Sources/Vorssaint/Services/QuickTools/ScreenTextService.swift"
    write("ScreenTextCompletion.swift", "import Foundation\n"
          + "extension ScreenTextCompletionTests {\nfinal class ScreenTextService: State {\n"
          + "".join(declaration(screen_text, prefix).replace("private func", "func", 1)
                    for prefix in ["    func copyText(", "    func receiveUnifiedCapture(",
                                   "    private func recognize(", "    func syncWithPreferences()",
                                   "    func suspend()", "    private func cancelSession()",
                                   "    enum Outcome:"])
          + "}\n}\n")
    write("ScreenshotOCRControl.swift", "import AppKit\nimport SwiftUI\n"
          + "extension ScreenshotOCRControlTests {\n"
          + declaration(preview, "final class ScreenshotQuickPreviewModel:")
          + declaration(preview, "private struct ScreenshotQuickPreviewView:").replace("private struct", "struct", 1)
          + "enum ScreenshotQuickPreviewController {\n"
          + declaration(preview, "    enum Action {")
          + declaration(preview, "    fileprivate static func size(").replace("fileprivate", "", 1)
          + "}\n}\nextension View {\n"
          + declaration("Sources/Vorssaint/UI/Screenshot/ScreenshotEditorView.swift", "    func screenshotSafeHelp(")
              .replace("    func", "    @ViewBuilder\n    func", 1)
          + "}\n")
    write("ScreenshotShareCompletion.swift", "import Foundation\n"
          + "extension ScreenshotShareCompletionTests {\nfinal class Controller: State {\n"
          + "".join(declaration(preview, prefix).replace("private func", "func", 1)
                    for prefix in ["    func shareLink()", "    private func performShare(",
                                   "    private func copySharedLink()", "    private func scheduleAutoDismiss(",
                                   "    private func copyText()"])
          + "}\nfinal class Editor: EditorState {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/ScreenshotEditorController.swift",
                        "    func share(duration:")
          + "}\n@MainActor final class CreationGate: CreationState {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/ScreenshotShareService.swift",
                        "    func createLink(pngData:")
          + "}\n}\n")
    screenshot_service = "Sources/Vorssaint/Services/QuickTools/ScreenshotService.swift"
    write("ScreenshotAutoCopy.swift", "import Foundation\nextension ScreenshotAutoCopyTests {\n"
          + "@MainActor final class Service: State {\n"
          + declaration(screenshot_service, "    private func autoCopy(").replace("private func", "func", 1)
          + "}\n}\n")
    write("ScreenshotShortcutCompletion.swift", "import Foundation\n"
          + "extension ScreenshotShareCompletionTests {\n@MainActor final class Uploader: UploadState {\n"
          + "".join(declaration(screenshot_service, prefix).replace("private func", "func", 1)
                    .replace("uploadShortcutEnabled()", "uploadShortcutEnabled(in: defaults)")
                    .replace("retainsLatestCapture()", "retainsLatestCapture(in: defaults)")
                    for prefix in ["    private func uploadLastCapture()", "    private func copyUploadedLink(",
                                   "    func openEditor(with", "    func editorDidClose(",
                                   "    private func invalidateLatestCaptureUploads()",
                                   "    private func beginLatestCapture(", "    private func discardLatestCapture(",
                                   "    private func withholdLatestCapture()", "    private func syncLatestCapture(",
                                   "    func afterAutoCopy("])
          + "}\n}\n")
    write("ScreenshotAutoShelf.swift", "import Foundation\n"
          + "extension ScreenshotAutoShelfTests {\n@MainActor final class Service: State {\n"
          + "".join(declaration(screenshot_service, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func autoShelve(", "    private func unshelve(",
                                   "    private func editFromPreview(",
                                   "    private func cancelAutoShelf()"])
          + "}\n}\n")
    write("ScreenshotPreviewHover.swift", "import Foundation\n"
          + "extension ScreenshotPreviewHoverTests {\nfinal class Controller: State {\n"
          + "".join(declaration(preview, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func hoverChanged(", "    private func scheduleAutoDismiss(",
                                   "    private func perform("])
          + "}\n}\n")
    editor = "Sources/Vorssaint/Services/QuickTools/ScreenshotEditorController.swift"
    editor_view = "Sources/Vorssaint/UI/Screenshot/ScreenshotEditorView.swift"
    write("ScreenshotSpotlightEditing.swift", "import CoreGraphics\nimport Foundation\nimport SwiftUI\n"
          + "extension ScreenshotSpotlightEditingTests {\nfinal class Model: State {\n"
          + declaration(editor, "    @Published var spotlightDimStrength: CGFloat {")
          .replace("@Published var", "override var", 1)
          + "".join(declaration(editor, prefix).replace("private func", "func", 1)
                    for prefix in ["    func beginDrag(at point:", "    func selectedAnnotationOwns(",
                                   "    func hitTest(", "    private func refreshDirtyState()"])
          + "}\nstruct Bar {\nlet model: Model\n"
          + "".join(declaration(editor_view, prefix).replace("private var", "var", 1)
                    for prefix in ["    private var showsColorControls:",
                                   "    private var showsSpotlightControls:",
                                   "    private var spotlightDimValue:"])
          + declaration(editor_view, "    private func updateHoverCursor(").replace("private func", "func", 1)
          + "}\n}\n")
    selection = "Sources/Vorssaint/Services/QuickTools/ScreenshotSelectionController.swift"
    refresh_methods = [
        "    private func screenCaptureToolDidChange()",
        "    private func adoptCapturePolicy(",
        "    private func applySource(",
        "    private func loadLiveLoupeImages()",
        "    private func markCapturePending()",
        "    private func confirmSelectionWithKeyboard()",
        "    private func captureFullDisplayUnderMouse()",
        "    fileprivate func captureFullScreenFromControl(",
        "    private func captureFullDisplay(",
        "    private func repeatLastRegion()",
        "    fileprivate func confirmWindow(",
        "    fileprivate func confirmRegion(",
        "    fileprivate func confirmColor(",
    ]
    write("ScreenshotSelectionRefresh.swift", "import Foundation\nimport AppKit\nimport SwiftUI\n"
          + "extension ScreenshotSelectionRefreshContract.Chooser {\n"
          + declaration(selection, "    fileprivate func setSelectionInProgress(").replace("fileprivate func", "func", 1)
          + declaration(selection, "    fileprivate var acceptsCaptureInput:").replace("fileprivate var", "var", 1)
          + declaration(selection, "    fileprivate var offersFullScreenCapture:").replace("fileprivate var", "var", 1)
          + declaration(selection, "    fileprivate var acceptsWindowClick:").replace("fileprivate var", "var", 1)
          + declaration(selection, "    private var repeatTargetPanel:").replace("private var", "var", 1)
          + declaration(selection, "    fileprivate var offersRepeatLastRegion:").replace("fileprivate var", "var", 1)
          + "".join(declaration(selection, prefix).replace("fileprivate func", "func", 1)
                    .replace("private func", "func", 1).replace("UserDefaults.standard", "ReviewDefaults.current")
                    for prefix in refresh_methods)
          + "}\nextension ScreenshotSelectionRefreshContract.View {\n"
          + declaration(selection, "    func captureToolDidChange()")
          + declaration(selection, "    func refreshFullScreenControlVisibility()")
          + declaration(selection, "    private func pointerIsOverFullScreenControl(").replace("private func", "func", 1)
          + declaration(selection, "    private func updatePointerHover(").replace("private func", "func", 1)
          + "}\n"
          + declaration(selection, "private final class PassThroughHostingView<")
              .replace("private final class", "final class", 1))
    hop = "Sources/Vorssaint/Services/Switcher/SpaceHop.swift"
    write("PointerOnDisplay.swift", "import AppKit\n"
          + "extension PointerOnDisplayContract.Bridge {\n"
          + declaration("Sources/Vorssaint/Services/Switcher/SpaceWindowBridge.swift", "    struct Topology {")
          + "}\nextension PointerOnDisplayContract.Hop {\n"
          + "".join(declaration(hop, prefix).replace("private ", "", 1)
                    for prefix in ["    private enum TravelOutcome {", "    private func start() {",
                                   "    private func stepWithSpaceShortcut()"])
          + "}\nextension PointerOnDisplayContract.Overlay {\n"
          + declaration(selection, "    func refreshGuideVisibility()")
          + "}\nextension PointerOnDisplayContract.Dock {\n"
          + declaration(dock, "    private func isNearDock(").replace("private func", "func", 1)
          + "}\n")




    brightness_row = "Sources/Vorssaint/UI/MenuPanel/BrightnessSection.swift"
    write("SoftwareDimmingRow.swift", "import CoreGraphics\nimport Foundation\n\n"
          + "extension SoftwareDimmingRouteContract {\n"
          + "final class Row {\nvar display = Display()\nvar chosen = false\nvar compact = false\n"
          + declaration(brightness_row, "    private var offered:").replace("private var", "var", 1)
          + "}\n}\n")

    brightness = "Sources/Vorssaint/Services/Display/BrightnessService.swift"
    write("SoftwareDimmingRoute.swift", "import CoreGraphics\nimport Foundation\n\n"
          + "extension SoftwareDimmingRouteContract {\n"
          + "final class Service {\nlet stateLock = NSLock()\nlet workQueue = Queue()\n"
          + "static let log = Log()\n"
          + "var routes: [CGDirectDisplayID: Route] = [:]\n"
          + "var lastApplied: [CGDirectDisplayID: Double] = [:]\n"
          + "var levelKnownAt: [CGDirectDisplayID: Foundation.Date] = [:]\n"
          + "var pendingLevels: [CGDirectDisplayID: Double] = [:]\n"
          + "var softwareDims: [(id: CGDirectDisplayID, value: Double)] = []\n"
          + "struct GammaTable { var red: [CGGammaValue] = [1]; var green: [CGGammaValue] = [1]; "
          + "var blue: [CGGammaValue] = [1]; var count: UInt32 = 1; var fingerprint: String }\n"
          + "var gammaBaselines: [CGDirectDisplayID: GammaTable] = [:]\n"
          + "var dimmedDisplays = Set<CGDirectDisplayID>()\n"
          + "var softwareSucceeds = true\nvar ddcSucceeds = true\nvar events: [String] = []\n"
          + "var forgottenWriteOnlyPaths: [String] = []\nvar refreshes = 0\n"
          + "static func displayFingerprint(_ id: CGDirectDisplayID) -> String { \"display-\\(id)\" }\n"
          + "func CGSetDisplayTransferByTable(_ id: CGDirectDisplayID, _ count: UInt32, "
          + "_ red: [CGGammaValue], _ green: [CGGammaValue], _ blue: [CGGammaValue]) { "
          + "events.append(\"restore:\\(id)\") }\n"
          + "func forgetWriteOnlyDDCPath(_ path: String?) { forgottenWriteOnlyPaths.append(path ?? \"\") }\n"
          + "@discardableResult func applySoftwareDim(_ id: CGDirectDisplayID, value: Double) -> Bool {\n"
          + "softwareDims.append((id, value)); events.append(\"picture:\\(value)\")\n"
          + "if softwareSucceeds { if value >= 0.999 { dimmedDisplays.remove(id) } else { dimmedDisplays.insert(id) } }\n"
          + "return softwareSucceeds\n}\n"
          + "func ddcSend(to id: CGDirectDisplayID, service: CFTypeRef, packet: [UInt8]) -> Bool {\n"
          + "let value = UInt16(packet[3]) << 8 | UInt16(packet[4])\n"
          + "events.append(\"ddc:\\(value)\"); return ddcSucceeds\n}\n"
          + "func refresh(force: Bool = false) { refreshes += 1 }\n"
          + declaration(brightness, "    func setSoftwareDimmingPreferred(")
          + declaration(brightness, "    func setExtendedDimmingPreferred(")
          + declaration(brightness, "    private func restoreAllGamma(").replace("private func", "func", 1)
          + declaration(brightness, "    private func writeExtendedBrightness(").replace("private func", "func", 1)
          + "}\n}\n")

    keep_awake = "Sources/Vorssaint/Services/KeepAwakeManager.swift"
    keep_awake_methods = [
        "    func refreshPasswordlessStatus(",
        "    func activate(minutes:",
        "    func activate(until date:",
        "    func startLastPick(",
        "    func resumeAfterSystemTeardown(",
        "    private func activate(end:",
        "    func deactivate(reason:",
        "    private func applyClamshellPreference(",
        "    private func prepareClamshellPreference(",
        "    private func finishClamshellSetup(",
        "    private func markClamshellSetupFailed(",
        "    private func enableClamshell(",
        "    private func disableClamshell(",
        "    private func sleepIfLidAlreadyClosed(",
        "    func recoverIfNeeded(",
        "    private func finishRecovery(",
        "    private var clamshellNeedsRestore:",
        "    private func finishClamshellRestore(",
        "    private func recoverDimmedDisplayIfNeeded(",
        "    private func syncLidDimmingObserver(",
        "    private func lidStateMayHaveChangedForDimming(",
        "    private func applyDimmingAction(",
        "    private func attemptDisplayRestore(",
    ]
    write("KeepAwakeLidSleep.swift", "import Foundation\nimport os\n\nextension KeepAwakeLidSleepContract {\n"
          # The extracted dimming bodies unwrap `Unmanaged<KeepAwakeManager>`
          # for the IOKit callback's context; this makes that name resolve to
          # the fixture's own class instead of leaving it undefined.
          + "typealias KeepAwakeManager = Service\n"
          + "final class Service {\n"
          + "static let log = Logger(subsystem: \"vorssaint.tests\", category: \"keep-awake\")\n"
          + "var isActive = false\nvar sessionPausedForScreenLock = false\n"
          + "var isTerminating = false\nvar clamshellEnablePending = false\nvar clamshellRestorePending = false\n"
          + "var clamshellOperationGeneration = 0\nvar clamshellSetupID: UUID?\n"
          + "var lidSleepGeneration = 0\nvar lidSleepAttemptsRemaining = 0\n"
          + "var clamshellSetupInProgress = false\nvar clamshellSetupFailed = false\n"
          + "var clamshellSetupRetried = false\nvar passwordlessClamshell = true\n"
          + "var recoveryCompleted = false\nvar screenLocked = false\nvar assertionsHeld = false\n"
          + "var automationSuppressedUntilConditionsClear = false\n"
          + "var endTimer: Timer?\nvar endDate: Date?\nvar sessionTrigger: SessionTrigger?\nvar sessionMinutes: Int?\n"
          + "var activeAutomationConditions = Set<KeepAwakeAutomationCondition>()\n"
          + "var onSessionEnded: ((EndReason) -> Void)?\n"
          + "var lidDimmingNotificationPort: IONotificationPortRef?\nvar lidDimmingNotification: io_object_t = 0\n"
          + "var lidClosedForDimming: Bool?\nvar savedDisplayBrightness: Double?\n"
          + declaration(keep_awake, "    @Published private(set) var clamshellActive = false {")
                .replace("@Published private(set) ", "", 1)
          + declaration(keep_awake, "    @Published var clamshellPreferred:").replace("@Published ", "", 1)
          + declaration(keep_awake, "    @Published var dimScreenOnLidClose: Bool {").replace("@Published ", "", 1)
          + "init() { clamshellPreferred = true; dimScreenOnLidClose = false }\n"
          + "func syncScreenLockMonitoring() {}\nfunc applyAssertions() { assertionsHeld = true }\n"
          + "func releaseAssertions() { assertionsHeld = false }\nfunc scheduleEnd(at date: Date) {}\n"
          + "func startBatteryWatch() {}\nfunc stopBatteryWatch() {}\nfunc syncMouseJiggleTimer() {}\n"
          + "func stopMouseJiggleTimer() {}\nfunc stopAutomationMonitoring() {}\nfunc syncWithPreferences() {}\n"
          + "static func lidSleepIsAllowed() -> Bool { KeepAwakeAutomationSupport.lidSleepIsAllowed("
          + "systemAllowsSleep: policy, assertions: assertions) }\n"
          + "".join(declaration(keep_awake, prefix).replace("private ", "", 1) for prefix in keep_awake_methods)
          + "}\n}\n"
          + "extension KeepAwakeLidSleepContract.Sudoers {\n"
          + declaration("Sources/Vorssaint/Services/ShellSupport.swift", "    static func isConfigured()")
          + declaration("Sources/Vorssaint/Services/ShellSupport.swift", "    static func restoreSleepWithAuthorization(")
          + "}\n")
    write("KeepAwakeTimerHandoff.swift", "import Foundation\n\nextension KeepAwakeTimerHandoffContract {\n"
          + "final class Service {\nvar sessionTrigger = SessionTrigger.manual\n"
          + "var automationSuppressedUntilConditionsClear = false\n"
          + "var activeAutomationConditions: Set<KeepAwakeAutomationCondition> = []\n"
          + "var enabled: Set<KeepAwakeAutomationCondition> = []\n"
          + "var matching: Set<KeepAwakeAutomationCondition> = []\n"
          + "var requireAll = false\nvar batteryAllows = true\n"
          + "var activations: [(end: Date?, trigger: SessionTrigger)] = []\n"
          + "func automaticSessionAllowedByBatteryProtection() -> Bool { batteryAllows }\n"
          + "func currentMatchingAutomationConditions() -> Set<KeepAwakeAutomationCondition> { matching }\n"
          + "func currentEnabledAutomationConditions() -> Set<KeepAwakeAutomationCondition> { enabled }\n"
          + "func automationRequiresAllConditions() -> Bool { requireAll }\n"
          + "func activate(end: Date?, trigger: SessionTrigger) { activations.append((end, trigger)) }\n"
          + declaration(keep_awake, "    private func continueAutomaticallyAfterTimerIfNeeded()")
            .replace("private func", "func", 1)
          + "}\n}\n")

    spaces_order = "Sources/Vorssaint/Services/SpacesOrder/SpacesOrderHold.swift"
    write("SpacesOrderRequests.swift", "import Foundation\nimport os\n"
          + "extension SpacesOrderRequestContract {\nfinal class Host: Fixture {\n"
          + "".join(declaration(spaces_order, prefix).replace("private ", "", 1)
                    .replace(", privacy: .public", "")
                    .replace("    func saveJournal(", "    @discardableResult\n    func saveJournal(", 1)
                    for prefix in [
              "    private func newRequest()", "    private func currentRequest()",
              "    private func awaitingLetGoPersistence()", "    private static func isOwed(",
              "    private var journal:", "    private func heldJournal(",
              "    func syncWithPreferences()", "    func letGoIfRearrangingReturned()",
              "    private func letGoIfRearrangingReturnedOnQueue(", "    func restoreForRemoval()",
              "    func reconcile(wanted:", "    private func reconcileOnQueue(",
              "    private func letGo(generation:", "    private func apply(",
              "    private func saveMarker(", "    private func clearMarker()",
              "    private func saveJournal("])
          + "}\n}\n")

    self_uninstall = "Sources/Vorssaint/Services/SelfUninstall.swift"
    write("SelfUninstallRemoval.swift", "import Foundation\n\nextension SelfUninstallContract {\nenum Host {\n"
          + "static let bundleID = \"test\"\n"
          + "static func suspendInputInterceptors() -> Bool { events.append(\"suspend\"); return suspensionAllowed }\n"
          + "static func restoreSleepBeforeRemoval() -> Bool { events.append(\"sleep\"); return sleepRestoreAllowed }\n"
          + "static func detachLoginItem() { events.append(\"login\") }\n"
          + "static func removePreferences() { events.append(\"preferences\") }\n"
          + "static func trashOwnBundleAndQuit() { events.append(\"trash\") }\n"
          + declaration(self_uninstall, "    static func clearPermissions(")
          + declaration(self_uninstall, "    static func uninstallCompletely(")
          + declaration(self_uninstall, "    private static func removeSudoersRuleIfPresent(")
          + declaration(self_uninstall, "    private static func resetTCC(")
            .replace("private static", "@discardableResult static", 1)
          + "}\n}\n")


    window_directional = "Sources/Vorssaint/Services/WindowLayout/WindowLayoutService.swift"
    window_maximizer = "Sources/Vorssaint/Services/WindowMaximizer.swift"
    write("WindowStageManagerMaximizer.swift", "import AppKit\nimport CoreGraphics\n"
          + "extension WindowStageManagerMaximizerTests {\n"
          + declaration(window_maximizer, "private struct AXFrame:").replace("private ", "", 1)
          + "final class Host: Fixture {\n"
          + declaration(window_maximizer, "    private func toggle(").replace("private ", "", 1)
          + declaration(window_maximizer, "    private func axFrame(")
          + "}\n}\n")
    window_gesture = "Sources/Vorssaint/Services/WindowLayout/WindowGestureSupport.swift"
    write("WindowEdgeSnapRuntime.swift", "import AppKit\nimport CoreGraphics\nimport Foundation\n"
          + "extension WindowEdgeSnapRuntimeTests {\n"
          + "".join(declaration(window_directional, prefix).replace("private ", "", 1)
                    for prefix in ["private enum WindowEdgeSnapPointerInput {",
                                   "private struct WindowEdgeSnapDrag {",
                                   "private struct WindowLayoutTarget {",
                                   "private struct WindowPointerGesture {",
                                   "private struct PendingWindowGesture {",
                                   "private struct WindowGestureTarget {"])
          + "final class Host: Fixture {\n"
          + "".join(declaration(window_directional, prefix).replace("private ", "", 1)
                    .replace("AXIsProcessTrusted()", "WindowEdgeSnapRuntimeTests.accessibilityGranted")
                    for prefix in [
              "    private func observeEdgeSnapEvent(",
              "    private static func seconds(of event: CGEvent)",
              "    private func handleEdgeSnapInput(",
              "    private func applyDelayedEdgeSnapIfMoved(",
              "    private func edgeSnapWindowFollowed(",
              "    private func beginEdgeSnapResolve(",
              "    private func resolveEdgeSnapWindow(",
              "    private func makeEdgeSnapDrag(",
              "    private func updateEdgeSnapDrag(",
              "    private func edgeSnapTarget(",
              "    private var edgeSnapLayout:",
              "    private func scheduleEdgeSnapStillCheck()",
              "    private func armEdgeSnapStillCheck(",
              "    private func resetEdgeSnapTrail()",
              "    private func applyEdgeSnap(",
              "    private func cancelEdgeSnapTracking()",
              "    private var edgeSnapCanTrack:",
              "    private func forwardToEdgeSnap(",
              "    private var gestureState:",
              "    private var trackedGestureButton:",
              "    private func handleGestureEvent(",
              "    private func gestureChord(",
              "    private func arm(",
              "    private func promote("])
          + "}\n}\n")
    write("WindowGestureApplyRuntime.swift", "import AppKit\nimport CoreGraphics\nimport Foundation\n"
          + "extension WindowGestureApplyRuntimeTests {\n"
          + declaration(window_directional, "private struct WindowPointerGesture {").replace("private ", "", 1)
          + "final class Host: Fixture {\n"
          + "".join(declaration(window_directional, prefix).replace("private ", "", 1)
                    for prefix in [
              "    private func enqueueGestureApply(",
              "    private func drainGestureApplies()",
              "    private func flushGestureApplies()"])
          + "}\n}\n")
    write("WindowDirectionalModifierRuntime.swift", "import AppKit\nimport CoreGraphics\nimport Foundation\n"
          + "extension WindowDirectionalModifierRuntimeTests {\n"
          + "".join(declaration(window_gesture, prefix) for prefix in [
              "struct WindowDirectionalModifierButtons {",
              "struct WindowDirectionalModifierPointerSnapshot:",
              "enum WindowDirectionalModifierStartupOutcome<Value> {",
              "enum WindowDirectionalModifierStartupGuard {"])
          + declaration(window_directional, "private struct WindowDirectionalSession {").replace("private ", "", 1)
          + "final class Host: Fixture {\n"
          + "".join(declaration(window_directional, prefix).replace("private ", "", 1)
                    .replace("AXIsProcessTrusted()", "WindowDirectionalModifierRuntimeTests.accessibilityGranted")
                    .replace("CGEvent.tapEnable(", "tapEnable(")
                    for prefix in [
              "    private func observeDirectionalModifierEvent(",
              "    private func beginDirectionalGesture(",
              "    private func updateDirectionalGesture(",
              "    private func finishDirectionalGesture()",
              "    private func cancelDirectionalGesture("])
          + "}\n}\n")

    factories = []
    pattern = r"static\s+func\s+(\w+)\s*\(\s*_\s+\w+:\s*AppLanguage\s*\)\s*->"
    for path in sorted((ROOT / "Sources/Vorssaint/Core").glob("*Strings.swift")):
        source = path.read_text()
        if "extension FeatureStrings" in source or "enum FeatureStrings" in source:
            scopes = re.findall(r"(?:extension|enum) FeatureStrings \{(.*?)^\}", source, re.S | re.M)
            names = [name for scope in scopes for name in re.findall(pattern, scope)]
            if not names:
                raise ValueError(f"No language factory found in {path}")
            factories.extend(names)
    if not factories or len(factories) != len(set(factories)):
        raise ValueError("Missing or duplicate localization factories")
    write("LocalizationCatalog.swift", "extension LocalizationTests {\n"
          + "static let factories: [(String, (AppLanguage) -> Any)] = [\n"
          + "".join(f'("{name}", {{ FeatureStrings.{name}($0) }}),\n' for name in factories)
          + "]\n}\n")

    screens = "Sources/Vorssaint/Core/AppKitExtensions.swift"
    bridge = "Sources/Vorssaint/Services/Switcher/SpaceWindowBridge.swift"
    write("PointerDisplayLookups.swift", "import AppKit\nimport Carbon.HIToolbox\nimport QuartzCore\n"
          + "extension PointerDisplayLookupContract.Screen {\n"
          + declaration(screens, "    static var withMouse:")
          + declaration(screens, "    static var withMenuBar:")
          + "}\nextension PointerDisplayLookupContract.Capturer {\n"
          + declaration("Sources/Vorssaint/Services/QuickTools/ScreenshotService.swift",
                        "    private func beginFullScreenCapture()").replace("private func", "func", 1)
          + "}\nextension PointerDisplayLookupContract.Bridge {\n"
          + declaration(bridge, "    struct Topology {")
          + declaration(bridge, "    static func visibleSpace(near")
          + "}\nextension PointerDisplayLookupContract.Layout {\n"
          + declaration("Sources/Vorssaint/Services/WindowLayout/WindowLayoutService.swift",
                        "    private func showDirectionalIndicator(").replace("private func", "func", 1)
          + "}\nextension PointerDisplayLookupContract.HUD {\n"
          + declaration("Sources/Vorssaint/UI/QuitProtection/QuitProtectionHUD.swift",
                        "    private func positionPanel(").replace("private func", "func", 1)
          + "}\nextension PointerDisplayLookupContract.Chooser {\n"
          + "".join(declaration(selection, prefix).replace("private func", "func", 1)
                    for prefix in ["    private func nudgePointer(", "    private func panelUnderMouse()"])
          + "}\nextension PointerDisplayLookupContract.Dock {\n"
          + declaration(dock, "    func endWindowDrag(")
          + "}\n")


    write("ScrollingTitleMotion.swift", "import Foundation\n"
          + "extension ScrollingTitleMotionTests {\nfinal class Host: Fixture {\n"
          + declaration("Sources/Vorssaint/UI/Switcher/ScrollingTitle.swift",
                        "    private var shouldScroll:").replace("private var", "var", 1)
          + "}\n}\n")






    # Same-file extensions exercise private routing and AppKit content without
    # widening production interfaces or presenting an application window.
    service = "Sources/Vorssaint/Services/QuitProtection/QuitProtectionService.swift"
    checks = "Tests/Fixtures/QuitProtectionRoutingChecks.swift"
    write("QuitProtectionRouting.swift", "import AppKit\nimport ApplicationServices\nimport Combine\n"
          + "extension QuitProtectionRoutingContract {\n"
          + declaration(service, "final class QuitProtectionService:")
          + "}\n" + f'#sourceLocation(file: {json.dumps(checks)}, line: 1)\n'
          + (ROOT / checks).read_text() + "\n#sourceLocation()\n")
    hud = "Sources/Vorssaint/UI/QuitProtection/QuitProtectionHUD.swift"
    checks = "Tests/Fixtures/QuitProtectionHUDChecks.swift"
    write("QuitProtectionHUDBodies.swift",
          f'#sourceLocation(file: {json.dumps(hud)}, line: 1)\n'
          + (ROOT / hud).read_text() + "\n"
          + f'#sourceLocation(file: {json.dumps(checks)}, line: 1)\n'
          + (ROOT / checks).read_text() + "\n#sourceLocation()\n")


if __name__ == "__main__":
    main()
