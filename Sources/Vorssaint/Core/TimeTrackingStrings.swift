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

/// Texts of the time tracking logic (day, rules, warnings, notifications),
/// ported from Tagwerk. German is Tagwerk's wording; the other languages show
/// English until they are translated.
struct TimeTrackingTexts {
    // Day (day.rs)
    let workWithoutMac: String
    /// Note or "work away from the Mac", then start and end.
    let workBlockFormat: String
    let underOneMinute: String
    let minutesFormat: String
    /// Start, end and length of a gap.
    let joinedSpanFormat: String
    /// Joins the last two items of a list.
    let andSeparator: String
    let joinedRestOneFormat: String
    let joinedRestManyFormat: String
    let joinedGapOneFormat: String
    let joinedGapManyFormat: String
    /// Minimum break, then the start and end of the new block.
    let joinedSummaryOneFormat: String
    let joinedSummaryEachFormat: String
    let activityMeeting: String
    let activityCall: String
    let activityNetworking: String
    let activityOther: String
    let absenceVacation: String
    let absenceSpecialLeave: String
    let absenceSick: String
    let absenceHoliday: String
    let absenceTimeOff: String
    let absenceHalfFormat: String
    let absenceShortHalfFormat: String
    /// Recognizes a half day when reading an absence back.
    let absenceHalfMarker: String
    let absenceCodeVacation: String
    let absenceCodeSpecialLeave: String
    let absenceCodeSick: String
    let absenceCodeHoliday: String
    let absenceCodeTimeOff: String
    let freeDayUncounted: String
    let freeDayCounted: String
    let freeDayStopped: String
    /// Recognizes `freeDayStopped` when reading a note back.
    let freeDayStoppedMarker: String
    /// Recognizes `freeDayUncounted` when reading a note back.
    let freeDayNegationMarker: String

    // Rules (rules.rs)
    /// Hours and minutes of a duration.
    let durationFormat: String
    let dailyTargetFormat: String
    let dailyTargetRangeFormat: String
    let weekdayMonday: String
    let weekdayTuesday: String
    let weekdayWednesday: String
    let weekdayThursday: String
    let weekdayFriday: String
    let weekdaySaturday: String
    let weekdaySunday: String
    let mondayToFriday: String
    let listSeparator: String
    let weekFormat: String
    /// Start and end of the working-time frame.
    let frameFormat: String
    /// Frame, weekly hours, workdays, minimum break in minutes, then `rulesSummaryFreeDays` or nothing.
    let rulesSummaryFormat: String
    let rulesSummaryFreeDays: String
    let decimalSeparator: String
    /// Day, month and year of a date.
    let dayFormat: String
    let rulesFromFormat: String
    let rulesUntilFormat: String
    let rulesRangeFormat: String
    let targetBasisFormat: String
    let targetBasisMixed: String
    let iconSetDayArc: String
    let iconSetLockClock: String
    let iconSetDayRing: String
    let iconSetBuilder: String
    let iconSetCraftswoman: String
    let iconSetCoffeeCup: String
    let iconSetHamsterWheel: String
    let iconSetRobot: String
    let iconSetRabbit: String

    // Warnings (rules.rs)
    let warningOutsideSuffix: String
    /// Hours of work, minutes of break required, then `warningOutsideSuffix` or nothing.
    let warningBreaksFormat: String
    let warningLongStretchFormat: String
    let warningMaxHoursFormat: String
    let warningRestFormat: String
    /// Times outside the frame, then the frame.
    let warningOutsideFrameFormat: String
    let warningWeekendCounted: String
    let warningWeekendUncounted: String
    let warningFreeWeekdayCounted: String
    let warningFreeWeekdayUncounted: String
    let spansOneFormat: String
    let spansFewFormat: String
    /// Number of spans, then their total length.
    let spansManyFormat: String

    // Notifications (rules.rs)
    let limitSoonTitleFormat: String
    let limitReachedTitle: String
    let limitSoonBodyFormat: String
    let limitReachedBody: String
    let breakSoonTitleFormat: String
    let breakReachedTitle: String
    let breakSoonBodyFormat: String
    let breakReachedBody: String

    /// Short weekday names, Monday first.
    var weekdayShortNames: [String] {
        [weekdayMonday, weekdayTuesday, weekdayWednesday, weekdayThursday, weekdayFriday,
         weekdaySaturday, weekdaySunday]
    }
}

extension FeatureStrings {
    static func timeTrackingTexts(_ language: AppLanguage) -> TimeTrackingTexts {
        switch language {
        case .de: return .de
        case .enUS, .ptBR, .tr, .ru, .es, .sk, .fr, .it, .ja, .ko, .uk, .zhHans, .zhTW, .zhHK: return .enUS
        }
    }
}

extension TimeTrackingTexts {
    static let enUS = TimeTrackingTexts(
        workWithoutMac: "Work away from the Mac",
        workBlockFormat: "%1$@ %2$@–%3$@",
        underOneMinute: "under 1 min",
        minutesFormat: "%d min",
        joinedSpanFormat: "from %1$@ to %2$@ (%3$@)",
        andSeparator: " and ",
        joinedRestOneFormat: "Only %@ would have been left of the manual break.",
        joinedRestManyFormat: "Only %@ would have been left of the manual breaks.",
        joinedGapOneFormat: "A gap %@ would have been left next to the working time.",
        joinedGapManyFormat: "Gaps %@ would have been left next to the working time.",
        joinedSummaryOneFormat: "That is shorter than the minimum break of %1$@, so the time was added to the new block. It now runs from %2$@ to %3$@.",
        joinedSummaryEachFormat: "Each is shorter than the minimum break of %1$@, so the time was added to the new block. It now runs from %2$@ to %3$@.",
        activityMeeting: "Meeting",
        activityCall: "Call",
        activityNetworking: "Networking",
        activityOther: "Other",
        absenceVacation: "Vacation",
        absenceSpecialLeave: "Special leave",
        absenceSick: "Sick",
        absenceHoliday: "Holiday",
        absenceTimeOff: "Time off",
        absenceHalfFormat: "%@ (half day)",
        absenceShortHalfFormat: "½ %@",
        absenceHalfMarker: "half",
        absenceCodeVacation: "V",
        absenceCodeSpecialLeave: "SL",
        absenceCodeSick: "S",
        absenceCodeHoliday: "H",
        absenceCodeTimeOff: "TO",
        freeDayUncounted: "free day, not counted",
        freeDayCounted: "free day, counted",
        freeDayStopped: "free day, not recorded",
        freeDayStoppedMarker: "not recorded",
        freeDayNegationMarker: "not",
        durationFormat: "%1$d:%2$02d h",
        dailyTargetFormat: "%@ h",
        dailyTargetRangeFormat: "%1$@ to %2$@ h",
        weekdayMonday: "Mon",
        weekdayTuesday: "Tue",
        weekdayWednesday: "Wed",
        weekdayThursday: "Thu",
        weekdayFriday: "Fri",
        weekdaySaturday: "Sat",
        weekdaySunday: "Sun",
        mondayToFriday: "Mon–Fri",
        listSeparator: ", ",
        weekFormat: "%d-day week",
        frameFormat: "%1$@–%2$@",
        rulesSummaryFormat: "Working hours %1$@  ·  Regular hours %2$@ h/week (%3$@)  ·  Breaks from %4$d min%5$@",
        rulesSummaryFreeDays: "  ·  Work on days off counts toward the balance",
        decimalSeparator: ".",
        dayFormat: "%3$04d-%2$02d-%1$02d",
        rulesFromFormat: "From %1$@: %2$@",
        rulesUntilFormat: "Until %1$@: %2$@",
        rulesRangeFormat: "%1$@ to %2$@: %3$@",
        targetBasisFormat: "%1$@ h/week, %2$@",
        targetBasisMixed: "by the rules that applied on each day",
        iconSetDayArc: "Day Arc",
        iconSetLockClock: "Lock Clock",
        iconSetDayRing: "Day Ring",
        iconSetBuilder: "Builder",
        iconSetCraftswoman: "Craftswoman",
        iconSetCoffeeCup: "Coffee Cup",
        iconSetHamsterWheel: "Hamster Wheel",
        iconSetRobot: "Robot",
        iconSetRabbit: "Rabbit",
        warningOutsideSuffix: ", including the time outside working hours",
        warningBreaksFormat: "More than %1$d h of work require a %2$d min break (§ 4 ArbZG)%3$@",
        warningLongStretchFormat: "%1$@ without a break – at most 6 h in a row are allowed (§ 4 ArbZG)%2$@",
        warningMaxHoursFormat: "%1$@ of work – more than 10 h a day (§ 3 ArbZG)%2$@",
        warningRestFormat: "Rest period only %1$@ – 11 h are required (§ 5 ArbZG)%2$@",
        warningOutsideFrameFormat: "%1$@ outside working hours (%2$@) – not counted",
        warningWeekendCounted: "Work on the weekend – counts as overtime, with no target",
        warningWeekendUncounted: "Work on the weekend – does not count toward the balance",
        warningFreeWeekdayCounted: "Work on a day off – counts as overtime, with no target",
        warningFreeWeekdayUncounted: "Work on a day off – does not count toward the balance",
        spansOneFormat: "%@",
        spansFewFormat: "%1$@ and %2$@",
        spansManyFormat: "%1$d periods (%2$@)",
        limitSoonTitleFormat: "%d min left until 10 h of work",
        limitReachedTitle: "10 h of work reached",
        limitSoonBodyFormat: "%@ worked today – more than 10 h a day are not allowed (§ 3 ArbZG).",
        limitReachedBody: "The maximum working time is reached – more than 10 h a day are not allowed (§ 3 ArbZG).",
        breakSoonTitleFormat: "%d min left until 6 h without a break",
        breakReachedTitle: "6 h worked without a break",
        breakSoonBodyFormat: "%@ without a break – after 6 h in a row at the latest, a break of at least 15 min is required (§ 4 ArbZG).",
        breakReachedBody: "A break of at least 15 min is required now (§ 4 ArbZG)."
    )

    static let de = TimeTrackingTexts(
        workWithoutMac: "Arbeit ohne Mac",
        workBlockFormat: "%1$@ %2$@–%3$@",
        underOneMinute: "unter 1 Min.",
        minutesFormat: "%d Min.",
        joinedSpanFormat: "von %1$@ bis %2$@ (%3$@)",
        andSeparator: " und ",
        joinedRestOneFormat: "Von der manuellen Pause bliebe nur %@ übrig.",
        joinedRestManyFormat: "Von den manuellen Pausen blieben nur %@ übrig.",
        joinedGapOneFormat: "Zur Arbeitszeit daneben bliebe eine Lücke %@.",
        joinedGapManyFormat: "Zur Arbeitszeit daneben blieben Lücken %@.",
        joinedSummaryOneFormat: "Das ist kürzer als die Mindestpause von %1$@; die Zeit wurde dem neuen Abschnitt dazugerechnet. Er reicht jetzt von %2$@ bis %3$@ Uhr.",
        joinedSummaryEachFormat: "Das ist jeweils kürzer als die Mindestpause von %1$@; die Zeit wurde dem neuen Abschnitt dazugerechnet. Er reicht jetzt von %2$@ bis %3$@ Uhr.",
        activityMeeting: "Meeting",
        activityCall: "Telefonat",
        activityNetworking: "Networking",
        activityOther: "Sonstiges",
        absenceVacation: "Urlaub",
        absenceSpecialLeave: "Sonderurlaub",
        absenceSick: "Krank",
        absenceHoliday: "Feiertag",
        absenceTimeOff: "Zeitausgleich",
        absenceHalfFormat: "%@ (halber Tag)",
        absenceShortHalfFormat: "½ %@",
        absenceHalfMarker: "halb",
        absenceCodeVacation: "U",
        absenceCodeSpecialLeave: "SU",
        absenceCodeSick: "K",
        absenceCodeHoliday: "F",
        absenceCodeTimeOff: "ZA",
        freeDayUncounted: "freier Tag, nicht gezählt",
        freeDayCounted: "freier Tag, gezählt",
        freeDayStopped: "freier Tag, nicht erfasst",
        freeDayStoppedMarker: "nicht erfasst",
        freeDayNegationMarker: "nicht",
        durationFormat: "%1$d:%2$02d Std.",
        dailyTargetFormat: "%@ Std.",
        dailyTargetRangeFormat: "%1$@ bis %2$@ Std.",
        weekdayMonday: "Mo",
        weekdayTuesday: "Di",
        weekdayWednesday: "Mi",
        weekdayThursday: "Do",
        weekdayFriday: "Fr",
        weekdaySaturday: "Sa",
        weekdaySunday: "So",
        mondayToFriday: "Mo–Fr",
        listSeparator: ", ",
        weekFormat: "%d-Tage-Woche",
        frameFormat: "%1$@–%2$@ Uhr",
        rulesSummaryFormat: "Arbeitszeitrahmen %1$@  ·  Regelarbeitszeit %2$@ Std./Woche (%3$@)  ·  Pausen ab %4$d Min.%5$@",
        rulesSummaryFreeDays: "  ·  Arbeit an freien Tagen im Saldo",
        decimalSeparator: ",",
        dayFormat: "%1$02d.%2$02d.%3$04d",
        rulesFromFormat: "Ab %1$@: %2$@",
        rulesUntilFormat: "Bis %1$@: %2$@",
        rulesRangeFormat: "%1$@ bis %2$@: %3$@",
        targetBasisFormat: "%1$@ Std./Woche, %2$@",
        targetBasisMixed: "nach den Regeln, die am jeweiligen Tag galten",
        iconSetDayArc: "Tagbogen",
        iconSetLockClock: "Schlossuhr",
        iconSetDayRing: "Tagesring",
        iconSetBuilder: "Bauarbeiter",
        iconSetCraftswoman: "Handwerkerin",
        iconSetCoffeeCup: "Kaffeetasse",
        iconSetHamsterWheel: "Hamsterrad",
        iconSetRobot: "Roboter",
        iconSetRabbit: "Kaninchen",
        warningOutsideSuffix: ", mit der Zeit außerhalb des Arbeitszeitrahmens",
        warningBreaksFormat: "Ab %1$d Std. Arbeit sind %2$d Min. Pause vorgeschrieben (§ 4 ArbZG)%3$@",
        warningLongStretchFormat: "%1$@ ohne Pause – erlaubt sind höchstens 6 Std. am Stück (§ 4 ArbZG)%2$@",
        warningMaxHoursFormat: "%1$@ Arbeitszeit – mehr als 10 Std. am Tag (§ 3 ArbZG)%2$@",
        warningRestFormat: "Ruhezeit nur %1$@ – vorgeschrieben sind 11 Std. (§ 5 ArbZG)%2$@",
        warningOutsideFrameFormat: "%1$@ außerhalb des Arbeitszeitrahmens (%2$@) – nicht gezählt",
        warningWeekendCounted: "Arbeit am Wochenende – zählt ohne Soll als Mehrarbeit",
        warningWeekendUncounted: "Arbeit am Wochenende – zählt nicht im Saldo",
        warningFreeWeekdayCounted: "Arbeit an einem freien Tag – zählt ohne Soll als Mehrarbeit",
        warningFreeWeekdayUncounted: "Arbeit an einem freien Tag – zählt nicht im Saldo",
        spansOneFormat: "%@ Uhr",
        spansFewFormat: "%1$@ und %2$@ Uhr",
        spansManyFormat: "%1$d Zeiträume (%2$@)",
        limitSoonTitleFormat: "Noch %d Min. bis 10 Std. Arbeitszeit",
        limitReachedTitle: "10 Std. Arbeitszeit erreicht",
        limitSoonBodyFormat: "Heute %@ gearbeitet – mehr als 10 Std. am Tag sind nicht erlaubt (§ 3 ArbZG).",
        limitReachedBody: "Die Höchstarbeitszeit ist erreicht – mehr als 10 Std. am Tag sind nicht erlaubt (§ 3 ArbZG).",
        breakSoonTitleFormat: "Noch %d Min. bis 6 Std. ohne Pause",
        breakReachedTitle: "6 Std. ohne Pause gearbeitet",
        breakSoonBodyFormat: "Seit %@ ohne Pause – nach spätestens 6 Std. am Stück ist eine Pause von mindestens 15 Min. vorgeschrieben (§ 4 ArbZG).",
        breakReachedBody: "Jetzt ist eine Pause von mindestens 15 Min. vorgeschrieben (§ 4 ArbZG)."
    )
}
