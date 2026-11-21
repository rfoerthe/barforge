// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Texts of the Time Tracking feature, ported from Tagwerk.
struct TimeTrackingFeatureStrings {
    let title: String
    let hubDescription: String
    let recordToggle: String
    let recordCaption: String
    /// What the section shows, in the panel layout editor.
    let panelDescription: String
    /// Shown while the feature is a beta, until the full Settings page arrives.
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
        panelDescription: "See today’s working time and balance, and pause or end work without opening a window.",
        betaNote: "This beta records working time and shows it in the menu bar. Settings for working hours and reminders and the Records window follow in the next builds."
    )

    static let de = TimeTrackingFeatureStrings(
        title: "Arbeitszeiterfassung",
        hubDescription: "Erfasst die Arbeitszeit automatisch, solange der Mac entsperrt ist, mit Pausen, Saldo und den Regeln des Arbeitszeitgesetzes",
        recordToggle: "Arbeitszeit erfassen",
        recordCaption: "Gezählt wird, solange der Mac entsperrt ist. Eine Sperre ab 15 Minuten ist eine Pause.",
        panelDescription: "Arbeitszeit und Saldo von heute im Blick, Pause und Feierabend ohne ein Fenster zu öffnen.",
        betaNote: "Diese Beta erfasst die Arbeitszeit und zeigt sie in der Menüleiste. Einstellungen für Arbeitszeit und Erinnerungen sowie das Fenster mit den Aufzeichnungen folgen in den nächsten Versionen."
    )

    static let ptBR = TimeTrackingFeatureStrings(
        title: "Registro de jornada",
        hubDescription: "Registre a jornada automaticamente enquanto o Mac está desbloqueado, com pausas, saldo e as regras alemãs de jornada de trabalho",
        recordToggle: "Registrar a jornada",
        recordCaption: "O tempo conta enquanto o Mac está desbloqueado. Um bloqueio de 15 minutos ou mais é uma pausa.",
        panelDescription: "Veja a jornada e o saldo de hoje e pause ou encerre o trabalho sem abrir uma janela.",
        betaNote: "Esta versão beta registra a jornada e a mostra na barra de menus. Os ajustes de jornada e lembretes e a janela de registros chegam nas próximas versões."
    )

    static let tr = TimeTrackingFeatureStrings(
        title: "Çalışma Süresi Takibi",
        hubDescription: "Mac kilidi açıkken çalışma süresini molalar, bakiye ve Alman çalışma süresi kurallarıyla otomatik olarak kaydedin",
        recordToggle: "Çalışma süresini kaydet",
        recordCaption: "Mac kilidi açıkken süre sayılır. 15 dakika veya daha uzun bir kilit moladır.",
        panelDescription: "Bugünkü çalışma süresini ve bakiyeyi görün, pencere açmadan molaya çıkın veya işi bitirin.",
        betaNote: "Bu beta çalışma süresini kaydeder ve menü çubuğunda gösterir. Çalışma süresi ve hatırlatıcı ayarları ile kayıtlar penceresi sonraki sürümlerde gelecek."
    )

    static let ru = TimeTrackingFeatureStrings(
        title: "Учёт рабочего времени",
        hubDescription: "Автоматически учитывайте рабочее время, пока Mac разблокирован, с перерывами, балансом и правилами немецкого закона о рабочем времени",
        recordToggle: "Учитывать рабочее время",
        recordCaption: "Время считается, пока Mac разблокирован. Блокировка от 15 минут считается перерывом.",
        panelDescription: "Рабочее время и баланс за сегодня, а также перерыв и конец рабочего дня без открытия окна.",
        betaNote: "Эта бета учитывает рабочее время и показывает его в строке меню. Настройки рабочего времени и напоминаний, а также окно записей появятся в следующих сборках."
    )

    static let es = TimeTrackingFeatureStrings(
        title: "Registro de jornada",
        hubDescription: "Registra la jornada automáticamente mientras el Mac está desbloqueado, con pausas, saldo y las normas alemanas de jornada laboral",
        recordToggle: "Registrar la jornada",
        recordCaption: "El tiempo cuenta mientras el Mac está desbloqueado. Un bloqueo de 15 minutos o más es una pausa.",
        panelDescription: "Consulta la jornada y el saldo de hoy, y pausa o termina el trabajo sin abrir ninguna ventana.",
        betaNote: "Esta beta registra la jornada y la muestra en la barra de menús. Los ajustes de jornada y recordatorios y la ventana de registros llegan en las próximas versiones."
    )

    static let sk = TimeTrackingFeatureStrings(
        title: "Evidencia pracovného času",
        hubDescription: "Automaticky zaznamenáva pracovný čas, kým je Mac odomknutý, s prestávkami, saldom a pravidlami nemeckého zákona o pracovnom čase",
        recordToggle: "Zaznamenávať pracovný čas",
        recordCaption: "Čas sa počíta, kým je Mac odomknutý. Zamknutie na 15 minút a dlhšie je prestávka.",
        panelDescription: "Dnešný pracovný čas a saldo, prestávka aj koniec práce bez otvárania okna.",
        betaNote: "Táto beta zaznamenáva pracovný čas a zobrazuje ho na lište ponúk. Nastavenia pracovného času a pripomienok a okno záznamov prídu v ďalších verziách."
    )

    static let fr = TimeTrackingFeatureStrings(
        title: "Suivi du temps de travail",
        hubDescription: "Enregistrez automatiquement le temps de travail tant que le Mac est déverrouillé, avec pauses, solde et règles allemandes sur le temps de travail",
        recordToggle: "Enregistrer le temps de travail",
        recordCaption: "Le temps compte tant que le Mac est déverrouillé. Un verrouillage de 15 minutes ou plus est une pause.",
        panelDescription: "Consultez le temps de travail et le solde du jour, et faites une pause ou terminez la journée sans ouvrir de fenêtre.",
        betaNote: "Cette bêta enregistre le temps de travail et l’affiche dans la barre des menus. Les réglages des horaires et des rappels ainsi que la fenêtre des relevés arrivent dans les prochaines versions."
    )

    static let it = TimeTrackingFeatureStrings(
        title: "Registrazione orario di lavoro",
        hubDescription: "Registra automaticamente l’orario di lavoro mentre il Mac è sbloccato, con pause, saldo e regole tedesche sull’orario di lavoro",
        recordToggle: "Registra l’orario di lavoro",
        recordCaption: "Il tempo conta finché il Mac è sbloccato. Un blocco di 15 minuti o più è una pausa.",
        panelDescription: "L’orario di lavoro e il saldo di oggi, con pausa e fine lavoro senza aprire una finestra.",
        betaNote: "Questa beta registra l’orario di lavoro e lo mostra nella barra dei menu. Le impostazioni di orario e promemoria e la finestra delle registrazioni arrivano nelle prossime versioni."
    )

    static let ja = TimeTrackingFeatureStrings(
        title: "勤務時間の記録",
        hubDescription: "Mac のロックが解除されている間の勤務時間を、休憩、残高、ドイツの労働時間規則とともに自動で記録します",
        recordToggle: "勤務時間を記録",
        recordCaption: "Mac のロックが解除されている間を勤務時間として数えます。15 分以上のロックは休憩です。",
        panelDescription: "今日の勤務時間と残高を確認し、ウインドウを開かずに休憩や終業を記録できます。",
        betaNote: "このベータ版は勤務時間を記録し、メニューバーに表示します。勤務時間とリマインダーの設定、記録ウインドウは今後のビルドで追加されます。"
    )

    static let ko = TimeTrackingFeatureStrings(
        title: "근무 시간 기록",
        hubDescription: "Mac 잠금이 해제된 동안 근무 시간을 휴식, 잔여 시간, 독일 근로시간 규정과 함께 자동으로 기록합니다",
        recordToggle: "근무 시간 기록하기",
        recordCaption: "Mac 잠금이 해제된 동안 시간이 계산됩니다. 15분 이상 잠기면 휴식으로 처리됩니다.",
        panelDescription: "오늘의 근무 시간과 잔여 시간을 확인하고, 창을 열지 않고 휴식이나 퇴근을 기록합니다.",
        betaNote: "이 베타는 근무 시간을 기록하고 메뉴 막대에 표시합니다. 근무 시간 및 알림 설정과 기록 창은 다음 빌드에서 제공됩니다."
    )

    static let uk = TimeTrackingFeatureStrings(
        title: "Облік робочого часу",
        hubDescription: "Автоматично враховуйте робочий час, поки Mac розблоковано, з перервами, балансом і правилами німецького закону про робочий час",
        recordToggle: "Враховувати робочий час",
        recordCaption: "Час рахується, поки Mac розблоковано. Блокування від 15 хвилин є перервою.",
        panelDescription: "Робочий час і баланс за сьогодні, а також перерва й кінець робочого дня без відкриття вікна.",
        betaNote: "Ця бета враховує робочий час і показує його в рядку меню. Налаштування робочого часу й нагадувань, а також вікно записів з’являться в наступних збірках."
    )

    static let zhHans = TimeTrackingFeatureStrings(
        title: "工时记录",
        hubDescription: "在 Mac 解锁期间自动记录工作时间，包括休息、余额和德国工时规定",
        recordToggle: "记录工作时间",
        recordCaption: "Mac 解锁期间计入工作时间。锁定 15 分钟或更久即为休息。",
        panelDescription: "查看今天的工作时间和余额，无需打开窗口即可暂停或结束工作。",
        betaNote: "此测试版会记录工作时间并显示在菜单栏中。工时和提醒设置以及记录窗口将在后续版本中提供。"
    )

    static let zhTW = TimeTrackingFeatureStrings(
        title: "工時記錄",
        hubDescription: "在 Mac 解鎖期間自動記錄工作時間，包括休息、餘額和德國工時規定",
        recordToggle: "記錄工作時間",
        recordCaption: "Mac 解鎖期間計入工作時間。鎖定 15 分鐘或更久即為休息。",
        panelDescription: "查看今天的工作時間和餘額，無需打開視窗即可暫停或結束工作。",
        betaNote: "此測試版會記錄工作時間並顯示在選單列中。工時和提醒設定以及記錄視窗將在後續版本中提供。"
    )

    static let zhHK = TimeTrackingFeatureStrings(
        title: "工時記錄",
        hubDescription: "在 Mac 解鎖期間自動記錄工作時間，包括休息、結餘和德國工時規定",
        recordToggle: "記錄工作時間",
        recordCaption: "Mac 解鎖期間計入工作時間。鎖定 15 分鐘或以上即為休息。",
        panelDescription: "查看今天的工作時間和結餘，無需開啟視窗即可暫停或結束工作。",
        betaNote: "此測試版會記錄工作時間並顯示在選單列中。工時和提醒設定以及記錄視窗將於後續版本提供。"
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

    // Export and import (store.rs)
    /// Short weekday, then the day (`Mo, 16.11.2026`).
    let weekdayDateFormat: String
    let exportFormatMarkdown: String
    let exportFormatCSV: String
    let exportFormatPDF: String
    /// App name, first and last day.
    let exportTitleFormat: String
    /// Day and time of the export, then `exportLocksUnderFormat` or
    /// `exportLocksUnderMinimum`, then the frame in parentheses or nothing.
    let exportIntroFormat: String
    let exportLocksUnderFormat: String
    let exportLocksUnderMinimum: String
    let exportRulesHeading: String
    let exportOverviewHeader: String
    /// Number of workdays, `exportWorkdayOne` or `exportWorkdayMany`, working
    /// time, breaks and balance.
    let exportTotalFormat: String
    let exportWorkdayOne: String
    let exportWorkdayMany: String
    /// Target, then `targetNote…`.
    let exportTargetFormat: String
    /// Basis of the target (see `targetBasisFormat`).
    let targetNoteTodayFormat: String
    let targetNoteFormat: String
    let exportWarningsHeading: String
    let exportNoWarnings: String
    let exportWarningsHeader: String
    let exportCorrectionsHeading: String
    let exportCorrectionsIntro: String
    let exportCorrectionsHeader: String
    let correctionStart: String
    let correctionBreak: String
    let correctionEnd: String
    let correctionAbsence: String
    let correctionCounting: String
    let exportPeriodsHeading: String
    /// App name.
    let exportPeriodsIntroFormat: String
    let exportPeriodsHeader: String
    let csvHeader: String
    let csvYes: String
    let csvNo: String
    /// The first skipped days, then `importSkippedMoreFormat` for the rest.
    let importSkippedFormat: String
    /// Day and reason.
    let importSkippedDayFormat: String
    let importSkippedMoreFormat: String
    let importProblemFuture: String
    let importProblemLaterToday: String
    let importProblemBoundsReversed: String
    let importProblemAbsenceWithEntries: String

    // Tracker (tracker.rs)
    /// The end of work the start must precede.
    let refusedStartNotBeforeEndFormat: String
    /// The manual start the end must follow.
    let refusedEndNotAfterStartFormat: String
    /// The start of the working-time frame.
    let refusedEndBeforeFrameFormat: String

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
        breakReachedBody: "A break of at least 15 min is required now (§ 4 ArbZG).",
        weekdayDateFormat: "%1$@, %2$@",
        exportFormatMarkdown: "Markdown (complete, can be imported again)",
        exportFormatCSV: "CSV (table for Excel or Numbers)",
        exportFormatPDF: "PDF (for printing)",
        exportTitleFormat: "# %1$@ – Working time %2$@ to %3$@",
        exportIntroFormat: "Exported on %1$@ at %2$@. Working time = time the Mac was unlocked, combined with the manual corrections; locks %3$@ count as working time. Only time within working hours%4$@ counts. Break time = time between start and end without work. The balance is computed like the Records window, with times in whole minutes.",
        exportLocksUnderFormat: "under %d min",
        exportLocksUnderMinimum: "shorter than the minimum break",
        exportRulesHeading: "Rules:",
        exportOverviewHeader: "| Date | Start | End | Working time | Break time | Balance |",
        exportTotalFormat: "| **Total: %1$d %2$@** | | | **%3$@** | **%4$@** | **%5$@** |",
        exportWorkdayOne: "workday",
        exportWorkdayMany: "workdays",
        exportTargetFormat: "Target: %1$@ (%2$@).",
        targetNoteTodayFormat: "%@; workdays up to yesterday count even without an entry, today only what is already worked",
        targetNoteFormat: "%@; workdays up to yesterday count even without an entry",
        exportWarningsHeading: "## Warnings",
        exportNoWarnings: "No violations of the Working Hours Act or of working hours.",
        exportWarningsHeader: "| Date | Warning |",
        exportCorrectionsHeading: "## Corrections",
        exportCorrectionsIntro: "Set by hand. Kind: Start of work, Break, Work away from the Mac (a call or meeting, for example), End of work, Absence (Vacation, Special leave, Sick, Holiday, Time off) or Recording (free day: recorded time counted or not).",
        exportCorrectionsHeader: "| Date | Kind | From | To | Note |",
        correctionStart: "Start of work",
        correctionBreak: "Break",
        correctionEnd: "End of work",
        correctionAbsence: "Absence",
        correctionCounting: "Recording",
        exportPeriodsHeading: "## Recorded periods",
        exportPeriodsIntroFormat: "Recorded automatically (Mac unlocked, %@ running), unabridged.",
        exportPeriodsHeader: "| Date | From | To |",
        csvHeader: "Date;Weekday;Start;End;Working time;Working time (hours);Breaks;Target;Balance;Absence;Corrected;Warnings",
        csvYes: "yes",
        csvNo: "no",
        importSkippedFormat: "Skipped: %@.",
        importSkippedDayFormat: "%1$@ (%2$@)",
        importSkippedMoreFormat: "and %d more",
        importProblemFuture: "times in the future",
        importProblemLaterToday: "times after the current time",
        importProblemBoundsReversed: "start of work not before the end of work",
        importProblemAbsenceWithEntries: "full-day absence next to other entries",
        refusedStartNotBeforeEndFormat: "The start of work must be before the end of work at %@.",
        refusedEndNotAfterStartFormat: "The end of work must be after the start of work at %@.",
        refusedEndBeforeFrameFormat: "Nothing counts today before %@, when the working-time frame begins. Yesterday already ended with its frame."
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
        breakReachedBody: "Jetzt ist eine Pause von mindestens 15 Min. vorgeschrieben (§ 4 ArbZG).",
        weekdayDateFormat: "%1$@, %2$@",
        exportFormatMarkdown: "Markdown (vollständig, wieder einlesbar)",
        exportFormatCSV: "CSV (Tabelle für Excel)",
        exportFormatPDF: "PDF (zum Drucken)",
        exportTitleFormat: "# %1$@ – Arbeitszeiten %2$@ bis %3$@",
        exportIntroFormat: "Exportiert am %1$@ um %2$@ Uhr. Arbeitszeit = Zeit, in der der Mac entsperrt war, verrechnet mit den manuellen Korrekturen; Sperren %3$@ zählen als Arbeitszeit. Gezählt wird nur im Arbeitszeitrahmen%4$@. Pausenzeit = Zeit zwischen Beginn und Ende, in der nicht gearbeitet wurde. Der Saldo rechnet wie das Fenster „Aufzeichnungen“ mit den Uhrzeiten in ganzen Minuten.",
        exportLocksUnderFormat: "unter %d Min.",
        exportLocksUnderMinimum: "unter der Mindestpause",
        exportRulesHeading: "Regeln:",
        exportOverviewHeader: "| Datum | Beginn | Ende | Arbeitszeit | Pausenzeit | Saldo |",
        exportTotalFormat: "| **Summe: %1$d %2$@** | | | **%3$@** | **%4$@** | **%5$@** |",
        exportWorkdayOne: "Arbeitstag",
        exportWorkdayMany: "Arbeitstage",
        exportTargetFormat: "Soll: %1$@ (%2$@).",
        targetNoteTodayFormat: "%@; Arbeitstage bis gestern auch ohne Eintrag, heute nur das schon Erarbeitete",
        targetNoteFormat: "%@; Arbeitstage bis gestern auch ohne Eintrag",
        exportWarningsHeading: "## Hinweise",
        exportNoWarnings: "Keine Verstöße gegen Arbeitszeitgesetz oder Arbeitszeitrahmen.",
        exportWarningsHeader: "| Datum | Hinweis |",
        exportCorrectionsHeading: "## Korrekturen",
        exportCorrectionsIntro: "Manuell festgelegt. Art: Arbeitsbeginn, Pause, Arbeit ohne Mac (z. B. Telefonat oder Meeting), Feierabend, Abwesenheit (Urlaub, Sonderurlaub, Krank, Feiertag, Zeitausgleich) oder Erfassung (freier Tag: erfasste Zeit gezählt oder nicht).",
        exportCorrectionsHeader: "| Datum | Art | Von | Bis | Notiz |",
        correctionStart: "Arbeitsbeginn",
        correctionBreak: "Pause",
        correctionEnd: "Feierabend",
        correctionAbsence: "Abwesenheit",
        correctionCounting: "Erfassung",
        exportPeriodsHeading: "## Erfasste Perioden",
        exportPeriodsIntroFormat: "Automatisch erfasst (Mac entsperrt, %@ aktiv), ungekürzt.",
        exportPeriodsHeader: "| Datum | Von | Bis |",
        csvHeader: "Datum;Wochentag;Beginn;Ende;Arbeitszeit;Arbeitszeit (Std.);Pausen;Soll;Saldo;Abwesenheit;Korrigiert;Hinweise",
        csvYes: "ja",
        csvNo: "nein",
        importSkippedFormat: "Übersprungen: %@.",
        importSkippedDayFormat: "%1$@ (%2$@)",
        importSkippedMoreFormat: "und %d weitere",
        importProblemFuture: "Zeiten in der Zukunft",
        importProblemLaterToday: "Zeiten nach der jetzigen Uhrzeit",
        importProblemBoundsReversed: "Arbeitsbeginn nicht vor dem Feierabend",
        importProblemAbsenceWithEntries: "ganztägige Abwesenheit neben anderen Einträgen",
        refusedStartNotBeforeEndFormat: "Der Arbeitsbeginn muss vor dem Feierabend um %@ Uhr liegen.",
        refusedEndNotAfterStartFormat: "Der Feierabend muss nach dem Arbeitsbeginn um %@ Uhr liegen.",
        refusedEndBeforeFrameFormat: "Vor %@ Uhr zählt heute noch nichts – der Arbeitszeitrahmen beginnt erst dann. Der gestrige Tag ist mit seinem Rahmen schon zu Ende."
    )
}

/// Texts of the menu bar section, the status item and the notifications
/// (Tagwerk's `menubar.rs` and `notify.rs`). German is Tagwerk's wording; the
/// other languages show English until they are translated.
struct TimeTrackingMenuTexts {
    // Status line
    /// A time of day (`08:05 Uhr`).
    let clockFormat: String
    /// Day, month and time of day on another day than today.
    let dateClockFormat: String
    let statusAbsentFormat: String
    let statusClosedFormat: String
    /// Work away from the Mac outside the working-time frame.
    let statusOutsideSuffixFormat: String
    let statusAwayFormat: String
    /// Since when, then the note (Meeting, Call …).
    let statusAwayNoteFormat: String
    let statusBreakFormat: String
    /// Since when, then the minimum break in minutes.
    let statusBreakPendingFormat: String
    let statusFreeDayStopped: String
    let statusFreeDay: String
    /// The working-time frame.
    let statusOutsideFormat: String
    let statusRunning: String
    let statusIdleFormat: String
    let statusPausedSinceFormat: String
    let statusPaused: String

    // Figures
    let workedToday: String
    let ofTargetFormat: String
    let breaksToday: String
    let startedToday: String
    let manualStart: String
    let weekBalance: String
    let timeAccount: String

    // Database errors
    let dbOpenFailed: String
    let dbOpenConsequence: String
    let dbReadFailed: String
    let dbReadConsequence: String
    let dbWriteFailed: String
    let dbWriteConsequence: String
    /// Feature name, then what failed.
    let dbErrorTitleFormat: String
    /// The error, then what follows from it.
    let dbErrorBodyFormat: String

    // Actions
    let recordToday: String
    let pauseWork: String
    let resumeWork: String
    let backAtMac: String
    let keepWorkingAway: String
    let awayNote: String
    let countBreak: String
    let setStart: String
    let endOfWork: String
    let nowFormat: String
    /// Minutes, then the time of day.
    let minutesAgoFormat: String
    let otherTime: String
    let useFirstUnlockFormat: String
    let removeManualStart: String
    let reopenDay: String
    let records: String
    /// Start, end and length of a break.
    let pauseTitleFormat: String
    let startPrompt: String
    let endPrompt: String
    let apply: String
    let cancel: String
    let offHint: String
    let turnOn: String

    // Status item
    /// Feature name, state, working time and breaks of today.
    let tooltipFormat: String
    let tipRunning: String
    let tipAway: String
    let tipPaused: String
    let tipBreak: String
    let tipFreeDay: String
    let tipOutside: String
    let tipClosed: String
    let tipAbsent: String
    let iconRunning: String
    let iconAway: String
    let iconPaused: String
    let iconBreak: String
    let iconOutside: String
    let iconClosed: String
    let iconAbsent: String

    // Notifications
    let startRefusedTitle: String
    let endRefusedTitle: String
    let workCutTitle: String
    let workCutBeforeStartFormat: String
    let workCutAfterEndFormat: String
    let forgottenTitle: String
    /// Day, then the entry.
    let forgottenBodyFormat: String
    let lockTitleFormat: String
    let lockBody: String
    let lockOtherWork: String
    let lockEndOfWork: String

    // Shortcuts
    let shortcutPause: String
    let shortcutRecords: String
}

extension FeatureStrings {
    static func timeTrackingMenu(_ language: AppLanguage) -> TimeTrackingMenuTexts {
        switch language {
        case .de: return .de
        case .enUS, .ptBR, .tr, .ru, .es, .sk, .fr, .it, .ja, .ko, .uk, .zhHans, .zhTW, .zhHK: return .enUS
        }
    }
}

extension TimeTrackingMenuTexts {
    static let enUS = TimeTrackingMenuTexts(
        clockFormat: "%@",
        dateClockFormat: "%2$d/%1$d %3$@",
        statusAbsentFormat: "Absent today: %@",
        statusClosedFormat: "Done for the day at %@",
        statusOutsideSuffixFormat: "%@ – outside working hours",
        statusAwayFormat: "Away from the Mac since %@",
        statusAwayNoteFormat: "Away from the Mac since %1$@ – %2$@",
        statusBreakFormat: "On a break since %@",
        statusBreakPendingFormat: "On a break since %1$@ (counts from %2$d min)",
        statusFreeDayStopped: "Day off – recording off",
        statusFreeDay: "Day off – recorded time doesn’t count",
        statusOutsideFormat: "Outside working hours (%@)",
        statusRunning: "Recording",
        statusIdleFormat: "No input since %@ – paused",
        statusPausedSinceFormat: "Recording paused since %@",
        statusPaused: "Recording paused",
        workedToday: "Worked today:",
        ofTargetFormat: "of %@",
        breaksToday: "Breaks today:",
        startedToday: "Started today:",
        manualStart: "(manual)",
        weekBalance: "Balance this week:",
        timeAccount: "Time account:",
        dbOpenFailed: "The database could not be opened",
        dbOpenConsequence: "Working time is not recorded until it can be opened.",
        dbReadFailed: "The database could not be read",
        dbReadConsequence: "Changes from the Records window are missing until reading works again.",
        dbWriteFailed: "Saving failed",
        dbWriteConsequence: "Working time keeps counting and is saved once saving works again.",
        dbErrorTitleFormat: "%1$@: %2$@",
        dbErrorBodyFormat: "%1$@. %2$@",
        recordToday: "Record today",
        pauseWork: "Pause work",
        resumeWork: "Resume work",
        backAtMac: "Back at the Mac",
        keepWorkingAway: "Keep working away from the Mac",
        awayNote: "Counts as working time, even while the Mac is locked – until you unlock it.",
        countBreak: "Count a break as working time",
        setStart: "Set start of work",
        endOfWork: "End of work",
        nowFormat: "Now  (%@)",
        minutesAgoFormat: "%1$d min ago  (%2$@)",
        otherTime: "Other time…",
        useFirstUnlockFormat: "Use first unlock  (%@)",
        removeManualStart: "Remove manual start",
        reopenDay: "Undo end of work",
        records: "Records…",
        pauseTitleFormat: "%1$@ – %2$@  (%3$@)",
        startPrompt: "From when does working time count today? A start before the first unlock counts too.",
        endPrompt: "When did work end today? After it nothing counts until tomorrow, unless you undo the end of work.",
        apply: "Apply",
        cancel: "Cancel",
        offHint: "Recording is off. Turn it on to count working time while your Mac is unlocked.",
        turnOn: "Turn On",
        tooltipFormat: "%1$@ – %2$@\nWorked today: %3$@\nBreaks: %4$@",
        tipRunning: "recording",
        tipAway: "work away from the Mac",
        tipPaused: "paused",
        tipBreak: "on a break",
        tipFreeDay: "day off, recorded time doesn’t count",
        tipOutside: "outside working hours",
        tipClosed: "done for the day",
        tipAbsent: "absent today",
        iconRunning: "Recording",
        iconAway: "Work away from the Mac",
        iconPaused: "Recording paused",
        iconBreak: "Break",
        iconOutside: "Outside working hours",
        iconClosed: "End of work",
        iconAbsent: "Absent today",
        startRefusedTitle: "Start of work not changed",
        endRefusedTitle: "No end of work entered",
        workCutTitle: "Work away from the Mac removed",
        workCutBeforeStartFormat: "%@ was before the start of work and no longer counts – the latest entry wins.",
        workCutAfterEndFormat: "%@ was after the end of work and no longer counts – the latest entry wins.",
        forgottenTitle: "Forgot “Back at the Mac”?",
        forgottenBodyFormat: "On %1$@, “Keep working away from the Mac” ran on until working hours ended: %2$@. If the end is wrong, correct it in the Records window.",
        lockTitleFormat: "Locked from %@",
        lockBody: "That counts as a break. Was it work away from the Mac, or were you already done for the day?",
        lockOtherWork: "Other work",
        lockEndOfWork: "End of work",
        shortcutPause: "Pause or resume work",
        shortcutRecords: "Open Records"
    )

    static let de = TimeTrackingMenuTexts(
        clockFormat: "%@ Uhr",
        dateClockFormat: "%1$02d.%2$02d. %3$@ Uhr",
        statusAbsentFormat: "Heute abwesend: %@",
        statusClosedFormat: "Feierabend um %@",
        statusOutsideSuffixFormat: "%@ – außerhalb des Arbeitszeitrahmens",
        statusAwayFormat: "Ohne Mac seit %@",
        statusAwayNoteFormat: "Ohne Mac seit %1$@ – %2$@",
        statusBreakFormat: "Pause seit %@",
        statusBreakPendingFormat: "Pause seit %1$@ (zählt ab %2$d Min.)",
        statusFreeDayStopped: "Freier Tag – Erfassung aus",
        statusFreeDay: "Freier Tag – Erfassung zählt nicht",
        statusOutsideFormat: "Außerhalb des Arbeitszeitrahmens (%@)",
        statusRunning: "Zeiterfassung läuft",
        statusIdleFormat: "Keine Eingabe seit %@ – pausiert",
        statusPausedSinceFormat: "Zeiterfassung pausiert seit %@",
        statusPaused: "Zeiterfassung pausiert",
        workedToday: "Heute gearbeitet:",
        ofTargetFormat: "von %@",
        breaksToday: "Pausen heute:",
        startedToday: "Beginn heute:",
        manualStart: "(manuell)",
        weekBalance: "Saldo diese Woche:",
        timeAccount: "Zeitkonto:",
        dbOpenFailed: "Die Datenbank konnte nicht geöffnet werden",
        dbOpenConsequence: "Die Arbeitszeit wird erst erfasst, wenn sie sich wieder öffnen lässt.",
        dbReadFailed: "Die Datenbank konnte nicht gelesen werden",
        dbReadConsequence: "Änderungen aus dem Fenster „Aufzeichnungen“ fehlen, bis das Lesen wieder gelingt.",
        dbWriteFailed: "Speichern fehlgeschlagen",
        dbWriteConsequence: "Die Arbeitszeit wird weiter gezählt, aber erst gesichert, wenn das Speichern wieder gelingt.",
        dbErrorTitleFormat: "%1$@: %2$@",
        dbErrorBodyFormat: "%1$@. %2$@",
        recordToday: "Heute erfassen",
        pauseWork: "Arbeit unterbrechen",
        resumeWork: "Weiter arbeiten",
        backAtMac: "Zurück am Mac",
        keepWorkingAway: "Ohne Mac weiterarbeiten",
        awayNote: "Zählt als Arbeitszeit, auch bei gesperrtem Mac – bis zum Entsperren.",
        countBreak: "Pause als Arbeitszeit zählen",
        setStart: "Arbeitsbeginn festlegen",
        endOfWork: "Feierabend",
        nowFormat: "Jetzt  (%@)",
        minutesAgoFormat: "Vor %1$d Min.  (%2$@)",
        otherTime: "Andere Uhrzeit …",
        useFirstUnlockFormat: "Erstes Entsperren verwenden  (%@)",
        removeManualStart: "Manuellen Beginn entfernen",
        reopenDay: "Feierabend aufheben",
        records: "Aufzeichnungen …",
        pauseTitleFormat: "%1$@ – %2$@ Uhr  (%3$@)",
        startPrompt: "Ab wann zählt die Arbeitszeit heute? Ein früherer Beginn als das erste Entsperren wird mitgezählt.",
        endPrompt: "Wann war heute Arbeitsende? Danach zählt bis morgen nichts mehr – bis der Feierabend wieder aufgehoben ist.",
        apply: "Übernehmen",
        cancel: "Abbrechen",
        offHint: "Die Erfassung ist aus. Eingeschaltet zählt sie die Arbeitszeit, solange der Mac entsperrt ist.",
        turnOn: "Einschalten",
        tooltipFormat: "%1$@ – %2$@\nHeute gearbeitet: %3$@\nPausen: %4$@",
        tipRunning: "läuft",
        tipAway: "Arbeit ohne Mac",
        tipPaused: "pausiert",
        tipBreak: "Pause",
        tipFreeDay: "freier Tag, Erfassung zählt nicht",
        tipOutside: "außerhalb des Arbeitszeitrahmens",
        tipClosed: "Feierabend",
        tipAbsent: "heute abwesend",
        iconRunning: "Zeiterfassung läuft",
        iconAway: "Arbeit ohne Mac",
        iconPaused: "Zeiterfassung pausiert",
        iconBreak: "Pause",
        iconOutside: "Außerhalb des Arbeitszeitrahmens",
        iconClosed: "Feierabend",
        iconAbsent: "Heute abwesend",
        startRefusedTitle: "Arbeitsbeginn nicht geändert",
        endRefusedTitle: "Kein Feierabend eingetragen",
        workCutTitle: "Arbeit ohne Mac entfällt",
        workCutBeforeStartFormat: "%@ lag vor dem Arbeitsbeginn und zählt nicht mehr – die letzte Angabe gilt.",
        workCutAfterEndFormat: "%@ lag nach dem Feierabend und zählt nicht mehr – die letzte Angabe gilt.",
        forgottenTitle: "„Zurück am Mac“ vergessen?",
        forgottenBodyFormat: "Am %1$@ lief „Ohne Mac weiterarbeiten“ bis zum Ende des Arbeitszeitrahmens weiter: %2$@. Stimmt das Ende nicht, lässt es sich im Fenster „Aufzeichnungen“ korrigieren.",
        lockTitleFormat: "Gesperrt von %@",
        lockBody: "Das zählt als Pause. War es Arbeit ohne Mac oder schon Feierabend?",
        lockOtherWork: "Sonstige Arbeit",
        lockEndOfWork: "Feierabend",
        shortcutPause: "Arbeit unterbrechen bzw. weiter arbeiten",
        shortcutRecords: "Aufzeichnungen öffnen"
    )
}
