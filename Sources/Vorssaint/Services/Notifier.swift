// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Roland Foerther

import Foundation
import os.log
import UserNotifications

enum Notifier {
    static let whatsAppOrganizerUndoActionIdentifier =
        "com.vorssaint.notification.whatsapp-organizer.undo"
    private static let whatsAppOrganizerTransactionKey =
        "com.vorssaint.notification.whatsapp-organizer.transaction"
    private static let whatsAppOrganizerCategoryIdentifier =
        "com.vorssaint.notification.whatsapp-organizer"
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "vorssaint",
                                    category: "notifications")

    /// Every category with actions, by identifier. `setNotificationCategories`
    /// replaces all categories of the app at once, so each feature's category
    /// lives here and every registration hands macOS the whole set: one
    /// feature registering never drops another's buttons.
    private static var categories: [String: UNNotificationCategory] = [:]

    /// The notification centre aborts the process when it cannot resolve an
    /// app bundle: a bare binary started from the terminal, or a bundle
    /// replaced or moved out from under a running copy. Every entry point
    /// checks this first, so such a run simply posts nothing.
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
            && FileManager.default.fileExists(atPath: Bundle.main.bundlePath)
    }

    static func requestPermission() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            // A denied prompt is the user's call; a request that ERRORS means
            // notifications silently cannot work at all — leave a trace so
            // that state is diagnosable instead of invisible.
            if let error {
                log.error("notification authorization failed: \(error.localizedDescription, privacy: .public)")
            } else if !granted {
                log.notice("notification authorization not granted")
            }
        }
    }

    static func post(title: String, body: String) {
        post(title: title, body: body, categoryIdentifier: nil, userInfo: [:])
    }

    static func postWhatsAppOrganization(title: String,
                                         body: String,
                                         undoTitle: String,
                                         transactionID: UUID) {
        guard isAvailable else { return }
        let undo = UNNotificationAction(
            identifier: whatsAppOrganizerUndoActionIdentifier,
            title: undoTitle,
            options: [.foreground])
        register(UNNotificationCategory(identifier: whatsAppOrganizerCategoryIdentifier,
                                        actions: [undo], intentIdentifiers: [], options: []))
        post(title: title, body: body,
             categoryIdentifier: whatsAppOrganizerCategoryIdentifier,
             userInfo: [whatsAppOrganizerTransactionKey: transactionID.uuidString])
    }

    static func whatsAppOrganizerTransactionID(from response: UNNotificationResponse) -> UUID? {
        guard response.actionIdentifier == whatsAppOrganizerUndoActionIdentifier,
              let raw = response.notification.request.content.userInfo[
                whatsAppOrganizerTransactionKey] as? String else { return nil }
        return UUID(uuidString: raw)
    }

    /// Adds or replaces one category and registers all of them together.
    /// Main thread only, like every caller.
    static func register(_ category: UNNotificationCategory) {
        guard isAvailable else { return }
        categories[category.identifier] = category
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories.values))
    }

    /// Posts with a fixed identifier, so a newer notification replaces the
    /// older one of the same kind (Time Tracking's reminders, for example),
    /// and with the default sound.
    static func post(identifier: String,
                     title: String,
                     body: String,
                     categoryIdentifier: String? = nil,
                     userInfo: [AnyHashable: Any] = [:]) {
        post(title: title, body: body, categoryIdentifier: categoryIdentifier, userInfo: userInfo,
             identifier: identifier, sound: true)
    }

    private static func post(title: String,
                             body: String,
                             categoryIdentifier: String?,
                             userInfo: [AnyHashable: Any],
                             identifier: String? = nil,
                             sound: Bool = false) {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
                log.notice("notification dropped: authorization status \(settings.authorizationStatus.rawValue)")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            if let categoryIdentifier { content.categoryIdentifier = categoryIdentifier }
            content.userInfo = userInfo
            if sound { content.sound = .default }
            let request = UNNotificationRequest(identifier: identifier ?? UUID().uuidString,
                                                content: content, trigger: nil)
            center.add(request) { error in
                if let error {
                    log.error("notification delivery failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}
