// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct CPUCoreFeatureStrings {
    let title: String
    let coreFormat: String
    let hint: String
    let superCores: String
    let performanceCores: String
    let efficiencyCores: String
    let apps: String
    /// Settings switch for the per-core bars under CPU.
    let perCore: String
    /// Switch above the CPU apps list that adds other users' processes.
    let allUsers: String
    let allUsersHelp: String
}

extension FeatureStrings {
    static func cpuCores(_ language: AppLanguage) -> CPUCoreFeatureStrings {
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
        case .zhTW, .zhHK: return .zhTW
        }
    }
}

extension CPUCoreFeatureStrings {
    static let enUS = CPUCoreFeatureStrings(
        title: "Logical CPU cores",
        coreFormat: "Core %d",
        hint: "Each bar is one logical core. Its fill height shows utilization, not remaining performance.",
        superCores: "Super",
        performanceCores: "Performance",
        efficiencyCores: "Efficiency",
        apps: "Apps using CPU",
        perCore: "Per core",
        allUsers: "All users",
        allUsersHelp: "Also show processes of other users, such as root and system daemons"
    )

    static let ptBR = CPUCoreFeatureStrings(
        title: "Núcleos lógicos da CPU",
        coreFormat: "Núcleo %d",
        hint: "Cada barra representa um núcleo lógico. A altura preenchida mostra a utilização.",
        superCores: "Super",
        performanceCores: "Desempenho",
        efficiencyCores: "Eficiência",
        apps: "Apps usando CPU",
        perCore: "Por núcleo",
        allUsers: "Todos os usuários",
        allUsersHelp: "Mostrar também processos de outros usuários, como root e daemons do sistema"
    )

    static let tr = CPUCoreFeatureStrings(
        title: "Mantıksal CPU çekirdekleri",
        coreFormat: "Çekirdek %d",
        hint: "Her çubuk bir mantıksal çekirdektir. Dolgu yüksekliği kullanımı gösterir.",
        superCores: "Süper",
        performanceCores: "Performans",
        efficiencyCores: "Verimlilik",
        apps: "CPU kullanan uygulamalar",
        perCore: "Çekirdek başına",
        allUsers: "Tüm kullanıcılar",
        allUsersHelp: "Diğer kullanıcıların süreçlerini de göster (root ve sistem servisleri gibi)"
    )

    static let ru = CPUCoreFeatureStrings(
        title: "Логические ядра CPU",
        coreFormat: "Ядро %d",
        hint: "Каждая полоса показывает одно логическое ядро, а высота заполнения показывает его загрузку.",
        superCores: "Супер",
        performanceCores: "Производительность",
        efficiencyCores: "Эффективность",
        apps: "Приложения, использующие CPU",
        perCore: "По ядрам",
        allUsers: "Все пользователи",
        allUsersHelp: "Показывать также процессы других пользователей, например root и системных служб"
    )

    static let es = CPUCoreFeatureStrings(
        title: "Núcleos lógicos de CPU",
        coreFormat: "Núcleo %d",
        hint: "Cada barra es un núcleo lógico. La altura del relleno indica su uso.",
        superCores: "Súper",
        performanceCores: "Rendimiento",
        efficiencyCores: "Eficiencia",
        apps: "Apps usando CPU",
        perCore: "Por núcleo",
        allUsers: "Todos los usuarios",
        allUsersHelp: "Mostrar también procesos de otros usuarios, como root y daemons del sistema"
    )

    static let sk = CPUCoreFeatureStrings(
        title: "Logické jadrá CPU",
        coreFormat: "Jadro %d",
        hint: "Každý stĺpec je jedno logické jadro. Výška výplne ukazuje vyťaženie, nie zostávajúci výkon.",
        superCores: "Super",
        performanceCores: "Výkonné",
        efficiencyCores: "Úsporné",
        apps: "Aplikácie využívajúce CPU",
        perCore: "Po jadrách",
        allUsers: "Všetci používatelia",
        allUsersHelp: "Zobraziť aj procesy iných používateľov, napríklad root a systémových démonov"
    )
    static let de = CPUCoreFeatureStrings(
        title: "Logische CPU-Kerne",
        coreFormat: "Kern %d",
        hint: "Jeder Balken ist ein logischer Kern. Die Füllhöhe zeigt die Auslastung.",
        superCores: "Super",
        performanceCores: "Leistung",
        efficiencyCores: "Effizienz",
        apps: "Apps mit CPU-Last",
        perCore: "Pro Kern",
        allUsers: "Alle Benutzer",
        allUsersHelp: "Auch Prozesse anderer Benutzer anzeigen, z. B. root und Systemdienste"
    )

    static let fr = CPUCoreFeatureStrings(
        title: "Cœurs logiques du CPU",
        coreFormat: "Cœur %d",
        hint: "Chaque barre représente un cœur logique. La hauteur du remplissage indique son utilisation.",
        superCores: "Super",
        performanceCores: "Performance",
        efficiencyCores: "Efficacité",
        apps: "Apps utilisant le CPU",
        perCore: "Par cœur",
        allUsers: "Tous les utilisateurs",
        allUsersHelp: "Afficher aussi les processus des autres utilisateurs, comme root et les démons système"
    )

    static let it = CPUCoreFeatureStrings(
        title: "Core logici CPU",
        coreFormat: "Core %d",
        hint: "Ogni barra rappresenta un core logico. L’altezza del riempimento indica l’utilizzo.",
        superCores: "Super",
        performanceCores: "Prestazioni",
        efficiencyCores: "Efficienza",
        apps: "App che usano la CPU",
        perCore: "Per core",
        allUsers: "Tutti gli utenti",
        allUsersHelp: "Mostra anche i processi di altri utenti, come root e i daemon di sistema"
    )

    static let ja = CPUCoreFeatureStrings(
        title: "CPU 論理コア",
        coreFormat: "コア %d",
        hint: "各バーは論理コアです。塗りつぶしの高さは使用率を表します。",
        superCores: "スーパー",
        performanceCores: "高性能",
        efficiencyCores: "高効率",
        apps: "CPUを使用中のアプリ",
        perCore: "コアごと",
        allUsers: "すべてのユーザ",
        allUsersHelp: "root やシステムデーモンなど、他のユーザのプロセスも表示します"
    )

    static let ko = CPUCoreFeatureStrings(
        title: "CPU 논리 코어",
        coreFormat: "코어 %d",
        hint: "막대 하나가 논리 코어 하나입니다. 채움 높이가 사용률을 나타냅니다.",
        superCores: "슈퍼",
        performanceCores: "성능",
        efficiencyCores: "효율",
        apps: "CPU를 사용하는 앱",
        perCore: "코어별",
        allUsers: "모든 사용자",
        allUsersHelp: "root 및 시스템 데몬 등 다른 사용자의 프로세스도 표시합니다"
    )

    static let uk = CPUCoreFeatureStrings(
        title: "Логічні ядра CPU",
        coreFormat: "Ядро %d",
        hint: "Кожен стовпчик показує одне логічне ядро. Висота заповнення показує навантаження, а не запас продуктивності.",
        superCores: "Супер",
        performanceCores: "Продуктивні",
        efficiencyCores: "Енергоефективні",
        apps: "Програми, що використовують CPU",
        perCore: "По ядрах",
        allUsers: "Усі користувачі",
        allUsersHelp: "Показувати також процеси інших користувачів, наприклад root і системних служб"
    )
    static let zhHans = CPUCoreFeatureStrings(
        title: "CPU 逻辑核心",
        coreFormat: "核心 %d",
        hint: "每条代表一个逻辑核心，填充高度表示占用率，不表示剩余性能。",
        superCores: "超级核心",
        performanceCores: "性能核心",
        efficiencyCores: "能效核心",
        apps: "正在使用 CPU 的 App",
        perCore: "每个核心",
        allUsers: "所有用户",
        allUsersHelp: "同时显示其他用户的进程，例如 root 和系统守护进程"
    )

    static let zhTW = CPUCoreFeatureStrings(
        title: "CPU 邏輯核心",
        coreFormat: "核心 %d",
        hint: "每條代表一個邏輯核心，填充高度表示使用率，不表示剩餘效能。",
        superCores: "超級核心",
        performanceCores: "效能核心",
        efficiencyCores: "節能核心",
        apps: "正使用 CPU 的 App",
        perCore: "每個核心",
        allUsers: "所有使用者",
        allUsersHelp: "同時顯示其他使用者的程序，例如 root 和系統常駐程式"
    )
}
