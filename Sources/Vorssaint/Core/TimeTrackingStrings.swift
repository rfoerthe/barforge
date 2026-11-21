// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Texts of the Time Tracking feature, ported from Tagwerk.
struct TimeTrackingFeatureStrings {
    let title: String
    let hubDescription: String
    let recordToggle: String
    let recordCaption: String
    /// Shown while only the groundwork is in place.
    let betaNote: String
}

extension FeatureStrings {
    static func timeTracking(_ language: AppLanguage) -> TimeTrackingFeatureStrings {
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
        case .uk: return .uk
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension TimeTrackingFeatureStrings {
    static let enUS = TimeTrackingFeatureStrings(
        title: "Time Tracking",
        hubDescription: "Record working time automatically while your Mac is unlocked, with breaks, balance and German working time rules",
        recordToggle: "Record working time",
        recordCaption: "Time counts while your Mac is unlocked. A lock of 15 minutes or more is a break.",
        betaNote: "This beta lays the groundwork. Recording, the menu panel section and the Records window follow in the next builds."
    )

    static let de = TimeTrackingFeatureStrings(
        title: "Arbeitszeiterfassung",
        hubDescription: "Erfasst die Arbeitszeit automatisch, solange der Mac entsperrt ist, mit Pausen, Saldo und den Regeln des Arbeitszeitgesetzes",
        recordToggle: "Arbeitszeit erfassen",
        recordCaption: "Gezählt wird, solange der Mac entsperrt ist. Eine Sperre ab 15 Minuten ist eine Pause.",
        betaNote: "Diese Beta legt die Grundlage. Erfassung, Bereich im Menüpanel und Fenster mit den Aufzeichnungen folgen in den nächsten Versionen."
    )

    static let ptBR = TimeTrackingFeatureStrings(
        title: "Registro de jornada",
        hubDescription: "Registre a jornada automaticamente enquanto o Mac está desbloqueado, com pausas, saldo e as regras alemãs de jornada de trabalho",
        recordToggle: "Registrar a jornada",
        recordCaption: "O tempo conta enquanto o Mac está desbloqueado. Um bloqueio de 15 minutos ou mais é uma pausa.",
        betaNote: "Esta versão beta prepara a base. O registro, a seção no painel e a janela de registros chegam nas próximas versões."
    )

    static let tr = TimeTrackingFeatureStrings(
        title: "Çalışma Süresi Takibi",
        hubDescription: "Mac kilidi açıkken çalışma süresini molalar, bakiye ve Alman çalışma süresi kurallarıyla otomatik olarak kaydedin",
        recordToggle: "Çalışma süresini kaydet",
        recordCaption: "Mac kilidi açıkken süre sayılır. 15 dakika veya daha uzun bir kilit moladır.",
        betaNote: "Bu beta temeli hazırlar. Kayıt, menü paneli bölümü ve kayıtlar penceresi sonraki sürümlerde gelecek."
    )

    static let ru = TimeTrackingFeatureStrings(
        title: "Учёт рабочего времени",
        hubDescription: "Автоматически учитывайте рабочее время, пока Mac разблокирован, с перерывами, балансом и правилами немецкого закона о рабочем времени",
        recordToggle: "Учитывать рабочее время",
        recordCaption: "Время считается, пока Mac разблокирован. Блокировка от 15 минут считается перерывом.",
        betaNote: "Эта бета закладывает основу. Учёт, раздел в панели меню и окно записей появятся в следующих сборках."
    )

    static let es = TimeTrackingFeatureStrings(
        title: "Registro de jornada",
        hubDescription: "Registra la jornada automáticamente mientras el Mac está desbloqueado, con pausas, saldo y las normas alemanas de jornada laboral",
        recordToggle: "Registrar la jornada",
        recordCaption: "El tiempo cuenta mientras el Mac está desbloqueado. Un bloqueo de 15 minutos o más es una pausa.",
        betaNote: "Esta beta sienta las bases. El registro, la sección del panel y la ventana de registros llegan en las próximas versiones."
    )

    static let sk = TimeTrackingFeatureStrings(
        title: "Evidencia pracovného času",
        hubDescription: "Automaticky zaznamenáva pracovný čas, kým je Mac odomknutý, s prestávkami, saldom a pravidlami nemeckého zákona o pracovnom čase",
        recordToggle: "Zaznamenávať pracovný čas",
        recordCaption: "Čas sa počíta, kým je Mac odomknutý. Zamknutie na 15 minút a dlhšie je prestávka.",
        betaNote: "Táto beta pripravuje základ. Záznam, sekcia v paneli ponuky a okno záznamov prídu v ďalších verziách."
    )

    static let fr = TimeTrackingFeatureStrings(
        title: "Suivi du temps de travail",
        hubDescription: "Enregistrez automatiquement le temps de travail tant que le Mac est déverrouillé, avec pauses, solde et règles allemandes sur le temps de travail",
        recordToggle: "Enregistrer le temps de travail",
        recordCaption: "Le temps compte tant que le Mac est déverrouillé. Un verrouillage de 15 minutes ou plus est une pause.",
        betaNote: "Cette bêta pose les bases. L’enregistrement, la section du panneau et la fenêtre des relevés arrivent dans les prochaines versions."
    )

    static let it = TimeTrackingFeatureStrings(
        title: "Registrazione orario di lavoro",
        hubDescription: "Registra automaticamente l’orario di lavoro mentre il Mac è sbloccato, con pause, saldo e regole tedesche sull’orario di lavoro",
        recordToggle: "Registra l’orario di lavoro",
        recordCaption: "Il tempo conta finché il Mac è sbloccato. Un blocco di 15 minuti o più è una pausa.",
        betaNote: "Questa beta getta le basi. La registrazione, la sezione nel pannello e la finestra delle registrazioni arrivano nelle prossime versioni."
    )

    static let ja = TimeTrackingFeatureStrings(
        title: "勤務時間の記録",
        hubDescription: "Mac のロックが解除されている間の勤務時間を、休憩、残高、ドイツの労働時間規則とともに自動で記録します",
        recordToggle: "勤務時間を記録",
        recordCaption: "Mac のロックが解除されている間を勤務時間として数えます。15 分以上のロックは休憩です。",
        betaNote: "このベータ版は土台です。記録、メニューパネルのセクション、記録ウインドウは今後のビルドで追加されます。"
    )

    static let ko = TimeTrackingFeatureStrings(
        title: "근무 시간 기록",
        hubDescription: "Mac 잠금이 해제된 동안 근무 시간을 휴식, 잔여 시간, 독일 근로시간 규정과 함께 자동으로 기록합니다",
        recordToggle: "근무 시간 기록하기",
        recordCaption: "Mac 잠금이 해제된 동안 시간이 계산됩니다. 15분 이상 잠기면 휴식으로 처리됩니다.",
        betaNote: "이 베타는 기반을 마련합니다. 기록, 메뉴 패널 섹션, 기록 창은 다음 빌드에서 제공됩니다."
    )

    static let uk = TimeTrackingFeatureStrings(
        title: "Облік робочого часу",
        hubDescription: "Автоматично враховуйте робочий час, поки Mac розблоковано, з перервами, балансом і правилами німецького закону про робочий час",
        recordToggle: "Враховувати робочий час",
        recordCaption: "Час рахується, поки Mac розблоковано. Блокування від 15 хвилин є перервою.",
        betaNote: "Ця бета закладає основу. Облік, розділ у панелі меню та вікно записів з’являться в наступних збірках."
    )

    static let zhHans = TimeTrackingFeatureStrings(
        title: "工时记录",
        hubDescription: "在 Mac 解锁期间自动记录工作时间，包括休息、余额和德国工时规定",
        recordToggle: "记录工作时间",
        recordCaption: "Mac 解锁期间计入工作时间。锁定 15 分钟或更久即为休息。",
        betaNote: "此测试版只是基础。记录功能、菜单面板区域和记录窗口将在后续版本中提供。"
    )

    static let zhTW = TimeTrackingFeatureStrings(
        title: "工時記錄",
        hubDescription: "在 Mac 解鎖期間自動記錄工作時間，包括休息、餘額和德國工時規定",
        recordToggle: "記錄工作時間",
        recordCaption: "Mac 解鎖期間計入工作時間。鎖定 15 分鐘或更久即為休息。",
        betaNote: "此測試版只是基礎。記錄功能、選單面板區域和記錄視窗將在後續版本中提供。"
    )

    static let zhHK = TimeTrackingFeatureStrings(
        title: "工時記錄",
        hubDescription: "在 Mac 解鎖期間自動記錄工作時間，包括休息、結餘和德國工時規定",
        recordToggle: "記錄工作時間",
        recordCaption: "Mac 解鎖期間計入工作時間。鎖定 15 分鐘或以上即為休息。",
        betaNote: "此測試版只是基礎。記錄功能、選單面板區域和記錄視窗將於後續版本提供。"
    )
}
