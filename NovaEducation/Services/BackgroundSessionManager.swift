import Foundation
import SwiftData

/// Actor responsible for handling background session initialization tasks
/// to prevent Main Thread hangs.
actor BackgroundSessionManager {
    static let shared = BackgroundSessionManager()
    
    private init() {}
    
    func initializeSession(container: ModelContainer) async {
        await MainActor.run {
            let context = ModelContext(container)
            context.autosaveEnabled = false

            // 1. Update Daily Activity
            let today = Calendar.current.startOfDay(for: Date())
            let descriptor = FetchDescriptor<DailyActivity>(predicate: #Predicate { $0.date == today })

            if (try? context.fetch(descriptor).first) == nil {
                let newActivity = DailyActivity(date: Date(), wasActive: true)
                context.insert(newActivity)
            }

            // 2. Initialize achievements if needed (Seeding)
            let achDescriptor = FetchDescriptor<Achievement>()
            if let existing = try? context.fetch(achDescriptor) {
                let existingIds = Set(existing.map { $0.id })

                for type in AchievementType.allCases {
                    if !existingIds.contains(type.rawValue) {
                        let achievement = Achievement(
                            id: type.rawValue,
                            isUnlocked: false,
                            progress: 0,
                            targetValue: type.targetValue
                        )
                        context.insert(achievement)
                    }
                }
            }

            do {
                try context.save()
            } catch {
                print("BackgroundSessionManager: Failed to save - \(error)")
            }
        }
    }
}
