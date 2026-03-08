import Foundation
import SwiftData

@Observable 
@MainActor 
final class HomeViewModel {
    var todayQuests: [DailyQuest] = []
    var currentStreak: Int = 0
    var selectedSubject: Subject?

    // Sub-sheet presentation states
    var showingGoalSheet = false
    var showQuestsExpanded = false
    
    // Scroll and appearance states
    var hasScrolled = false
    var headerAppeared = false
    var chipsAppeared = false
    var cardsAppeared = false

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Buenos días"
        case 12..<19:
            return "Buenas tardes"
        default:
            return "Buenas noches"
        }
    }

    func loadGamificationData(context: ModelContext) {
        DailyQuestService.shared.loadTodayQuests(context: context)

        if DailyQuestService.shared.needsQuestGeneration(context: context) {
            DailyQuestService.shared.generateDefaultQuests(context: context)
        }

        todayQuests = DailyQuestService.shared.todayQuests
        currentStreak = calculateCurrentStreak(context: context)
    }

    func calculateCurrentStreak(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<DailyActivity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let activities = try? context.fetch(descriptor) else { return 0 }

        var streak = 0
        var expectedDate = Calendar.current.startOfDay(for: Date())

        for activity in activities {
            let activityDate = Calendar.current.startOfDay(for: activity.date)

            if activityDate == expectedDate && activity.wasActive {
                streak += 1
                expectedDate = Calendar.current.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            } else if activityDate < expectedDate {
                break
            }
        }

        return streak
    }
}
