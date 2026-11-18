// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import CoreGraphics
import Foundation

/// Runs the volume tap's production monitor routing against the in-memory
/// mixer and display. The tap's feedback is recorded instead of shown.
enum MonitorVolumeRoutingTests {
    typealias DispatchQueue = MixerOutputAdjustmentContract.DispatchQueue
    enum AppVolumeMixer {
        typealias OutputKeyResult = MixerOutputAdjustmentContract.Mixer.OutputKeyResult
        static var shared = MixerOutputAdjustmentContract.Mixer()
    }
    enum UserDefaults {
        static let standard = UserDefaults.self
        static var precise = false
        static func bool(forKey key: String) -> Bool {
            key == DefaultsKey.preciseVolumeRollerEnabled && precise
        }
    }
    enum AppFeature {
        case mixer
        static var mixerAvailable = true
        var isAvailable: Bool { Self.mixerAvailable }
    }
    /// The levels the brightness overlay would show, zero while muted.
    enum Feedback {
        static var shownLevels: [Double] = []
    }
    struct NSEvent {
        struct Subtype { let rawValue = 8 }
        let subtype = Subtype()
        let data1: Int
    }
    typealias BrightnessService = DisplaySpeakerVolumeTests.Service
    class State {
        var monitorVolumeKeysHeld: [BrightnessSupport.VolumeKeyAction: BrightnessSupport.SpeakerTarget] = [:]
        var gate = PreciseVolumeRollerGate()
        var feedbackStep = 0
        var feedback: (key: Int32, step: Int, applied: Bool, released: Bool)?
        var clicks = 0
        func playFeedbackIfReady() {
            guard let feedback, feedback.applied, feedback.released else { return }
            self.feedback = nil
            clicks += 1
        }
        static func showMonitorFeedback() {
            let mixer = AppVolumeMixer.shared
            guard let level = mixer.systemOutputVolume else { return }
            Feedback.shownLevels.append(mixer.systemOutputMuted == true ? 0 : level)
        }
    }
}
