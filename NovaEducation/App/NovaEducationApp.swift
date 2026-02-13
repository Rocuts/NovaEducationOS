import SwiftUI
import SwiftData

@main
struct NovaEducationApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [
            ChatMessage.self,
            UserSettings.self,
            StudySession.self,
            DailyActivity.self,
            Achievement.self,
            StudentKnowledge.self,
            QuizQuestion.self,
            LearningPlan.self,
            XPTransaction.self,
            DailyQuest.self
        ])
    }
}
