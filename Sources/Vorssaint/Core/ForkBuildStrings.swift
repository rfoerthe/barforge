// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// What a build from a fork says about itself in Settings. Each format takes
/// the fork's "owner/name". `attribution` names the original project, as its
/// trademark policy and the GPL ask of a modified version.
struct ForkBuildStrings {
    let aboutFormat: String
    let updatesUnsignedFormat: String
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
        updatesUnsignedFormat: "This version is not signed with a Developer ID, so it cannot update itself. New versions are on the releases page of %@.",
        attribution: "An unofficial, modified version of Vorssaint, not endorsed by the Vorssaint project. Free software under GPL-3.0-or-later, without any warranty.",
        basedOnFormat: "Based on Vorssaint %@"
    )
    static let de = ForkBuildStrings(
        aboutFormat: "Gebaut aus dem Fork %@",
        updatesUnsignedFormat: "Diese Version ist nicht mit einer Developer ID signiert und kann sich daher nicht selbst aktualisieren. Neue Versionen gibt es auf der Releases-Seite von %@.",
        attribution: "Eine inoffizielle, veränderte Version von Vorssaint, nicht vom Vorssaint-Projekt unterstützt. Freie Software unter GPL-3.0-or-later, ohne jede Gewährleistung.",
        basedOnFormat: "Basiert auf Vorssaint %@"
    )
    static let ptBR = ForkBuildStrings(
        aboutFormat: "Compilado a partir do fork %@",
        updatesUnsignedFormat: "Esta versão não está assinada com um Developer ID, por isso não pode se atualizar sozinha. Novas versões estão na página de releases de %@.",
        attribution: "Uma versão modificada e não oficial do Vorssaint, sem endosso do projeto Vorssaint. Software livre sob a GPL-3.0-or-later, sem qualquer garantia.",
        basedOnFormat: "Baseado no Vorssaint %@"
    )
    static let tr = ForkBuildStrings(
        aboutFormat: "%@ çatalından derlendi",
        updatesUnsignedFormat: "Bu sürüm bir Developer ID ile imzalanmadığı için kendini güncelleyemez. Yeni sürümler %@ deposunun sürümler sayfasında.",
        attribution: "Vorssaint’in resmî olmayan, değiştirilmiş bir sürümü; Vorssaint projesi tarafından desteklenmez. GPL-3.0-or-later kapsamında, hiçbir garanti olmadan sunulan özgür yazılım.",
        basedOnFormat: "Vorssaint %@ tabanlı"
    )
    static let ru = ForkBuildStrings(
        aboutFormat: "Собрано из форка %@",
        updatesUnsignedFormat: "Эта версия не подписана Developer ID, поэтому не может обновляться сама. Новые версии есть на странице релизов %@.",
        attribution: "Неофициальная изменённая версия Vorssaint, не одобренная проектом Vorssaint. Свободное ПО под лицензией GPL-3.0-or-later, без каких-либо гарантий.",
        basedOnFormat: "На основе Vorssaint %@"
    )
    static let es = ForkBuildStrings(
        aboutFormat: "Compilado desde el fork %@",
        updatesUnsignedFormat: "Esta versión no está firmada con un Developer ID, así que no puede actualizarse sola. Las nuevas versiones están en la página de versiones de %@.",
        attribution: "Una versión modificada y no oficial de Vorssaint, sin el respaldo del proyecto Vorssaint. Software libre bajo la GPL-3.0-or-later, sin ninguna garantía.",
        basedOnFormat: "Basado en Vorssaint %@"
    )
    static let sk = ForkBuildStrings(
        aboutFormat: "Zostavené z forku %@",
        updatesUnsignedFormat: "Táto verzia nie je podpísaná certifikátom Developer ID, preto sa nemôže sama aktualizovať. Nové verzie nájdete na stránke vydaní %@.",
        attribution: "Neoficiálna upravená verzia aplikácie Vorssaint, ktorú projekt Vorssaint nepodporuje. Slobodný softvér pod licenciou GPL-3.0-or-later, bez akejkoľvek záruky.",
        basedOnFormat: "Založené na Vorssaint %@"
    )
    static let fr = ForkBuildStrings(
        aboutFormat: "Compilé depuis le fork %@",
        updatesUnsignedFormat: "Cette version n’est pas signée avec un Developer ID et ne peut donc pas se mettre à jour elle-même. Les nouvelles versions sont sur la page des versions de %@.",
        attribution: "Une version modifiée et non officielle de Vorssaint, non approuvée par le projet Vorssaint. Logiciel libre sous GPL-3.0-or-later, sans aucune garantie.",
        basedOnFormat: "Basé sur Vorssaint %@"
    )
    static let it = ForkBuildStrings(
        aboutFormat: "Compilato dal fork %@",
        updatesUnsignedFormat: "Questa versione non è firmata con un Developer ID, quindi non può aggiornarsi da sola. Le nuove versioni sono nella pagina delle release di %@.",
        attribution: "Una versione modificata e non ufficiale di Vorssaint, non approvata dal progetto Vorssaint. Software libero con licenza GPL-3.0-or-later, senza alcuna garanzia.",
        basedOnFormat: "Basato su Vorssaint %@"
    )
    static let ja = ForkBuildStrings(
        aboutFormat: "フォーク %@ からビルド",
        updatesUnsignedFormat: "このバージョンは Developer ID で署名されていないため、自動でアップデートできません。新しいバージョンは %@ のリリースページにあります。",
        attribution: "Vorssaint の非公式な改変版で、Vorssaint プロジェクトの承認は受けていません。GPL-3.0-or-later のフリーソフトウェアで、いかなる保証もありません。",
        basedOnFormat: "Vorssaint %@ ベース"
    )
    static let ko = ForkBuildStrings(
        aboutFormat: "포크 %@에서 빌드됨",
        updatesUnsignedFormat: "이 버전은 Developer ID로 서명되지 않아 스스로 업데이트할 수 없습니다. 새 버전은 %@의 릴리스 페이지에 있습니다.",
        attribution: "Vorssaint의 비공식 수정 버전으로, Vorssaint 프로젝트의 승인을 받지 않았습니다. GPL-3.0-or-later에 따른 자유 소프트웨어이며 어떠한 보증도 없습니다.",
        basedOnFormat: "Vorssaint %@ 기반"
    )
    static let zhHans = ForkBuildStrings(
        aboutFormat: "构建自分支 %@",
        updatesUnsignedFormat: "此版本未使用 Developer ID 签名，因此无法自动更新。新版本请前往 %@ 的发布页面。",
        attribution: "Vorssaint 的非官方修改版本，未获 Vorssaint 项目认可。依据 GPL-3.0-or-later 授权的自由软件，不提供任何担保。",
        basedOnFormat: "基于 Vorssaint %@"
    )
    static let zhTW = ForkBuildStrings(
        aboutFormat: "建置自分支 %@",
        updatesUnsignedFormat: "此版本未使用 Developer ID 簽署，因此無法自動更新。新版本請前往 %@ 的發佈頁面。",
        attribution: "Vorssaint 的非官方修改版本，未經 Vorssaint 專案認可。依據 GPL-3.0-or-later 授權的自由軟體，不提供任何擔保。",
        basedOnFormat: "基於 Vorssaint %@"
    )
    static let zhHK = ForkBuildStrings(
        aboutFormat: "建置自分支 %@",
        updatesUnsignedFormat: "此版本未使用 Developer ID 簽署，因此無法自動更新。新版本請前往 %@ 的發佈頁面。",
        attribution: "Vorssaint 的非官方修改版本，未經 Vorssaint 專案認可。依據 GPL-3.0-or-later 授權的自由軟件，不提供任何擔保。",
        basedOnFormat: "基於 Vorssaint %@"
    )
    static let uk = ForkBuildStrings(
        aboutFormat: "Зібрано з форку %@",
        updatesUnsignedFormat: "Ця версія не підписана Developer ID, тому не може оновлюватися сама. Нові версії є на сторінці релізів %@.",
        attribution: "Неофіційна змінена версія Vorssaint, не схвалена проєктом Vorssaint. Вільне ПЗ за ліцензією GPL-3.0-or-later, без жодних гарантій.",
        basedOnFormat: "На основі Vorssaint %@"
    )
}
