// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import CoreAudio
import Foundation

/// Actual mixer methods run against an in-memory audio device. No output
/// device, volume, mute state or event tap is touched.
enum MixerOutputAdjustmentContract {
    enum Hardware {
        struct Write: Equatable {
            let device: AudioObjectID
            let volume: Float?
            let muted: Bool?
        }
        static var device: AudioObjectID = 1
        static var writes: [Write] = []
        static var succeeds = true
        static var muted: Bool? = false
    }

    static func run(_ suite: TestSuite) {
        func make() -> Mixer {
            Hardware.device = 1
            Hardware.writes = []
            Hardware.succeeds = true
            Hardware.muted = false
            let mixer = Mixer()
            mixer.selectOutput(1, volume: 0.2, muted: false)
            return mixer
        }

        // The menu bar panel's slider and the command bar's volume write the
        // level and the switch directly.
        var mixer = make()
        suite.expect(mixer.setCurrentOutputVolume(0)
                     && Hardware.writes == [.init(device: 1, volume: 0, muted: nil),
                                            .init(device: 1, volume: nil, muted: true)]
                     && mixer.systemOutputVolume == 0 && mixer.systemOutputMuted == true,
                     "the panel's slider at zero mutes the output and publishes it")
        Hardware.writes = []
        suite.expect(mixer.setCurrentOutputVolume(0.3)
                     && Hardware.writes == [.init(device: 1, volume: 0.3, muted: nil),
                                            .init(device: 1, volume: nil, muted: false)]
                     && mixer.systemOutputMuted == false,
                     "the panel's slider above zero unmutes the output")

        mixer = make()
        Hardware.muted = nil
        mixer.selectOutput(1, volume: 0.2, muted: nil)
        suite.expect(mixer.setCurrentOutputVolume(0)
                     && Hardware.writes == [.init(device: 1, volume: 0, muted: nil)]
                     && mixer.systemOutputMuted == nil,
                     "the panel's slider at zero invents no mute state for an output without a mute switch")

        mixer = make()
        suite.expect(mixer.setCurrentOutputVolume(0.004)
                     && Hardware.writes == [.init(device: 1, volume: 0.004, muted: nil),
                                            .init(device: 1, volume: nil, muted: true)]
                     && mixer.systemOutputMuted == true,
                     "the panel's slider at a level the labels show as 0% mutes the output")

        mixer = make()
        suite.expect(mixer.setCurrentOutputVolume(0.005)
                     && Hardware.writes == [.init(device: 1, volume: 0.005, muted: nil),
                                            .init(device: 1, volume: nil, muted: false)]
                     && mixer.systemOutputMuted == false,
                     "the panel's slider at the first level the labels show as 1% keeps the output audible")

        mixer = make()
        Hardware.succeeds = false
        suite.expect(!mixer.setCurrentOutputVolume(0.6) && mixer.listenerRefreshes == 1
                     && mixer.systemOutputVolume == 0.2,
                     "a refused write keeps the published level and asks the output again")
        Hardware.succeeds = true

        _ = make()
        suite.expect(Mixer.setSystemOutputVolume(0)
                     && Hardware.writes == [.init(device: 1, volume: 0, muted: nil),
                                            .init(device: 1, volume: nil, muted: true)],
                     "the command bar's volume 0 mutes the output")
        Hardware.writes = []
        suite.expect(Mixer.setSystemOutputVolume(0.25)
                     && Hardware.writes == [.init(device: 1, volume: 0.25, muted: nil),
                                            .init(device: 1, volume: nil, muted: false)],
                     "the command bar's volume above zero unmutes the output")
        Hardware.writes = []
        Hardware.succeeds = false
        suite.expect(!Mixer.setSystemOutputVolume(0)
                     && Hardware.writes == [.init(device: 1, volume: 0, muted: nil),
                                            .init(device: 1, volume: nil, muted: true)],
                     "the command bar's volume 0 still mutes an output that refuses the level")
        Hardware.succeeds = true
    }
}
