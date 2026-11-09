// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

struct DiskAnalyzerFeatureStrings {
    let title: String
    let hubDescription: String
    let panelCaption: String
    let openButton: String
    let settingsCaption: String
    let disks: String
    let folders: String
    let scan: String
    let show: String
    let scanFolder: String
    /// A disk's used space, free space and capacity.
    let usageFormat: String
    let keepFolder: String
    let forgetFolder: String
    let discardResult: String
    let scanningFormat: String
    let filesFormat: String
    let stop: String
    /// Shown once every folder is read, while the result is put together.
    let evaluating: String
    let back: String
    let forward: String
    let up: String
    let home: String
    let rescan: String
    let rescanFolder: String
    let rings: String
    let tiles: String
    let smallerItemsFormat: String
    let hiddenSpace: String
    let purgeableSpace: String
    let freeSpace: String
    let hiddenHelp: String
    let purgeableHelp: String
    let emptyFolder: String
    let showInFinder: String
    let openInTerminal: String
    let quickLook: String
    let addToCollector: String
    let removeFromCollector: String
    let showPackageContents: String
    let collector: String
    let collectorHint: String
    let moveToTrash: String
    let countdownFormat: String
    /// Item count, then total size.
    let itemsFormat: String
    let removeAll: String
    let refuseSpace: String
    let refuseSystemFormat: String
    let refuseTimeMachine: String
    let refuseLockedFormat: String
    let refuseFolderFormat: String
    let refuseVolumeFormat: String
    let trashFailedFormat: String
    let fullDiskAccessTitle: String
    let fullDiskAccessMessage: String
    let openSettings: String
}

extension FeatureStrings {
    static func diskAnalyzer(_ language: AppLanguage) -> DiskAnalyzerFeatureStrings {
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

extension DiskAnalyzerFeatureStrings {
    static let enUS = DiskAnalyzerFeatureStrings(
        title: "Disk Analyzer",
        hubDescription: "See what fills your disks as rings or tiles and move what you no longer need to the Trash",
        panelCaption: "See what fills your disks",
        openButton: "Open Disk Analyzer",
        settingsCaption: "Scans disks and folders and shows their contents as rings or tiles. Results stay in memory until the window closes.",
        disks: "Disks", folders: "Folders", scan: "Scan", show: "Show", scanFolder: "Scan Folder…",
        usageFormat: "%1$@ used · %2$@ free · %3$@ total", keepFolder: "Keep in list", forgetFolder: "Remove from list",
        discardResult: "Discard result", scanningFormat: "Scanning %@…", filesFormat: "Files: %@", stop: "Stop", evaluating: "Preparing the result…",
        back: "Back", forward: "Forward", up: "Enclosing Folder", home: "Disks and Folders",
        rescan: "Rescan", rescanFolder: "Rescan This Folder", rings: "Rings", tiles: "Tiles",
        smallerItemsFormat: "Smaller items: %d", hiddenSpace: "Hidden space", purgeableSpace: "Purgeable space",
        freeSpace: "Free space", hiddenHelp: "Space in use that the scan could not read",
        purgeableHelp: "Space macOS can free up by itself, such as caches and local snapshots",
        emptyFolder: "This folder is empty", showInFinder: "Show in Finder", openInTerminal: "Open in Terminal",
        quickLook: "Quick Look", addToCollector: "Add to Collector", removeFromCollector: "Remove from Collector",
        showPackageContents: "Show Package Contents", collector: "Collector",
        collectorHint: "Drag items here or press ⌘⌫", moveToTrash: "Move to Trash",
        countdownFormat: "Moving to the Trash in %d s", itemsFormat: "Items: %1$d · %2$@", removeAll: "Remove All",
        refuseSpace: "This space can’t be moved to the Trash", refuseSystemFormat: "“%@” is needed by macOS",
        refuseTimeMachine: "Delete Time Machine backups in Time Machine", refuseLockedFormat: "“%@” is locked",
        refuseFolderFormat: "The folder “%@” is read-only", refuseVolumeFormat: "The disk “%@” is read-only",
        trashFailedFormat: "Could not move to the Trash: %d", fullDiskAccessTitle: "Some folders could not be read",
        fullDiskAccessMessage: "Allow Full Disk Access to include them. Until then their space shows as hidden.",
        openSettings: "Open Settings")

    static let de = DiskAnalyzerFeatureStrings(
        title: "Speicheranalyse",
        hubDescription: "Sieh als Ringe oder Kacheln, was deine Festplatten füllt, und lege Unnötiges in den Papierkorb",
        panelCaption: "Sieh, was deine Festplatten füllt",
        openButton: "Speicheranalyse öffnen",
        settingsCaption: "Durchsucht Festplatten und Ordner und zeigt ihren Inhalt als Ringe oder Kacheln. Ergebnisse bleiben im Speicher, bis das Fenster geschlossen wird.",
        disks: "Festplatten", folders: "Ordner", scan: "Scannen", show: "Zeigen", scanFolder: "Ordner scannen …",
        usageFormat: "%1$@ belegt · %2$@ frei · %3$@ gesamt", keepFolder: "In der Liste behalten", forgetFolder: "Aus der Liste entfernen",
        discardResult: "Ergebnis verwerfen", scanningFormat: "%@ wird gescannt …", filesFormat: "Dateien: %@", stop: "Stoppen", evaluating: "Ergebnis wird aufbereitet …",
        back: "Zurück", forward: "Vorwärts", up: "Übergeordneter Ordner", home: "Festplatten und Ordner",
        rescan: "Erneut scannen", rescanFolder: "Diesen Ordner erneut scannen", rings: "Ringe", tiles: "Kacheln",
        smallerItemsFormat: "Kleinere Objekte: %d", hiddenSpace: "Versteckter Speicher", purgeableSpace: "Löschbarer Speicher",
        freeSpace: "Freier Speicher", hiddenHelp: "Belegter Speicher, den der Scan nicht lesen konnte",
        purgeableHelp: "Speicher, den macOS selbst freigeben kann, etwa Caches und lokale Schnappschüsse",
        emptyFolder: "Dieser Ordner ist leer", showInFinder: "Im Finder zeigen", openInTerminal: "Im Terminal öffnen",
        quickLook: "Übersicht", addToCollector: "In den Sammelbereich", removeFromCollector: "Aus dem Sammelbereich entfernen",
        showPackageContents: "Paketinhalt zeigen", collector: "Sammelbereich",
        collectorHint: "Objekte hierher ziehen oder ⌘⌫ drücken", moveToTrash: "In den Papierkorb legen",
        countdownFormat: "In %d s in den Papierkorb", itemsFormat: "Objekte: %1$d · %2$@", removeAll: "Alle entfernen",
        refuseSpace: "Dieser Speicher kann nicht in den Papierkorb gelegt werden", refuseSystemFormat: "„%@“ wird von macOS benötigt",
        refuseTimeMachine: "Time-Machine-Backups bitte in Time Machine löschen", refuseLockedFormat: "„%@“ ist geschützt",
        refuseFolderFormat: "Der Ordner „%@“ ist schreibgeschützt", refuseVolumeFormat: "Die Festplatte „%@“ ist schreibgeschützt",
        trashFailedFormat: "Nicht in den Papierkorb gelegt: %d", fullDiskAccessTitle: "Einige Ordner konnten nicht gelesen werden",
        fullDiskAccessMessage: "Erlaube den Festplattenvollzugriff, um sie einzubeziehen. Bis dahin zählt ihr Speicher als versteckt.",
        openSettings: "Einstellungen öffnen")

    static let ptBR = DiskAnalyzerFeatureStrings(
        title: "Analisador de disco",
        hubDescription: "Veja em anéis ou blocos o que ocupa seus discos e mova para o Lixo o que não precisa mais",
        panelCaption: "Veja o que ocupa seus discos",
        openButton: "Abrir Analisador de disco",
        settingsCaption: "Analisa discos e pastas e mostra o conteúdo em anéis ou blocos. Os resultados ficam na memória até a janela ser fechada.",
        disks: "Discos", folders: "Pastas", scan: "Analisar", show: "Mostrar", scanFolder: "Analisar pasta…",
        usageFormat: "%1$@ usados · %2$@ livres · %3$@ no total", keepFolder: "Manter na lista", forgetFolder: "Remover da lista",
        discardResult: "Descartar resultado", scanningFormat: "Analisando %@…", filesFormat: "Arquivos: %@", stop: "Parar", evaluating: "Preparando o resultado…",
        back: "Voltar", forward: "Avançar", up: "Pasta superior", home: "Discos e pastas",
        rescan: "Analisar de novo", rescanFolder: "Analisar esta pasta de novo", rings: "Anéis", tiles: "Blocos",
        smallerItemsFormat: "Itens menores: %d", hiddenSpace: "Espaço oculto", purgeableSpace: "Espaço removível",
        freeSpace: "Espaço livre", hiddenHelp: "Espaço em uso que a análise não conseguiu ler",
        purgeableHelp: "Espaço que o macOS pode liberar sozinho, como caches e instantâneos locais",
        emptyFolder: "Esta pasta está vazia", showInFinder: "Mostrar no Finder", openInTerminal: "Abrir no Terminal",
        quickLook: "Visualização Rápida", addToCollector: "Adicionar à coleta", removeFromCollector: "Remover da coleta",
        showPackageContents: "Mostrar conteúdo do pacote", collector: "Coleta",
        collectorHint: "Arraste itens para cá ou pressione ⌘⌫", moveToTrash: "Mover para o Lixo",
        countdownFormat: "Movendo para o Lixo em %d s", itemsFormat: "Itens: %1$d · %2$@", removeAll: "Remover tudo",
        refuseSpace: "Este espaço não pode ir para o Lixo", refuseSystemFormat: "“%@” é necessário para o macOS",
        refuseTimeMachine: "Apague backups do Time Machine no próprio Time Machine", refuseLockedFormat: "“%@” está bloqueado",
        refuseFolderFormat: "A pasta “%@” é somente leitura", refuseVolumeFormat: "O disco “%@” é somente leitura",
        trashFailedFormat: "Não movidos para o Lixo: %d", fullDiskAccessTitle: "Algumas pastas não puderam ser lidas",
        fullDiskAccessMessage: "Permita o Acesso Total ao Disco para incluí-las. Até lá, o espaço delas aparece como oculto.",
        openSettings: "Abrir Ajustes")

    static let tr = DiskAnalyzerFeatureStrings(
        title: "Disk Analizi",
        hubDescription: "Disklerinizi neyin doldurduğunu halkalar veya karolar olarak görün ve gerekmeyenleri Çöp Sepeti’ne taşıyın",
        panelCaption: "Disklerinizi neyin doldurduğunu görün",
        openButton: "Disk Analizi’ni aç",
        settingsCaption: "Diskleri ve klasörleri tarar, içeriklerini halkalar veya karolar olarak gösterir. Sonuçlar pencere kapanana kadar bellekte kalır.",
        disks: "Diskler", folders: "Klasörler", scan: "Tara", show: "Göster", scanFolder: "Klasör tara…",
        usageFormat: "%1$@ kullanılan · %2$@ boş · %3$@ toplam", keepFolder: "Listede tut", forgetFolder: "Listeden kaldır",
        discardResult: "Sonucu at", scanningFormat: "%@ taranıyor…", filesFormat: "Dosyalar: %@", stop: "Durdur", evaluating: "Sonuç hazırlanıyor…",
        back: "Geri", forward: "İleri", up: "Üst klasör", home: "Diskler ve klasörler",
        rescan: "Yeniden tara", rescanFolder: "Bu klasörü yeniden tara", rings: "Halkalar", tiles: "Karolar",
        smallerItemsFormat: "Daha küçük öğeler: %d", hiddenSpace: "Gizli alan", purgeableSpace: "Temizlenebilir alan",
        freeSpace: "Boş alan", hiddenHelp: "Taramanın okuyamadığı kullanılan alan",
        purgeableHelp: "macOS’in önbellekler ve yerel anlık görüntüler gibi kendi başına boşaltabileceği alan",
        emptyFolder: "Bu klasör boş", showInFinder: "Finder’da göster", openInTerminal: "Terminal’de aç",
        quickLook: "Hızlı Bakış", addToCollector: "Toplayıcıya ekle", removeFromCollector: "Toplayıcıdan çıkar",
        showPackageContents: "Paket içeriğini göster", collector: "Toplayıcı",
        collectorHint: "Öğeleri buraya sürükleyin veya ⌘⌫ tuşlarına basın", moveToTrash: "Çöp Sepeti’ne taşı",
        countdownFormat: "%d sn içinde Çöp Sepeti’ne taşınacak", itemsFormat: "Öğeler: %1$d · %2$@", removeAll: "Tümünü kaldır",
        refuseSpace: "Bu alan Çöp Sepeti’ne taşınamaz", refuseSystemFormat: "“%@” macOS için gerekli",
        refuseTimeMachine: "Time Machine yedeklerini Time Machine’de silin", refuseLockedFormat: "“%@” kilitli",
        refuseFolderFormat: "“%@” klasörü salt okunur", refuseVolumeFormat: "“%@” diski salt okunur",
        trashFailedFormat: "Çöp Sepeti’ne taşınamadı: %d", fullDiskAccessTitle: "Bazı klasörler okunamadı",
        fullDiskAccessMessage: "Onları dahil etmek için Tam Disk Erişimi’ne izin verin. O zamana kadar alanları gizli görünür.",
        openSettings: "Ayarları aç")

    static let ru = DiskAnalyzerFeatureStrings(
        title: "Анализ диска",
        hubDescription: "Смотрите в виде колец или плиток, чем заняты диски, и перемещайте ненужное в Корзину",
        panelCaption: "Смотрите, чем заняты диски",
        openButton: "Открыть анализ диска",
        settingsCaption: "Сканирует диски и папки и показывает их содержимое кольцами или плитками. Результаты хранятся в памяти, пока окно открыто.",
        disks: "Диски", folders: "Папки", scan: "Сканировать", show: "Показать", scanFolder: "Сканировать папку…",
        usageFormat: "Занято %1$@ · свободно %2$@ · всего %3$@", keepFolder: "Оставить в списке", forgetFolder: "Убрать из списка",
        discardResult: "Отбросить результат", scanningFormat: "Сканирование: %@…", filesFormat: "Файлы: %@", stop: "Остановить", evaluating: "Подготовка результата…",
        back: "Назад", forward: "Вперед", up: "Папка уровнем выше", home: "Диски и папки",
        rescan: "Сканировать снова", rescanFolder: "Сканировать эту папку снова", rings: "Кольца", tiles: "Плитки",
        smallerItemsFormat: "Мелкие объекты: %d", hiddenSpace: "Скрытое пространство", purgeableSpace: "Очищаемое пространство",
        freeSpace: "Свободное пространство", hiddenHelp: "Занятое пространство, которое не удалось прочитать при сканировании",
        purgeableHelp: "Пространство, которое macOS может освободить сама, например кэши и локальные снимки",
        emptyFolder: "Эта папка пуста", showInFinder: "Показать в Finder", openInTerminal: "Открыть в Терминале",
        quickLook: "Быстрый просмотр", addToCollector: "Добавить в сборщик", removeFromCollector: "Убрать из сборщика",
        showPackageContents: "Показать содержимое пакета", collector: "Сборщик",
        collectorHint: "Перетащите объекты сюда или нажмите ⌘⌫", moveToTrash: "Переместить в Корзину",
        countdownFormat: "Перемещение в Корзину через %d с", itemsFormat: "Объекты: %1$d · %2$@", removeAll: "Убрать все",
        refuseSpace: "Это пространство нельзя переместить в Корзину", refuseSystemFormat: "«%@» нужен macOS",
        refuseTimeMachine: "Удаляйте резервные копии Time Machine в самой Time Machine", refuseLockedFormat: "«%@» защищен",
        refuseFolderFormat: "Папка «%@» доступна только для чтения", refuseVolumeFormat: "Диск «%@» доступен только для чтения",
        trashFailedFormat: "Не перемещено в Корзину: %d", fullDiskAccessTitle: "Некоторые папки не удалось прочитать",
        fullDiskAccessMessage: "Разрешите полный доступ к диску, чтобы учесть их. До этого их пространство считается скрытым.",
        openSettings: "Открыть настройки")

    static let uk = DiskAnalyzerFeatureStrings(
        title: "Аналіз диска",
        hubDescription: "Дивіться у вигляді кілець або плиток, чим зайняті диски, і переміщуйте непотрібне в Смітник",
        panelCaption: "Дивіться, чим зайняті диски",
        openButton: "Відкрити аналіз диска",
        settingsCaption: "Сканує диски й папки та показує їхній вміст кільцями або плитками. Результати зберігаються в пам’яті, доки вікно відкрите.",
        disks: "Диски", folders: "Папки", scan: "Сканувати", show: "Показати", scanFolder: "Сканувати папку…",
        usageFormat: "Зайнято %1$@ · вільно %2$@ · усього %3$@", keepFolder: "Залишити в списку", forgetFolder: "Прибрати зі списку",
        discardResult: "Відкинути результат", scanningFormat: "Сканування: %@…", filesFormat: "Файли: %@", stop: "Зупинити", evaluating: "Підготовка результату…",
        back: "Назад", forward: "Уперед", up: "Папка рівнем вище", home: "Диски й папки",
        rescan: "Сканувати знову", rescanFolder: "Сканувати цю папку знову", rings: "Кільця", tiles: "Плитки",
        smallerItemsFormat: "Дрібні об’єкти: %d", hiddenSpace: "Прихований простір", purgeableSpace: "Простір для очищення",
        freeSpace: "Вільний простір", hiddenHelp: "Зайнятий простір, який не вдалося прочитати під час сканування",
        purgeableHelp: "Простір, який macOS може звільнити сама, наприклад кеші та локальні знімки",
        emptyFolder: "Ця папка порожня", showInFinder: "Показати у Finder", openInTerminal: "Відкрити в Терміналі",
        quickLook: "Швидкий перегляд", addToCollector: "Додати до збирача", removeFromCollector: "Прибрати зі збирача",
        showPackageContents: "Показати вміст пакета", collector: "Збирач",
        collectorHint: "Перетягніть об’єкти сюди або натисніть ⌘⌫", moveToTrash: "Перемістити в Смітник",
        countdownFormat: "Переміщення в Смітник через %d с", itemsFormat: "Об’єкти: %1$d · %2$@", removeAll: "Прибрати все",
        refuseSpace: "Цей простір не можна перемістити в Смітник", refuseSystemFormat: "«%@» потрібен macOS",
        refuseTimeMachine: "Видаляйте резервні копії Time Machine у самій Time Machine", refuseLockedFormat: "«%@» захищено",
        refuseFolderFormat: "Папка «%@» доступна лише для читання", refuseVolumeFormat: "Диск «%@» доступний лише для читання",
        trashFailedFormat: "Не переміщено в Смітник: %d", fullDiskAccessTitle: "Деякі папки не вдалося прочитати",
        fullDiskAccessMessage: "Дозвольте повний доступ до диска, щоб урахувати їх. Доти їхній простір вважається прихованим.",
        openSettings: "Відкрити параметри")

    static let es = DiskAnalyzerFeatureStrings(
        title: "Analizador de disco",
        hubDescription: "Mira en anillos o mosaicos qué llena tus discos y mueve a la papelera lo que ya no necesitas",
        panelCaption: "Mira qué llena tus discos",
        openButton: "Abrir Analizador de disco",
        settingsCaption: "Analiza discos y carpetas y muestra su contenido en anillos o mosaicos. Los resultados se guardan en memoria hasta cerrar la ventana.",
        disks: "Discos", folders: "Carpetas", scan: "Analizar", show: "Mostrar", scanFolder: "Analizar carpeta…",
        usageFormat: "%1$@ usados · %2$@ libres · %3$@ en total", keepFolder: "Mantener en la lista", forgetFolder: "Quitar de la lista",
        discardResult: "Descartar resultado", scanningFormat: "Analizando %@…", filesFormat: "Archivos: %@", stop: "Detener", evaluating: "Preparando el resultado…",
        back: "Atrás", forward: "Adelante", up: "Carpeta superior", home: "Discos y carpetas",
        rescan: "Volver a analizar", rescanFolder: "Volver a analizar esta carpeta", rings: "Anillos", tiles: "Mosaicos",
        smallerItemsFormat: "Elementos más pequeños: %d", hiddenSpace: "Espacio oculto", purgeableSpace: "Espacio purgable",
        freeSpace: "Espacio libre", hiddenHelp: "Espacio en uso que el análisis no pudo leer",
        purgeableHelp: "Espacio que macOS puede liberar por sí mismo, como cachés e instantáneas locales",
        emptyFolder: "Esta carpeta está vacía", showInFinder: "Mostrar en el Finder", openInTerminal: "Abrir en Terminal",
        quickLook: "Vista rápida", addToCollector: "Añadir al recolector", removeFromCollector: "Quitar del recolector",
        showPackageContents: "Mostrar contenido del paquete", collector: "Recolector",
        collectorHint: "Arrastra elementos aquí o pulsa ⌘⌫", moveToTrash: "Mover a la papelera",
        countdownFormat: "Moviendo a la papelera en %d s", itemsFormat: "Elementos: %1$d · %2$@", removeAll: "Quitar todo",
        refuseSpace: "Este espacio no se puede mover a la papelera", refuseSystemFormat: "macOS necesita «%@»",
        refuseTimeMachine: "Elimina las copias de Time Machine en Time Machine", refuseLockedFormat: "«%@» está bloqueado",
        refuseFolderFormat: "La carpeta «%@» es de solo lectura", refuseVolumeFormat: "El disco «%@» es de solo lectura",
        trashFailedFormat: "No movidos a la papelera: %d", fullDiskAccessTitle: "No se pudieron leer algunas carpetas",
        fullDiskAccessMessage: "Permite el acceso total al disco para incluirlas. Hasta entonces su espacio aparece como oculto.",
        openSettings: "Abrir Ajustes")

    static let sk = DiskAnalyzerFeatureStrings(
        title: "Analýza disku",
        hubDescription: "Pozrite sa v kruhoch alebo dlaždiciach, čo zapĺňa vaše disky, a presuňte nepotrebné do Koša",
        panelCaption: "Pozrite sa, čo zapĺňa vaše disky",
        openButton: "Otvoriť analýzu disku",
        settingsCaption: "Prehľadá disky a priečinky a zobrazí ich obsah ako kruhy alebo dlaždice. Výsledky ostávajú v pamäti, kým sa okno nezatvorí.",
        disks: "Disky", folders: "Priečinky", scan: "Prehľadať", show: "Zobraziť", scanFolder: "Prehľadať priečinok…",
        usageFormat: "Obsadené: %1$@ · voľné: %2$@ · celkom: %3$@", keepFolder: "Ponechať v zozname", forgetFolder: "Odstrániť zo zoznamu",
        discardResult: "Zahodiť výsledok", scanningFormat: "Prehľadáva sa %@…", filesFormat: "Súbory: %@", stop: "Zastaviť", evaluating: "Pripravuje sa výsledok…",
        back: "Späť", forward: "Dopredu", up: "Nadradený priečinok", home: "Disky a priečinky",
        rescan: "Prehľadať znova", rescanFolder: "Prehľadať tento priečinok znova", rings: "Kruhy", tiles: "Dlaždice",
        smallerItemsFormat: "Menšie položky: %d", hiddenSpace: "Skrytý priestor", purgeableSpace: "Uvoľniteľný priestor",
        freeSpace: "Voľný priestor", hiddenHelp: "Obsadený priestor, ktorý sa pri prehľadávaní nepodarilo prečítať",
        purgeableHelp: "Priestor, ktorý macOS dokáže uvoľniť sám, napríklad vyrovnávacie pamäte a lokálne snímky",
        emptyFolder: "Tento priečinok je prázdny", showInFinder: "Zobraziť vo Finderi", openInTerminal: "Otvoriť v Termináli",
        quickLook: "Rýchly náhľad", addToCollector: "Pridať do zberača", removeFromCollector: "Odstrániť zo zberača",
        showPackageContents: "Zobraziť obsah balíka", collector: "Zberač",
        collectorHint: "Presuňte sem položky alebo stlačte ⌘⌫", moveToTrash: "Presunúť do Koša",
        countdownFormat: "Presun do Koša o %d s", itemsFormat: "Položky: %1$d · %2$@", removeAll: "Odstrániť všetko",
        refuseSpace: "Tento priestor nie je možné presunúť do Koša", refuseSystemFormat: "„%@“ potrebuje macOS",
        refuseTimeMachine: "Zálohy Time Machine vymažte priamo v Time Machine", refuseLockedFormat: "„%@“ je zamknuté",
        refuseFolderFormat: "Priečinok „%@“ je iba na čítanie", refuseVolumeFormat: "Disk „%@“ je iba na čítanie",
        trashFailedFormat: "Nepresunuté do Koša: %d", fullDiskAccessTitle: "Niektoré priečinky sa nepodarilo prečítať",
        fullDiskAccessMessage: "Povoľte úplný prístup k disku, aby sa zahrnuli. Dovtedy sa ich priestor zobrazuje ako skrytý.",
        openSettings: "Otvoriť nastavenia")

    static let fr = DiskAnalyzerFeatureStrings(
        title: "Analyse du disque",
        hubDescription: "Voyez en anneaux ou en mosaïque ce qui remplit vos disques et placez à la corbeille ce dont vous n’avez plus besoin",
        panelCaption: "Voyez ce qui remplit vos disques",
        openButton: "Ouvrir l’analyse du disque",
        settingsCaption: "Analyse les disques et dossiers et affiche leur contenu en anneaux ou en mosaïque. Les résultats restent en mémoire jusqu’à la fermeture de la fenêtre.",
        disks: "Disques", folders: "Dossiers", scan: "Analyser", show: "Afficher", scanFolder: "Analyser un dossier…",
        usageFormat: "%1$@ utilisés · %2$@ libres · %3$@ au total", keepFolder: "Garder dans la liste", forgetFolder: "Retirer de la liste",
        discardResult: "Supprimer le résultat", scanningFormat: "Analyse de %@…", filesFormat: "Fichiers : %@", stop: "Arrêter", evaluating: "Préparation du résultat…",
        back: "Précédent", forward: "Suivant", up: "Dossier parent", home: "Disques et dossiers",
        rescan: "Analyser à nouveau", rescanFolder: "Analyser à nouveau ce dossier", rings: "Anneaux", tiles: "Mosaïque",
        smallerItemsFormat: "Éléments plus petits : %d", hiddenSpace: "Espace masqué", purgeableSpace: "Espace purgeable",
        freeSpace: "Espace libre", hiddenHelp: "Espace utilisé que l’analyse n’a pas pu lire",
        purgeableHelp: "Espace que macOS peut libérer seul, comme les caches et les instantanés locaux",
        emptyFolder: "Ce dossier est vide", showInFinder: "Afficher dans le Finder", openInTerminal: "Ouvrir dans Terminal",
        quickLook: "Coup d’œil", addToCollector: "Ajouter au collecteur", removeFromCollector: "Retirer du collecteur",
        showPackageContents: "Afficher le contenu du paquet", collector: "Collecteur",
        collectorHint: "Faites glisser des éléments ici ou appuyez sur ⌘⌫", moveToTrash: "Placer dans la corbeille",
        countdownFormat: "Placement dans la corbeille dans %d s", itemsFormat: "Éléments : %1$d · %2$@", removeAll: "Tout retirer",
        refuseSpace: "Cet espace ne peut pas être placé dans la corbeille", refuseSystemFormat: "macOS a besoin de « %@ »",
        refuseTimeMachine: "Supprimez les sauvegardes Time Machine dans Time Machine", refuseLockedFormat: "« %@ » est verrouillé",
        refuseFolderFormat: "Le dossier « %@ » est en lecture seule", refuseVolumeFormat: "Le disque « %@ » est en lecture seule",
        trashFailedFormat: "Non placés dans la corbeille : %d", fullDiskAccessTitle: "Certains dossiers n’ont pas pu être lus",
        fullDiskAccessMessage: "Autorisez l’accès complet au disque pour les inclure. D’ici là, leur espace apparaît comme masqué.",
        openSettings: "Ouvrir les réglages")

    static let it = DiskAnalyzerFeatureStrings(
        title: "Analisi disco",
        hubDescription: "Guarda ad anelli o a riquadri cosa riempie i tuoi dischi e sposta nel Cestino ciò che non ti serve più",
        panelCaption: "Guarda cosa riempie i tuoi dischi",
        openButton: "Apri Analisi disco",
        settingsCaption: "Analizza dischi e cartelle e ne mostra il contenuto ad anelli o a riquadri. I risultati restano in memoria finché la finestra è aperta.",
        disks: "Dischi", folders: "Cartelle", scan: "Analizza", show: "Mostra", scanFolder: "Analizza cartella…",
        usageFormat: "%1$@ usati · %2$@ liberi · %3$@ in totale", keepFolder: "Mantieni nell’elenco", forgetFolder: "Rimuovi dall’elenco",
        discardResult: "Scarta risultato", scanningFormat: "Analisi di %@…", filesFormat: "File: %@", stop: "Interrompi", evaluating: "Preparazione del risultato…",
        back: "Indietro", forward: "Avanti", up: "Cartella superiore", home: "Dischi e cartelle",
        rescan: "Analizza di nuovo", rescanFolder: "Analizza di nuovo questa cartella", rings: "Anelli", tiles: "Riquadri",
        smallerItemsFormat: "Elementi più piccoli: %d", hiddenSpace: "Spazio nascosto", purgeableSpace: "Spazio eliminabile",
        freeSpace: "Spazio libero", hiddenHelp: "Spazio in uso che l’analisi non è riuscita a leggere",
        purgeableHelp: "Spazio che macOS può liberare da solo, come cache e istantanee locali",
        emptyFolder: "Questa cartella è vuota", showInFinder: "Mostra nel Finder", openInTerminal: "Apri nel Terminale",
        quickLook: "Visualizzazione rapida", addToCollector: "Aggiungi alla raccolta", removeFromCollector: "Rimuovi dalla raccolta",
        showPackageContents: "Mostra contenuto pacchetto", collector: "Raccolta",
        collectorHint: "Trascina qui gli elementi o premi ⌘⌫", moveToTrash: "Sposta nel Cestino",
        countdownFormat: "Spostamento nel Cestino tra %d s", itemsFormat: "Elementi: %1$d · %2$@", removeAll: "Rimuovi tutto",
        refuseSpace: "Questo spazio non può essere spostato nel Cestino", refuseSystemFormat: "“%@” serve a macOS",
        refuseTimeMachine: "Elimina i backup di Time Machine in Time Machine", refuseLockedFormat: "“%@” è bloccato",
        refuseFolderFormat: "La cartella “%@” è di sola lettura", refuseVolumeFormat: "Il disco “%@” è di sola lettura",
        trashFailedFormat: "Non spostati nel Cestino: %d", fullDiskAccessTitle: "Alcune cartelle non sono state lette",
        fullDiskAccessMessage: "Consenti l’accesso completo al disco per includerle. Fino ad allora il loro spazio appare nascosto.",
        openSettings: "Apri Impostazioni")

    static let ja = DiskAnalyzerFeatureStrings(
        title: "ディスク解析",
        hubDescription: "ディスクを占めているものをリングやタイルで確認し、不要なものをゴミ箱に移動します",
        panelCaption: "ディスクを占めているものを確認",
        openButton: "ディスク解析を開く",
        settingsCaption: "ディスクやフォルダをスキャンし、内容をリングまたはタイルで表示します。結果はウインドウを閉じるまでメモリに保持されます。",
        disks: "ディスク", folders: "フォルダ", scan: "スキャン", show: "表示", scanFolder: "フォルダをスキャン…",
        usageFormat: "使用済み %1$@ · 空き %2$@ · 合計 %3$@", keepFolder: "リストに残す", forgetFolder: "リストから削除",
        discardResult: "結果を破棄", scanningFormat: "%@をスキャン中…", filesFormat: "ファイル: %@", stop: "停止", evaluating: "結果を準備中…",
        back: "戻る", forward: "進む", up: "親フォルダ", home: "ディスクとフォルダ",
        rescan: "再スキャン", rescanFolder: "このフォルダを再スキャン", rings: "リング", tiles: "タイル",
        smallerItemsFormat: "小さな項目: %d", hiddenSpace: "隠れた領域", purgeableSpace: "パージ可能な領域",
        freeSpace: "空き領域", hiddenHelp: "使用中だがスキャンで読み取れなかった領域",
        purgeableHelp: "キャッシュやローカルスナップショットなど、macOSが自動で解放できる領域",
        emptyFolder: "このフォルダは空です", showInFinder: "Finderに表示", openInTerminal: "ターミナルで開く",
        quickLook: "クイックルック", addToCollector: "コレクターに追加", removeFromCollector: "コレクターから削除",
        showPackageContents: "パッケージの内容を表示", collector: "コレクター",
        collectorHint: "項目をここにドラッグするか⌘⌫を押します", moveToTrash: "ゴミ箱に入れる",
        countdownFormat: "%d秒後にゴミ箱に移動", itemsFormat: "項目: %1$d · %2$@", removeAll: "すべて削除",
        refuseSpace: "この領域はゴミ箱に移動できません", refuseSystemFormat: "「%@」はmacOSに必要です",
        refuseTimeMachine: "Time MachineのバックアップはTime Machineで削除してください", refuseLockedFormat: "「%@」はロックされています",
        refuseFolderFormat: "フォルダ「%@」は読み出し専用です", refuseVolumeFormat: "ディスク「%@」は読み出し専用です",
        trashFailedFormat: "ゴミ箱に移動できなかった項目: %d", fullDiskAccessTitle: "一部のフォルダを読み取れませんでした",
        fullDiskAccessMessage: "フルディスクアクセスを許可すると含められます。それまでは隠れた領域として表示されます。",
        openSettings: "設定を開く")

    static let ko = DiskAnalyzerFeatureStrings(
        title: "디스크 분석",
        hubDescription: "디스크를 채우는 항목을 링이나 타일로 확인하고 필요 없는 항목을 휴지통으로 이동합니다",
        panelCaption: "디스크를 채우는 항목 확인",
        openButton: "디스크 분석 열기",
        settingsCaption: "디스크와 폴더를 스캔하여 내용을 링이나 타일로 보여줍니다. 결과는 윈도우를 닫을 때까지 메모리에 유지됩니다.",
        disks: "디스크", folders: "폴더", scan: "스캔", show: "보기", scanFolder: "폴더 스캔…",
        usageFormat: "사용 %1$@ · 여유 %2$@ · 전체 %3$@", keepFolder: "목록에 유지", forgetFolder: "목록에서 제거",
        discardResult: "결과 버리기", scanningFormat: "%@ 스캔 중…", filesFormat: "파일: %@", stop: "중단", evaluating: "결과 준비 중…",
        back: "뒤로", forward: "앞으로", up: "상위 폴더", home: "디스크 및 폴더",
        rescan: "다시 스캔", rescanFolder: "이 폴더 다시 스캔", rings: "링", tiles: "타일",
        smallerItemsFormat: "작은 항목: %d", hiddenSpace: "숨겨진 공간", purgeableSpace: "제거 가능한 공간",
        freeSpace: "사용 가능한 공간", hiddenHelp: "사용 중이지만 스캔에서 읽을 수 없었던 공간",
        purgeableHelp: "캐시와 로컬 스냅샷처럼 macOS가 스스로 비울 수 있는 공간",
        emptyFolder: "이 폴더는 비어 있습니다", showInFinder: "Finder에서 보기", openInTerminal: "터미널에서 열기",
        quickLook: "훑어보기", addToCollector: "수집함에 추가", removeFromCollector: "수집함에서 제거",
        showPackageContents: "패키지 내용 보기", collector: "수집함",
        collectorHint: "항목을 여기로 드래그하거나 ⌘⌫를 누르십시오", moveToTrash: "휴지통으로 이동",
        countdownFormat: "%d초 후 휴지통으로 이동", itemsFormat: "항목: %1$d · %2$@", removeAll: "모두 제거",
        refuseSpace: "이 공간은 휴지통으로 이동할 수 없습니다", refuseSystemFormat: "macOS에 “%@”이(가) 필요합니다",
        refuseTimeMachine: "Time Machine 백업은 Time Machine에서 삭제하십시오", refuseLockedFormat: "“%@”이(가) 잠겨 있습니다",
        refuseFolderFormat: "“%@” 폴더는 읽기 전용입니다", refuseVolumeFormat: "“%@” 디스크는 읽기 전용입니다",
        trashFailedFormat: "휴지통으로 이동하지 못한 항목: %d", fullDiskAccessTitle: "일부 폴더를 읽을 수 없었습니다",
        fullDiskAccessMessage: "전체 디스크 접근 권한을 허용하면 포함됩니다. 그 전까지는 해당 공간이 숨겨진 공간으로 표시됩니다.",
        openSettings: "설정 열기")

    static let zhHans = DiskAnalyzerFeatureStrings(
        title: "磁盘分析",
        hubDescription: "以圆环或方块查看占满磁盘的内容，并将不再需要的内容移到废纸篓",
        panelCaption: "查看占满磁盘的内容",
        openButton: "打开磁盘分析",
        settingsCaption: "扫描磁盘和文件夹，并以圆环或方块显示其内容。结果保留在内存中，直到关闭窗口。",
        disks: "磁盘", folders: "文件夹", scan: "扫描", show: "显示", scanFolder: "扫描文件夹…",
        usageFormat: "已用 %1$@ · 可用 %2$@ · 总计 %3$@", keepFolder: "保留在列表中", forgetFolder: "从列表中移除",
        discardResult: "丢弃结果", scanningFormat: "正在扫描 %@…", filesFormat: "文件：%@", stop: "停止", evaluating: "正在整理结果…",
        back: "后退", forward: "前进", up: "上层文件夹", home: "磁盘和文件夹",
        rescan: "重新扫描", rescanFolder: "重新扫描此文件夹", rings: "圆环", tiles: "方块",
        smallerItemsFormat: "较小项目：%d", hiddenSpace: "隐藏空间", purgeableSpace: "可清除空间",
        freeSpace: "可用空间", hiddenHelp: "已使用但扫描无法读取的空间",
        purgeableHelp: "macOS 可自行释放的空间，例如缓存和本地快照",
        emptyFolder: "此文件夹为空", showInFinder: "在访达中显示", openInTerminal: "在终端中打开",
        quickLook: "快速查看", addToCollector: "添加到收集区", removeFromCollector: "从收集区移除",
        showPackageContents: "显示包内容", collector: "收集区",
        collectorHint: "将项目拖到这里或按 ⌘⌫", moveToTrash: "移到废纸篓",
        countdownFormat: "%d 秒后移到废纸篓", itemsFormat: "项目：%1$d · %2$@", removeAll: "全部移除",
        refuseSpace: "此空间无法移到废纸篓", refuseSystemFormat: "macOS 需要“%@”",
        refuseTimeMachine: "请在时间机器中删除时间机器备份", refuseLockedFormat: "“%@”已锁定",
        refuseFolderFormat: "文件夹“%@”为只读", refuseVolumeFormat: "磁盘“%@”为只读",
        trashFailedFormat: "未能移到废纸篓：%d", fullDiskAccessTitle: "部分文件夹无法读取",
        fullDiskAccessMessage: "允许完全磁盘访问权限即可包含它们。在此之前，它们的空间显示为隐藏空间。",
        openSettings: "打开设置")

    static let zhTW = DiskAnalyzerFeatureStrings(
        title: "磁碟分析",
        hubDescription: "以圓環或方塊檢視佔滿磁碟的內容，並將不再需要的內容丟到垃圾桶",
        panelCaption: "檢視佔滿磁碟的內容",
        openButton: "打開磁碟分析",
        settingsCaption: "掃描磁碟和檔案夾，並以圓環或方塊顯示其內容。結果會保留在記憶體中，直到關閉視窗。",
        disks: "磁碟", folders: "檔案夾", scan: "掃描", show: "顯示", scanFolder: "掃描檔案夾⋯",
        usageFormat: "已使用 %1$@ · 可用 %2$@ · 總計 %3$@", keepFolder: "保留在列表中", forgetFolder: "從列表中移除",
        discardResult: "丟棄結果", scanningFormat: "正在掃描 %@⋯", filesFormat: "檔案：%@", stop: "停止", evaluating: "正在整理結果⋯",
        back: "上一頁", forward: "下一頁", up: "上層檔案夾", home: "磁碟和檔案夾",
        rescan: "重新掃描", rescanFolder: "重新掃描此檔案夾", rings: "圓環", tiles: "方塊",
        smallerItemsFormat: "較小項目：%d", hiddenSpace: "隱藏空間", purgeableSpace: "可清除空間",
        freeSpace: "可用空間", hiddenHelp: "已使用但掃描無法讀取的空間",
        purgeableHelp: "macOS 可自行釋放的空間，例如快取和本機快照",
        emptyFolder: "此檔案夾是空的", showInFinder: "在 Finder 中顯示", openInTerminal: "在終端機中打開",
        quickLook: "快速查看", addToCollector: "加入收集區", removeFromCollector: "從收集區移除",
        showPackageContents: "顯示套件內容", collector: "收集區",
        collectorHint: "將項目拖到這裡或按下 ⌘⌫", moveToTrash: "丟到垃圾桶",
        countdownFormat: "%d 秒後丟到垃圾桶", itemsFormat: "項目：%1$d · %2$@", removeAll: "全部移除",
        refuseSpace: "此空間無法丟到垃圾桶", refuseSystemFormat: "macOS 需要「%@」",
        refuseTimeMachine: "請在「時光機」中刪除「時光機」備份", refuseLockedFormat: "「%@」已鎖定",
        refuseFolderFormat: "檔案夾「%@」為唯讀", refuseVolumeFormat: "磁碟「%@」為唯讀",
        trashFailedFormat: "未能丟到垃圾桶：%d", fullDiskAccessTitle: "部分檔案夾無法讀取",
        fullDiskAccessMessage: "允許「完整磁碟取用權限」即可包含它們。在此之前，它們的空間會顯示為隱藏空間。",
        openSettings: "打開設定")

    static let zhHK = DiskAnalyzerFeatureStrings(
        title: "磁碟分析",
        hubDescription: "以圓環或方塊檢視佔滿磁碟的內容，並將不再需要的內容丟到垃圾桶",
        panelCaption: "檢視佔滿磁碟的內容",
        openButton: "打開磁碟分析",
        settingsCaption: "掃描磁碟和檔案夾，並以圓環或方塊顯示其內容。結果會保留在記憶體中，直至關閉視窗。",
        disks: "磁碟", folders: "檔案夾", scan: "掃描", show: "顯示", scanFolder: "掃描檔案夾⋯",
        usageFormat: "已使用 %1$@ · 可用 %2$@ · 總計 %3$@", keepFolder: "保留在列表中", forgetFolder: "從列表中移除",
        discardResult: "丟棄結果", scanningFormat: "正在掃描 %@⋯", filesFormat: "檔案：%@", stop: "停止", evaluating: "正在整理結果⋯",
        back: "上一頁", forward: "下一頁", up: "上層檔案夾", home: "磁碟和檔案夾",
        rescan: "重新掃描", rescanFolder: "重新掃描此檔案夾", rings: "圓環", tiles: "方塊",
        smallerItemsFormat: "較小項目：%d", hiddenSpace: "隱藏空間", purgeableSpace: "可清除空間",
        freeSpace: "可用空間", hiddenHelp: "已使用但掃描無法讀取的空間",
        purgeableHelp: "macOS 可自行釋放的空間，例如快取和本機快照",
        emptyFolder: "此檔案夾是空的", showInFinder: "在 Finder 中顯示", openInTerminal: "在終端機中打開",
        quickLook: "快速查看", addToCollector: "加入收集區", removeFromCollector: "從收集區移除",
        showPackageContents: "顯示套件內容", collector: "收集區",
        collectorHint: "將項目拖到這裏或按下 ⌘⌫", moveToTrash: "丟到垃圾桶",
        countdownFormat: "%d 秒後丟到垃圾桶", itemsFormat: "項目：%1$d · %2$@", removeAll: "全部移除",
        refuseSpace: "此空間無法丟到垃圾桶", refuseSystemFormat: "macOS 需要「%@」",
        refuseTimeMachine: "請在「時光機」中刪除「時光機」備份", refuseLockedFormat: "「%@」已鎖定",
        refuseFolderFormat: "檔案夾「%@」為唯讀", refuseVolumeFormat: "磁碟「%@」為唯讀",
        trashFailedFormat: "未能丟到垃圾桶：%d", fullDiskAccessTitle: "部分檔案夾無法讀取",
        fullDiskAccessMessage: "允許「完整磁碟取用權限」即可包含它們。在此之前，它們的空間會顯示為隱藏空間。",
        openSettings: "打開設定")
}
