// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// What a build from a fork says about itself in Settings. Each format takes
/// the fork's "owner/name". `attribution` names the original project, as its
/// trademark policy and the GPL ask of a modified version.
struct ForkBuildStrings {
    let aboutFormat: String
    let updatesOffFormat: String
    let attribution: String
    /// Takes the Vorssaint version the build is made from.
    let basedOnFormat: String
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
        updatesOffFormat: "This version was built from the fork %@. Automatic updates are off, so no official release replaces it.",
        attribution: "An unofficial, modified version of Vorssaint, not endorsed by the Vorssaint project. Free software under GPL-3.0-or-later, without any warranty.",
        basedOnFormat: "Based on Vorssaint %@"
    )
    static let de = ForkBuildStrings(
        aboutFormat: "Gebaut aus dem Fork %@",
        updatesOffFormat: "Diese Version wurde aus dem Fork %@ gebaut. Automatische Updates sind aus, damit keine offizielle Version sie ersetzt.",
        attribution: "Eine inoffizielle, veränderte Version von Vorssaint, nicht vom Vorssaint-Projekt unterstützt. Freie Software unter GPL-3.0-or-later, ohne jede Gewährleistung.",
        basedOnFormat: "Basiert auf Vorssaint %@"
    )
    static let ptBR = ForkBuildStrings(
        aboutFormat: "Compilado a partir do fork %@",
        updatesOffFormat: "Esta versão foi compilada a partir do fork %@. As atualizações automáticas estão desativadas para que nenhuma versão oficial a substitua.",
        attribution: "Uma versão modificada e não oficial do Vorssaint, sem endosso do projeto Vorssaint. Software livre sob a GPL-3.0-or-later, sem qualquer garantia.",
        basedOnFormat: "Baseado no Vorssaint %@"
    )
    static let tr = ForkBuildStrings(
        aboutFormat: "%@ çatalından derlendi",
        updatesOffFormat: "Bu sürüm %@ çatalından derlendi. Resmi bir sürüm onun yerini almasın diye otomatik güncellemeler kapalı.",
        attribution: "Vorssaint’in resmî olmayan, değiştirilmiş bir sürümü; Vorssaint projesi tarafından desteklenmez. GPL-3.0-or-later kapsamında, hiçbir garanti olmadan sunulan özgür yazılım.",
        basedOnFormat: "Vorssaint %@ tabanlı"
    )
    static let ru = ForkBuildStrings(
        aboutFormat: "Собрано из форка %@",
        updatesOffFormat: "Эта версия собрана из форка %@. Автоматические обновления выключены, чтобы официальный выпуск её не заменил.",
        attribution: "Неофициальная изменённая версия Vorssaint, не одобренная проектом Vorssaint. Свободное ПО под лицензией GPL-3.0-or-later, без каких-либо гарантий.",
        basedOnFormat: "На основе Vorssaint %@"
    )
    static let es = ForkBuildStrings(
        aboutFormat: "Compilado desde el fork %@",
        updatesOffFormat: "Esta versión se compiló desde el fork %@. Las actualizaciones automáticas están desactivadas para que ninguna versión oficial la reemplace.",
        attribution: "Una versión modificada y no oficial de Vorssaint, sin el respaldo del proyecto Vorssaint. Software libre bajo la GPL-3.0-or-later, sin ninguna garantía.",
        basedOnFormat: "Basado en Vorssaint %@"
    )
    static let sk = ForkBuildStrings(
        aboutFormat: "Zostavené z forku %@",
        updatesOffFormat: "Táto verzia bola zostavená z forku %@. Automatické aktualizácie sú vypnuté, aby ju nenahradila oficiálna verzia.",
        attribution: "Neoficiálna upravená verzia aplikácie Vorssaint, ktorú projekt Vorssaint nepodporuje. Slobodný softvér pod licenciou GPL-3.0-or-later, bez akejkoľvek záruky.",
        basedOnFormat: "Založené na Vorssaint %@"
    )
    static let fr = ForkBuildStrings(
        aboutFormat: "Compilé depuis le fork %@",
        updatesOffFormat: "Cette version a été compilée depuis le fork %@. Les mises à jour automatiques sont désactivées pour qu’aucune version officielle ne la remplace.",
        attribution: "Une version modifiée et non officielle de Vorssaint, non approuvée par le projet Vorssaint. Logiciel libre sous GPL-3.0-or-later, sans aucune garantie.",
        basedOnFormat: "Basé sur Vorssaint %@"
    )
    static let it = ForkBuildStrings(
        aboutFormat: "Compilato dal fork %@",
        updatesOffFormat: "Questa versione è stata compilata dal fork %@. Gli aggiornamenti automatici sono disattivati, così nessuna versione ufficiale la sostituisce.",
        attribution: "Una versione modificata e non ufficiale di Vorssaint, non approvata dal progetto Vorssaint. Software libero con licenza GPL-3.0-or-later, senza alcuna garanzia.",
        basedOnFormat: "Basato su Vorssaint %@"
    )
    static let ja = ForkBuildStrings(
        aboutFormat: "フォーク %@ からビルド",
        updatesOffFormat: "このバージョンはフォーク %@ からビルドされています。公式リリースで置き換えられないよう、自動アップデートはオフです。",
        attribution: "Vorssaint の非公式な改変版で、Vorssaint プロジェクトの承認は受けていません。GPL-3.0-or-later のフリーソフトウェアで、いかなる保証もありません。",
        basedOnFormat: "Vorssaint %@ ベース"
    )
    static let ko = ForkBuildStrings(
        aboutFormat: "포크 %@에서 빌드됨",
        updatesOffFormat: "이 버전은 포크 %@에서 빌드되었습니다. 공식 릴리스가 이 버전을 대체하지 않도록 자동 업데이트가 꺼져 있습니다.",
        attribution: "Vorssaint의 비공식 수정 버전으로, Vorssaint 프로젝트의 승인을 받지 않았습니다. GPL-3.0-or-later에 따른 자유 소프트웨어이며 어떠한 보증도 없습니다.",
        basedOnFormat: "Vorssaint %@ 기반"
    )
    static let zhHans = ForkBuildStrings(
        aboutFormat: "构建自分支 %@",
        updatesOffFormat: "此版本构建自分支 %@。自动更新已关闭，以免被官方版本替换。",
        attribution: "Vorssaint 的非官方修改版本，未获 Vorssaint 项目认可。依据 GPL-3.0-or-later 授权的自由软件，不提供任何担保。",
        basedOnFormat: "基于 Vorssaint %@"
    )
    static let zhTW = ForkBuildStrings(
        aboutFormat: "建置自分支 %@",
        updatesOffFormat: "此版本建置自分支 %@。自動更新已關閉，以免被官方版本取代。",
        attribution: "Vorssaint 的非官方修改版本，未經 Vorssaint 專案認可。依據 GPL-3.0-or-later 授權的自由軟體，不提供任何擔保。",
        basedOnFormat: "基於 Vorssaint %@"
    )
    static let zhHK = ForkBuildStrings(
        aboutFormat: "建置自分支 %@",
        updatesOffFormat: "此版本建置自分支 %@。自動更新已關閉，以免被官方版本取代。",
        attribution: "Vorssaint 的非官方修改版本，未經 Vorssaint 專案認可。依據 GPL-3.0-or-later 授權的自由軟件，不提供任何擔保。",
        basedOnFormat: "基於 Vorssaint %@"
    )
    static let uk = ForkBuildStrings(
        aboutFormat: "Зібрано з форку %@",
        updatesOffFormat: "Цю версію зібрано з форку %@. Автоматичні оновлення вимкнено, щоб офіційний випуск її не замінив.",
        attribution: "Неофіційна змінена версія Vorssaint, не схвалена проєктом Vorssaint. Вільне ПЗ за ліцензією GPL-3.0-or-later, без жодних гарантій.",
        basedOnFormat: "На основі Vorssaint %@"
    )
}
