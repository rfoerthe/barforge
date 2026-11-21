// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation

/// Time Tracking, the port of Tagwerk: its place in the catalog, its texts
/// and its settings. The tracker, rules and store suites join here as the
/// milestones in docs/TIME-TRACKING-PLAN.md land.
enum TimeTrackingTests {
    static func run(_ suite: TestSuite) {
        catalog(suite)
        strings(suite)
        preferences(suite)
    }

    private static func catalog(_ suite: TestSuite) {
        let feature = AppFeature.timeTracking
        suite.expect(feature.rawValue == "timeTracking", "the Time Tracking id is stable")
        suite.expect(feature.group == .tools && !feature.installedByDefault && feature.isBeta,
                     "Time Tracking is an opt-in beta tool")
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
        let on = [DefaultsKey.timeTrackingEnabled: true]
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
