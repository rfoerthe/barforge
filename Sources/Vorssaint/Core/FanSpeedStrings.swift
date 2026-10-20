// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Labels for the read-only fan speed readout.
struct FanSpeedStrings {
    let title: String
    let fanNameFormat: String
    let rpmFormat: String
}

extension FeatureStrings {
    static func fanSpeed(_ language: AppLanguage) -> FanSpeedStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension FanSpeedStrings {
    static let enUS = FanSpeedStrings(
        title: "Fan speed",
        fanNameFormat: "Fan %d",
        rpmFormat: "%d RPM"
    )

    static let ptBR = FanSpeedStrings(
        title: "Velocidade das ventoinhas",
        fanNameFormat: "Ventoinha %d",
        rpmFormat: "%d RPM"
    )

    static let tr = FanSpeedStrings(
        title: "Fan hızı",
        fanNameFormat: "Fan %d",
        rpmFormat: "%d RPM"
    )

    static let ru = FanSpeedStrings(
        title: "Скорость вентилятора",
        fanNameFormat: "Вентилятор %d",
        rpmFormat: "%d об/мин"
    )

    static let es = FanSpeedStrings(
        title: "Velocidad de ventiladores",
        fanNameFormat: "Ventilador %d",
        rpmFormat: "%d RPM"
    )

    static let sk = FanSpeedStrings(
        title: "Otáčky ventilátora",
        fanNameFormat: "Ventilátor %d",
        rpmFormat: "%d ot./min"
    )

    static let de = FanSpeedStrings(
        title: "Lüftergeschwindigkeit",
        fanNameFormat: "Lüfter %d",
        rpmFormat: "%d U/min"
    )

    static let fr = FanSpeedStrings(
        title: "Vitesse des ventilateurs",
        fanNameFormat: "Ventilateur %d",
        rpmFormat: "%d tr/min"
    )

    static let it = FanSpeedStrings(
        title: "Velocità ventole",
        fanNameFormat: "Ventola %d",
        rpmFormat: "%d RPM"
    )

    static let ja = FanSpeedStrings(
        title: "ファン速度",
        fanNameFormat: "ファン%d",
        rpmFormat: "%d RPM"
    )

    static let ko = FanSpeedStrings(
        title: "팬 속도",
        fanNameFormat: "팬 %d",
        rpmFormat: "%d RPM"
    )

    static let zhHans = FanSpeedStrings(
        title: "风扇转速",
        fanNameFormat: "风扇%d",
        rpmFormat: "%d RPM"
    )

    static let zhTW = FanSpeedStrings(
        title: "風扇轉速",
        fanNameFormat: "風扇%d",
        rpmFormat: "%d RPM"
    )

    static let zhHK = FanSpeedStrings(
        title: "風扇轉速",
        fanNameFormat: "風扇%d",
        rpmFormat: "%d RPM"
    )

    static let uk = FanSpeedStrings(
        title: "Швидкість вентилятора",
        fanNameFormat: "Вентилятор %d",
        rpmFormat: "%d об/хв"
    )
}
