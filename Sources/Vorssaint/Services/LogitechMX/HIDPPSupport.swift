// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// The pure half of Logitech's HID++ 2.0 protocol, as far as the MX Master
/// extension needs it: packet layout, the feature pages it talks to, and the
/// decoders for every reply and event. Nothing here touches IOKit, so the
/// byte layouts are pinned by tests against real MX Master 4 replies.
///
/// A packet is `[report ID, device index, feature index, function | swID,
/// parameters…]`. A request carries a software ID in the low nibble; the
/// device echoes it in the reply. Unsolicited events use software ID 0, which
/// is how a reply is told apart from a notification.
enum HIDPP {
    static let logitechVendorID = 0x046D
    static let shortReportID: UInt8 = 0x10
    static let longReportID: UInt8 = 0x11
    static let longReportLength = 20
    /// Usage page and usage of a receiver's (Bolt, Unifying) long HID++
    /// collection.
    static let receiverUsagePage = 0xFF00
    static let receiverUsage = 0x0002
    /// Usage page and usage of the HID++ collection of a mouse paired
    /// straight over Bluetooth. macOS lists it only among the device's usage
    /// pairs: the device's primary usage is the keyboard collection.
    static let bluetoothUsagePage = 0xFF43
    static let bluetoothUsage = 0x0202

    /// How one HID device carries HID++, decided from all its usage pairs
    /// rather than the primary usage alone.
    enum Interface: Equatable {
        case receiver
        case direct
    }

    static func interface(usagePairs: [(page: Int, usage: Int)]) -> Interface? {
        if usagePairs.contains(where: { $0.page == receiverUsagePage && $0.usage == receiverUsage }) {
            return .receiver
        }
        if usagePairs.contains(where: { $0.page == bluetoothUsagePage && $0.usage == bluetoothUsage }) {
            return .direct
        }
        return nil
    }
    /// A device paired straight to the Mac answers on this index; a receiver
    /// numbers its paired devices 1 through 6.
    static let directDeviceIndex: UInt8 = 0xFF
    static let receiverDeviceIndices: [UInt8] = [1, 2, 3, 4, 5, 6]
    /// Logi Options+ uses 0xA. Any other non-zero value keeps the replies of
    /// both programs apart when both have the device open.
    static let softwareID: UInt8 = 0x06

    /// HID++ 2.0 feature pages. The device maps each to a per-device index,
    /// asked once through the root feature.
    enum Feature: UInt16, CaseIterable {
        case root = 0x0000
        case deviceName = 0x0005
        case batteryStatus = 0x1000
        case unifiedBattery = 0x1004
        case wirelessDeviceStatus = 0x1D4B
        case haptic = 0x19B0
        case forceSensingButton = 0x19C0
        case reprogControls = 0x1B04
        case smartShift = 0x2110
        case smartShiftEnhanced = 0x2111
        case hiResWheel = 0x2121
        case thumbWheel = 0x2150
        case adjustableDPI = 0x2201
    }

    // MARK: - Packets

    static func request(deviceIndex: UInt8, featureIndex: UInt8, function: UInt8,
                        parameters: [UInt8] = []) -> [UInt8] {
        var packet: [UInt8] = [longReportID, deviceIndex, featureIndex,
                               (function << 4) | (softwareID & 0x0F)]
        packet += parameters.prefix(longReportLength - 4)
        packet += Array(repeating: 0, count: longReportLength - packet.count)
        return packet
    }

    /// What one input report is to this program.
    enum Message: Equatable {
        /// A reply to a request carrying our software ID.
        case reply(deviceIndex: UInt8, featureIndex: UInt8, function: UInt8, payload: [UInt8])
        /// A HID++ 2.0 error for one of our requests.
        case error(deviceIndex: UInt8, featureIndex: UInt8, function: UInt8, code: UInt8)
        /// The receiver could not reach that index (HID++ 1.0 error).
        case unreachable(deviceIndex: UInt8)
        /// An unsolicited event from a feature (software ID 0).
        case event(deviceIndex: UInt8, featureIndex: UInt8, event: UInt8, payload: [UInt8])
        /// A receiver saying a device connected or dropped its link.
        case connection(deviceIndex: UInt8, linkEstablished: Bool)
        /// Someone else's traffic, or a report this program has no use for.
        case ignored
    }

    static func classify(_ report: [UInt8]) -> Message {
        guard report.count >= 4 else { return .ignored }
        let reportID = report[0], index = report[1], subID = report[2], address = report[3]
        guard reportID == shortReportID || reportID == longReportID else { return .ignored }
        let payload = Array(report.dropFirst(4))
        if subID == 0x8F {
            // HID++ 1.0 error: [10, index, 8F, sub, address, code, 0]. Only
            // ours matter, and the receiver echoes the software ID it got.
            guard let echoed = payload.first, echoed & 0x0F == softwareID else { return .ignored }
            return .unreachable(deviceIndex: index)
        }
        if subID == 0x41, reportID == shortReportID {
            // Device connection: [10, index, 41, protocol, info, wpid…].
            // Bit 6 of the info byte means the link is NOT established.
            let linkLost = (payload.first ?? 0) & 0x40 != 0
            return .connection(deviceIndex: index, linkEstablished: !linkLost)
        }
        if subID == 0xFF {
            guard payload.count >= 2, payload[0] & 0x0F == softwareID else { return .ignored }
            return .error(deviceIndex: index, featureIndex: address,
                          function: payload[0] >> 4, code: payload[1])
        }
        let swID = address & 0x0F
        if swID == softwareID {
            return .reply(deviceIndex: index, featureIndex: subID, function: address >> 4, payload: payload)
        }
        if swID == 0 {
            return .event(deviceIndex: index, featureIndex: subID, event: address >> 4, payload: payload)
        }
        return .ignored
    }

    static func uint16(_ bytes: [UInt8], at offset: Int) -> UInt16? {
        guard offset >= 0, bytes.count >= offset + 2 else { return nil }
        return UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    static func int16(_ bytes: [UInt8], at offset: Int) -> Int16? {
        uint16(bytes, at: offset).map { Int16(bitPattern: $0) }
    }

    static func bytes(_ value: UInt16) -> [UInt8] {
        [UInt8(value >> 8), UInt8(value & 0xFF)]
    }

    // MARK: - Root and name

    /// Root function 0 answers the index of a feature page, 0 meaning absent.
    static func featureIndex(fromRootReply payload: [UInt8]) -> UInt8? {
        guard let index = payload.first, index != 0 else { return nil }
        return index
    }

    /// Name chunks arrive NUL padded; the whole name is their concatenation.
    static func nameChunk(_ payload: [UInt8], remaining: Int) -> String {
        let chunk = payload.prefix(max(0, min(remaining, payload.count))).prefix { $0 != 0 }
        return String(decoding: chunk, as: UTF8.self)
    }

    // MARK: - Reprogrammable controls (0x1B04)

    struct ControlFlags: OptionSet, Hashable {
        let rawValue: UInt16
        static let mouseButton = ControlFlags(rawValue: 0x0001)
        static let reprogrammable = ControlFlags(rawValue: 0x0010)
        static let divertable = ControlFlags(rawValue: 0x0020)
        static let persistentlyDivertable = ControlFlags(rawValue: 0x0040)
        static let virtual = ControlFlags(rawValue: 0x0080)
        static let rawXY = ControlFlags(rawValue: 0x0100)
        static let forceRawXY = ControlFlags(rawValue: 0x0200)
    }

    struct ControlInfo: Equatable {
        let controlID: UInt16
        let taskID: UInt16
        let flags: ControlFlags
    }

    /// getCidInfo: cid(2) tid(2) flags(1) position(1) group(1) groupMask(1)
    /// additionalFlags(1). The additional byte is the high half of the flags.
    static func controlInfo(_ payload: [UInt8]) -> ControlInfo? {
        guard payload.count >= 9, let cid = uint16(payload, at: 0), let tid = uint16(payload, at: 2),
              cid != 0 else { return nil }
        let flags = UInt16(payload[4]) | UInt16(payload[8]) << 8
        return ControlInfo(controlID: cid, taskID: tid, flags: ControlFlags(rawValue: flags))
    }

    struct ControlReporting: Equatable {
        let controlID: UInt16
        let diverted: Bool
        let rawXY: Bool
    }

    /// getCidReporting: cid(2) flags(1) remap(2) …
    static func controlReporting(_ payload: [UInt8]) -> ControlReporting? {
        guard payload.count >= 3, let cid = uint16(payload, at: 0) else { return nil }
        return ControlReporting(controlID: cid, diverted: payload[2] & 0x01 != 0,
                                rawXY: payload[2] & 0x10 != 0)
    }

    /// setCidReporting parameters. Each flag travels with its "valid" bit, so
    /// diversion and raw XY are both stated outright: a raw XY diversion some
    /// other program left behind is cleared rather than inherited. Remap 0
    /// leaves the control's mapping alone; nothing is made persistent.
    static func setControlReporting(controlID: UInt16, diverted: Bool, rawXY: Bool) -> [UInt8] {
        var flags: UInt8 = 0x02 | 0x20
        if diverted { flags |= 0x01 }
        if diverted && rawXY { flags |= 0x10 }
        return bytes(controlID) + [flags, 0x00, 0x00]
    }

    /// Event 0: the diverted controls held right now, up to four.
    static func pressedControls(_ payload: [UInt8]) -> Set<UInt16> {
        var pressed: Set<UInt16> = []
        for offset in stride(from: 0, to: min(payload.count, 8) - 1, by: 2) {
            if let cid = uint16(payload, at: offset), cid != 0 { pressed.insert(cid) }
        }
        return pressed
    }

    /// Event 1: raw pointer movement while a raw XY diverted control is held.
    static func rawMotion(_ payload: [UInt8]) -> (dx: Int, dy: Int)? {
        guard let dx = int16(payload, at: 0), let dy = int16(payload, at: 2) else { return nil }
        return (Int(dx), Int(dy))
    }

    // MARK: - SmartShift (0x2110, 0x2111)

    enum WheelMode: UInt8 {
        case freeSpin = 1
        case ratchet = 2
    }

    /// The firmware value meaning "never leave ratchet on its own", which is
    /// SmartShift switched off.
    static let smartShiftDisabledThreshold: UInt8 = 0xFF

    struct SmartShiftState: Equatable {
        var mode: WheelMode?
        var threshold: UInt8
        var torque: UInt8?
    }

    struct SmartShiftCapabilities: Equatable {
        let tunableTorque: Bool
        let defaultThreshold: UInt8
        let defaultTorque: UInt8
    }

    /// 0x2111 function 0: capabilities(1) defaultThreshold(1) defaultTorque(1).
    static func smartShiftCapabilities(_ payload: [UInt8]) -> SmartShiftCapabilities? {
        guard payload.count >= 3 else { return nil }
        return SmartShiftCapabilities(tunableTorque: payload[0] & 0x01 != 0,
                                      defaultThreshold: payload[1], defaultTorque: payload[2])
    }

    /// Mode(1) threshold(1) and, on 0x2111, torque(1).
    static func smartShiftState(_ payload: [UInt8], enhanced: Bool) -> SmartShiftState? {
        guard payload.count >= 2 else { return nil }
        return SmartShiftState(mode: WheelMode(rawValue: payload[0]), threshold: payload[1],
                               torque: enhanced && payload.count >= 3 ? payload[2] : nil)
    }

    /// Zero in any byte means "leave this one as it is".
    static func setSmartShift(mode: WheelMode?, threshold: UInt8?, torque: UInt8?, enhanced: Bool) -> [UInt8] {
        var parameters = [mode?.rawValue ?? 0, threshold ?? 0]
        parameters.append(enhanced ? (torque ?? 0) : 0)
        return parameters
    }

    // MARK: - High-resolution wheel (0x2121)

    struct WheelReportingMode: OptionSet, Equatable {
        let rawValue: UInt8
        /// Wheel movement goes to HID++ events instead of the HID mouse report.
        static let diverted = WheelReportingMode(rawValue: 0x01)
        static let highResolution = WheelReportingMode(rawValue: 0x02)
        static let inverted = WheelReportingMode(rawValue: 0x04)
    }

    struct WheelCapabilities: Equatable {
        let multiplier: UInt8
        let hasRatchetSwitch: Bool
        let canInvert: Bool
    }

    static func wheelCapabilities(_ payload: [UInt8]) -> WheelCapabilities? {
        guard payload.count >= 2 else { return nil }
        return WheelCapabilities(multiplier: payload[0], hasRatchetSwitch: payload[1] & 0x04 != 0,
                                 canInvert: payload[1] & 0x08 != 0)
    }

    // MARK: - Thumb wheel (0x2150)

    struct ThumbWheelStatus: Equatable {
        let diverted: Bool
        let inverted: Bool
    }

    static func thumbWheelStatus(_ payload: [UInt8]) -> ThumbWheelStatus? {
        guard payload.count >= 2 else { return nil }
        return ThumbWheelStatus(diverted: payload[0] & 0x01 != 0, inverted: payload[1] & 0x01 != 0)
    }

    static func setThumbWheel(diverted: Bool, inverted: Bool) -> [UInt8] {
        [diverted ? 1 : 0, inverted ? 1 : 0]
    }

    /// Diverted rotation(int16) timestamp(2) status(1) flags(1). Only the
    /// rotation matters to the actions it drives.
    static func thumbWheelRotation(_ payload: [UInt8]) -> Int? {
        int16(payload, at: 0).map(Int.init)
    }

    // MARK: - Adjustable DPI (0x2201)

    struct DPIRange: Equatable {
        let minimum: Int
        let maximum: Int
        let step: Int
        /// Devices that list fixed values instead of a range.
        let values: [Int]

        func sanitized(_ dpi: Int) -> Int {
            if !values.isEmpty {
                return values.min { abs($0 - dpi) < abs($1 - dpi) } ?? dpi
            }
            let clamped = min(max(dpi, minimum), maximum)
            let step = max(1, self.step)
            let snapped = minimum + ((clamped - minimum + step / 2) / step) * step
            return min(snapped, maximum)
        }
    }

    /// getSensorDpiList: sensor(1) then 16-bit entries ending at 0. An entry
    /// with its top three bits set is a step that turns the values around it
    /// into a range (0x00C8, 0xE032, 0x1F40 reads 200…8000 in steps of 50).
    static func dpiRange(_ payload: [UInt8]) -> DPIRange? {
        var entries: [UInt16] = []
        var offset = 1
        while let entry = uint16(payload, at: offset), entry != 0 {
            entries.append(entry)
            offset += 2
        }
        var values: [Int] = []
        var step: Int?
        var index = 0
        while index < entries.count {
            let entry = entries[index]
            if entry & 0xE000 == 0xE000 {
                step = Int(entry & 0x1FFF)
                if index + 1 < entries.count {
                    values.append(Int(entries[index + 1]))
                    index += 1
                }
            } else {
                values.append(Int(entry))
            }
            index += 1
        }
        guard let minimum = values.min(), let maximum = values.max(), minimum > 0 else { return nil }
        if let step, step > 0 {
            return DPIRange(minimum: minimum, maximum: maximum, step: step, values: [])
        }
        return DPIRange(minimum: minimum, maximum: maximum, step: 0, values: values.sorted())
    }

    /// getSensorDpi: sensor(1) dpi(2) default(2).
    static func currentDPI(_ payload: [UInt8]) -> Int? {
        guard let dpi = uint16(payload, at: 1), dpi != 0 else { return nil }
        return Int(dpi)
    }

    static func setDPI(_ dpi: Int) -> [UInt8] {
        [0] + bytes(UInt16(clamping: dpi))
    }

    // MARK: - Haptics (0x19B0, MX Master 4)

    struct HapticCapabilities: Equatable {
        /// Some devices only take four fixed levels instead of 0…100.
        let fourLevelsOnly: Bool
        let waveforms: UInt32
    }

    static func hapticCapabilities(_ payload: [UInt8]) -> HapticCapabilities? {
        guard payload.count >= 8 else { return nil }
        let mask = payload[4...7].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        return HapticCapabilities(fourLevelsOnly: payload[2] & 0x01 != 0, waveforms: mask)
    }

    struct HapticState: Equatable {
        let enabled: Bool
        let level: Int
    }

    static func hapticState(_ payload: [UInt8]) -> HapticState? {
        guard payload.count >= 2 else { return nil }
        return HapticState(enabled: payload[0] & 0x01 != 0, level: Int(payload[1]))
    }

    static func setHaptic(enabled: Bool, level: Int) -> [UInt8] {
        [enabled ? 1 : 0, UInt8(clamping: min(max(level, 0), 100))]
    }

    /// The short, crisp click the device calls "sharp state change".
    static let gestureWaveform: UInt8 = 0x00

    // MARK: - Force sensing buttons (0x19C0, MX Master 4 haptic panel)

    /// How hard a pressure-sensitive control must be pressed to count, in
    /// the device's own force units (3749…6232 on the MX Master 4).
    struct ForceButtonInfo: Equatable {
        let changeable: Bool
        let defaultValue: Int
        let minimum: Int
        let maximum: Int

        func sanitized(_ value: Int) -> Int {
            min(max(value, minimum), maximum)
        }

        /// 0 is the lightest press the device accepts, 100 the firmest.
        func percent(_ value: Int) -> Int {
            guard maximum > minimum else { return 0 }
            return Int((Double(sanitized(value) - minimum) * 100 / Double(maximum - minimum)).rounded())
        }
    }

    /// Function 1 (button): flags(2) default(2) maximum(2) minimum(2).
    static func forceButtonInfo(_ payload: [UInt8]) -> ForceButtonInfo? {
        guard let flags = uint16(payload, at: 0), let defaultValue = uint16(payload, at: 2),
              let maximum = uint16(payload, at: 4), let minimum = uint16(payload, at: 6),
              minimum > 0, maximum >= minimum else { return nil }
        return ForceButtonInfo(changeable: flags & 0x01 != 0, defaultValue: Int(defaultValue),
                               minimum: Int(minimum), maximum: Int(maximum))
    }

    /// Function 2 (button): current(2).
    static func forceButtonCurrent(_ payload: [UInt8]) -> Int? {
        uint16(payload, at: 0).map(Int.init)
    }

    /// Function 3: button(1) value(2).
    static func setForceButton(_ button: UInt8, value: Int) -> [UInt8] {
        [button] + bytes(UInt16(clamping: value))
    }

    // MARK: - Battery (0x1000 on the MX Master 3, 0x1004 on the 3S and 4)

    struct BatteryState: Equatable {
        /// Nil when the device only reports coarse levels.
        let percent: Int?
        let charging: Bool
        let full: Bool
    }

    /// 0x1000 function 0 and event 0: level(1) nextLevel(1) status(1), where
    /// status 1, 2 and 4 mean charging and 3 means charged.
    static func batteryStatus(_ payload: [UInt8]) -> BatteryState? {
        guard payload.count >= 3 else { return nil }
        let level = Int(payload[0])
        let status = payload[2]
        guard status <= 4 else { return nil }
        return BatteryState(percent: (1...100).contains(level) ? level : nil,
                            charging: status == 1 || status == 2 || status == 4, full: status == 3)
    }

    /// 0x1004 function 0: supportedLevels(1) flags(1); bit 1 of the flags
    /// says the device reports a percentage.
    static func unifiedBatteryReportsPercent(_ payload: [UInt8]) -> Bool {
        payload.count >= 2 && payload[1] & 0x02 != 0
    }

    /// 0x1004 function 1 and event 0: percent(1) level(1) charging(1)
    /// externalPower(1), where charging 1 and 2 mean charging and 3 complete.
    static func unifiedBattery(_ payload: [UInt8], reportsPercent: Bool) -> BatteryState? {
        guard payload.count >= 3 else { return nil }
        let percent = Int(payload[0])
        let charging = payload[2]
        return BatteryState(percent: reportsPercent && percent <= 100 ? percent : nil,
                            charging: charging == 1 || charging == 2, full: charging == 3)
    }

    // MARK: - Wireless status (0x1D4B)

    /// Event 0 status(1) request(1): request 1 asks the host to apply its
    /// settings again, which is what a reconnect after sleep says.
    static func wantsReconfiguration(_ payload: [UInt8]) -> Bool {
        payload.count >= 2 && payload[1] == 0x01
    }
}
