// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Read-only fan speed readings from the SMC, shown in the System card and
/// the menu bar. Nothing here ever writes to the fans.
enum FanTelemetry {
    static let maximumFanCount = 8
    static let maximumSaneRPM = 20_000.0

    static func fanCount(from value: Double) -> Int? {
        guard value.isFinite else { return nil }
        let rounded = value.rounded()
        guard abs(value - rounded) < 0.001 else { return nil }
        let count = Int(rounded)
        return (1...maximumFanCount).contains(count) ? count : nil
    }

    static func validReading(_ value: Double) -> Bool {
        value.isFinite && value >= 0 && value <= maximumSaneRPM
    }

    static func readings(expectedCount: Int, readings: [Double?]) -> [Double]? {
        guard (1...maximumFanCount).contains(expectedCount),
              readings.count == expectedCount else { return nil }
        let values = readings.compactMap { $0 }
        guard values.count == expectedCount,
              values.allSatisfy(validReading) else { return nil }
        return values
    }

    static func menuBarValue(for speeds: [Double]) -> String? {
        guard !speeds.isEmpty, speeds.allSatisfy(validReading) else { return nil }
        return speeds.map { String(Int($0.rounded())) }.joined(separator: "/")
    }

    static func menuBarWidthUnits(fanCount: Int) -> Int {
        guard (1...maximumFanCount).contains(fanCount) else { return 0 }
        return 7 + fanCount * 5 + (fanCount - 1)
    }
}

enum SMCValueCodec {
    static func decode(_ bytes: [UInt8], type: String) -> Double? {
        switch type {
        case "flt " where bytes.count == 4:
            let bits = UInt32(bytes[0])
                | UInt32(bytes[1]) << 8
                | UInt32(bytes[2]) << 16
                | UInt32(bytes[3]) << 24
            let value = Double(Float32(bitPattern: bits))
            return value.isFinite ? value : nil
        case "fpe2" where bytes.count == 2:
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(raw) / 4.0
        case "sp78" where bytes.count == 2:
            let raw = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            return Double(Int16(bitPattern: raw)) / 256.0
        case "ui8 " where bytes.count == 1:
            return Double(bytes[0])
        case "ui16" where bytes.count == 2:
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32" where bytes.count == 4:
            return Double(UInt32(bytes[0]) << 24
                          | UInt32(bytes[1]) << 16
                          | UInt32(bytes[2]) << 8
                          | UInt32(bytes[3]))
        case "ioft" where bytes.count == 8:
            var raw: UInt64 = 0
            for (offset, byte) in bytes.enumerated() {
                raw |= UInt64(byte) << UInt64(offset * 8)
            }
            return Double(raw) / 65_536.0
        default:
            return nil
        }
    }
}
