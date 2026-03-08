import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var showingNameEditor = false
    var tempName = ""
    var showNotificationDeniedAlert = false
    var sectionsAppeared = false
    
    func saveName(settings: UserSettings) {
        if !tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.studentName = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
            settings.updatedAt = Date()
        }
        showingNameEditor = false
    }

    func updateNotifications(settings: UserSettings) {
        if settings.notificationsEnabled && settings.studyRemindersEnabled {
            Task {
                let granted = await NotificationManager.shared.requestPermissionAsync()
                if granted {
                    NotificationManager.shared.scheduleDailyReminder(at: settings.studyReminderTime)
                } else {
                    await MainActor.run {
                        settings.notificationsEnabled = false
                        showNotificationDeniedAlert = true
                    }
                }
            }
        } else {
            NotificationManager.shared.cancelReminders()
        }
    }
}
