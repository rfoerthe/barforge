# Umsetzungsplan: Arbeitszeiterfassung (Time Tracking) – Portierung von Tagwerk

Stand: 21.11.2026 · Quelle: Tagwerk 1.7.0 (Rust, ~22 000 Zeilen, 162 Tests) · Ziel: Barforge 1.0.7 (Swift 6.2, macOS 26)

## 1. Ziel und Abgrenzung

Barforge bekommt ein neues, installierbares Feature **Time Tracking** („Arbeitszeiterfassung“). Es übernimmt den
Funktionsumfang von Tagwerk: Die Arbeitszeit wird automatisch erfasst, solange der Mac entsperrt ist. Dazu kommen Pausen,
Arbeit ohne Mac, Arbeitsbeginn und Feierabend, Abwesenheiten, Soll, Saldo, Zeitkonto, die Prüfung der Regeln nach ArbZG,
Mitteilungen, das Fenster „Aufzeichnungen“ mit den Ansichten Tage und Woche sowie Export und Import.

Die Portierung ist eine **Neuimplementierung in Swift** und keine Einbindung des Rust-Codes. Fachlich soll sie sich genau
wie Tagwerk verhalten: Die Rechenregeln, die Reihenfolge bei Korrekturen („der letzte Eintrag gewinnt“) und die Salden
müssen übereinstimmen. Technisch und in der Bedienung folgt sie den Mustern von Barforge.

**Nicht übernommen** werden, weil Barforge das schon kann oder es nur Tagwerk betrifft:

| Tagwerk | Ersatz in Barforge |
|---|---|
| `login_item.rs` (Anmeldeobjekt) | Barforge startet bereits selbst bei der Anmeldung |
| `about.rs`, eigenes App-Symbol, DMG, `build.sh`, `github-release.sh` | Infrastruktur von Barforge |
| `snapshot.rs`, `--*-screenshot`, `TAGWERK_MENU_STATE` | nicht nötig; Bilder für das README von Hand |
| Prozess `--records`, Statusdatei `.status`, Abgleich über `PRAGMA data_version` | alles läuft in einem Prozess, ein gemeinsamer Store im Speicher |
| `.lock` (nur eine Instanz) | Barforge läuft ohnehin nur einmal |
| Import der alten `tagwerk.md` (Schema 0) | nur Import aus der Datenbank von Tagwerk 1.2 oder neuer (Schema 3) |

## 2. Grundsatzentscheidungen

Die Punkte E1 bis E3 sollten **vor Beginn** feststehen. Für alle anderen gibt es einen Vorschlag.

| # | Frage | Vorschlag | Begründung |
|---|---|---|---|
| E1 | **Sprachen.** Tagwerk gibt es nur auf Deutsch, Barforge verlangt für jedes Feature alle 15 Sprachen (`LocalizationTests`). | Englisch und Deutsch von Hand schreiben, die übrigen 13 Sprachen in Meilenstein M8 übersetzen. Bis dahin bleibt das Feature hinter `isBeta`. | Das Feature hat mehrere hundert Texte; die Tests lassen keine Sprache aus. |
| E2 | **Arbeitszeitregeln.** Die Regeln aus ArbZG und Betriebsvereinbarung sind deutsch, Barforge wird international verwendet. | Den Regelsatz „Deutschland (ArbZG)“ als Standard übernehmen und abschaltbar machen („Keine gesetzlichen Hinweise“). Die Schwellen bleiben fest. | Das Verhalten bleibt so wie in Tagwerk, und die Hinweise stören außerhalb Deutschlands nicht. Ein Regelsatz für andere Länder lässt sich später ergänzen. |
| E3 | **Übernahme der Daten aus Tagwerk.** | Unter Einstellungen › Time Tracking die Aktion „Daten aus Tagwerk übernehmen …“. Sie kopiert `~/Library/Application Support/Tagwerk/tagwerk.db` per `VACUUM INTO` und übernimmt die Einstellungen. Läuft Tagwerk (`de.foerther.tagwerk`), weist Barforge darauf hin. | Bei gleichem Schema ist die Übernahme verlustfrei. Laufen Tagwerk und Barforge gleichzeitig, erfassen beide doppelt. |
| E4 | **Speicherung** | SQLite über das Systemmodul `import SQLite3` mit einem schlanken Wrapper, ohne externe Abhängigkeit. Das **Schema entspricht Tagwerk v3**: `periods`, `breaks`, `day_marks`, `work_blocks`, `absences`, `auto_counting`, `work_rules`. | CONTRIBUTING verbietet externe Pakete. Die Daten wachsen mit den Jahren, und die Tabellen von Tagwerk lassen sich so 1:1 übernehmen. JSON wie bei Scratchpad reicht für Backups, Import und Undo nicht aus. |
| E5 | **Wo die Einstellungen liegen** | Einstellungen in `UserDefaults` (`DefaultsKey.timeTracking*`) mit Backup und Export wie in Barforge üblich. Die **datierten Arbeitszeitregeln** und das Zeitkonto (Startdatum, Übertrag) bleiben in der DB, weil sie zu den Daten gehören. | Für Einstellungen schreibt CONTRIBUTING UserDefaults und Backup vor. Erfasste Daten gehören nach CONTRIBUTING nicht in UserDefaults. |
| E6 | **Zeitmodell** | Wie in Tagwerk: Uhrzeiten als Sekunden seit lokaler Mitternacht (`Int`, 0 bis 86 400), Datum als `LocalDate` (Jahr, Monat, Tag), halboffene `Span`. Sommer- und Winterzeit werden weiterhin nicht behandelt; das wird als bekannte Grenze dokumentiert. | Nur so lassen sich die Rust-Tests 1:1 portieren und die Ergebnisse vergleichen. |
| E7 | **Menüleiste** | (a) Eine eigene Sektion **Time Tracking** im Menüpanel. (b) Optional ein eigenes Statussymbol mit dem Symbol von Tagwerk und der Arbeitszeit, nach dem Vorbild der Zwischenablage-Vorschau (`StatusItemController`). Zunächst kommen nur 2 bis 3 der 9 Symbolsätze, etwa Tagbogen, Schlossuhr und Tagesring. | Barforge hat ein einziges Hauptsymbol. Ein eigenes Symbol ist für Tagwerk-Nutzer aber wichtig. |
| E8 | **UI-Technik** | SwiftUI wie im übrigen Barforge: `Table`, `.inspector`, `.toolbar`. Die Wochenansicht wird eine eigene SwiftUI-`Canvas` oder ein `NSView` über `NSViewRepresentable`; für das Ziehen, Hover und die VoiceOver-Elemente ist ein `NSView` wahrscheinlich robuster. | Das entspricht der Codebasis. Die Wochenansicht ist der aufwendigste UI-Teil. |
| E9 | **Kommandozeile** | `--time-tracking-export` und `--time-tracking-import` erst in einer späteren Ausbaustufe (M9). | Für den Start nicht nötig. |
| E10 | **Lizenz** | Tagwerk steht unter MIT, Barforge unter der GPL-3.0. Weil beide Projekte vom selben Autor stammen, ist die Übernahme unproblematisch. Neue Dateien bekommen den Kopf `GPL-3.0-or-later` und `Copyright (C) 2026 Roland Foerther`. | – |

## 3. Zielarchitektur in Barforge

```
Sources/Vorssaint/
  Core/
    TimeTrackingStrings.swift            // XFeatureStrings, alle 15 Sprachen (extension FeatureStrings)
    TimeTracking/                        // reine Logik, ohne AppKit → kommt in die TEST_SOURCES
      TTSpan.swift                       // Span, union/clip/subtract/fillGaps, shownLen    ← day.rs
      TTDay.swift                        // Day, Break, WorkBlock, Absence, FreeDay, Pipeline   ← day.rs
      TTRules.swift                      // WorkRules, RulesPeriod, Soll, Saldo, Zeitkonto      ← rules.rs
      TTWarnings.swift                   // ArbZG-Prüfungen, Warning-Texte                      ← rules.rs
      TTAlerts.swift                     // LimitAlert/BreakAlert, Watch                        ← rules.rs
      TTTracker.swift                    // Zustandsautomat, ohne Ereignisquellen              ← tracker.rs
      TTEdits.swift                      // Edit, refusal(), Corrections.rewind (Undo)          ← records.rs (Logik)
      TTWeekLayout.swift                 // Stundenraster, Blöcke, Vorschläge, Snapping        ← week_view.rs (Logik)
      TTMarkdown.swift, TTCSV.swift      // Export und Import                                  ← store.rs
      TTFormat.swift                     // fmtClock/fmtBalance/parse*, lokalisierte Formatierung
  Services/TimeTracking/
    TimeTrackingDatabase.swift           // SQLite3-Wrapper, Schema v3, Migration, Backups      ← store.rs
    TimeTrackingStore.swift              // lädt und speichert Tage, Diff, editDay, importDays
    TimeTrackingService.swift            // ObservableObject .shared, syncWithPreferences(),
                                         //   Lock/Sleep/Session/Idle, 15-s-Timer, roll over, Persistenz
    TimeTrackingNotifications.swift      // Kategorien, Nachfrage nach langer Sperre, Erinnerungen
    TimeTrackingPDF.swift                // PDF für A4                                          ← pdf.rs
    TimeTrackingTagwerkImport.swift      // Übernahme von DB und Einstellungen aus Tagwerk
  UI/TimeTracking/
    TimeTrackingSection.swift            // Sektion im Menüpanel
    TimeTrackingStatusItem.swift         // optionales Statussymbol mit Zeit           ← menubar.rs, glyphs.rs
    TimeTrackingGlyphs.swift             // Symbolsätze als Pfade
    RecordsWindow.swift                  // Fenster (NSWindow und NSHostingController, Vorbild DiskAnalyzer)
    RecordsDaysView.swift                // Kennzahlen, Tabelle, Filter, Fußzeile       ← records.rs
    RecordsInspector.swift               // Inspektor
    RecordsWeekView.swift                // Wochenansicht (NSView/Canvas)               ← week_view.rs
    RecordsExportSheet.swift, RecordsImportSheet.swift
  UI/Settings/
    TimeTrackingSettings.swift           // eigene SettingsPage                         ← settings_window.rs
    TimeTrackingRulesSheet.swift         // Blatt „Arbeitszeit ändern“
Tests/
  TimeTrackingDayTests.swift, …RulesTests, …TrackerTests, …StoreTests, …EditsTests, …WeekLayoutTests,
  …SettingsTests, TimeTrackingParityTests.swift, Fixtures/TimeTracking/…
```

**Datenfluss:** `TimeTrackingService` hält einen `TTTracker` und die `TimeTrackingStore`-Instanz. Die UI (Panel, Fenster,
Einstellungen) beobachtet den Service mit `@Published`. Änderungen aus dem Fenster laufen immer über den Service, damit
ein laufender Abschnitt und Arbeit ohne Mac stimmig bleiben; in Tagwerk erledigt das `Embed`/`via_menubar`. Den Abgleich
mehrerer Prozesse über `data_version` und die Statusdatei braucht es nicht mehr. Die Daten zum Neustart (Pause seit, Ohne Mac
seit und Grund) liegen als Maschinenzustand in `UserDefaults` (`machineStateKeys`, ohne Export).

**Dateien:** `PrivateFileStore.containerURL/TimeTracking/timetracking.db` und `…/TimeTracking/backups/`. Die
Developer-Variante ist über die Bundle-ID automatisch getrennt. Der Deinstaller entfernt den Container ohnehin.

## 4. Einbindung in Barforge (Checkliste)

Vorbild ist der Commit `35268031 feat(disk-analyzer)`, der genau diese Stellen berührt hat.

- [ ] `Core/FeatureCatalog.swift`: neuer Fall `AppFeature.timeTracking`, dessen Rohwert sich nie wieder ändern darf. Dazu
      `group = .tools`, `symbolName = "clock.badge.checkmark"`, `enabledKeys = [DefaultsKey.timeTrackingEnabled]`,
      `permissions = [.notifications]`, `installedByDefault = false`, `isBeta = true` bis M8,
      `activeFeatures(using:)` (Mitteilungen nur, wenn eine Erinnerung oder die Nachfrage an ist).
- [ ] `Core/FeaturePresets.swift` (`energyProfile = .periodic`), `App/FeatureRuntime.swift` (`bindings`,
      `hardwareUnsupportedReason`), `Core/ReleaseChangeAliases.swift`.
- [ ] `UI/Settings/FeatureHubSettings.swift` (`hubTitle`, `hubDescription`) und `FeatureVisibilitySupport.swift`
      (`SettingsPage.timeTracking`, `settingsDestination`, `features(for:)`).
- [ ] `UI/Settings/SettingsView.swift` (detail) und `SettingsDirectory.swift` (Eintrag und alle `searchItems` für
      `SettingsSearchCoverageTests`).
- [ ] `UI/MenuPanel/PanelLayout.swift`: `PanelSectionID.timeTracking` mit `title`, `symbolName`, `visibilityKey`,
      `featureGate`. Dazu `MenuPanelView.swift` (`@AppStorage`, Höhe, `section(for:)`, `isSectionVisible`) und
      `PanelLayoutEditor.swift` (description).
- [ ] `Core/Defaults.swift`: alle Schlüssel und `registeredDefaults`. Maschinenzustand kommt in `machineStateKeys`.
- [ ] `Core/GlobalShortcut.swift`: die Rollen `timeTrackingPause` (⌃⌥⌘P) und `timeTrackingRecords` (⌃⌥⌘A), mit allen
      Pflichtfeldern. `QuickToolHotkey`-IDs kommen aus dem freien Bereich 30 bis 56.
- [ ] `Services/Notifier.swift`: **zentrale Registrierung der Kategorien**, weil `setNotificationCategories` alle
      ersetzt. Bisher gibt es nur die Kategorie für WhatsApp. `AppDelegate` bekommt `willPresent`, damit Mitteilungen auch
      bei offenem Panel erscheinen, und eine Weiterleitung in `didReceive response`.
- [ ] `AppDelegate.applicationWillTerminate`: `TimeTrackingService.shared.shutdown()`, nur wenn das Feature verfügbar
      ist. Ein neuer Beobachter für `willPowerOff` (beim Abmelden oder Neustart endet die Pause).
- [ ] Optional: Eintrag in der Command Bar („Aufzeichnungen öffnen“), Kachel im Schnellpanel, Kontextmenü.
- [ ] `build.sh` `TEST_SOURCES`: alle Dateien aus `Core/TimeTracking/*`, `TimeTrackingStrings.swift` und dem Datenbankteil.
      Prüfen, ob `swiftc` `SQLite3` ohne `-lsqlite3` linkt; das Modul des SDK linkt normalerweise selbst.
- [ ] `Tests/MetricsTests.swift` (`groups`): die Suite `time-tracking` registrieren.
- [ ] Vertragstests anpassen: `FeatureCatalogTests` (Anzahl 68 → 69, Reihenfolge, Gruppen, `activeSet(.notifications)`),
      `ReleaseDigestTests`, `UpdateFeatureTests`, `SettingsSearchCoverageTests`, `MenuPanelSectionGateTests`,
      `KeyboardFeatureTests` und die Shortcut-Tests, `SettingsFeatureTests` (Backup-Schlüssel).

## 5. Meilensteine

Jeder Meilenstein wird ein eigener PR gegen `develop`. Er baut ohne Warnungen und besteht `./build.sh --test` und
`./build/BarforgeDeveloper --selftest`. Bis M4 ist das Feature nur in der Developer-Variante sichtbar oder bleibt
hinter `isBeta`.

### M0 – Gerüst (S)
- Das Feature im Katalog eintragen (Checkliste §4, ohne Panel und Shortcuts). Dazu ein leerer `TimeTrackingService`
  mit `syncWithPreferences()`, eine leere Einstellungsseite, `TimeTrackingStrings` mit EN, DE und vorläufig englischen
  Platzhaltern, die Test-Suite und `TEST_SOURCES`.
- **Fertig, wenn** das Feature im Feature-Hub installiert und deinstalliert werden kann und alle Vertragstests grün sind.

### M1 – Fachkern: Tag und Regeln (L)
- `TTSpan` und `TTDay` portieren: die Pipeline `unframed_spans` (gefüllte Lücken → manueller Beginn und Ende → Arbeit ohne
  Mac → Pausen abziehen), Clipping am Rahmen, `outside_frame_spans`, `actual_spans`, `record()` mit `shown_*`, Pausen,
  Abschnitte am Stück, `set_start`/`set_end`/`add_break`/`add_work`/`join_work_gaps` („der letzte Eintrag gewinnt“) und die
  Prädikate für Abwesenheiten.
- `TTRules`: `WorkRules` (Standardwerte, `sanitized`, Bitmaske Mo–Fr), datierte Stände (`rules(date)`, `set_rules`,
  `remove_rules`, `normalized`), `daily_target_on` (Verteilung in ganzen Minuten), `day_target`, `counted_target`
  (heute höchstens bis zum Erarbeiteten), `missing_workdays`, `balance`, `account`.
- `TTWarnings`: § 3, § 4 und § 5 ArbZG, LongStretch, freier Tag, außerhalb des Rahmens. Jede Prüfung läuft zweimal, erst
  mit der gezählten, dann mit der tatsächlichen Zeit (`outside: true`).
- `TTAlerts`: die Schwellen 5:45/6:00 und 9:45/10:00, `Watch` mit `init()`.
- **Tests:** die 34 Tests aus `day.rs` und die 22 aus `rules.rs` 1:1 portieren. Wo sie deutsche Texte prüfen, prüfen sie
  `de`.
- **Fertig, wenn** alle 56 Tests grün sind.

### M2 – Speicherung, Export und Import (M)
- `TimeTrackingDatabase`: `sqlite3_open_v2`, WAL, `busy_timeout`, `user_version = 3`, `application_id`. Alle Tabellen
  `WITHOUT ROWID` wie in Tagwerk, dazu `CREATE TABLE IF NOT EXISTS` und `ALTER TABLE` für `free_days_count`. Ein Tag wird
  immer ganz geschrieben (löschen, dann einfügen), `saveDays(changed, removed)` läuft in einer IMMEDIATE-Transaktion,
  dazu `editDay(date, f)` und `drop_stale_free_days`.
- Backups: Vor der ersten Änderung eines Tages `VACUUM INTO backups/timetracking-YYYY-MM-DD.db`; die letzten 15 bleiben.
  Vor einem Import ein eigenes Backup.
- Export als Markdown (vollständig, lässt sich wieder einlesen), als CSV (BOM, `;`, CRLF, Dezimalkomma) und als `Report`
  (für das PDF in M6). Den Import mit tolerantem Parser und `check_import` übernehmen.
- **Übernahme aus Tagwerk (E3):** die DB kopieren, das Schema prüfen, Einstellungen aus `settings` und `work_rules` nach
  UserDefaults bzw. in die eigene DB übertragen.
- **Tests:** die 18 Tests aus `store.rs`. Dazu Rundlauf-Tests mit einer temporären DB über ein injiziertes
  `directoryURL`, nach dem Vorbild `ScratchpadStoreContractTests`.

### M3 – Erfassung: Tracker und Ereignisse (L)
- `TTTracker` als reinen Zustandsautomaten portieren: `start`, `stop(reason)`, `commit` (über Mitternacht geteilt),
  `go_idle`, `take_break`, `go_away`/`end_away`, `roll_over`, `set_start`, `close_day`, `reopen_day`, `set_counting`,
  `remove_work`, `replace_days`, `diff`/`save` (nur geänderte Tage), `status()` mit der Rangfolge
  Absent > Closed > Away > Break > FreeDay > Outside > Running > Paused, `TodayInfo`.
- Im `TimeTrackingService` die Ereignisse anbinden, mit den vorhandenen Bausteinen von Barforge:
  - Sperren und Entsperren über `DistributedNotificationCenter`, nach dem Muster in `KeepAwakeManager`
    (`syncScreenLockMonitoring`).
  - Anfangszustand über `KeepAwakeAutomationSupport.isScreenLocked(...)`.
  - `SessionActivity.shared` für den schnellen Benutzerwechsel.
  - NSWorkspace `willSleep`, `didWake` und `willPowerOff`.
  - Inaktivität über `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: kCGAnyInputEventType)`.
    Während `PreventUserIdleDisplaySleep` oder `NoDisplaySleepAssertion` aktiv ist, zählt keine Inaktivität
    (`IOPMCopyAssertionsStatus`).
  - Ein Timer alle 15 s in den Common Modes: `roll_over`, Sicherheitsnetz, Inaktivität, Neustart, Speichern bei Änderung
    oder spätestens nach 60 s.
- Neustart und Absturz: den Zustand zum Neustart aus UserDefaults lesen. Eine Pause am selben Tag wird nur bei
  entsperrtem Mac wiederhergestellt, Arbeit ohne Mac auch bei gesperrtem.
- Deinstallation: In `syncWithPreferences()` werden Beobachter und Timer beendet und der laufende Abschnitt gespeichert.
- **Tests:** die 25 Tests aus `tracker.rs`. Sie verwenden eine manuelle Uhr, die als `now` übergeben wird; es gibt
  bereits `Tests/ManualScheduler.swift`.

### M4 – Menüleiste, Mitteilungen, Kurzbefehle (M)
- **Sektion im Panel:** Status mit farbigem Punkt, „Heute gearbeitet X von Soll“, Pausen, Beginn, Wochensaldo,
  Zeitkonto, bis zu sechs Hinweise. Als Aktionen „Heute erfassen“ (nur an freien Tagen), „Arbeit unterbrechen“,
  „Weiter arbeiten“ und „Zurück am Mac“, „Ohne Mac weiterarbeiten ›“ (Meeting, Telefonat, Networking, Sonstiges),
  „Pause als Arbeitszeit zählen ›“, „Arbeitsbeginn ›“ und „Feierabend ›“ (Jetzt, vor 15 und vor 30 Min.,
  andere Uhrzeit, erstes Entsperren) sowie „Feierabend aufheben“ und „Aufzeichnungen …“. Die Regeln zur Sichtbarkeit
  kommen aus `menubar.rs:813-867`.
- **Statussymbol (E7):** optional, mit Symbol und Arbeitszeit von heute (Ziffern in fester Breite) und Tooltip.
  Ein Klick öffnet das Panel auf der Sektion.
- **Mitteilungen:** `max-hours-soon/reached`, `break-soon/reached`, `entry-refused`, `work-cut`, `away-forgotten`,
  `db-error`, außerdem die Kategorie `time-tracking.lock-ask` mit fünf Aktionen. Die Antwort trägt Arbeit ohne Mac über
  die Sperre ein oder setzt den Feierabend auf den Beginn der Sperre. Die Bedingungen stehen in `menubar.rs:639-655`.
- **Kurzbefehle:** die beiden `GlobalShortcutRole`s aus §4, abgeschaltet als Standard.
- Fehler der DB erscheinen rot in der Sektion und im Tooltip, beim ersten Mal zusätzlich als Mitteilung.
- **Tests:** die 9 Tests aus `menubar.rs` (Logik: Titel, Texte, Kodierung der Tags) und die Bedingungen der Nachfrage.

### M5 – Einstellungen (M)
- Eine eigene `SettingsPage.timeTracking` mit vier Bereichen:
  - **Allgemein:** Statussymbol an oder aus, Symbolsatz mit Vorschau der vier Zustände, Arbeitszeit neben dem Symbol,
    Kurzbefehle als `ShortcutPreferenceRow`.
  - **Arbeitszeit:** Liste der Stände (Gültig ab, Woche, Arbeitstage, Rahmen, Pause ab, Freie Tage) mit Neu, Bearbeiten
    und Löschen. Das Blatt zeigt die betroffenen Tage, rückwirkende Änderungen in Orange. Dazu das Zeitkonto mit
    Startdatum und Übertrag (`+12:30`) und der Regelsatz nach E2.
  - **Erfassung:** Mindestdauer für Arbeit ohne Mac, Inaktivität, Nachfrage nach langer Sperre, Freie Tage.
  - **Mitteilungen:** Status der Berechtigung (`Permissions.shared.notifications`) und die beiden Erinnerungen.
- „Standardwerte“ mit Rückfrage; der Ordner-Knopf zeigt den Datenordner. Außerdem „Daten aus Tagwerk übernehmen …“ (E3).
- **Tests:** die 9 Tests aus `settings_window.rs` (Hinweise im Blatt, betroffene Tage, 24:00, ungerades Soll).

### M6 – Fenster „Aufzeichnungen“: Ansicht Tage (L)
- Fenster nach dem Muster von DiskAnalyzer: `NSWindow`, `NSHostingController`, `WindowActivationPolicy`,
  `setFrameAutosaveName`, Mindestgröße 940×480.
- Symbolleiste: Aktualisieren, Tag bearbeiten, Exportieren, Inspektor, Umschalter Tage | Woche (⌘1 und ⌘2), Filter
  (Zeitraum, nur mit Hinweisen, nur korrigiert). Dazu die Menübefehle ⌘N, ⌘E, ⇧⌘I, ⌘T, ⌘R und ⌥⌘I. Barforge ist eine
  Accessory-App, deshalb kommen die Befehle per `.commands`/`keyboardShortcut` im Fenster.
- Fünf Kennzahlen-Karten, eine Tabelle mit Wochenzeilen, Tagen und fehlenden Arbeitstagen, eine Fußzeile mit den Regeln
  des gewählten Tages.
- **Inspektor:** Kopf mit Arbeitszeit, Pausen, Saldo und Hinweisen. Darunter Abwesenheit (ganz oder halb), Erfassung,
  Arbeitsbeginn, Pausen, Arbeit ohne Mac, Feierabend, „Automatisch erfasst“ (aufklappbar) und „Alle Einträge löschen …“.
  Jeder Abschnitt hat einen Info-Knopf.
- **Bearbeiten:** `TTEdits` mit `refusal()`/`refuses()`, Rückfrage vor dem ersten erfassten Tag, Rückfrage bei
  ganztägiger Abwesenheit heute. Undo und Redo mit 50 Schritten und Dreiwege-Merge (`Corrections::rewind`). Dafür einen
  eigenen `UndoManager` des Fensters nutzen und die Logik in `TTEdits` behalten.
- Export-Dialog: `NSSavePanel` mit Zubehör (Vorgaben, Zeitraum, Format, Zusammenfassung). PDF über `NSPrintOperation`
  oder Core Graphics, A4, Inhalt wie `pdf.rs`. Import mit Rückfrage und vorherigem Backup.
- **Tests:** die 16 Tests aus `records.rs`.

### M7 – Fenster „Aufzeichnungen“: Wochenansicht (L+)
- `TTWeekLayout` als reine Logik: Stundenbereich (kompakt oder voller Rahmen), schmale Spalten für freie Tage, Blockarten
  (Arbeit, außerhalb, freier Tag, Arbeit ohne Mac schraffiert), Band für Abwesenheiten, Kopf mit Arbeitszeit, Pausen,
  fehlendem Soll und Warnschild.
- Interaktion: Beginn und Ende ziehen (Raster 5 Min., mit ⌥ 1 Min., Magnet am erfassten Wert, Grenzen, Schild mit
  Abweichung, Esc, ⌘Z). Ein Klick auf einen freien Bereich öffnet „Arbeit ohne Mac eintragen“ mit Vorschlag und
  Hover-Rahmen. Ein Klick auf eine Schraffur bietet „löschen“ an. Ein Klick auf eine Uhrzeit kopiert sie. Ein Doppelklick
  springt zu Tage und Inspektor. Dazu das Kontextmenü und die Pfeiltasten für die Navigation.
- VoiceOver: ein Element je Tag und je Abschnitt, mit eigenen Aktionen (5 Min. früher oder später, ändern, zurücksetzen).
- **Tests:** die 24 Tests aus `week_view.rs`.

### M8 – Sprachen, Doku, Release (M)
- Die übrigen 13 Sprachen in `TimeTrackingStrings` übersetzen. Die Regeln aus `LocalizationTests` gelten: keine
  Geviertstriche, `…`, Anführungszeichen je Sprache, gleiche Formatargumente. Uhrzeit- und Zahlenformate sollen der
  Sprache folgen, CSV und Markdown bleiben fest im Format von Tagwerk.
- `isBeta` entfernen. Doku: README („Everything it does“), `CHANGELOG-BARFORGE.md` (`[Unreleased]`),
  `docs/PERMISSIONS.md` (Mitteilungen), `docs/PRIVACY.md` (lokale DB), eventuell `docs/TROUBLESHOOTING.md`.
  Anschließend `python3 Tools/fork-rebrand.py --check`.

### M9 – Später (optional)
- Kommandozeile `--time-tracking-export/-import`, weitere Symbolsätze, ein Regelsatz für andere Länder, ein
  Feiertagskalender je Bundesland (bisher gibt es in Tagwerk keinen), Behandlung von Sommer- und Winterzeit.

## 6. Teststrategie

1. **Unit-Tests portieren:** Die Logik-Tests aus `day`, `rules`, `tracker`, `store`, `records`, `week_view`,
   `settings_window` und `menubar` werden fast 1:1 übernommen; zusammen sind es rund 157 Tests. Sie laufen im
   Barforge-Harness (`suite.expect`) und rechnen mit fester Uhr und festem Datum.
2. **Vergleich mit Tagwerk:** `testdata/generate_testdata.py` erzeugt eine Markdown-Datei über 18 Monate mit
   Feiertagen, Urlaub, Zeitausgleich, Sonderurlaub, Arbeit ohne Mac und Regelverstößen. Diese Datei, ihr **CSV- und
   Markdown-Export aus Tagwerk** und der Saldo des Zeitkontos landen als Fixtures unter `Tests/Fixtures/TimeTracking/`.
   `TimeTrackingParityTests` liest die Datei mit der Swift-Implementierung ein, exportiert sie wieder und vergleicht
   byteweise. Das sichert Saldo, Pausen, Hinweise und Rundung über Hunderte echter Tage ab.
3. **DB-Kompatibilität:** Eine Testdatenbank aus `testdata/testdb.sh` wird mit der Übernahme aus Tagwerk geöffnet; die
   Ergebnisse müssen dem Vergleichstest entsprechen.
4. **Manuell:** sperren, entsperren, Ruhezustand, Benutzerwechsel, Inaktivität bei laufender Videokonferenz, Mitternacht
   mit `now` aus `TAGWERK_NOW` (als Umgebungsvariable `BARFORGE_TT_NOW` nur in Developer-Builds), Deinstallation und
   Neuinstallation während einer laufenden Erfassung.

## 7. Risiken und offene Punkte

| Risiko | Gegenmaßnahme |
|---|---|
| Der Umfang ist groß: allein `records.rs` und `week_view.rs` umfassen rund 9 300 Zeilen. | Die Meilensteine einzeln ausliefern; M1 bis M5 ergeben schon eine nutzbare Erfassung ohne Fenster. |
| Ergebnisse weichen von Tagwerk ab, etwa bei der Rundung der angezeigten Minuten. | Vergleichstest (§6.2) ab M2 in jedem Build. |
| Tagwerk und Barforge erfassen gleichzeitig. | Barforge erkennt ein laufendes Tagwerk (Bundle-ID) und warnt im Panel und in den Einstellungen. |
| Upstream-Merges von Vorssaint stoßen auf geänderte gemeinsame Dateien (FeatureCatalog, MenuPanelView, Defaults …). | Änderungen an Upstream-Dateien klein halten und die Logik in eigene Dateien legen. Bei Konflikten hilft `Tools/fork-rebrand.py`. |
| `setNotificationCategories` ersetzt alle Kategorien. | Registrierung zentral in `Notifier` (§4). |
| Ein Timer alle 15 s kostet Energie, besonders in der Hub-Anzeige mit `.periodic`. | Der Timer läuft nur, wenn das Feature an ist, und der Mac weder gesperrt ist noch schläft. Die Toleranz des Timers wird gesetzt. |
| Barforge ist eine Accessory-App; Menübefehle im Fenster sind ungewohnt. | Das Muster von `WindowActivationPolicy` mit Dock-Symbol, solange das Fenster offen ist, und die Kurzbefehle im Fenster. |

## 8. Grobe Größenordnung

| Meilenstein | Umfang | Abhängig von |
|---|---|---|
| M0 Gerüst | S | – |
| M1 Fachkern | L | M0 |
| M2 Speicherung | M | M1 |
| M3 Tracker und Ereignisse | L | M1, M2 |
| M4 Menüleiste und Mitteilungen | M | M3 |
| M5 Einstellungen | M | M2 |
| M6 Tage, Inspektor, Export | L | M2, M3 |
| M7 Wochenansicht | L+ | M6 |
| M8 Sprachen und Release | M | alle |

M1 und M2 sowie M5 und M6 lassen sich teilweise parallel bearbeiten, wenn die Datentypen aus M1 feststehen.

## 9. Konventionen für die Umsetzung

Diese Regeln gelten für alle Meilensteine ab M1.

1. **Ablage:**
   - Reine Logik liegt in `Sources/Vorssaint/Core/TimeTracking/`. Sie importiert nur Foundation, kein AppKit und kein SwiftUI, und jede Datei steht in `build.sh` unter `TEST_SOURCES`.
   - Services kommen nach `Sources/Vorssaint/Services/TimeTracking/`.
   - Die Oberfläche kommt nach `Sources/Vorssaint/UI/TimeTracking/`, die Einstellungen nach `UI/Settings/`.
2. **Namen:** Typen der Fachlogik tragen das Präfix `TT` (`TTDate`, `TTSpan`, `TTDay`, `TTWorkRules`, `TTSettings`, `TTTracker` …).
3. **Getreue Portierung:**
   - Algorithmen, Standardwerte, Grenzen und Rundungen entsprechen Tagwerk. Ein Kommentar verweist auf die Stelle in Rust (`day.rs:674`), wo das hilft.
   - Uhrzeiten sind `Int`, gezählt in Sekunden seit Mitternacht (0 bis 86 400).
   - Ein Datum ist ein `TTDate` (Jahr, Monat, Tag, gregorianisch, ohne Zeitzone). Seine Ordinalzahl entspricht chronos `num_days_from_ce`, denn `account_from_day` wird so gespeichert.
4. **Keine Uhr in der Logik:** Die Logik liest „jetzt“ nie selbst. Datum und Uhrzeit werden immer übergeben.
5. **Texte:**
   - Alle Texte, die Benutzer sehen, stehen in `Core/TimeTrackingStrings.swift`. Dort gibt es neue Structs in `extension FeatureStrings` mit Englisch und Deutsch.
   - Die übrigen 13 Sprachen liefern bis M8 die englischen Texte (`case .ptBR: return .enUS`).
   - Funktionen, die Text erzeugen, bekommen den String-Struct als Parameter. Tests, die Tagwerks deutsche Texte prüfen, übergeben `.de`.
   - Verboten sind der Geviertstrich U+2014 und `...`; stattdessen `…`. Die Anführungszeichen „“ gibt es nur auf Deutsch. Ein negativer Saldo bekommt wie in Tagwerk das Minuszeichen U+2212.
6. **Tests:**
   - Jeder `#[test]` des portierten Moduls wird übernommen; die mit `#[ignore]` (GUI) entfallen.
   - Die Tests stehen in `Tests/TimeTracking<Modul>Tests.swift` als `enum … { static func run(_ suite: TestSuite) }` und werden aus `TimeTrackingTests.run` aufgerufen.
   - Gezielt laufen sie mit `./build.sh --test-suite=time-tracking`, am Ende jedes Meilensteins mit `./build.sh --test` und `./build.sh --dev`, ohne Warnungen.
7. **Dateiköpfe:**
   - Neue Dateien beginnen mit `// SPDX-License-Identifier: GPL-3.0-or-later` und `// Copyright (C) 2026 Roland Foerther`.
   - Geänderte Upstream-Dateien bekommen die Zeile `Roland Foerther` unter der Zeile von Vorssaint, falls sie fehlt.
8. **Technik:** Swift 6.2, keine externen Pakete. Der Zugriff auf die Datenbank läuft über `import SQLite3`.
9. **Dateien:** Die Datenbank liegt unter `PrivateFileStore.containerURL/TimeTracking/timetracking.db`, die Backups unter `…/TimeTracking/backups/`.
