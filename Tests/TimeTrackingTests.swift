// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Time Tracking, the port of Tagwerk: its place in the catalog, its texts,
/// its settings, the logic of days and rules, storage, export and import. The
/// other suites join here as the milestones in docs/TIME-TRACKING-PLAN.md land.
enum TimeTrackingTests {
    static func run(_ suite: TestSuite) {
        catalog(suite)
        strings(suite)
        preferences(suite)
        markdownLanguage(suite)
        sentences(suite)
        translations(suite)
        TimeTrackingDayTests.run(suite)
        TimeTrackingRulesTests.run(suite)
        TimeTrackingStoreTests.run(suite)
        TimeTrackingParityTests.run(suite)
        TimeTrackingTrackerTests.run(suite)
        TimeTrackingEngineTests.run(suite)
        TimeTrackingMenuTests.run(suite)
        TimeTrackingSettingsTests.run(suite)
        TimeTrackingRecordsTests.run(suite)
        TimeTrackingWeekTests.run(suite)
    }

    private static func catalog(_ suite: TestSuite) {
        let feature = AppFeature.timeTracking
        suite.expect(feature.rawValue == "timeTracking", "the Time Tracking id is stable")
        suite.expect(feature.group == .tools && !feature.installedByDefault && !feature.isBeta,
                     "Time Tracking is an opt-in tool")
        suite.expect(feature.enabledKeys == [DefaultsKey.timeTrackingEnabled],
                     "installing Time Tracking turns its recording switch on")
        suite.expect(feature.permissions == [.notifications], "Time Tracking only ever uses notifications")
        suite.expect(feature.energyProfile == .periodic, "Time Tracking checks the time on an interval")
        suite.expect(feature.settingsDestination == FeatureSettingsDestination(.timeTracking),
                     "Time Tracking has a Settings page of its own")
        suite.expect(FeatureVisibilitySupport.features(for: .timeTracking) == [feature],
                     "the Time Tracking page is gated by the feature")

        func notifies(_ values: [String: Bool]) -> Bool {
            AppFeature.activeFeatures(using: .notifications,
                                      isAvailable: { $0 == .timeTracking },
                                      boolFor: { values[$0] ?? false },
                                      stringFor: { _ in nil })
                .contains(.timeTracking)
        }
        let on = [DefaultsKey.timeTrackingEnabled: true, DefaultsKey.timeTrackingLegalHints: true]
        suite.expect(!notifies(on), "recording without reminders or the lock question uses no notifications")
        for key in [DefaultsKey.timeTrackingNotifyLimit, DefaultsKey.timeTrackingNotifyBreak,
                    DefaultsKey.timeTrackingAskAfterLock] {
            suite.expect(notifies(on.merging([key: true]) { $1 }), "\(key) uses notifications while recording")
            suite.expect(!notifies([key: true]), "\(key) uses no notifications while recording is off")
        }
    }

    private static func strings(_ suite: TestSuite) {
        let english = TimeTrackingFeatureStrings.enUS
        for language in AppLanguage.allCases where language != .enUS {
            let text = FeatureStrings.timeTracking(language)
            suite.expect(text.title != english.title && text.hubDescription != english.hubDescription
                         && text.recordToggle != english.recordToggle
                         && text.recordCaption != english.recordCaption,
                         "\(language.rawValue) translates Time Tracking")
        }
    }

    private static func sentences(_ suite: TestSuite) {
        suite.expect(TTSentence.ended("Pausen ab 15 Min.") == "Pausen ab 15 Min.", "a finished sentence stays")
        suite.expect(TTSentence.ended("Breaks from 15 min") == "Breaks from 15 min.", "a sentence gets its full stop")
        suite.expect(TTSentence.ended("休息从 15 分钟") == "休息从 15 分钟。", "Chinese ends with a full-width stop")
        suite.expect(TTSentence.ended("休憩は 15 分から") == "休憩は 15 分から。", "Japanese ends with a full-width stop")
        var text = "Beginn 07:30"
        TTSentence.append("Arbeitszeit +0:25 Std.", to: &text)
        suite.expect(text == "Beginn 07:30. Arbeitszeit +0:25 Std.", "a further sentence follows after a space")
        var cjk = "开始时间已更改"
        TTSentence.append("工作时间 +0:25", to: &cjk)
        suite.expect(cjk == "开始时间已更改。工作时间 +0:25", "a further Chinese sentence follows without a space")
    }

    private static func translations(_ suite: TestSuite) {
        for language in AppLanguage.allCases where language != .enUS {
            suite.expect(FeatureStrings.timeTrackingTexts(language).workWithoutMac != TimeTrackingTexts.enUS.workWithoutMac
                         && FeatureStrings.timeTrackingMenu(language).statusAbsentFormat
                            != TimeTrackingMenuTexts.enUS.statusAbsentFormat
                         && FeatureStrings.timeTrackingSettings(language).statusItem
                            != TimeTrackingSettingsStrings.enUS.statusItem
                         && FeatureStrings.timeTrackingRecords(language).weekdayNames
                            != TimeTrackingRecordsStrings.enUS.weekdayNames
                         && FeatureStrings.timeTrackingWeek(language).previousWeekTip
                            != TimeTrackingWeekStrings.enUS.previousWeekTip,
                         "\(language.rawValue) translates the Time Tracking texts")
        }
    }

    private static func markdownLanguage(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let texts = TTImport.markdownTexts(for: language)
            suite.expect(TTImport.languages.contains { $0.workWithoutMac == texts.workWithoutMac },
                         "a Markdown export in \(language.rawValue) reads back in")
        }
    }

    private static func preferences(_ suite: TestSuite) {
        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.timeTrackingEnabled] as? Bool == false
                     && registered[DefaultsKey.timeTrackingNotifyLimit] as? Bool == true
                     && registered[DefaultsKey.timeTrackingNotifyBreak] as? Bool == true
                     && registered[DefaultsKey.timeTrackingAskAfterLock] as? Bool == false,
                     "Time Tracking starts with Tagwerk's defaults")
        let exported = SettingsBackupSupport.exportKeys()
        suite.expect([DefaultsKey.timeTrackingEnabled, DefaultsKey.timeTrackingNotifyLimit,
                      DefaultsKey.timeTrackingNotifyBreak, DefaultsKey.timeTrackingAskAfterLock]
                        .allSatisfy(exported.contains),
                     "Time Tracking settings travel with backups")
    }
}
