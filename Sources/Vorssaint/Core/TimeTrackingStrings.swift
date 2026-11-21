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
        panelDescription: "See today’s working time and balance, and pause or end work without opening a window."
    )

    static let de = TimeTrackingFeatureStrings(
        title: "Arbeitszeiterfassung",
        hubDescription: "Erfasst die Arbeitszeit automatisch, solange der Mac entsperrt ist, mit Pausen, Saldo und den Regeln des Arbeitszeitgesetzes",
        recordToggle: "Arbeitszeit erfassen",
        recordCaption: "Gezählt wird, solange der Mac entsperrt ist. Eine Sperre ab 15 Minuten ist eine Pause.",
        panelDescription: "Arbeitszeit und Saldo von heute im Blick, Pause und Feierabend ohne ein Fenster zu öffnen."
    )

    static let ptBR = TimeTrackingFeatureStrings(
        title: "Registro de jornada",
        hubDescription: "Registre a jornada automaticamente enquanto o Mac está desbloqueado, com pausas, saldo e as regras alemãs de jornada de trabalho",
        recordToggle: "Registrar a jornada",
        recordCaption: "O tempo conta enquanto o Mac está desbloqueado. Um bloqueio de 15 minutos ou mais é uma pausa.",
        panelDescription: "Veja a jornada e o saldo de hoje e pause ou encerre o trabalho sem abrir uma janela."
    )

    static let tr = TimeTrackingFeatureStrings(
        title: "Çalışma Süresi Takibi",
        hubDescription: "Mac kilidi açıkken çalışma süresini molalar, bakiye ve Alman çalışma süresi kurallarıyla otomatik olarak kaydedin",
        recordToggle: "Çalışma süresini kaydet",
        recordCaption: "Mac kilidi açıkken süre sayılır. 15 dakika veya daha uzun bir kilit moladır.",
        panelDescription: "Bugünkü çalışma süresini ve bakiyeyi görün, pencere açmadan molaya çıkın veya işi bitirin."
    )

    static let ru = TimeTrackingFeatureStrings(
        title: "Учёт рабочего времени",
        hubDescription: "Автоматически учитывайте рабочее время, пока Mac разблокирован, с перерывами, балансом и правилами немецкого закона о рабочем времени",
        recordToggle: "Учитывать рабочее время",
        recordCaption: "Время считается, пока Mac разблокирован. Блокировка от 15 минут считается перерывом.",
        panelDescription: "Рабочее время и баланс за сегодня, а также перерыв и конец рабочего дня без открытия окна."
    )

    static let es = TimeTrackingFeatureStrings(
        title: "Registro de jornada",
        hubDescription: "Registra la jornada automáticamente mientras el Mac está desbloqueado, con pausas, saldo y las normas alemanas de jornada laboral",
        recordToggle: "Registrar la jornada",
        recordCaption: "El tiempo cuenta mientras el Mac está desbloqueado. Un bloqueo de 15 minutos o más es una pausa.",
        panelDescription: "Consulta la jornada y el saldo de hoy, y pausa o termina el trabajo sin abrir ninguna ventana."
    )

    static let sk = TimeTrackingFeatureStrings(
        title: "Evidencia pracovného času",
        hubDescription: "Automaticky zaznamenáva pracovný čas, kým je Mac odomknutý, s prestávkami, saldom a pravidlami nemeckého zákona o pracovnom čase",
        recordToggle: "Zaznamenávať pracovný čas",
        recordCaption: "Čas sa počíta, kým je Mac odomknutý. Zamknutie na 15 minút a dlhšie je prestávka.",
        panelDescription: "Dnešný pracovný čas a saldo, prestávka aj koniec práce bez otvárania okna."
    )

    static let fr = TimeTrackingFeatureStrings(
        title: "Suivi du temps de travail",
        hubDescription: "Enregistrez automatiquement le temps de travail tant que le Mac est déverrouillé, avec pauses, solde et règles allemandes sur le temps de travail",
        recordToggle: "Enregistrer le temps de travail",
        recordCaption: "Le temps compte tant que le Mac est déverrouillé. Un verrouillage de 15 minutes ou plus est une pause.",
        panelDescription: "Consultez le temps de travail et le solde du jour, et faites une pause ou terminez la journée sans ouvrir de fenêtre."
    )

    static let it = TimeTrackingFeatureStrings(
        title: "Registrazione orario di lavoro",
        hubDescription: "Registra automaticamente l’orario di lavoro mentre il Mac è sbloccato, con pause, saldo e regole tedesche sull’orario di lavoro",
        recordToggle: "Registra l’orario di lavoro",
        recordCaption: "Il tempo conta finché il Mac è sbloccato. Un blocco di 15 minuti o più è una pausa.",
        panelDescription: "L’orario di lavoro e il saldo di oggi, con pausa e fine lavoro senza aprire una finestra."
    )

    static let ja = TimeTrackingFeatureStrings(
        title: "勤務時間の記録",
        hubDescription: "Mac のロックが解除されている間の勤務時間を、休憩、残高、ドイツの労働時間規則とともに自動で記録します",
        recordToggle: "勤務時間を記録",
        recordCaption: "Mac のロックが解除されている間を勤務時間として数えます。15 分以上のロックは休憩です。",
        panelDescription: "今日の勤務時間と残高を確認し、ウインドウを開かずに休憩や終業を記録できます。"
    )

    static let ko = TimeTrackingFeatureStrings(
        title: "근무 시간 기록",
        hubDescription: "Mac 잠금이 해제된 동안 근무 시간을 휴식, 잔여 시간, 독일 근로시간 규정과 함께 자동으로 기록합니다",
        recordToggle: "근무 시간 기록하기",
        recordCaption: "Mac 잠금이 해제된 동안 시간이 계산됩니다. 15분 이상 잠기면 휴식으로 처리됩니다.",
        panelDescription: "오늘의 근무 시간과 잔여 시간을 확인하고, 창을 열지 않고 휴식이나 퇴근을 기록합니다."
    )

    static let uk = TimeTrackingFeatureStrings(
        title: "Облік робочого часу",
        hubDescription: "Автоматично враховуйте робочий час, поки Mac розблоковано, з перервами, балансом і правилами німецького закону про робочий час",
        recordToggle: "Враховувати робочий час",
        recordCaption: "Час рахується, поки Mac розблоковано. Блокування від 15 хвилин є перервою.",
        panelDescription: "Робочий час і баланс за сьогодні, а також перерва й кінець робочого дня без відкриття вікна."
    )

    static let zhHans = TimeTrackingFeatureStrings(
        title: "工时记录",
        hubDescription: "在 Mac 解锁期间自动记录工作时间，包括休息、余额和德国工时规定",
        recordToggle: "记录工作时间",
        recordCaption: "Mac 解锁期间计入工作时间。锁定 15 分钟或更久即为休息。",
        panelDescription: "查看今天的工作时间和余额，无需打开窗口即可暂停或结束工作。"
    )

    static let zhTW = TimeTrackingFeatureStrings(
        title: "工時記錄",
        hubDescription: "在 Mac 解鎖期間自動記錄工作時間，包括休息、餘額和德國工時規定",
        recordToggle: "記錄工作時間",
        recordCaption: "Mac 解鎖期間計入工作時間。鎖定 15 分鐘或更久即為休息。",
        panelDescription: "查看今天的工作時間和餘額，無需打開視窗即可暫停或結束工作。"
    )

    static let zhHK = TimeTrackingFeatureStrings(
        title: "工時記錄",
        hubDescription: "在 Mac 解鎖期間自動記錄工作時間，包括休息、結餘和德國工時規定",
        recordToggle: "記錄工作時間",
        recordCaption: "Mac 解鎖期間計入工作時間。鎖定 15 分鐘或以上即為休息。",
        panelDescription: "查看今天的工作時間和結餘，無需開啟視窗即可暫停或結束工作。"
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

/// Texts of the Time Tracking settings page and its sheet "Change working
/// time" (Tagwerk's `settings_window.rs`). German is Tagwerk's wording where
/// it has one; the other languages show English until they are translated.
struct TimeTrackingSettingsStrings {
    // Sections
    let generalSection: String
    let workingTimeSection: String
    let recordingSection: String
    let notificationsSection: String
    let dataSection: String

    // General
    let statusItem: String
    let statusItemCaption: String
    let iconSet: String
    let previewRunning: String
    let previewBreak: String
    let previewOutside: String
    let previewClosed: String
    let showTime: String
    let showTimeCaption: String
    let globalShortcuts: String
    let globalShortcutsCaption: String

    // Working time: the list of rules
    let columnFrom: String
    let columnWeekly: String
    let columnWorkdays: String
    let columnFrame: String
    let columnPause: String
    let columnFreeDays: String
    let columnFreeDaysHelp: String
    let rowBeginning: String
    /// Weekly hours in the list (`39 Std.`).
    let weeklyCellFormat: String
    let freeDaysInBalance: String
    let rowTipCurrent: String
    let rowTipPlanned: String
    let rowTipPast: String
    let newRules: String
    let newRulesHelp: String
    let editRules: String
    let deleteRules: String
    let deleteRulesHelp: String
    let rulesCaption: String
    /// Since when (`currentSinceBeginning` or `currentFromFormat`), then the target per workday.
    let currentRulesFormat: String
    let currentSinceBeginning: String
    let currentFromFormat: String
    /// The day, then the target per workday.
    let plannedRulesFormat: String
    /// Target of a workday, then the week (`5-Tage-Woche`).
    let perWorkdayFormat: String
    /// Weekly hours, workdays, target of a workday, frame, minimum break in
    /// minutes, then `rulesSummaryFreeDays` or nothing.
    let rulesLineFormat: String
    let deleteTitleFormat: String
    /// The day, then the rules that apply from it again (`rulesLineFormat`);
    /// the end of the sentence is added unless the rules end with one.
    let deleteInfoFormat: String
    let deleteChangesFormat: String

    // Working time: time account and the Working Hours Act
    let accountStart: String
    let accountStartCaption: String
    let carry: String
    let carryCaption: String
    let carryUnit: String
    let carryError: String
    let legalHints: String
    let legalHintsCaption: String

    // Sheet "Change working time"
    let sheetNewTitle: String
    let sheetFirstTitle: String
    let sheetEditTitleFormat: String
    let validFrom: String
    let regularHours: String
    let hoursPerWeek: String
    let workdays: String
    /// The week (`4-Tage-Woche`), then the target of a workday.
    let dailyNoteFormat: String
    let freeDays: String
    let freeDaysCount: String
    let freeDaysCountHelp: String
    let freeDaysCaption: String
    let frame: String
    let frameTo: String
    let frameFromHelp: String
    let frameToHelp: String
    let frameCaption: String
    let minBreak: String
    let minutes: String
    let minBreakCaption: String
    let apply: String
    let cancel: String
    let hintAllBeforeFormat: String
    let hintAll: String
    /// First and last day.
    let hintRangeFormat: String
    let hintFromFormat: String
    let hintReplacesFormat: String
    let hintSameNothing: String
    let hintSameDropped: String
    /// The changed days (`spans…`).
    let hintRetroactiveFormat: String
    let hintOtherFormat: String
    let spansAll: String
    let spansUntilFormat: String
    let spansFromFormat: String
    let spansDayFormat: String
    /// First and last day.
    let spansRangeFormat: String
    /// Lowest and highest weekly hours.
    let errorWeeklyFormat: String
    /// Lowest and highest minimum break in minutes.
    let errorPauseFormat: String
    let errorWorkday: String
    let errorFrameTimes: String
    let errorFrameMidnight: String
    let errorFrameOrder: String

    // Recording
    let minWork: String
    let minWorkCaption: String
    let atLeast: String
    let minutesShort: String
    /// Lowest and highest minimum length in minutes.
    let errorMinWorkFormat: String
    let idle: String
    let idleCaption: String
    let idleMinutes: String
    /// Lowest and highest idle time in minutes.
    let errorIdleFormat: String
    let askAfterLock: String
    /// Minutes, then `askNoteMinBreak` or nothing.
    let askNoteFormat: String
    let askNoteMinBreak: String
    let autoWorkdaysOnly: String
    let autoWorkdaysOnlyCaption: String

    // Notifications
    let permission: String
    let permissionAllowed: String
    let permissionDenied: String
    let permissionHidden: String
    let permissionUndetermined: String
    let permissionUnavailable: String
    let noteAllowed: String
    let noteHidden: String
    let noteDenied: String
    let noteUnavailable: String
    let openSystemSettings: String
    let notifyLimit: String
    let notifyBreak: String
    let remindersCaption: String
    let remindersOffCaption: String

    // Data
    let dataFolder: String
    let dataFolderCaption: String
    let showInFinder: String
    let takeOver: String
    let takeOverCaption: String
    let takeOverButton: String
    let takeOverMissing: String
    let tagwerkRunning: String
    let takeOverConfirmTitle: String
    let takeOverConfirmInfo: String
    let takeOverConfirmButton: String
    let takeOverDoneTitle: String
    /// Number of days.
    let takeOverDoneFormat: String
    /// Path of the backup.
    let takeOverBackupFormat: String
    let takeOverNoBackup: String
    let takeOverFailedTitle: String
    let resetDefaults: String
    let resetDefaultsCaption: String
    let resetButton: String
    let resetTitle: String
    let resetWhat: String
    /// What the account was (`resetAccountFromFormat`, `resetAccountCarryFormat`).
    let resetAccountFormat: String
    let resetAccountFromFormat: String
    let resetAccountCarryFormat: String
    let resetRulesAlreadyDefault: String
    /// Today, then the default rules (as `deleteInfoFormat`).
    let resetRulesFormat: String
    let resetPlannedOneFormat: String
    /// The earlier days, then the last.
    let resetPlannedManyFormat: String
    let resetStays: String
    let resetConfirm: String
    /// The error.
    let errorSaveFormat: String
    let errorLoadFormat: String
}

extension FeatureStrings {
    static func timeTrackingSettings(_ language: AppLanguage) -> TimeTrackingSettingsStrings {
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

extension TimeTrackingSettingsStrings {
    static let enUS = TimeTrackingSettingsStrings(
        generalSection: "General",
        workingTimeSection: "Working Time",
        recordingSection: "Recording",
        notificationsSection: "Notifications",
        dataSection: "Data",
        statusItem: "Menu bar icon",
        statusItemCaption: "An icon of its own with the state of recording. A click opens the panel on Time Tracking.",
        iconSet: "Icon set",
        previewRunning: "Running",
        previewBreak: "Break",
        previewOutside: "Outside hours or day off",
        previewClosed: "End of work",
        showTime: "Show today’s working time",
        showTimeCaption: "Shows today’s working time next to the icon, for example 6:12.",
        globalShortcuts: "Global shortcuts",
        globalShortcutsCaption: "They work in every app, even with the panel closed.",
        columnFrom: "Valid from",
        columnWeekly: "Week",
        columnWorkdays: "Workdays",
        columnFrame: "Hours",
        columnPause: "Break from",
        columnFreeDays: "Days off",
        columnFreeDaysHelp: "“in balance”: work on days off counts toward balance and time account",
        rowBeginning: "Beginning",
        weeklyCellFormat: "%@ h",
        freeDaysInBalance: "in balance",
        rowTipCurrent: "Applies today",
        rowTipPlanned: "Planned, applies from this day",
        rowTipPast: "Applied before",
        newRules: "New…",
        newRulesHelp: "Add working time rules that apply from a date",
        editRules: "Edit…",
        deleteRules: "Delete",
        deleteRulesHelp: "From its date the rules before apply again",
        rulesCaption: "Each set of rules applies from its date until the next one, so a change does not recompute earlier days. The regular hours spread evenly over the workdays. Other days have no target, and work there only counts toward balance and time account when the rules say so. Outside working hours neither work nor breaks count.",
        currentRulesFormat: "Today the rules %1$@ apply: %2$@.",
        currentSinceBeginning: "since the beginning",
        currentFromFormat: "from %@",
        plannedRulesFormat: "Planned from %1$@: %2$@.",
        perWorkdayFormat: "%1$@ per workday (%2$@)",
        rulesLineFormat: "%1$@ h/week (%2$@, %3$@ per workday)  ·  working hours %4$@  ·  breaks from %5$d min%6$@",
        deleteTitleFormat: "Delete the rules from %@?",
        deleteInfoFormat: "From %1$@ the rules before apply again: %2$@",
        deleteChangesFormat: " The balance and records from %@ on change.",
        accountStart: "Count the time account from a date",
        accountStartCaption: "Off, the time account counts all recorded days.",
        carry: "Carry-over",
        carryCaption: "The time account is the balance of all recorded days, or of those from the date, plus the carry-over: the balance from before, for example +12:30 or −3:15.",
        carryUnit: "h",
        carryError: "The carry-over is a balance such as +12:30 or −3:15.",
        legalHints: "German working time law hints",
        legalHintsCaption: "Checks breaks (§ 4), rest (§ 5) and maximum hours (§ 3) under the German Working Hours Act (ArbZG) and reminds you of breaks and the maximum working time. Off, only the hints about days off and working hours stay.",
        sheetNewTitle: "Change Working Time",
        sheetFirstTitle: "Working Time Since the Beginning",
        sheetEditTitleFormat: "Edit Working Time from %@",
        validFrom: "Valid from:",
        regularHours: "Regular hours:",
        hoursPerWeek: "hours per week",
        workdays: "Workdays:",
        dailyNoteFormat: "%1$@  ·  %2$@ per workday",
        freeDays: "Days off:",
        freeDaysCount: "Count work on days off in balance and time account",
        freeDaysCountHelp: "On, work on the weekend and on deselected workdays counts as overtime in balance and time account. Separately, “Record today” in the panel decides whether time recorded on a day off counts as working time at all.",
        freeDaysCaption: "Weekends and other days off have no target. Off, work there is shown but does not change balance and time account. Whether time recorded there counts as working time at all is up to “Record today” in the panel.",
        frame: "Working hours:",
        frameTo: "to",
        frameFromHelp: "Start of working hours, for example 07:00",
        frameToHelp: "End of working hours, for example 22:00; until midnight: 24:00",
        frameCaption: "Outside this span neither work nor breaks count. Until midnight: 24:00.",
        minBreak: "Minimum break:",
        minutes: "minutes",
        minBreakCaption: "A shorter lock keeps counting as working time. Under the German Working Hours Act breaks only count from 15 minutes.",
        apply: "Apply",
        cancel: "Cancel",
        hintAllBeforeFormat: "Applies to all days before %@.",
        hintAll: "Applies to all days.",
        hintRangeFormat: "Applies from %1$@ to %2$@.",
        hintFromFormat: "Applies from %@.",
        hintReplacesFormat: "Replaces the existing rules from %@.",
        hintSameNothing: "Same as the rules before, so nothing changes.",
        hintSameDropped: "Same as the rules before, so they are dropped.",
        hintRetroactiveFormat: "Retroactive: the balance and records change for %@.",
        hintOtherFormat: "Different rules than before apply to %@.",
        spansAll: "all days",
        spansUntilFormat: "the days until %@",
        spansFromFormat: "the days from %@",
        spansDayFormat: "%@",
        spansRangeFormat: "%1$@ to %2$@",
        errorWeeklyFormat: "The regular hours must be between %1$d and %2$d hours per week.",
        errorPauseFormat: "The minimum break must be between %1$d and %2$d minutes.",
        errorWorkday: "At least one workday must remain.",
        errorFrameTimes: "Working hours need times such as 07:00 or 24:00.",
        errorFrameMidnight: "The end of working hours must come after their start. Midnight as the end is 24:00.",
        errorFrameOrder: "The end of working hours must come after their start.",
        minWork: "Work away from the Mac",
        minWorkCaption: "The shortest entry by hand. Shorter spans cannot be entered in the Records window, which guards against accidental entries.",
        atLeast: "at least",
        minutesShort: "min",
        errorMinWorkFormat: "The minimum length of work away from the Mac must be between %1$d and %2$d minutes.",
        idle: "Pause recording when idle",
        idleCaption: "The unlocked Mac then counts as left: recording ends at the last input, as with a lock. While an app keeps the display awake (video call, presentation), time keeps counting.",
        idleMinutes: "minutes without input",
        errorIdleFormat: "The idle time must be between %1$d and %2$d minutes.",
        askAfterLock: "Ask after a long lock",
        askNoteFormat: "After a lock of %1$d min or more%2$@, a notification asks whether it was work away from the Mac or already the end of work, if the lock began within working hours and ends on the same day. Without an answer it stays a break. Needs notifications.",
        askNoteMinBreak: " (as long as the minimum break)",
        autoWorkdaysOnly: "Count automatic recording only on workdays",
        autoWorkdaysOnlyCaption: "On weekends and other days off time is recorded but only counts as working time after “Record today” in the panel. Entries by hand always count. Whether this time also counts toward balance and time account is up to the working time rules.",
        permission: "Permission",
        permissionAllowed: "Allowed",
        permissionDenied: "Not allowed",
        permissionHidden: "Hidden",
        permissionUndetermined: "Not allowed yet",
        permissionUnavailable: "Only in the installed app",
        noteAllowed: "Reminds you of breaks and the maximum working time in Notification Center, asks after a long lock and reports errors when saving.",
        noteHidden: "Allowed, but notifications appear neither as banners nor in Notification Center. To be reminded and asked, choose a style in System Settings › Notifications.",
        noteDenied: "To be reminded of breaks and the maximum working time and asked after a long lock, turn on “Allow notifications” in System Settings › Notifications.",
        noteUnavailable: "Reminders and the question after a long lock are only available in the installed app.",
        openSystemSettings: "Open System Settings",
        notifyLimit: "Maximum working time (at 9:45 and 10 h of work)",
        notifyBreak: "Break (at 5:45 and 6 h of work in a row)",
        remindersCaption: "Each threshold is reported once while you work. The hints in the panel are not affected.",
        remindersOffCaption: "Off while the German working time law hints are off.",
        dataFolder: "Data folder",
        dataFolderCaption: "The database and its daily backups.",
        showInFinder: "Show in Finder",
        takeOver: "Take over data from Tagwerk",
        takeOverCaption: "Copies Tagwerk’s recorded days, working time rules, time account and settings.",
        takeOverButton: "Take Over…",
        takeOverMissing: "No Tagwerk data found.",
        tagwerkRunning: "Tagwerk is running. Quit it first, or both apps record the same time.",
        takeOverConfirmTitle: "Take over the data from Tagwerk?",
        takeOverConfirmInfo: "This replaces the recorded days, the working time rules and the time account of Time Tracking with Tagwerk’s, and takes over its settings. The current data is backed up first.",
        takeOverConfirmButton: "Take Over",
        takeOverDoneTitle: "Data taken over",
        takeOverDoneFormat: "Days taken over from Tagwerk: %d.",
        takeOverBackupFormat: " The previous data is backed up in %@.",
        takeOverNoBackup: " There was no previous data to back up.",
        takeOverFailedTitle: "The data could not be taken over",
        resetDefaults: "Restore defaults",
        resetDefaultsCaption: "Resets all settings of Time Tracking. The records stay.",
        resetButton: "Restore Defaults…",
        resetTitle: "Reset all settings to their defaults?",
        resetWhat: "This resets the menu bar icon with its icon set and working time, the shortcuts, the German working time law hints, the time account with its carry-over, work away from the Mac, idle time, the question after a long lock, days off (recording) and the reminders.",
        resetAccountFormat: "The time account then counts all recorded days without carry-over (until now %@).",
        resetAccountFromFormat: "from %@",
        resetAccountCarryFormat: "carry-over %@",
        resetRulesAlreadyDefault: "Today’s working time rules already are the defaults.",
        resetRulesFormat: "From today (%1$@) the default rules apply again: %2$@",
        resetPlannedOneFormat: "The rules planned from %@ are dropped.",
        resetPlannedManyFormat: "The rules planned from %1$@ and %2$@ are dropped.",
        resetStays: "“Record working time”, the working time rules until yesterday and all records stay.",
        resetConfirm: "Reset",
        errorSaveFormat: "Saving failed: %@",
        errorLoadFormat: "The database could not be read: %@"
    )

    static let de = TimeTrackingSettingsStrings(
        generalSection: "Allgemein",
        workingTimeSection: "Arbeitszeit",
        recordingSection: "Erfassung",
        notificationsSection: "Mitteilungen",
        dataSection: "Daten",
        statusItem: "Symbol in der Menüleiste",
        statusItemCaption: "Ein eigenes Symbol mit dem Stand der Erfassung. Ein Klick öffnet das Panel bei der Arbeitszeiterfassung.",
        iconSet: "Symbolsatz",
        previewRunning: "läuft",
        previewBreak: "Pause",
        previewOutside: "außerhalb oder frei",
        previewClosed: "Feierabend",
        showTime: "Arbeitszeit von heute zeigen",
        showTimeCaption: "Zeigt die Arbeitszeit von heute neben dem Symbol in der Menüleiste, z. B. 6:12.",
        globalShortcuts: "Kurzbefehle",
        globalShortcutsCaption: "Sie wirken in jeder App, auch bei geschlossenem Panel.",
        columnFrom: "Gültig ab",
        columnWeekly: "Woche",
        columnWorkdays: "Arbeitstage",
        columnFrame: "Rahmen",
        columnPause: "Pause ab",
        columnFreeDays: "Freie Tage",
        columnFreeDaysHelp: "„im Saldo“: Arbeit an freien Tagen geht in Saldo und Zeitkonto ein",
        rowBeginning: "Beginn",
        weeklyCellFormat: "%@ Std.",
        freeDaysInBalance: "im Saldo",
        rowTipCurrent: "Gilt heute",
        rowTipPlanned: "Geplant – gilt ab diesem Tag",
        rowTipPast: "Galt früher",
        newRules: "Neu …",
        newRulesHelp: "Neuen Stand der Arbeitszeitregeln anlegen, gültig ab einem Datum",
        editRules: "Bearbeiten …",
        deleteRules: "Löschen",
        deleteRulesHelp: "Ab dem Datum gilt wieder der Stand davor",
        rulesCaption: "Jeder Stand gilt ab seinem Datum bis zum nächsten – eine Änderung rechnet frühere Tage nicht neu. Die Regelarbeitszeit verteilt sich gleichmäßig auf die Arbeitstage; an den übrigen Tagen gibt es kein Soll, und Arbeit dort geht nur in Saldo und Zeitkonto ein, wenn der Stand es vorsieht. Außerhalb des Rahmens wird weder Arbeitszeit noch eine Pause gezählt.",
        currentRulesFormat: "Heute gilt der Stand %1$@: %2$@.",
        currentSinceBeginning: "seit Beginn",
        currentFromFormat: "ab %@",
        plannedRulesFormat: "Geplant ab %1$@: %2$@.",
        perWorkdayFormat: "%1$@ pro Arbeitstag (%2$@)",
        rulesLineFormat: "%1$@ Std./Woche (%2$@, %3$@ pro Arbeitstag)  ·  Rahmen %4$@  ·  Pausen ab %5$d Min.%6$@",
        deleteTitleFormat: "Stand ab %@ löschen?",
        deleteInfoFormat: "Ab dem %1$@ gilt dann wieder der Stand davor: %2$@",
        deleteChangesFormat: " Saldo und Aufzeichnungen ab dem %@ ändern sich.",
        accountStart: "Zeitkonto erst ab einem Datum zählen",
        accountStartCaption: "Ohne zählt das Zeitkonto alle erfassten Tage.",
        carry: "Übertrag",
        carryCaption: "Das Zeitkonto ist der Saldo aller erfassten Tage – oder erst ab dem Datum – plus Übertrag: der Saldo aus der Zeit davor, z. B. +12:30 oder −3:15.",
        carryUnit: "Std.",
        carryError: "Der Übertrag ist ein Saldo wie +12:30 oder −3:15.",
        legalHints: "Hinweise nach dem Arbeitszeitgesetz",
        legalHintsCaption: "Prüft Pausen (§ 4), Ruhezeit (§ 5) und Höchstarbeitszeit (§ 3) nach dem Arbeitszeitgesetz und erinnert an Pause und Höchstarbeitszeit. Ohne bleiben nur die Hinweise zu freien Tagen und zum Arbeitszeitrahmen.",
        sheetNewTitle: "Arbeitszeit ändern",
        sheetFirstTitle: "Arbeitszeit seit Beginn",
        sheetEditTitleFormat: "Arbeitszeit ab %@ bearbeiten",
        validFrom: "Gültig ab:",
        regularHours: "Regelarbeitszeit:",
        hoursPerWeek: "Stunden pro Woche",
        workdays: "Arbeitstage:",
        dailyNoteFormat: "%1$@  ·  %2$@ pro Arbeitstag",
        freeDays: "Freie Tage:",
        freeDaysCount: "Arbeit an freien Tagen in Saldo und Zeitkonto einrechnen",
        freeDaysCountHelp: "Mit Haken geht Arbeit am Wochenende und an abgewählten Arbeitstagen als Mehrarbeit in Saldo und Zeitkonto ein. Davon unabhängig: „Heute erfassen“ im Panel legt fest, ob die an einem freien Tag erfasste Zeit überhaupt als Arbeitszeit zählt.",
        freeDaysCaption: "Am Wochenende und an den übrigen freien Tagen gibt es kein Soll. Ohne Haken wird Arbeit dort angezeigt, wirkt sich aber nicht auf Saldo und Zeitkonto aus. Ob die automatisch erfasste Zeit dort überhaupt als Arbeitszeit zählt, legt „Heute erfassen“ im Panel fest.",
        frame: "Arbeitszeitrahmen:",
        frameTo: "bis",
        frameFromHelp: "Beginn des Arbeitszeitrahmens, z. B. 07:00",
        frameToHelp: "Ende des Arbeitszeitrahmens, z. B. 22:00 – bis Mitternacht: 24:00",
        frameCaption: "Außerhalb dieses Zeitraums wird weder Arbeitszeit noch eine Pause gezählt. Bis Mitternacht: 24:00.",
        minBreak: "Mindestpause:",
        minutes: "Minuten",
        minBreakCaption: "Ist der Mac kürzer gesperrt, zählt die Zeit weiter zur Arbeitszeit. Nach dem Arbeitszeitgesetz zählen Pausen erst ab 15 Minuten.",
        apply: "Übernehmen",
        cancel: "Abbrechen",
        hintAllBeforeFormat: "Gilt für alle Tage vor dem %@.",
        hintAll: "Gilt für alle Tage.",
        hintRangeFormat: "Gilt vom %1$@ bis %2$@.",
        hintFromFormat: "Gilt ab %@.",
        hintReplacesFormat: "Ersetzt den vorhandenen Stand ab %@.",
        hintSameNothing: "Gleicht dem Stand davor – es ändert sich nichts.",
        hintSameDropped: "Gleicht dem Stand davor und entfällt deshalb.",
        hintRetroactiveFormat: "Rückwirkend: Saldo und Aufzeichnungen %@ ändern sich.",
        hintOtherFormat: "Andere Regeln als bisher gelten %@.",
        spansAll: "aller Tage",
        spansUntilFormat: "bis zum %@",
        spansFromFormat: "ab dem %@",
        spansDayFormat: "am %@",
        spansRangeFormat: "vom %1$@ bis %2$@",
        errorWeeklyFormat: "Die Regelarbeitszeit muss zwischen %1$d und %2$d Stunden pro Woche liegen.",
        errorPauseFormat: "Die Mindestpause muss zwischen %1$d und %2$d Minuten liegen.",
        errorWorkday: "Mindestens ein Arbeitstag muss bleiben.",
        errorFrameTimes: "Der Arbeitszeitrahmen braucht Uhrzeiten wie 07:00 oder 24:00.",
        errorFrameMidnight: "Das Ende des Arbeitszeitrahmens muss nach seinem Beginn liegen – Mitternacht als Ende ist 24:00.",
        errorFrameOrder: "Das Ende des Arbeitszeitrahmens muss nach seinem Beginn liegen.",
        minWork: "Arbeit ohne Mac",
        minWorkCaption: "Mindestdauer eines Eintrags von Hand. Kürzere Abschnitte lassen sich im Fenster „Aufzeichnungen“ nicht eintragen. Das schützt vor versehentlichen Einträgen.",
        atLeast: "mindestens",
        minutesShort: "Min.",
        errorMinWorkFormat: "Die Mindestdauer für Arbeit ohne Mac muss zwischen %1$d und %2$d Minuten liegen.",
        idle: "Erfassung bei Inaktivität anhalten",
        idleCaption: "Der entsperrte Mac gilt dann als verlassen: Die Erfassung endet rückwirkend mit der letzten Eingabe, wie bei einer Sperre. Solange eine App den Bildschirm wach hält (Videokonferenz, Präsentation), zählt die Zeit weiter.",
        idleMinutes: "Minuten ohne Eingabe",
        errorIdleFormat: "Die Inaktivität muss zwischen %1$d und %2$d Minuten liegen.",
        askAfterLock: "Beim Entsperren nach langer Sperre nachfragen",
        askNoteFormat: "Ab %1$d Min. Sperre%2$@ fragt eine Mitteilung, ob es Arbeit ohne Mac oder schon Feierabend war – sofern die Sperre im Arbeitszeitrahmen begonnen hat und am selben Tag endet. Ohne Antwort bleibt es eine Pause. Braucht Mitteilungen.",
        askNoteMinBreak: " (so lang wie die Mindestpause)",
        autoWorkdaysOnly: "Automatische Erfassung nur an Arbeitstagen zählen",
        autoWorkdaysOnlyCaption: "Am Wochenende und an den übrigen freien Tagen wird erfasst, aber erst als Arbeitszeit gezählt, wenn im Panel „Heute erfassen“ gewählt ist. Einträge von Hand zählen immer. Ob diese Arbeitszeit auch in Saldo und Zeitkonto eingeht, legt der Stand der Arbeitszeitregeln fest.",
        permission: "Berechtigung",
        permissionAllowed: "Erlaubt",
        permissionDenied: "Nicht erlaubt",
        permissionHidden: "Ausgeblendet",
        permissionUndetermined: "Noch nicht erlaubt",
        permissionUnavailable: "Nur in der installierten App",
        noteAllowed: "Erinnert über die Mitteilungszentrale an Pause und Höchstarbeitszeit, fragt nach langer Sperre nach und meldet Fehler beim Speichern.",
        noteHidden: "Erlaubt, aber Mitteilungen erscheinen weder als Banner noch in der Mitteilungszentrale. Damit erinnert und nachgefragt werden kann, unter Systemeinstellungen › Mitteilungen einen Stil wählen.",
        noteDenied: "Damit an Pause und Höchstarbeitszeit erinnert und nach langer Sperre nachgefragt werden kann, unter Systemeinstellungen › Mitteilungen „Mitteilungen erlauben“ einschalten.",
        noteUnavailable: "Erinnerungen und die Nachfrage nach langer Sperre gibt es nur in der installierten App.",
        openSystemSettings: "Systemeinstellungen öffnen",
        notifyLimit: "Höchstarbeitszeit (bei 9:45 und 10 Std. Arbeit)",
        notifyBreak: "Pause (bei 5:45 und 6 Std. Arbeit am Stück)",
        remindersCaption: "Jede Schwelle wird einmal gemeldet, solange gearbeitet wird. Die Hinweise im Panel bleiben davon unberührt.",
        remindersOffCaption: "Aus, solange die Hinweise nach dem Arbeitszeitgesetz aus sind.",
        dataFolder: "Datenordner",
        dataFolderCaption: "Die Datenbank und ihre täglichen Backups.",
        showInFinder: "Im Finder zeigen",
        takeOver: "Daten aus Tagwerk übernehmen",
        takeOverCaption: "Übernimmt die erfassten Tage, die Arbeitszeitregeln, das Zeitkonto und die Einstellungen von Tagwerk.",
        takeOverButton: "Übernehmen …",
        takeOverMissing: "Keine Daten von Tagwerk gefunden.",
        tagwerkRunning: "Tagwerk läuft. Erst beenden, sonst erfassen beide Apps dieselbe Zeit.",
        takeOverConfirmTitle: "Daten aus Tagwerk übernehmen?",
        takeOverConfirmInfo: "Das ersetzt die erfassten Tage, die Arbeitszeitregeln und das Zeitkonto der Arbeitszeiterfassung durch die von Tagwerk und übernimmt seine Einstellungen. Die bisherigen Daten werden vorher gesichert.",
        takeOverConfirmButton: "Übernehmen",
        takeOverDoneTitle: "Daten übernommen",
        takeOverDoneFormat: "Aus Tagwerk übernommene Tage: %d.",
        takeOverBackupFormat: " Die bisherigen Daten sind gesichert in %@.",
        takeOverNoBackup: " Bisher gab es keine Daten zu sichern.",
        takeOverFailedTitle: "Die Daten konnten nicht übernommen werden",
        resetDefaults: "Standardwerte wiederherstellen",
        resetDefaultsCaption: "Setzt alle Einstellungen der Arbeitszeiterfassung zurück. Die Aufzeichnungen bleiben.",
        resetButton: "Standardwerte …",
        resetTitle: "Alle Einstellungen auf Standardwerte zurücksetzen?",
        resetWhat: "Zurückgesetzt werden Symbol, Symbolsatz und Arbeitszeit in der Menüleiste, Kurzbefehle, die Hinweise nach dem Arbeitszeitgesetz, Zeitkonto samt Übertrag, Arbeit ohne Mac, Inaktivität, Nachfrage nach langer Sperre, freie Tage (Erfassung) und Erinnerungen.",
        resetAccountFormat: "Das Zeitkonto zählt danach alle erfassten Tage ohne Übertrag (bisher %@).",
        resetAccountFromFormat: "ab %@",
        resetAccountCarryFormat: "Übertrag %@",
        resetRulesAlreadyDefault: "Die Arbeitszeitregeln von heute sind schon die Standardwerte.",
        resetRulesFormat: "Ab heute (%1$@) gelten wieder die Standardregeln: %2$@",
        resetPlannedOneFormat: "Der geplante Stand ab %@ entfällt.",
        resetPlannedManyFormat: "Die geplanten Stände ab %1$@ und %2$@ entfallen.",
        resetStays: "Es bleiben „Arbeitszeit erfassen“, die Arbeitszeitregeln bis gestern und alle Aufzeichnungen.",
        resetConfirm: "Zurücksetzen",
        errorSaveFormat: "Speichern fehlgeschlagen: %@",
        errorLoadFormat: "Die Datenbank konnte nicht gelesen werden: %@"
    )
}

/// Texts of the Records window: table, cards, inspector, undo, export and
/// import (Tagwerk's `records.rs` and `pdf.rs`). German is Tagwerk's wording;
/// the other languages show English until they are translated.
struct TimeTrackingRecordsStrings {
    // Window and toolbar
    let windowTitle: String
    /// Subtitle while recording is off.
    let subtitleOff: String
    let viewLabel: String
    let viewTip: String
    let days: String
    let week: String
    let daysTip: String
    let weekTip: String
    let filter: String
    let filterTip: String
    let filterActiveTip: String
    let periodAll: String
    let periodThisMonth: String
    let periodLastMonth: String
    let periodThisYear: String
    let periodLastYear: String
    let filterWarnings: String
    let filterCorrected: String
    let filterReset: String
    let refresh: String
    let refreshTip: String
    let editDay: String
    let editDayTip: String
    let export: String
    let exportTip: String
    let importLabel: String
    let importTip: String
    let inspector: String
    let inspectorTip: String
    let showInWeek: String
    let today: String

    // Cards
    let cardToday: String
    let cardWeek: String
    let cardMonth: String
    let cardAverage: String
    let cardAccount: String
    /// Hours and minutes of today's target.
    let targetFormat: String
    let notAWorkday: String
    let startFormat: String
    let startManualFormat: String
    let detailSeparator: String
    /// Workdays; the balance follows in colour.
    let balanceDetailFormat: String
    /// Average breaks, then the month.
    let averageDetailFormat: String
    let accountFromFormat: String
    let accountSinceFormat: String
    let accountNothingYet: String
    /// Since when, then the carry.
    let accountCarryFormat: String
    let workdaysOneFormat: String
    let workdaysManyFormat: String
    /// Weekday, day, month and year.
    let longDateFormat: String
    /// Monday first.
    let weekdayNames: [String]
    let monthNames: [String]

    // Table
    let columnDate: String
    let columnStart: String
    let columnEnd: String
    let columnWork: String
    let columnBreaks: String
    let columnBalance: String
    let markColumnTip: String
    /// ISO week, first and last day.
    let weekTitleFormat: String
    /// Day and month of the Monday (the Sunday follows in full).
    let weekStartFormat: String
    /// Workdays and total; the balance follows in colour.
    let weekTotalFormat: String
    let running: String
    let warningTip: String
    let correctedTip: String
    let missingTip: String

    // Footer
    let footerRecordedFormat: String
    /// Days shown, then `footerDays…Format`.
    let footerFilterFormat: String
    let footerDaysOneFormat: String
    let footerDaysManyFormat: String
    let footerSeparator: String
    /// Day, then the rules.
    let rulesOnFormat: String

    // Inspector
    let noDayTitle: String
    let noDayHint: String
    let statWork: String
    let statBreaks: String
    let statBalance: String
    let noteFutureWorkday: String
    let noteFutureFreeDay: String
    let noteNoWorkNoTarget: String
    let noteFreeDayUncounted: String
    let noteNoWorkInFrame: String
    let noteNothingYet: String
    let explanation: String
    let sectionAbsence: String
    let sectionRecording: String
    let sectionStart: String
    let sectionBreaks: String
    let sectionWork: String
    let sectionEnd: String
    let sectionRecorded: String
    let helpAbsence: String
    /// `countBalanceYes` or `countBalanceNo`.
    let helpRecordingFormat: String
    let helpStart: String
    /// Minimum break in minutes.
    let helpBreaksFormat: String
    let helpWork: String
    let helpEnd: String
    /// The working-time frame.
    let helpRecordedFormat: String
    let absenceNone: String
    let wholeDay: String
    let halfDay: String
    let partTipNone: String
    let partTip: String
    let freeDayAbsence: String
    let wholeDayBlocked: String
    let lockedByAbsence: String
    let effectNoTarget: String
    let effectFreeDay: String
    let effectKeepsTargetFormat: String
    /// Full and lowered target.
    let effectLowersFormat: String
    let countRecorded: String
    let countBalanceYes: String
    let countBalanceNo: String
    /// `countBalanceYes` or `countBalanceNo`.
    let countTipFormat: String
    let freeDayCountedInBalance: String
    let freeDayCountedNotInBalance: String
    let freeDayStoppedNote: String
    let freeDayUncountedNote: String
    let setManually: String
    let futureText: String
    let uncountedNote: String
    let inFrameSuffix: String
    /// `inFrameSuffix` or nothing, then the time.
    let startNoteFormat: String
    let startNoteNone: String
    let endNoteFormat: String
    let endNoteNone: String
    let endNoteToday: String
    let startCut: String
    let endCut: String
    let noBreaks: String
    let to: String
    let add: String
    let removeBreak: String
    /// Minimum break in minutes.
    let breakMinFormat: String
    let breakOrder: String
    let nothingEntered: String
    let reason: String
    let removeWork: String
    /// Minimum length in minutes.
    let minWorkFormat: String
    let workOrder: String
    let gapAddedTitle: String
    let recordedToggleTip: String
    let recordedNone: String
    let recordedOneFormat: String
    let recordedManyFormat: String
    /// Count, first and last time.
    let recordedSummaryFormat: String
    let clearDay: String
    let clearDayTip: String

    // Edits and refusals
    let editSetStart: String
    let editSetEnd: String
    let editAddBreak: String
    let editRemoveBreak: String
    let editAddWork: String
    let editRemoveWork: String
    let editSetAbsence: String
    let editCountOn: String
    let editCountOff: String
    let editClearDay: String
    /// The time now.
    let laterThanNowFormat: String
    /// First recorded day, the new day, `beforeFirstBetween…`, hours.
    let beforeFirstFormat: String
    let beforeFirstBetweenOne: String
    let beforeFirstBetweenManyFormat: String
    /// The long date.
    let beforeFirstTitleFormat: String
    let enter: String
    let cancel: String
    let ok: String
    let notSaved: String
    let saveFailed: String
    let workCutTitle: String

    // Undo and redo
    let undo: String
    let redo: String
    /// Undo or redo, then the step.
    let historyTitleFormat: String
    /// Name and day of the step.
    let rewindStepFormat: String
    let partialUndoTitle: String
    let partialRedoTitle: String
    let partialUndoFormat: String
    let partialRedoFormat: String
    let refusedUndoTitle: String
    let refusedRedoTitle: String
    let refusedUndoFormat: String
    let refusedRedoFormat: String
    let whyChangedFormat: String
    let whyOrder: String
    let whyAbsenceBesideEntries: String
    let fieldStart: String
    let fieldBreaks: String
    let fieldWork: String
    let fieldEnd: String
    let fieldAbsence: String
    let fieldCounting: String

    // Delete all entries, absence today, edit day
    /// The long date.
    let clearTitleFormat: String
    let delete: String
    let deleteFailed: String
    let clearPeriodsOne: String
    let clearPeriodsManyFormat: String
    let clearStart: String
    let clearBreaksOne: String
    let clearBreaksManyFormat: String
    let clearWorkOne: String
    let clearWorkManyFormat: String
    let clearEnd: String
    let clearAbsenceFormat: String
    let clearNothing: String
    let clearAffectsFormat: String
    let clearTodayFreeDay: String
    let clearTodayContinues: String
    let undoHint: String
    /// The absence.
    let absenceTodayTitleFormat: String
    /// The time recorded today.
    let absenceTodayFormat: String
    let absenceTodayHalf: String
    let absenceWholeButton: String
    let absenceHalfButton: String
    let editDayMessage: String
    let open: String

    // Export
    let exportMessage: String
    let presetLastFourWeeks: String
    let presetCustom: String
    let periodLabel: String
    let fromLabel: String
    let formatLabel: String
    /// Workdays, working time, balance.
    let exportSummaryFormat: String
    let exportSavedTitle: String
    /// First day, last day, file name.
    let exportSavedFormat: String
    let showInFinder: String
    let exportFailedTitle: String
    let readFailedFormat: String
    let writeFailedFormat: String
    /// App name, first and last day.
    let pdfTitleFormat: String
    /// Day and time.
    let pdfExportedFormat: String
    let pdfWeekFormat: String
    /// Number of workdays and the word.
    let pdfTotalFormat: String
    /// Target and its note.
    let pdfTargetFormat: String
    let pdfWarningsHeading: String

    // Import
    let importMessage: String
    let importReadFailedFormat: String
    let importFailedTitle: String
    let noRecordsTitle: String
    let noRecordsFormat: String
    let nothingToImportTitle: String
    /// File name, skipped days.
    let nothingToImportFormat: String
    /// Days, first and last day.
    let importConfirmFormat: String
    let importDaysOneFormat: String
    let importDaysManyFormat: String
    let importNoExisting: String
    let importExistingFormat: String
    let importBackupNote: String
    let importDoneTitle: String
    let importedFormat: String
    /// Days, then the backup file.
    let importedBackupFormat: String
}

extension FeatureStrings {
    static func timeTrackingRecords(_ language: AppLanguage) -> TimeTrackingRecordsStrings {
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

extension TimeTrackingRecordsStrings {
    static let enUS = TimeTrackingRecordsStrings(
        windowTitle: "Records",
        subtitleOff: "Recording is off",
        viewLabel: "View",
        viewTip: "Switch between days and week",
        days: "Days",
        week: "Week",
        daysTip: "Table with inspector (⌘1)",
        weekTip: "Week as a calendar (⌘2)",
        filter: "Filter",
        filterTip: "Limit the table to a period or certain days",
        filterActiveTip: "Filter on – the table doesn’t show all days",
        periodAll: "All Days",
        periodThisMonth: "This Month",
        periodLastMonth: "Last Month",
        periodThisYear: "This Year",
        periodLastYear: "Last Year",
        filterWarnings: "Only Days with Warnings",
        filterCorrected: "Only Corrected Days",
        filterReset: "Reset Filter",
        refresh: "Refresh",
        refreshTip: "Reload the records (⌘R)",
        editDay: "Edit Day",
        editDayTip: "Open any day and add times (⌘N)",
        export: "Export",
        exportTip: "Export a period as Markdown, CSV or PDF (⌘E)",
        importLabel: "Import",
        importTip: "Read a Markdown export back in (⇧⌘I)",
        inspector: "Inspector",
        inspectorTip: "Show or hide the inspector (⌥⌘I)",
        showInWeek: "Show in Week View",
        today: "Today",
        cardToday: "Today",
        cardWeek: "This Week",
        cardMonth: "This Month",
        cardAverage: "Ø per Workday",
        cardAccount: "Time Account",
        targetFormat: "Target %@",
        notAWorkday: "Not a workday",
        startFormat: "Start %@",
        startManualFormat: "Start %@ (manual)",
        detailSeparator: " · ",
        balanceDetailFormat: "%@ · Balance ",
        averageDetailFormat: "Breaks Ø %1$@ · %2$@",
        accountFromFormat: "from %@",
        accountSinceFormat: "since %@",
        accountNothingYet: "nothing recorded yet",
        accountCarryFormat: "%1$@ · carried over %2$@",
        workdaysOneFormat: "%d workday",
        workdaysManyFormat: "%d workdays",
        longDateFormat: "%1$@, %3$@ %2$d, %4$d",
        weekdayNames: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
        monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September",
                     "October", "November", "December"],
        columnDate: "Date",
        columnStart: "Start",
        columnEnd: "End",
        columnWork: "Working Time",
        columnBreaks: "Breaks",
        columnBalance: "Balance",
        markColumnTip: "Warnings about rule violations and corrections by hand",
        weekTitleFormat: "Week %1$d  ·  %2$@ – %3$@",
        weekStartFormat: "%2$02d-%1$02d",
        weekTotalFormat: "%1$@  ·  %2$@  ·  Balance ",
        running: "running",
        warningTip: "Warning",
        correctedTip: "Corrected by hand",
        missingTip: "Nothing recorded – the workday counts with its target. Times or an absence can be added in the inspector.",
        footerRecordedFormat: "%@ recorded",
        footerFilterFormat: "Filter: %1$d of %2$@",
        footerDaysOneFormat: "%d day",
        footerDaysManyFormat: "%d days",
        footerSeparator: "  ·  ",
        rulesOnFormat: "Rules on %1$@: %2$@",
        noDayTitle: "No Day Selected",
        noDayHint: "Select a day in the list to correct the start of work, breaks, work away from the Mac or the end of work.",
        statWork: "Working Time",
        statBreaks: "Breaks",
        statBalance: "Balance",
        noteFutureWorkday: "Future day – only an absence can be entered.",
        noteFutureFreeDay: "Future day off – there is nothing to enter here.",
        noteNoWorkNoTarget: "No working time, no target.",
        noteFreeDayUncounted: "Day off – the recorded time doesn’t count.",
        noteNoWorkInFrame: "No working time within working hours.",
        noteNothingYet: "Nothing recorded for this day yet.",
        explanation: "Explanation",
        sectionAbsence: "Absence",
        sectionRecording: "Recording",
        sectionStart: "Start of Work",
        sectionBreaks: "Breaks",
        sectionWork: "Work Away from the Mac",
        sectionEnd: "End of Work",
        sectionRecorded: "Recorded Automatically",
        helpAbsence: "Vacation, sickness and holidays lower the day’s target, a half day to half; special leave always applies to the whole day. Time off keeps the target, even without working time – the time account goes down accordingly. A whole-day absence only works on a day without other entries: delete them first with “Delete All Entries…” below. A half day also works next to working time – choose “Half Day” for it, also before the kind. Days off (weekend, deselected workdays) have no target and therefore no absence.",
        helpRecordingFormat: "On days off (weekend, deselected workdays) the time recorded automatically only counts as working time once it should count – “Record today” in the panel. Until then the start of work, breaks and the end of work can’t be set; work away from the Mac always counts. %@",
        helpStart: "Without an entry the day starts with the first unlock. If the Mac was locked at the start, the time until the unlock after it counts too; what was recorded before goes. Work away from the Mac before a newly set start goes – the latest entry wins.",
        helpBreaksFormat: "Locks from %d min on count as breaks by themselves, shorter ones count as working time. Additional breaks can be entered here.",
        helpWork: "A call, meeting or appointment while the Mac was locked: these times count as working time. A break in that time goes.",
        helpEnd: "Without an entry the day ends with the last lock. If the Mac was locked at the end of work, the time since the lock before it counts too; what was recorded after goes. Work away from the Mac after a newly set end of work goes – the latest entry wins.",
        helpRecordedFormat: "Times the Mac was unlocked. Only what lies within working hours (%@) counts. The triangle shows and hides the single times – for all days.",
        absenceNone: "None",
        wholeDay: "Whole Day",
        halfDay: "Half Day",
        partTipNone: "Whole or half day – applies to the kind chosen next. A half day also works next to working time.",
        partTip: "Vacation, sickness and holidays come as half days too; a half day also works next to working time.",
        freeDayAbsence: "Days off (weekend, deselected workdays) have no target – an absence can’t be entered there, an existing one can only be removed.",
        wholeDayBlocked: "A whole day only once the day has no other entries – see “Delete All Entries…” below.",
        lockedByAbsence: "The start of work, breaks, work away from the Mac and the end of work can only be changed once the absence is set to “None”.",
        effectNoTarget: "This day has no target – the absence changes nothing about it. Remove it with “None”.",
        effectFreeDay: "Day off without a target – there is no absence to enter here.",
        effectKeepsTargetFormat: "The target of %@ stays, even without working time – the time account goes down accordingly.",
        effectLowersFormat: "The target goes down from %1$@ to %2$@.",
        countRecorded: "Count recorded time",
        countBalanceYes: "On this day it goes into balance and time account – the working time rules count work on days off.",
        countBalanceNo: "On this day it still doesn’t go into balance and time account: that only happens when “Count work on days off in balance and time account” is on in the working time rules.",
        countTipFormat: "Checked, the time recorded automatically counts as working time. %@",
        freeDayCountedInBalance: "Day off: the time recorded automatically counts as working time, also in balance and time account.",
        freeDayCountedNotInBalance: "Day off: the time recorded automatically counts as working time – by the working time rules it doesn’t go into balance and time account.",
        freeDayStoppedNote: "Day off: all entries were deleted, automatic recording is off. Checked, it counts again.",
        freeDayUncountedNote: "Day off: the time recorded automatically doesn’t count. The start of work, breaks and the end of work can only be set once checked; work away from the Mac always counts.",
        setManually: "Set manually",
        futureText: "On future days only an absence can be entered – times once the day has come.",
        uncountedNote: "Only once the recorded time counts (see “Recording” above).",
        inFrameSuffix: " within working hours",
        startNoteFormat: "Without an entry the first unlock%1$@ at %2$@ applies. If the Mac was locked at the start, the time until the unlock after it counts too.",
        startNoteNone: "Without an entry the first unlock of the Mac within working hours applies.",
        endNoteFormat: "Without an entry the last lock%1$@ at %2$@ applies. If the Mac was locked at the end of work, the time since the lock before it counts too.",
        endNoteNone: "Without an entry the last lock of the Mac within working hours applies.",
        endNoteToday: "Without an entry the last lock applies. After the end of work nothing more is recorded today.",
        startCut: "Work away from the Mac before the start of work was removed – the latest entry wins. ⌘Z takes it back.",
        endCut: "Work away from the Mac after the end of work was removed – the latest entry wins. ⌘Z takes it back.",
        noBreaks: "No breaks entered",
        to: "to",
        add: "Add",
        removeBreak: "Remove Break",
        breakMinFormat: "A break lasts at least %d min (see Settings).",
        breakOrder: "The end of the break must be after its start.",
        nothingEntered: "Nothing entered",
        reason: "Reason",
        removeWork: "Remove Work Away from the Mac",
        minWorkFormat: "Work away from the Mac lasts at least %d min (see Settings).",
        workOrder: "The end of the work away from the Mac must be after its start.",
        gapAddedTitle: "Gap Added",
        recordedToggleTip: "Show or hide the times recorded automatically",
        recordedNone: "None – the Mac was not unlocked.",
        recordedOneFormat: "%d period",
        recordedManyFormat: "%d periods",
        recordedSummaryFormat: "%1$@, %2$@ – %3$@",
        clearDay: "Delete All Entries…",
        clearDayTip: "Deletes the times recorded automatically and every entry made by hand on this day.",
        editSetStart: "Change Start of Work",
        editSetEnd: "Change End of Work",
        editAddBreak: "Add Break",
        editRemoveBreak: "Remove Break",
        editAddWork: "Add Work Away from the Mac",
        editRemoveWork: "Remove Work Away from the Mac",
        editSetAbsence: "Change Absence",
        editCountOn: "Count Recorded Time",
        editCountOff: "Don’t Count Recorded Time",
        editClearDay: "Delete All Entries",
        laterThanNowFormat: "Times after now (%@) can’t be entered.",
        beforeFirstFormat: "So far the records begin on %1$@. With an entry on %2$@, %3$@ – together about %4$d h in the minus in balance and time account, until times or absences are entered there.",
        beforeFirstBetweenOne: "the workday in between counts with its target too",
        beforeFirstBetweenManyFormat: "the %d workdays in between count with their target too",
        beforeFirstTitleFormat: "Entry before the first recorded day on %@?",
        enter: "Enter",
        cancel: "Cancel",
        ok: "OK",
        notSaved: "Not Saved",
        saveFailed: "Saving Failed",
        workCutTitle: "Work Away from the Mac Removed",
        undo: "Undo",
        redo: "Redo",
        historyTitleFormat: "%1$@ %2$@",
        rewindStepFormat: "“%1$@” from %2$@",
        partialUndoTitle: "Only Partly Undone",
        partialRedoTitle: "Only Partly Redone",
        partialUndoFormat: "%1$@ was only partly undone. Changed differently since and therefore kept: %2$@.",
        partialRedoFormat: "%1$@ was only partly redone. Changed differently since and therefore kept: %2$@.",
        refusedUndoTitle: "Not Undone",
        refusedRedoTitle: "Not Redone",
        refusedUndoFormat: "%1$@ can no longer be undone – %2$@. The day stays as it is.",
        refusedRedoFormat: "%1$@ can no longer be redone – %2$@. The day stays as it is.",
        whyChangedFormat: "changed differently since: %@",
        whyOrder: "the start of work would then not be before the end of work",
        whyAbsenceBesideEntries: "the full-day absence would then stand next to entries recorded since",
        fieldStart: "start of work",
        fieldBreaks: "breaks",
        fieldWork: "work away from the Mac",
        fieldEnd: "end of work",
        fieldAbsence: "absence",
        fieldCounting: "count recorded time",
        clearTitleFormat: "Delete all entries of %@?",
        delete: "Delete",
        deleteFailed: "Deleting Failed",
        clearPeriodsOne: "1 period recorded automatically",
        clearPeriodsManyFormat: "%d periods recorded automatically",
        clearStart: "the start of work set by hand",
        clearBreaksOne: "1 break entered",
        clearBreaksManyFormat: "%d breaks entered",
        clearWorkOne: "1 entry of work away from the Mac",
        clearWorkManyFormat: "%d entries of work away from the Mac",
        clearEnd: "the end of work set by hand",
        clearAbsenceFormat: "the absence “%@”",
        clearNothing: "nothing",
        clearAffectsFormat: "This affects %@.",
        clearTodayFreeDay: " Automatic recording stays off today until “Record today” is chosen in the panel.",
        clearTodayContinues: " Automatic recording then goes on from now.",
        undoHint: " ⌘Z takes it back.",
        absenceTodayTitleFormat: "Enter “%@” for the whole day today?",
        absenceTodayFormat: "The time recorded automatically today (%@) is deleted, and recording ends for today – until the absence is set back to “None”. ⌘Z takes it back.",
        absenceTodayHalf: " A half day also works next to the recorded time – it then stays.",
        absenceWholeButton: "Enter Whole Day",
        absenceHalfButton: "Enter Half Day",
        editDayMessage: "Choose a day to add the start of work, breaks, work away from the Mac or the end of work.",
        open: "Open",
        exportMessage: "Save the records of a period as Markdown, CSV or PDF.",
        presetLastFourWeeks: "Last 4 Weeks",
        presetCustom: "Custom Range",
        periodLabel: "Period:",
        fromLabel: "From:",
        formatLabel: "Format:",
        exportSummaryFormat: "%1$@ · %2$@ working time · Balance %3$@",
        exportSavedTitle: "Export Saved",
        exportSavedFormat: "The records from %1$@ to %2$@ were saved to “%3$@”.",
        showInFinder: "Show in Finder",
        exportFailedTitle: "Export Failed",
        readFailedFormat: "The database could not be read: %@",
        writeFailedFormat: "Writing failed: %@",
        pdfTitleFormat: "%1$@ – Working time %2$@ to %3$@",
        pdfExportedFormat: "Exported on %1$@ at %2$@",
        pdfWeekFormat: "Week %d",
        pdfTotalFormat: "Total: %1$d %2$@",
        pdfTargetFormat: "Target: %1$@ (%2$@).  ✎ corrected by hand  ·  ⚠ see warnings",
        pdfWarningsHeading: "Warnings",
        importMessage: "Choose a Markdown export (CSV and PDF don’t hold all data).",
        importReadFailedFormat: "“%1$@” could not be read: %2$@",
        importFailedTitle: "Import Failed",
        noRecordsTitle: "No Records Found",
        noRecordsFormat: "“%@” holds no records. A Markdown export of Barforge or Tagwerk can be read in.",
        nothingToImportTitle: "Nothing to Import",
        nothingToImportFormat: "No day from “%1$@” can be taken over. %2$@",
        importConfirmFormat: "Import %1$@ from %2$@ to %3$@?",
        importDaysOneFormat: "%d day",
        importDaysManyFormat: "%d days",
        importNoExisting: "These days have no entries yet.",
        importExistingFormat: "%@ of them already have entries – they are replaced by the ones from the file.",
        importBackupNote: "Before that, Barforge saves the current state in the “backups” folder – it can be brought back from there.",
        importDoneTitle: "Import Complete",
        importedFormat: "%@ taken over.",
        importedBackupFormat: "%1$@ taken over. The state before is saved in the “backups” folder as “%2$@”."
    )

    static let de = TimeTrackingRecordsStrings(
        windowTitle: "Aufzeichnungen",
        subtitleOff: "Zeiterfassung aus",
        viewLabel: "Ansicht",
        viewTip: "Zwischen Tagen und Woche wechseln",
        days: "Tage",
        week: "Woche",
        daysTip: "Tabelle mit Inspektor (⌘1)",
        weekTip: "Woche als Kalender (⌘2)",
        filter: "Filter",
        filterTip: "Tabelle auf einen Zeitraum oder bestimmte Tage einschränken",
        filterActiveTip: "Filter aktiv – die Tabelle zeigt nicht alle Tage",
        periodAll: "Alle Tage",
        periodThisMonth: "Dieser Monat",
        periodLastMonth: "Letzter Monat",
        periodThisYear: "Dieses Jahr",
        periodLastYear: "Letztes Jahr",
        filterWarnings: "Nur Tage mit Hinweisen",
        filterCorrected: "Nur korrigierte Tage",
        filterReset: "Filter zurücksetzen",
        refresh: "Aktualisieren",
        refreshTip: "Aufzeichnungen neu laden (⌘R)",
        editDay: "Tag bearbeiten",
        editDayTip: "Einen beliebigen Tag öffnen und Zeiten nachtragen (⌘N)",
        export: "Exportieren",
        exportTip: "Zeitraum als Markdown, CSV oder PDF exportieren (⌘E)",
        importLabel: "Importieren",
        importTip: "Einen Markdown-Export wieder einlesen (⇧⌘I)",
        inspector: "Informationen",
        inspectorTip: "Informationen ein- oder ausblenden (⌥⌘I)",
        showInWeek: "In der Wochenansicht zeigen",
        today: "Heute",
        cardToday: "Heute",
        cardWeek: "Diese Woche",
        cardMonth: "Dieser Monat",
        cardAverage: "Ø pro Arbeitstag",
        cardAccount: "Zeitkonto",
        targetFormat: "Soll %@",
        notAWorkday: "Kein Arbeitstag",
        startFormat: "Beginn %@ Uhr",
        startManualFormat: "Beginn %@ Uhr (manuell)",
        detailSeparator: " · ",
        balanceDetailFormat: "%@ · Saldo ",
        averageDetailFormat: "Pausen Ø %1$@ · %2$@",
        accountFromFormat: "ab %@",
        accountSinceFormat: "seit %@",
        accountNothingYet: "noch nichts erfasst",
        accountCarryFormat: "%1$@ · Übertrag %2$@",
        workdaysOneFormat: "%d Arbeitstag",
        workdaysManyFormat: "%d Arbeitstage",
        longDateFormat: "%1$@, %2$d. %3$@ %4$d",
        weekdayNames: ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"],
        monthNames: ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September",
                     "Oktober", "November", "Dezember"],
        columnDate: "Datum",
        columnStart: "Beginn",
        columnEnd: "Ende",
        columnWork: "Arbeitszeit",
        columnBreaks: "Pausen",
        columnBalance: "Saldo",
        markColumnTip: "Hinweise auf Regelverstöße und manuelle Korrekturen",
        weekTitleFormat: "KW %1$d  ·  %2$@ – %3$@",
        weekStartFormat: "%1$02d.%2$02d.",
        weekTotalFormat: "%1$@  ·  %2$@  ·  Saldo ",
        running: "läuft",
        warningTip: "Hinweis",
        correctedTip: "Manuell korrigiert",
        missingTip: "Nichts erfasst – der Arbeitstag zählt mit seinem Soll. Zeiten oder eine Abwesenheit lassen sich im Inspektor nachtragen.",
        footerRecordedFormat: "%@ erfasst",
        footerFilterFormat: "Filter: %1$d von %2$@",
        footerDaysOneFormat: "%d Tag",
        footerDaysManyFormat: "%d Tagen",
        footerSeparator: "  ·  ",
        rulesOnFormat: "Regeln am %1$@: %2$@",
        noDayTitle: "Kein Tag ausgewählt",
        noDayHint: "Wähle in der Liste einen Tag aus, um Arbeitsbeginn, Pausen, Arbeit ohne Mac oder Feierabend zu korrigieren.",
        statWork: "Arbeitszeit",
        statBreaks: "Pausen",
        statBalance: "Saldo",
        noteFutureWorkday: "Künftiger Tag – eintragen lässt sich nur eine Abwesenheit.",
        noteFutureFreeDay: "Künftiger freier Tag – hier gibt es nichts einzutragen.",
        noteNoWorkNoTarget: "Keine Arbeitszeit, kein Soll.",
        noteFreeDayUncounted: "Freier Tag – die erfasste Zeit zählt nicht.",
        noteNoWorkInFrame: "Keine Arbeitszeit im Arbeitszeitrahmen.",
        noteNothingYet: "Für diesen Tag ist noch nichts erfasst.",
        explanation: "Erklärung",
        sectionAbsence: "Abwesenheit",
        sectionRecording: "Erfassung",
        sectionStart: "Arbeitsbeginn",
        sectionBreaks: "Pausen",
        sectionWork: "Arbeit ohne Mac",
        sectionEnd: "Feierabend",
        sectionRecorded: "Automatisch erfasst",
        helpAbsence: "Urlaub, Krankheit und Feiertag senken das Soll des Tages, ein halber Tag auf die Hälfte; Sonderurlaub gilt immer ganztags. Zeitausgleich lässt das Soll stehen, auch ohne Arbeitszeit – das Zeitkonto sinkt entsprechend. Ganztags geht eine Abwesenheit nur an einem Tag ohne andere Einträge: Die löscht man vorher mit „Alle Einträge löschen …“ unten; ein halber Tag geht auch neben Arbeitszeit – dafür „Halber Tag“ wählen, auch vor der Art. An freien Tagen (Wochenende, abgewählte Arbeitstage) gibt es kein Soll und deshalb keine Abwesenheit.",
        helpRecordingFormat: "An freien Tagen (Wochenende, abgewählte Arbeitstage) zählt die automatisch erfasste Zeit erst als Arbeitszeit, wenn sie gezählt werden soll – im Panel „Heute erfassen“. Bis dahin lassen sich Arbeitsbeginn, Pausen und Feierabend nicht festlegen; Arbeit ohne Mac zählt immer. %@",
        helpStart: "Ohne Angabe beginnt der Tag mit dem ersten Entsperren. War der Mac zum Beginn gesperrt, zählt die Zeit bis zum Entsperren danach mit; was davor erfasst wurde, entfällt. Arbeit ohne Mac vor einem neu festgelegten Beginn entfällt – die letzte Angabe gilt.",
        helpBreaksFormat: "Sperren ab %d Min. gelten automatisch als Pause, kürzere zählen zur Arbeitszeit. Hier lassen sich zusätzliche Pausen eintragen.",
        helpWork: "Telefonat, Meeting oder Termin bei gesperrtem Mac: Diese Zeiten zählen als Arbeitszeit. Eine Pause in dieser Zeit entfällt.",
        helpEnd: "Ohne Angabe endet der Tag mit dem letzten Sperren. War der Mac zum Feierabend gesperrt, zählt die Zeit seit dem Sperren davor mit; was danach erfasst wurde, entfällt. Arbeit ohne Mac nach einem neu festgelegten Feierabend entfällt – die letzte Angabe gilt.",
        helpRecordedFormat: "Zeiten, in denen der Mac entsperrt war. Gezählt wird nur im Arbeitszeitrahmen (%@). Das Dreieck klappt die einzelnen Zeiten auf und zu – für alle Tage.",
        absenceNone: "Keine",
        wholeDay: "Ganzer Tag",
        halfDay: "Halber Tag",
        partTipNone: "Ganzer oder halber Tag – gilt für die Art, die danach gewählt wird. Ein halber Tag geht auch neben Arbeitszeit.",
        partTip: "Halbe Tage gibt es bei Urlaub, Krankheit und Feiertag; ein halber Tag geht auch neben Arbeitszeit.",
        freeDayAbsence: "An freien Tagen (Wochenende, abgewählte Arbeitstage) gibt es kein Soll – eine Abwesenheit lässt sich dort nicht eintragen, eine vorhandene nur entfernen.",
        wholeDayBlocked: "Ganztags erst, wenn der Tag keine anderen Einträge hat – siehe „Alle Einträge löschen …“ unten.",
        lockedByAbsence: "Arbeitsbeginn, Pausen, Arbeit ohne Mac und Feierabend lassen sich erst ändern, wenn die Abwesenheit auf „Keine“ steht.",
        effectNoTarget: "An diesem Tag gibt es kein Soll – die Abwesenheit ändert daran nichts. Entfernen lässt sie sich mit „Keine“.",
        effectFreeDay: "Freier Tag ohne Soll – hier gibt es keine Abwesenheit einzutragen.",
        effectKeepsTargetFormat: "Das Soll von %@ bleibt, auch ohne Arbeitszeit – das Zeitkonto sinkt entsprechend.",
        effectLowersFormat: "Das Soll sinkt von %1$@ auf %2$@.",
        countRecorded: "Erfasste Zeit zählen",
        countBalanceYes: "In Saldo und Zeitkonto geht sie an diesem Tag ein – der Stand der Arbeitszeitregeln sieht „Arbeit an freien Tagen in Saldo und Zeitkonto einrechnen“ vor.",
        countBalanceNo: "In Saldo und Zeitkonto geht sie an diesem Tag trotzdem nicht ein: Das geschieht nur, wenn im Stand der Arbeitszeitregeln „Arbeit an freien Tagen in Saldo und Zeitkonto einrechnen“ eingeschaltet ist.",
        countTipFormat: "Mit Haken zählt die automatisch erfasste Zeit als Arbeitszeit. %@",
        freeDayCountedInBalance: "Freier Tag: Die automatisch erfasste Zeit zählt als Arbeitszeit, auch in Saldo und Zeitkonto.",
        freeDayCountedNotInBalance: "Freier Tag: Die automatisch erfasste Zeit zählt als Arbeitszeit – in Saldo und Zeitkonto geht sie nach den Arbeitszeitregeln nicht ein.",
        freeDayStoppedNote: "Freier Tag: Alle Einträge wurden gelöscht, die automatische Erfassung ist aus. Mit dem Haken zählt sie wieder.",
        freeDayUncountedNote: "Freier Tag: Die automatisch erfasste Zeit zählt nicht. Arbeitsbeginn, Pausen und Feierabend lassen sich erst mit dem Haken festlegen; Arbeit ohne Mac zählt immer.",
        setManually: "Manuell festlegen",
        futureText: "An künftigen Tagen lässt sich nur eine Abwesenheit eintragen – Zeiten erst, wenn der Tag da ist.",
        uncountedNote: "Erst wenn die erfasste Zeit zählt (siehe „Erfassung“ oben).",
        inFrameSuffix: " im Arbeitszeitrahmen",
        startNoteFormat: "Ohne Angabe gilt das erste Entsperren%1$@ um %2$@ Uhr. War der Mac zum Beginn gesperrt, zählt die Zeit bis zum Entsperren danach mit.",
        startNoteNone: "Ohne Angabe gilt das erste Entsperren des Macs im Arbeitszeitrahmen.",
        endNoteFormat: "Ohne Angabe gilt das letzte Sperren%1$@ um %2$@ Uhr. War der Mac zum Feierabend gesperrt, zählt die Zeit seit dem Sperren davor mit.",
        endNoteNone: "Ohne Angabe gilt das letzte Sperren des Macs im Arbeitszeitrahmen.",
        endNoteToday: "Ohne Angabe gilt das letzte Sperren. Mit Feierabend wird heute nichts mehr erfasst.",
        startCut: "Arbeit ohne Mac vor dem Arbeitsbeginn ist entfallen – die letzte Angabe gilt. ⌘Z nimmt das zurück.",
        endCut: "Arbeit ohne Mac nach dem Feierabend ist entfallen – die letzte Angabe gilt. ⌘Z nimmt das zurück.",
        noBreaks: "Keine Pausen eingetragen",
        to: "bis",
        add: "Hinzufügen",
        removeBreak: "Pause entfernen",
        breakMinFormat: "Eine Pause dauert mindestens %d Min. (siehe Einstellungen).",
        breakOrder: "Das Ende der Pause muss nach ihrem Beginn liegen.",
        nothingEntered: "Nichts eingetragen",
        reason: "Grund",
        removeWork: "Arbeit ohne Mac entfernen",
        minWorkFormat: "Arbeit ohne Mac dauert mindestens %d Min. (siehe Einstellungen).",
        workOrder: "Das Ende der Arbeit ohne Mac muss nach ihrem Beginn liegen.",
        gapAddedTitle: "Lücke dazugerechnet",
        recordedToggleTip: "Automatisch erfasste Zeiten ein- oder ausblenden",
        recordedNone: "Keine – der Mac war nicht entsperrt.",
        recordedOneFormat: "%d Zeit",
        recordedManyFormat: "%d Zeiten",
        recordedSummaryFormat: "%1$@, %2$@ – %3$@",
        clearDay: "Alle Einträge löschen …",
        clearDayTip: "Löscht die automatisch erfassten Zeiten und alle manuellen Einträge dieses Tages.",
        editSetStart: "Arbeitsbeginn ändern",
        editSetEnd: "Feierabend ändern",
        editAddBreak: "Pause eintragen",
        editRemoveBreak: "Pause entfernen",
        editAddWork: "Arbeit ohne Mac eintragen",
        editRemoveWork: "Arbeit ohne Mac entfernen",
        editSetAbsence: "Abwesenheit ändern",
        editCountOn: "Erfasste Zeit zählen",
        editCountOff: "Erfasste Zeit nicht zählen",
        editClearDay: "Alle Einträge löschen",
        laterThanNowFormat: "Zeiten nach jetzt (%@ Uhr) lassen sich nicht eintragen.",
        beforeFirstFormat: "Bisher beginnen die Aufzeichnungen am %1$@. Mit einem Eintrag am %2$@ %3$@ – zusammen etwa %4$d Std. Minus in Saldo und Zeitkonto, bis dort Zeiten oder Abwesenheiten eingetragen sind.",
        beforeFirstBetweenOne: "zählt auch der Arbeitstag dazwischen mit seinem Soll",
        beforeFirstBetweenManyFormat: "zählen auch die %d Arbeitstage dazwischen mit ihrem Soll",
        beforeFirstTitleFormat: "Eintrag vor dem ersten erfassten Tag am %@?",
        enter: "Eintragen",
        cancel: "Abbrechen",
        ok: "OK",
        notSaved: "Nicht gespeichert",
        saveFailed: "Speichern fehlgeschlagen",
        workCutTitle: "Arbeit ohne Mac entfallen",
        undo: "Widerrufen",
        redo: "Wiederholen",
        historyTitleFormat: "%1$@: %2$@",
        rewindStepFormat: "„%1$@“ vom %2$@",
        partialUndoTitle: "Nur zum Teil widerrufen",
        partialRedoTitle: "Nur zum Teil wiederholt",
        partialUndoFormat: "%1$@ ist nur zum Teil widerrufen. Inzwischen anders geändert und deshalb so geblieben: %2$@.",
        partialRedoFormat: "%1$@ ist nur zum Teil wiederholt. Inzwischen anders geändert und deshalb so geblieben: %2$@.",
        refusedUndoTitle: "Nicht widerrufen",
        refusedRedoTitle: "Nicht wiederholt",
        refusedUndoFormat: "%1$@ lässt sich nicht mehr widerrufen – %2$@. Der Tag bleibt, wie er ist.",
        refusedRedoFormat: "%1$@ lässt sich nicht mehr wiederholen – %2$@. Der Tag bleibt, wie er ist.",
        whyChangedFormat: "inzwischen anders geändert: %@",
        whyOrder: "der Arbeitsbeginn läge dann nicht vor dem Feierabend",
        whyAbsenceBesideEntries: "die ganztägige Abwesenheit stünde dann neben inzwischen erfassten Einträgen",
        fieldStart: "Arbeitsbeginn",
        fieldBreaks: "Pausen",
        fieldWork: "Arbeit ohne Mac",
        fieldEnd: "Feierabend",
        fieldAbsence: "Abwesenheit",
        fieldCounting: "Erfasste Zeit zählen",
        clearTitleFormat: "Alle Einträge vom %@ löschen?",
        delete: "Löschen",
        deleteFailed: "Löschen fehlgeschlagen",
        clearPeriodsOne: "1 automatisch erfasste Zeit",
        clearPeriodsManyFormat: "%d automatisch erfasste Zeiten",
        clearStart: "den festgelegten Arbeitsbeginn",
        clearBreaksOne: "1 eingetragene Pause",
        clearBreaksManyFormat: "%d eingetragene Pausen",
        clearWorkOne: "1 Eintrag Arbeit ohne Mac",
        clearWorkManyFormat: "%d Einträge Arbeit ohne Mac",
        clearEnd: "den festgelegten Feierabend",
        clearAbsenceFormat: "die Abwesenheit „%@“",
        clearNothing: "nichts",
        clearAffectsFormat: "Das betrifft %@.",
        clearTodayFreeDay: " Die automatische Erfassung bleibt heute aus, bis im Panel „Heute erfassen“ gewählt ist.",
        clearTodayContinues: " Die automatische Erfassung läuft danach ab jetzt weiter.",
        undoHint: " ⌘Z nimmt das zurück.",
        absenceTodayTitleFormat: "Heute ganztägig „%@“ eintragen?",
        absenceTodayFormat: "Die heute automatisch erfasste Zeit (%@) wird gelöscht, und die Erfassung endet für heute – bis die Abwesenheit wieder auf „Keine“ steht. ⌘Z nimmt das zurück.",
        absenceTodayHalf: " Ein halber Tag geht auch neben der erfassten Zeit – sie bleibt dann.",
        absenceWholeButton: "Ganztags eintragen",
        absenceHalfButton: "Halben Tag eintragen",
        editDayMessage: "Wähle einen Tag, um Arbeitsbeginn, Pausen, Arbeit ohne Mac oder Feierabend nachzutragen.",
        open: "Öffnen",
        exportMessage: "Aufzeichnungen eines Zeitraums als Markdown, CSV oder PDF sichern.",
        presetLastFourWeeks: "Letzte 4 Wochen",
        presetCustom: "Eigener Zeitraum",
        periodLabel: "Zeitraum:",
        fromLabel: "Von:",
        formatLabel: "Format:",
        exportSummaryFormat: "%1$@ · %2$@ Arbeitszeit · Saldo %3$@",
        exportSavedTitle: "Export gesichert",
        exportSavedFormat: "Die Aufzeichnungen vom %1$@ bis %2$@ wurden in „%3$@“ gesichert.",
        showInFinder: "Im Finder zeigen",
        exportFailedTitle: "Export fehlgeschlagen",
        readFailedFormat: "Die Datenbank konnte nicht gelesen werden: %@",
        writeFailedFormat: "Schreiben fehlgeschlagen: %@",
        pdfTitleFormat: "%1$@ – Arbeitszeiten %2$@ bis %3$@",
        pdfExportedFormat: "Exportiert am %1$@ um %2$@ Uhr",
        pdfWeekFormat: "KW %d",
        pdfTotalFormat: "Summe: %1$d %2$@",
        pdfTargetFormat: "Soll: %1$@ (%2$@).  ✎ manuell korrigiert  ·  ⚠ siehe Hinweise",
        pdfWarningsHeading: "Hinweise",
        importMessage: "Einen Markdown-Export wählen (CSV und PDF enthalten nicht alle Daten).",
        importReadFailedFormat: "„%1$@“ konnte nicht gelesen werden: %2$@",
        importFailedTitle: "Import fehlgeschlagen",
        noRecordsTitle: "Keine Aufzeichnungen gefunden",
        noRecordsFormat: "„%@“ enthält keine Aufzeichnungen. Einlesen lässt sich ein Markdown-Export von Barforge oder Tagwerk.",
        nothingToImportTitle: "Nichts zu importieren",
        nothingToImportFormat: "Kein Tag aus „%1$@“ lässt sich übernehmen. %2$@",
        importConfirmFormat: "%1$@ vom %2$@ bis %3$@ importieren?",
        importDaysOneFormat: "%d Tag",
        importDaysManyFormat: "%d Tage",
        importNoExisting: "Für diese Tage gibt es noch keine Einträge.",
        importExistingFormat: "Für %@ davon gibt es schon Einträge – sie werden durch die aus der Datei ersetzt.",
        importBackupNote: "Vorher sichert Barforge den jetzigen Stand eigens im Ordner „backups“ – damit lässt er sich zurückholen.",
        importDoneTitle: "Import abgeschlossen",
        importedFormat: "%@ übernommen.",
        importedBackupFormat: "%1$@ übernommen. Der Stand davor ist im Ordner „backups“ als „%2$@“ gesichert."
    )
}

// MARK: - Week view

/// Texts of the week view in the Records window (Tagwerk's `week_view.rs`).
/// German is Tagwerk's wording; the other languages show English until they
/// are translated. Times carry "Uhr" in German only (`clockFormat`).
struct TimeTrackingWeekStrings {
    // Bar above the grid
    let previousWeek: String
    let nextWeek: String
    let previousWeekTip: String
    let nextWeekTip: String
    let todayTip: String
    let fullFrame: String
    let fullFrameTip: String
    let warningsRowTip: String
    /// ISO week, first day, last day, month, year.
    let titleSameMonthFormat: String
    /// ISO week, first day and month, last day and month, year.
    let titleSameYearFormat: String
    /// ISO week, first day, month and year, last day, month and year.
    let titleAcrossYearsFormat: String
    /// Working time and breaks of the week.
    let summaryFormat: String
    /// Follows the summary; the balance follows in colour.
    let summaryBalance: String
    let summaryNone: String
    let warningsOneDay: String
    let warningsManyDaysFormat: String
    /// The missing target.
    let missingFormat: String
    /// Short weekday, date.
    let shortDayFormat: String
    /// Short weekday, day, month.
    let headerDateFormat: String
    /// A time of day.
    let clockFormat: String

    // Blocks
    let noteStartManual: String
    let noteAfterBreak: String
    let noteBeforeBreak: String
    /// From, to, `noteAwaySuffixFormat` or nothing.
    let noteAwayFormat: String
    let noteAwaySuffixFormat: String
    let noteEndManual: String
    let now: String
    let notCounted: String
    /// Length of a break.
    let pauseFormat: String
    let cutLabel: String
    /// The copied time.
    let copiedFormat: String
    let emptyWeek: String

    // Dragging the start and end of work
    let dragStart: String
    let dragEnd: String
    /// Start or end, the time.
    let dragLabelFormat: String
    let dragSeparator: String
    let dragAuto: String
    /// Sign, minutes.
    let diffMinutesFormat: String
    /// Sign, hours, minutes.
    let diffHoursFormat: String
    let dragWorkUnchanged: String
    /// The change of the working time.
    let dragWorkFormat: String

    // Limits of the start and end of work
    let boundFuture: String
    let startFuture: String
    let endFuture: String
    /// The end of work.
    let startBeforeEndFormat: String
    /// The start of work.
    let endAfterStartFormat: String
    /// Start and end of the working-time frame.
    let startFrameFormat: String
    let endFrameFormat: String
    /// Minutes.
    let minDayFormat: String
    let startDialogText: String
    let endDialogText: String
    let endDialogToday: String
    /// The day, the explanation.
    let dialogInfoFormat: String
    let apply: String

    // Work away from the Mac
    let workFuture: String
    let endBeforeStart: String
    let endInFuture: String
    /// From, to, duration.
    let spanFormat: String
    let fromLabel: String
    /// The day.
    let workDialogTextFormat: String

    // Context menu
    /// The time.
    let copyTimeFormat: String
    let addWorkHere: String
    /// The note (or "Work away from the Mac"), `spanFormat`.
    let workLineFormat: String
    let deleteWork: String
    let changeStart: String
    let changeEnd: String
    /// The recorded time.
    let resetStartFormat: String
    let resetEndFormat: String
    let absenceBlocked: String
    let absenceFreeDay: String

    // VoiceOver
    /// The week title, the summary.
    let axWeekFormat: String
    /// Weekday, day, month.
    let axDayFormat: String
    let axNoWorkFormat: String
    /// Day, working time, breaks.
    let axWorkFormat: String
    let axMissingFormat: String
    let axWarningFormat: String
    /// From, to.
    let axRangeFormat: String
    /// Range, duration.
    let axOutsideFormat: String
    let axFreeDayFormat: String
    /// Since, duration so far.
    let axRunningFormat: String
    let axWorkSpanFormat: String
    let axPauseFormat: String
    let axAway: String
    let axAwayNoteFormat: String
    /// What, range.
    let axAwaySpanFormat: String
    let spokenMinutesFormat: String
    let spokenHoursFormat: String
    let spokenHoursMinutesFormat: String
    let startEarlier: String
    let startLater: String
    let endEarlier: String
    let endLater: String
    let resetStart: String
    let resetEnd: String

    // Tooltips
    /// Day, working time, breaks.
    let tipDayFormat: String
    let tipLocked: String
    let tipWarningsForFormat: String
    let tipWarnings: String
    let tipBulletFormat: String
    let tipDoubleClick: String
    /// Day, start, end, duration.
    let tipBlockFormat: String
    let tipRunning: String
    let tipOutside: String
    let tipFreeDay: String
    let tipCountHint: String
    let tipClick: String
    let tipDragTop: String
    let tipDragBottom: String
    let tipHatch: String
    /// Day, `spanFormat`.
    let tipGapFormat: String
    /// The day.
    let popoverTitleFormat: String
}

extension FeatureStrings {
    static func timeTrackingWeek(_ language: AppLanguage) -> TimeTrackingWeekStrings {
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

extension TimeTrackingWeekStrings {
    static let enUS = TimeTrackingWeekStrings(
        previousWeek: "Previous Week",
        nextWeek: "Next Week",
        previousWeekTip: "Previous week (←)",
        nextWeekTip: "Next week (→)",
        todayTip: "Go to the current week (⌘T)",
        fullFrame: "Whole Working Hours",
        fullFrameTip: "Show the whole working hours – otherwise only the time worked this week",
        warningsRowTip: "Click a day with a warning sign to see its warnings",
        titleSameMonthFormat: "Week %1$d  ·  %4$@ %2$d – %3$d, %5$d",
        titleSameYearFormat: "Week %1$d  ·  %3$@ %2$d – %5$@ %4$d, %6$d",
        titleAcrossYearsFormat: "Week %1$d  ·  %3$@ %2$d, %4$d – %6$@ %5$d, %7$d",
        summaryFormat: "Week: %1$@  ·  Breaks: %2$@",
        summaryBalance: "  ·  Balance ",
        summaryNone: "Week: –",
        warningsOneDay: "Warnings on 1 day",
        warningsManyDaysFormat: "Warnings on %d days",
        missingFormat: "No working time: the target of %@ counts as a minus. Add times or an absence (right-click).",
        shortDayFormat: "%1$@, %2$@",
        headerDateFormat: "%1$@ %3$02d-%2$02d",
        clockFormat: "%@",
        noteStartManual: "Start of work set manually",
        noteAfterBreak: "Starts after a manual break",
        noteBeforeBreak: "Ends with a manual break",
        noteAwayFormat: "Worked away from the Mac %1$@ – %2$@%3$@",
        noteAwaySuffixFormat: " (%@)",
        noteEndManual: "End of work set manually",
        now: "now",
        notCounted: "not counted",
        pauseFormat: "Break %@",
        cutLabel: "removed",
        copiedFormat: "%@ copied",
        emptyWeek: "No working time this week",
        dragStart: "Start",
        dragEnd: "End",
        dragLabelFormat: "%1$@ %2$@",
        dragSeparator: " · ",
        dragAuto: "automatic",
        diffMinutesFormat: "%1$@%2$d min",
        diffHoursFormat: "%1$@%2$d:%3$02d h",
        dragWorkUnchanged: "Working time unchanged",
        dragWorkFormat: "Working time %@",
        boundFuture: "No times can be entered on future days.",
        startFuture: "The start of work can’t be in the future.",
        endFuture: "The end of work can’t be in the future.",
        startBeforeEndFormat: "The start of work must be before the end of work (%@).",
        endAfterStartFormat: "The end of work must be after the start of work (%@).",
        startFrameFormat: "The start of work must be within working hours from %1$@ to %2$@ – working time only counts there (see Settings).",
        endFrameFormat: "The end of work must be within working hours from %1$@ to %2$@ – working time only counts there (see Settings).",
        minDayFormat: "At least %d minutes must lie between the start and the end of work.",
        startDialogText: "Without an entry the day starts with the first unlock. Work away from the Mac before it goes – the latest entry wins.",
        endDialogText: "Without an entry the day ends with the last lock. Work away from the Mac after it goes – the latest entry wins.",
        endDialogToday: " After the end of work nothing more is recorded today.",
        dialogInfoFormat: "%1$@: %2$@",
        apply: "Apply",
        workFuture: "No work away from the Mac can be entered on future days.",
        endBeforeStart: "The end must be after the start.",
        endInFuture: "The end can’t be in the future.",
        spanFormat: "%1$@ – %2$@ (%3$@)",
        fromLabel: "From",
        workDialogTextFormat: "%@: A call, meeting or appointment while the Mac was locked counts as working time. A break in that time goes.",
        copyTimeFormat: "Copy Time %@",
        addWorkHere: "Add Work Away from the Mac…",
        workLineFormat: "%1$@ %2$@",
        deleteWork: "Delete Work Away from the Mac",
        changeStart: "Change Start of Work…",
        changeEnd: "Change End of Work…",
        resetStartFormat: "Reset Start of Work (%@)",
        resetEndFormat: "Reset End of Work (%@)",
        absenceBlocked: "Whole day only after “Delete All Entries”",
        absenceFreeDay: "Day off: remove only",
        axWeekFormat: "Week %1$@. %2$@",
        axDayFormat: "%1$@, %3$@ %2$d",
        axNoWorkFormat: "%@: no working time",
        axWorkFormat: "%1$@: working time %2$@, breaks %3$@",
        axMissingFormat: "Nothing recorded, balance minus %@",
        axWarningFormat: "Warning: %@",
        axRangeFormat: "%1$@ to %2$@",
        axOutsideFormat: "Not counted, outside working hours: %1$@, %2$@",
        axFreeDayFormat: "Not counted, day off: %1$@, %2$@",
        axRunningFormat: "Work since %1$@, running, so far %2$@",
        axWorkSpanFormat: "Work %1$@, %2$@",
        axPauseFormat: "Break %1$@, %2$@",
        axAway: "Work away from the Mac",
        axAwayNoteFormat: "Work away from the Mac, %@",
        axAwaySpanFormat: "%1$@: %2$@",
        spokenMinutesFormat: "%d min",
        spokenHoursFormat: "%d h",
        spokenHoursMinutesFormat: "%1$d h %2$d min",
        startEarlier: "Start of work 5 minutes earlier",
        startLater: "Start of work 5 minutes later",
        endEarlier: "End of work 5 minutes earlier",
        endLater: "End of work 5 minutes later",
        resetStart: "Reset start of work",
        resetEnd: "Reset end of work",
        tipDayFormat: "%1$@\nWorking time %2$@  ·  Breaks %3$@",
        tipLocked: "Other entries only once the absence is set to “None” (right-click).",
        tipWarningsForFormat: "Warnings for %@:",
        tipWarnings: "Warnings:",
        tipBulletFormat: "• %@",
        tipDoubleClick: "Double-click: edit day",
        tipBlockFormat: "%1$@\n%2$@ – %3$@\n%4$@",
        tipRunning: "now (running)",
        tipOutside: "Outside working hours – not counted",
        tipFreeDay: "Day off – recorded, but not counted",
        tipCountHint: "Right-click: “Count recorded time”.",
        tipClick: "Click a time to copy it. Right-click: all options.",
        tipDragTop: "Drag the top edge: move the start of work.",
        tipDragBottom: "Drag the bottom edge: move the end of work.",
        tipHatch: "Click the hatching: delete work away from the Mac.",
        tipGapFormat: "%1$@\nBreak %2$@\nClick: enter as work away from the Mac (a call or meeting, for example)",
        popoverTitleFormat: "Warnings for %@"
    )

    static let de = TimeTrackingWeekStrings(
        previousWeek: "Vorherige Woche",
        nextWeek: "Nächste Woche",
        previousWeekTip: "Vorherige Woche (←)",
        nextWeekTip: "Nächste Woche (→)",
        todayTip: "Zur aktuellen Woche (⌘T)",
        fullFrame: "Ganzer Rahmen",
        fullFrameTip: "Den ganzen Arbeitszeitrahmen zeigen – sonst nur die Zeit, in der in dieser Woche gearbeitet wurde",
        warningsRowTip: "Tage mit Warnschild anklicken, um die Hinweise zu sehen",
        titleSameMonthFormat: "KW %1$d  ·  %2$d. – %3$d. %4$@ %5$d",
        titleSameYearFormat: "KW %1$d  ·  %2$d. %3$@ – %4$d. %5$@ %6$d",
        titleAcrossYearsFormat: "KW %1$d  ·  %2$d. %3$@ %4$d – %5$d. %6$@ %7$d",
        summaryFormat: "Woche: %1$@  ·  Pausen: %2$@",
        summaryBalance: "  ·  Saldo ",
        summaryNone: "Woche: –",
        warningsOneDay: "Hinweise an 1 Tag",
        warningsManyDaysFormat: "Hinweise an %d Tagen",
        missingFormat: "Keine Arbeitszeit: Das Soll von %@ zählt als Minus. Zeiten oder eine Abwesenheit nachtragen (Rechtsklick).",
        shortDayFormat: "%1$@, %2$@",
        headerDateFormat: "%1$@ %2$02d.%3$02d.",
        clockFormat: "%@ Uhr",
        noteStartManual: "Arbeitsbeginn manuell festgelegt",
        noteAfterBreak: "beginnt nach einer manuellen Pause",
        noteBeforeBreak: "endet mit einer manuellen Pause",
        noteAwayFormat: "ohne Mac gearbeitet %1$@ – %2$@%3$@",
        noteAwaySuffixFormat: " (%@)",
        noteEndManual: "Feierabend manuell festgelegt",
        now: "jetzt",
        notCounted: "nicht gezählt",
        pauseFormat: "Pause %@",
        cutLabel: "entfällt",
        copiedFormat: "%@ kopiert",
        emptyWeek: "Keine Arbeitszeit in dieser Woche",
        dragStart: "Beginn",
        dragEnd: "Feierabend",
        dragLabelFormat: "%1$@ %2$@",
        dragSeparator: " · ",
        dragAuto: "automatisch",
        diffMinutesFormat: "%1$@%2$d Min.",
        diffHoursFormat: "%1$@%2$d:%3$02d h",
        dragWorkUnchanged: "Arbeitszeit unverändert",
        dragWorkFormat: "Arbeitszeit %@",
        boundFuture: "An künftigen Tagen lassen sich keine Zeiten eintragen.",
        startFuture: "Der Arbeitsbeginn kann nicht in der Zukunft liegen.",
        endFuture: "Der Feierabend kann nicht in der Zukunft liegen.",
        startBeforeEndFormat: "Der Arbeitsbeginn muss vor dem Feierabend (%@ Uhr) liegen.",
        endAfterStartFormat: "Der Feierabend muss nach dem Arbeitsbeginn (%@ Uhr) liegen.",
        startFrameFormat: "Der Arbeitsbeginn muss im Arbeitszeitrahmen von %1$@ bis %2$@ Uhr liegen – nur dort zählt Arbeitszeit (siehe Einstellungen).",
        endFrameFormat: "Der Feierabend muss im Arbeitszeitrahmen von %1$@ bis %2$@ Uhr liegen – nur dort zählt Arbeitszeit (siehe Einstellungen).",
        minDayFormat: "Zwischen Arbeitsbeginn und Feierabend müssen mindestens %d Minuten liegen.",
        startDialogText: "Ohne Angabe beginnt der Tag mit dem ersten Entsperren. Arbeit ohne Mac davor entfällt – die letzte Angabe gilt.",
        endDialogText: "Ohne Angabe endet der Tag mit dem letzten Sperren. Arbeit ohne Mac danach entfällt – die letzte Angabe gilt.",
        endDialogToday: " Mit Feierabend wird heute nichts mehr erfasst.",
        dialogInfoFormat: "%1$@: %2$@",
        apply: "Übernehmen",
        workFuture: "An künftigen Tagen lässt sich keine Arbeit ohne Mac eintragen.",
        endBeforeStart: "Das Ende muss nach dem Beginn liegen.",
        endInFuture: "Das Ende kann nicht in der Zukunft liegen.",
        spanFormat: "%1$@ – %2$@ Uhr (%3$@)",
        fromLabel: "Von",
        workDialogTextFormat: "%@: Telefonat, Meeting oder Termin bei gesperrtem Mac zählt als Arbeitszeit. Eine Pause in dieser Zeit entfällt.",
        copyTimeFormat: "Uhrzeit %@ kopieren",
        addWorkHere: "Arbeit ohne Mac eintragen …",
        workLineFormat: "%1$@ %2$@",
        deleteWork: "Arbeit ohne Mac löschen",
        changeStart: "Arbeitsbeginn ändern …",
        changeEnd: "Feierabend ändern …",
        resetStartFormat: "Arbeitsbeginn zurücksetzen (%@ Uhr)",
        resetEndFormat: "Feierabend zurücksetzen (%@ Uhr)",
        absenceBlocked: "Ganztags erst nach „Alle Einträge löschen“",
        absenceFreeDay: "Freier Tag: nur entfernen",
        axWeekFormat: "Woche %1$@. %2$@",
        axDayFormat: "%1$@, %2$d. %3$@",
        axNoWorkFormat: "%@: keine Arbeitszeit",
        axWorkFormat: "%1$@: Arbeitszeit %2$@, Pausen %3$@",
        axMissingFormat: "Nichts erfasst, Saldo minus %@",
        axWarningFormat: "Hinweis: %@",
        axRangeFormat: "%1$@ bis %2$@ Uhr",
        axOutsideFormat: "Nicht gezählt, außerhalb des Arbeitszeitrahmens: %1$@, %2$@",
        axFreeDayFormat: "Nicht gezählt, freier Tag: %1$@, %2$@",
        axRunningFormat: "Arbeit seit %1$@, läuft, bisher %2$@",
        axWorkSpanFormat: "Arbeit %1$@, %2$@",
        axPauseFormat: "Pause %1$@, %2$@",
        axAway: "Arbeit ohne Mac",
        axAwayNoteFormat: "Arbeit ohne Mac, %@",
        axAwaySpanFormat: "%1$@: %2$@",
        spokenMinutesFormat: "%d Min.",
        spokenHoursFormat: "%d Std.",
        spokenHoursMinutesFormat: "%1$d Std. %2$d Min.",
        startEarlier: "Arbeitsbeginn 5 Minuten früher",
        startLater: "Arbeitsbeginn 5 Minuten später",
        endEarlier: "Feierabend 5 Minuten früher",
        endLater: "Feierabend 5 Minuten später",
        resetStart: "Arbeitsbeginn zurücksetzen",
        resetEnd: "Feierabend zurücksetzen",
        tipDayFormat: "%1$@\nArbeitszeit %2$@  ·  Pausen %3$@",
        tipLocked: "Andere Einträge erst, wenn die Abwesenheit auf „Keine“ steht (Rechtsklick).",
        tipWarningsForFormat: "Hinweise für %@:",
        tipWarnings: "Hinweise:",
        tipBulletFormat: "• %@",
        tipDoubleClick: "Doppelklick: Tag bearbeiten",
        tipBlockFormat: "%1$@\n%2$@ Uhr – %3$@\n%4$@",
        tipRunning: "jetzt (läuft)",
        tipOutside: "außerhalb des Arbeitszeitrahmens – nicht gezählt",
        tipFreeDay: "freier Tag – erfasst, aber nicht gezählt",
        tipCountHint: "Rechtsklick: „Erfasste Zeit zählen“.",
        tipClick: "Klick auf eine Uhrzeit kopiert sie. Rechtsklick: alle Möglichkeiten.",
        tipDragTop: "Oberkante ziehen: Arbeitsbeginn verschieben.",
        tipDragBottom: "Unterkante ziehen: Feierabend verschieben.",
        tipHatch: "Klick auf die Schraffur: Arbeit ohne Mac löschen.",
        tipGapFormat: "%1$@\nPause %2$@\nKlick: als Arbeit ohne Mac eintragen (z. B. Telefonat oder Meeting)",
        popoverTitleFormat: "Hinweise für %@"
    )
}
