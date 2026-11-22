// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Roland Foerther

import Foundation
import UserNotifications

/// Tagwerk's notifications for Time Tracking (`menubar.rs`, `notify.rs`): the
/// reminders about breaks and the maximum working time, refused and cut
/// entries, a forgotten "Back at the Mac", the first database error and the
/// question after a long lock with its five buttons. What to post is decided
/// by `TTNotice`, `TTReminders` and `TTLockQuestion`; this only posts it.
/// Main thread only, owned by `TimeTrackingService` while recording runs.
final class TimeTrackingNotifications {
    /// `nil` until the first state after recording started: thresholds
    /// reached by then are not reported (`LimitWatch::init`).
    private var reminders: TTReminders?

    /// Registers the category of the lock question with the app's other
    /// categories (the buttons are named in the app's language).
    static func registerCategory(texts: TimeTrackingTexts, menu: TimeTrackingMenuTexts) {
        let actions = TTLockAnswer.all.map {
            UNNotificationAction(identifier: $0.actionIdentifier, title: $0.title(texts, menu), options: [])
        }
        Notifier.register(UNNotificationCategory(identifier: TTLockQuestion.categoryIdentifier, actions: actions,
                                                 intentIdentifiers: [], options: []))
    }

    /// New state of today: crossed thresholds give a reminder, if switched on.
    /// The watches always follow, so turning a reminder on later does not
    /// report what was crossed before.
    func update(_ snapshot: TimeTrackingSnapshot, texts: TimeTrackingTexts) {
        let today = snapshot.today
        guard var reminders else {
            reminders = TTReminders(date: snapshot.date, work: today.workSecs, stretch: today.stretchSecs)
            return
        }
        let notices = reminders.update(date: snapshot.date, work: today.workSecs, stretch: today.stretchSecs,
                                       working: snapshot.isRunning || snapshot.onAway,
                                       settings: snapshot.settings, texts: texts)
        self.reminders = reminders
        notices.forEach(Self.post)
    }

    /// Something the engine reported. `question` is the lock question due
    /// after `resumedAfterLock` (decided by the caller, which has the tracker).
    func handle(_ event: TimeTrackingEvent, question: TTLockQuestion?, texts: TimeTrackingTexts,
                menu: TimeTrackingMenuTexts, title: String) {
        switch event {
        case let .forgottenAway(forgotten):
            Self.post(.forgottenAway(forgotten, texts: texts, menu: menu))
        case let .workCut(blocks, place):
            if let notice = TTNotice.workCut(blocks, beforeStart: place == .beforeStart, texts: texts, menu: menu) {
                Self.post(notice)
            }
        case let .entryRefused(entry, why):
            Self.post(.entryRefused(start: entry == .start, why, texts: texts, menu: menu))
        case .resumedAfterLock:
            guard let question else { return }
            // The buttons in the current language.
            Self.registerCategory(texts: texts, menu: menu)
            let notice = question.notice(texts: texts, menu: menu)
            Notifier.post(identifier: notice.id, title: notice.title, body: notice.body,
                          categoryIdentifier: TTLockQuestion.categoryIdentifier, userInfo: question.userInfo)
        case let .databaseError(fault, first):
            // Only the first error: it stands in the menu until it is gone.
            guard first else { return }
            Self.post(.databaseError(fault.failure, detail: fault.message, title: title, menu: menu))
        }
    }

    private static func post(_ notice: TTNotice) {
        Notifier.post(identifier: notice.id, title: notice.title, body: notice.body)
    }
}
