import Foundation
import SwiftData
import SwiftUI

/// Gestor de logros del sistema de gamificación
@Observable
@MainActor
final class AchievementManager {
    static let shared = AchievementManager()

    // MARK: - Published State

    /// Último logro desbloqueado (para animaciones)
    var lastUnlockedAchievement: AchievementType?

    /// Si hay un logro recién desbloqueado para mostrar
    var hasNewUnlock: Bool = false

    private init() {}

    // MARK: - Achievement Checking

    /// Verifica todos los logros y desbloquea los que correspondan
    func checkAchievements(context: ModelContext) {
        // Obtener settings y datos necesarios
        guard let settings = fetchSettings(context: context) else { return }

        let sessions = fetchSessions(context: context)
        let messages = fetchMessages(context: context)
        let knowledge = fetchKnowledge(context: context)
        let quizzes = fetchQuizzes(context: context)
        let dailyActivities = fetchDailyActivities(context: context)

        // Verificar cada categoría de logros
        checkLearningAchievements(settings: settings, messages: messages, quizzes: quizzes, context: context)
        checkStreakAchievements(settings: settings, dailyActivities: dailyActivities, context: context)
        checkExplorationAchievements(sessions: sessions, context: context)
        checkScheduleAchievements(sessions: sessions, dailyActivities: dailyActivities, context: context)
        checkMasteryAchievements(knowledge: knowledge, quizzes: quizzes, context: context)
        checkLevelAchievements(settings: settings, context: context)
    }

    // MARK: - Learning Achievements

    private func checkLearningAchievements(
        settings: UserSettings,
        messages: [ChatMessage],
        quizzes: [QuizQuestion],
        context: ModelContext
    ) {
        let messageCount = messages.count
        let perfectQuizCount = settings.perfectQuizzes
        let plansCompleted = settings.completedPlans

        // First Message
        if messageCount >= 1 {
            unlock(.firstMessage, progress: 1, context: context)
        }

        // Curious achievements (message counts)
        updateProgress(.curious10, current: messageCount, context: context)
        updateProgress(.curious100, current: messageCount, context: context)
        updateProgress(.curious1000, current: messageCount, context: context)

        // Quiz achievements
        let completedQuizzes = quizzes.filter { $0.wasAnsweredCorrectly != nil }
        if !completedQuizzes.isEmpty {
            unlock(.quizFirst, progress: 1, context: context)
        }

        updateProgress(.quizMaster10, current: perfectQuizCount, context: context)
        updateProgress(.quizMaster50, current: perfectQuizCount, context: context)

        // Plan completed
        if plansCompleted >= 1 {
            unlock(.planCompleted, progress: 1, context: context)
        }
    }

    // MARK: - Streak Achievements

    private func checkStreakAchievements(
        settings: UserSettings,
        dailyActivities: [DailyActivity],
        context: ModelContext
    ) {
        let currentStreak = calculateCurrentStreak(activities: dailyActivities)

        // Streak achievements
        updateProgress(.streak3, current: currentStreak, context: context)
        updateProgress(.streak7, current: currentStreak, context: context)
        updateProgress(.streak30, current: currentStreak, context: context)
        updateProgress(.streak100, current: currentStreak, context: context)

        // Comeback achievement
        if settings.daysInactiveBeforeReturn >= 7 {
            unlock(.comeback, progress: 1, context: context)
        }

        // Perfect week (7 consecutive days with daily goal met)
        updateProgress(.perfectWeek, current: settings.dailyGoalStreak, context: context)
    }

    // MARK: - Exploration Achievements

    private func checkExplorationAchievements(
        sessions: [StudySession],
        context: ModelContext
    ) {
        // Unique subjects explored
        let uniqueSubjects = Set(sessions.map { $0.subjectId })
        updateProgress(.explorer3, current: uniqueSubjects.count, context: context)
        updateProgress(.explorer6, current: uniqueSubjects.count, context: context)
        updateProgress(.explorer12, current: uniqueSubjects.count, context: context)

        // Session duration achievements
        let maxSessionMinutes = sessions.map { Int($0.duration / 60) }.max() ?? 0
        updateProgress(.deepDive, current: maxSessionMinutes, context: context)
        updateProgress(.marathon, current: maxSessionMinutes, context: context)
        updateProgress(.ultraMarathon, current: maxSessionMinutes, context: context)
    }

    // MARK: - Schedule Achievements

    private func checkScheduleAchievements(
        sessions: [StudySession],
        dailyActivities: [DailyActivity],
        context: ModelContext
    ) {
        let calendar = Calendar.current

        for session in sessions {
            let hour = calendar.component(.hour, from: session.startTime)
            let weekday = calendar.component(.weekday, from: session.startTime)

            // Early Bird (before 7 AM)
            if hour < 7 {
                unlock(.earlyBird, progress: 1, context: context)
            }

            // Night Owl (after 11 PM)
            if hour >= 23 {
                unlock(.nightOwl, progress: 1, context: context)
            }

            // Lunch Learner (12-2 PM)
            if hour >= 12 && hour < 14 {
                unlock(.lunchLearner, progress: 1, context: context)
            }

            // Weekend Warrior (check if studied both Saturday and Sunday in the same week)
            if weekday == 1 || weekday == 7 { // Sunday = 1, Saturday = 7
                checkWeekendWarrior(activities: dailyActivities, context: context)
            }
        }
    }

    private func checkWeekendWarrior(activities: [DailyActivity], context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()

        // Get this week's Saturday and Sunday
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return }

        let activeDates = Set(activities.filter { $0.wasActive }.map {
            calendar.startOfDay(for: $0.date)
        })

        // Check if both weekend days are active
        var saturday: Date?
        var sunday: Date?

        var currentDate = weekInterval.start
        while currentDate < weekInterval.end {
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday == 7 { saturday = currentDate }
            if weekday == 1 { sunday = currentDate }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        if let sat = saturday, let sun = sunday,
           activeDates.contains(sat) && activeDates.contains(sun) {
            unlock(.weekendWarrior, progress: 1, context: context)
        }
    }

    // MARK: - Mastery Achievements

    private func checkMasteryAchievements(
        knowledge: [StudentKnowledge],
        quizzes: [QuizQuestion],
        context: ModelContext
    ) {
        // First mastery (80%+ on any concept)
        let masteredConcepts = knowledge.filter { $0.masteryLevel >= 0.8 }
        if !masteredConcepts.isEmpty {
            unlock(.firstMastery, progress: 1, context: context)
        }

        // Subject expert (10 concepts with 80%+ in one subject)
        let conceptsBySubject = Dictionary(grouping: masteredConcepts) { $0.subjectId }
        let maxConceptsInSubject = conceptsBySubject.values.map { $0.count }.max() ?? 0
        updateProgress(.subjectExpert, current: maxConceptsInSubject, context: context)

        // Polymath (5 concepts with 80%+ in 5 different subjects)
        let subjectsWithMastery = conceptsBySubject.filter { $0.value.count >= 5 }.count
        updateProgress(.polymath, current: subjectsWithMastery, context: context)

        // Perfect score (100% on a 10-question quiz)
        // This would need quiz session tracking - simplified check
        let perfectQuizzes = quizzes.filter { $0.wasAnsweredCorrectly == true }
        if perfectQuizzes.count >= 10 {
            // Check if 10 consecutive correct answers
            unlock(.perfectScore, progress: 1, context: context)
        }

        // Knowledge keeper (50 concepts stored)
        updateProgress(.knowledgeKeeper, current: knowledge.count, context: context)
    }

    // MARK: - Level Achievements

    private func checkLevelAchievements(
        settings: UserSettings,
        context: ModelContext
    ) {
        let level = settings.currentLevel

        if level >= 5 {
            unlock(.level5, progress: 5, context: context)
        }
        if level >= 10 {
            unlock(.level10, progress: 10, context: context)
        }
        if level >= 20 {
            unlock(.level20, progress: 20, context: context)
        }
    }

    // MARK: - Unlock & Progress Methods

    /// Actualiza el progreso de un logro
    private func updateProgress(_ type: AchievementType, current: Int, context: ModelContext) {
        let id = type.rawValue
        let descriptor = FetchDescriptor<Achievement>(predicate: #Predicate { $0.id == id })

        if let achievement = try? context.fetch(descriptor).first {
            if !achievement.isUnlocked {
                achievement.progress = current
                if current >= type.targetValue {
                    achievement.isUnlocked = true
                    achievement.unlockedAt = Date()
                    triggerUnlockFeedback(type)
                }
            }
        } else {
            // Crear nuevo logro con progreso
            let newAchievement = Achievement(
                id: id,
                isUnlocked: current >= type.targetValue,
                unlockedAt: current >= type.targetValue ? Date() : nil,
                progress: current,
                targetValue: type.targetValue
            )
            context.insert(newAchievement)

            if current >= type.targetValue {
                triggerUnlockFeedback(type)
            }
        }
    }

    /// Desbloquea un logro directamente
    private func unlock(_ type: AchievementType, progress: Int, context: ModelContext) {
        let id = type.rawValue
        let descriptor = FetchDescriptor<Achievement>(predicate: #Predicate { $0.id == id })

        if let existing = try? context.fetch(descriptor).first {
            if !existing.isUnlocked {
                existing.isUnlocked = true
                existing.unlockedAt = Date()
                existing.progress = progress
                triggerUnlockFeedback(type)
            }
        } else {
            let newAchievement = Achievement(
                id: id,
                isUnlocked: true,
                unlockedAt: Date(),
                progress: progress,
                targetValue: type.targetValue
            )
            context.insert(newAchievement)
            triggerUnlockFeedback(type)
        }
    }

    /// Dispara feedback cuando se desbloquea un logro
    private func triggerUnlockFeedback(_ type: AchievementType) {
        lastUnlockedAchievement = type
        hasNewUnlock = true

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Resetea el estado de animación (llamar después de mostrar)
    func resetUnlockState() {
        lastUnlockedAchievement = nil
        hasNewUnlock = false
    }

    // MARK: - Initialization

    /// Inicializa todos los logros si no existen
    func initializeAchievements(context: ModelContext) {
        let descriptor = FetchDescriptor<Achievement>()
        guard let existing = try? context.fetch(descriptor) else { return }
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

    // MARK: - Helper Methods

    private func calculateCurrentStreak(activities: [DailyActivity]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var expectedDate = calendar.startOfDay(for: Date())

        let sortedActivities = activities.sorted { $0.date > $1.date }

        for activity in sortedActivities {
            let activityDate = calendar.startOfDay(for: activity.date)

            if activityDate == expectedDate && activity.wasActive {
                streak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            } else if activityDate < expectedDate {
                break
            }
        }

        return streak
    }

    // MARK: - Data Fetching

    private func fetchSettings(context: ModelContext) -> UserSettings? {
        let descriptor = FetchDescriptor<UserSettings>()
        return try? context.fetch(descriptor).first
    }

    private func fetchSessions(context: ModelContext) -> [StudySession] {
        let descriptor = FetchDescriptor<StudySession>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchMessages(context: ModelContext) -> [ChatMessage] {
        let descriptor = FetchDescriptor<ChatMessage>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchKnowledge(context: ModelContext) -> [StudentKnowledge] {
        let descriptor = FetchDescriptor<StudentKnowledge>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchQuizzes(context: ModelContext) -> [QuizQuestion] {
        let descriptor = FetchDescriptor<QuizQuestion>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchDailyActivities(context: ModelContext) -> [DailyActivity] {
        let descriptor = FetchDescriptor<DailyActivity>()
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Statistics

    /// Obtiene estadísticas de logros
    func getAchievementStats(context: ModelContext) -> AchievementStats {
        let descriptor = FetchDescriptor<Achievement>()
        let achievements = (try? context.fetch(descriptor)) ?? []

        let unlocked = achievements.filter { $0.isUnlocked }
        let total = AchievementType.allCases.count

        let byTier: [AchievementTier: (unlocked: Int, total: Int)] = [
            .bronze: countByTier(.bronze, achievements: achievements),
            .silver: countByTier(.silver, achievements: achievements),
            .gold: countByTier(.gold, achievements: achievements)
        ]

        let totalXP = unlocked.compactMap { achievement -> Int? in
            guard let type = AchievementType(rawValue: achievement.id) else { return nil }
            return type.xpReward
        }.reduce(0, +)

        return AchievementStats(
            unlockedCount: unlocked.count,
            totalCount: total,
            byTier: byTier,
            totalXPFromAchievements: totalXP
        )
    }

    private func countByTier(_ tier: AchievementTier, achievements: [Achievement]) -> (unlocked: Int, total: Int) {
        let tierTypes = AchievementType.achievements(for: tier)
        let tierIds = Set(tierTypes.map { $0.rawValue })

        let unlockedInTier = achievements.filter { tierIds.contains($0.id) && $0.isUnlocked }.count
        return (unlockedInTier, tierTypes.count)
    }
}

// MARK: - Achievement Stats

struct AchievementStats {
    let unlockedCount: Int
    let totalCount: Int
    let byTier: [AchievementTier: (unlocked: Int, total: Int)]
    let totalXPFromAchievements: Int

    var completionPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(unlockedCount) / Double(totalCount)
    }
}
