import Foundation
import os
import UserNotifications

final class NotificationManager: Sendable {
    static let shared = NotificationManager()
    private static let logger = Logger(subsystem: "com.nova.education", category: "Notifications")

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if error != nil {
                Self.logger.error("Notification permission request failed")
            }
        }
    }

    /// Async version that returns whether permission was granted
    func requestPermissionAsync() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleDailyReminder(at date: Date) {
        // First cancel existing
        cancelReminders()

        let content = UNMutableNotificationContent()
        content.title = "Hora de aprender"
        content.body = "Continúa tu racha y aprende algo nuevo hoy en NovaEducation."
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "daily-study-reminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                Self.logger.error("Failed to schedule notification")
            }
        }
    }

    func cancelReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-study-reminder"])
    }
}
