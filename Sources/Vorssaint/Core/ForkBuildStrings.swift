// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// What a build from a fork says about itself in Settings. Each format takes
/// the fork's "owner/name".
struct ForkBuildStrings {
    let aboutFormat: String
    let updatesOffFormat: String
}

extension FeatureStrings {
    static func forkBuild(_ language: AppLanguage) -> ForkBuildStrings {
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

extension ForkBuildStrings {
    static let enUS = ForkBuildStrings(
        aboutFormat: "Built from the fork %@",
        updatesOffFormat: "This version was built from the fork %@. Automatic updates are off, so no official release replaces it."
    )
    static let de = ForkBuildStrings(
        aboutFormat: "Gebaut aus dem Fork %@",
        updatesOffFormat: "Diese Version wurde aus dem Fork %@ gebaut. Automatische Updates sind aus, damit keine offizielle Version sie ersetzt."
    )
    static let ptBR = ForkBuildStrings(
        aboutFormat: "Compilado a partir do fork %@",
        updatesOffFormat: "Esta versão foi compilada a partir do fork %@. As atualizações automáticas estão desativadas para que nenhuma versão oficial a substitua."
    )
    static let tr = ForkBuildStrings(
        aboutFormat: "%@ çatalından derlendi",
        updatesOffFormat: "Bu sürüm %@ çatalından derlendi. Resmi bir sürüm onun yerini almasın diye otomatik güncellemeler kapalı."
    )
    static let ru = ForkBuildStrings(
        aboutFormat: "Собрано из форка %@",
        updatesOffFormat: "Эта версия собрана из форка %@. Автоматические обновления выключены, чтобы официальный выпуск её не заменил."
    )
    static let es = ForkBuildStrings(
        aboutFormat: "Compilado desde el fork %@",
        updatesOffFormat: "Esta versión se compiló desde el fork %@. Las actualizaciones automáticas están desactivadas para que ninguna versión oficial la reemplace."
    )
    static let sk = ForkBuildStrings(
        aboutFormat: "Zostavené z forku %@",
        updatesOffFormat: "Táto verzia bola zostavená z forku %@. Automatické aktualizácie sú vypnuté, aby ju nenahradila oficiálna verzia."
    )
    static let fr = ForkBuildStrings(
        aboutFormat: "Compilé depuis le fork %@",
        updatesOffFormat: "Cette version a été compilée depuis le fork %@. Les mises à jour automatiques sont désactivées pour qu’aucune version officielle ne la remplace."
    )
    static let it = ForkBuildStrings(
        aboutFormat: "Compilato dal fork %@",
        updatesOffFormat: "Questa versione è stata compilata dal fork %@. Gli aggiornamenti automatici sono disattivati, così nessuna versione ufficiale la sostituisce."
    )
    static let ja = ForkBuildStrings(
        aboutFormat: "フォーク %@ からビルド",
        updatesOffFormat: "このバージョンはフォーク %@ からビルドされています。公式リリースで置き換えられないよう、自動アップデートはオフです。"
    )
    static let ko = ForkBuildStrings(
        aboutFormat: "포크 %@에서 빌드됨",
        updatesOffFormat: "이 버전은 포크 %@에서 빌드되었습니다. 공식 릴리스가 이 버전을 대체하지 않도록 자동 업데이트가 꺼져 있습니다."
    )
    static let zhHans = ForkBuildStrings(
        aboutFormat: "构建自分支 %@",
        updatesOffFormat: "此版本构建自分支 %@。自动更新已关闭，以免被官方版本替换。"
    )
    static let zhTW = ForkBuildStrings(
        aboutFormat: "建置自分支 %@",
        updatesOffFormat: "此版本建置自分支 %@。自動更新已關閉，以免被官方版本取代。"
    )
    static let zhHK = ForkBuildStrings(
        aboutFormat: "建置自分支 %@",
        updatesOffFormat: "此版本建置自分支 %@。自動更新已關閉，以免被官方版本取代。"
    )
    static let uk = ForkBuildStrings(
        aboutFormat: "Зібрано з форку %@",
        updatesOffFormat: "Цю версію зібрано з форку %@. Автоматичні оновлення вимкнено, щоб офіційний випуск її не замінив."
    )
}
