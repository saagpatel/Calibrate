import Foundation
import UserNotifications

struct NotificationScheduler {

    /// Requests notification permission in response to an explicit user action.
    /// Returns whether the reminder was enabled.
    static func enableDailyReminder() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                scheduleDailyReminder()
            }
            return granted
        } catch {
            return false
        }
    }

    /// Restores an existing opt-in without prompting again at launch.
    static func scheduleIfAuthorized() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else { return }
        scheduleDailyReminder()
    }

    static func disableDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Constants.Notifications.dailyCategoryID]
        )
    }

    /// Removes any existing daily reminder and schedules a new one at the configured hour and minute.
    static func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()

        // Remove existing daily notification before rescheduling.
        center.removePendingNotificationRequests(withIdentifiers: [Constants.Notifications.dailyCategoryID])

        let content = UNMutableNotificationContent()
        content.title = "Your daily calibration is ready"
        content.body = "5 questions. 2 minutes. How well do you know what you don't know?"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = Constants.Notifications.dailyHour
        dateComponents.minute = Constants.Notifications.dailyMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Constants.Notifications.dailyCategoryID,
            content: content,
            trigger: trigger
        )

        center.add(request) { _ in
            // Scheduling errors are non-fatal — the user simply won't receive the reminder.
        }
    }
}
