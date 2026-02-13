import Foundation
import SwiftData
import SwiftUI

/// Gestor de XP y multiplicadores del sistema de gamificación
@Observable
@MainActor
final class XPManager {
    static let shared = XPManager()

    // MARK: - Published State

    /// Último XP ganado (para animaciones)
    var lastXPGained: Int = 0

    /// Si hubo level up en la última transacción
    var didLevelUp: Bool = false

    /// Nuevo nivel si hubo level up
    var newLevel: Int = 0

    /// Multiplicador actual
    var currentMultiplier: Double = 1.0

    /// Desglose del multiplicador
    var multiplierBreakdown: [MultiplierBonus] = []

    private init() {}

    // MARK: - XP Award Methods

    /// Otorga XP por una acción específica
    /// - Returns: XP total ganado (con multiplicador) y si subió de nivel
    @discardableResult
    func awardXP(
        source: XPSource,
        customAmount: Int? = nil,
        subjectId: String? = nil,
        context: ModelContext
    ) -> (xpGained: Int, leveledUp: Bool) {
        guard let settings = fetchSettings(context: context) else {
            return (0, false)
        }

        // Calcular multiplicador actual
        let multiplier = calculateMultiplier(context: context)
        currentMultiplier = multiplier.total

        // Calcular XP
        let baseXP = customAmount ?? source.baseXP
        let finalXP = Int(Double(baseXP) * multiplier.total)

        // Crear transacción
        let transaction = XPTransaction(
            baseAmount: baseXP,
            multiplier: multiplier.total,
            source: source,
            subjectId: subjectId
        )
        context.insert(transaction)

        // Actualizar settings
        let previousLevel = settings.currentLevel
        settings.addXP(finalXP)

        // Actualizar contadores según la fuente
        switch source {
        case .message, .firstOfDay:
            settings.incrementMessages()
        case .quizPerfect:
            settings.incrementPerfectQuizzes()
        case .planCompleted:
            settings.incrementCompletedPlans()
        default:
            break
        }

        // Detectar level up
        let leveledUp = settings.currentLevel > previousLevel

        // Actualizar estado observable
        lastXPGained = finalXP
        didLevelUp = leveledUp
        if leveledUp {
            newLevel = settings.currentLevel
        }

        // Verificar logros
        AchievementManager.shared.checkAchievements(context: context)

        return (finalXP, leveledUp)
    }

    /// Otorga XP por completar una misión
    @discardableResult
    func awardQuestXP(
        quest: DailyQuest,
        context: ModelContext
    ) -> (xpGained: Int, leveledUp: Bool) {
        return awardXP(
            source: quest.type.xpSource,
            customAmount: quest.xpReward,
            subjectId: quest.subjectId,
            context: context
        )
    }

    /// Otorga XP por desbloquear un logro
    @discardableResult
    func awardAchievementXP(
        achievementType: AchievementType,
        context: ModelContext
    ) -> (xpGained: Int, leveledUp: Bool) {
        return awardXP(
            source: .achievementUnlock,
            customAmount: achievementType.xpReward,
            context: context
        )
    }

    // MARK: - Multiplier Calculation

    struct MultiplierResult {
        let total: Double
        let breakdown: [MultiplierBonus]
    }

    struct MultiplierBonus: Identifiable {
        let id = UUID()
        let name: String
        let value: Double
        let icon: String
        let isActive: Bool
    }

    /// Calcula el multiplicador actual basado en varios factores
    func calculateMultiplier(context: ModelContext) -> MultiplierResult {
        var bonuses: [MultiplierBonus] = []
        var total = 1.0

        // 1. Bonus por racha de días
        let streakDays = calculateCurrentStreak(context: context)
        let streakBonus = min(Double(streakDays) * 0.1, 1.0)
        bonuses.append(MultiplierBonus(
            name: "Racha \(streakDays) días",
            value: streakBonus,
            icon: "flame.fill",
            isActive: streakBonus > 0
        ))
        total += streakBonus

        // 2. Bonus por variedad de materias esta semana
        let subjectsThisWeek = countSubjectsThisWeek(context: context)
        let varietyBonus = min(Double(max(0, subjectsThisWeek - 1)) * 0.1, 0.3)
        bonuses.append(MultiplierBonus(
            name: "\(subjectsThisWeek) materias esta semana",
            value: varietyBonus,
            icon: "books.vertical.fill",
            isActive: varietyBonus > 0
        ))
        total += varietyBonus

        // 3. Bonus por quizzes perfectos hoy
        let perfectToday = countPerfectQuizzesToday(context: context)
        let quizBonus = min(Double(perfectToday) * 0.1, 0.2)
        bonuses.append(MultiplierBonus(
            name: "\(perfectToday) quiz perfecto hoy",
            value: quizBonus,
            icon: "checkmark.seal.fill",
            isActive: quizBonus > 0
        ))
        total += quizBonus

        // 4. Bonus por meta diaria cumplida hoy
        let goalMetToday = isDailyGoalMetToday(context: context)
        let goalBonus = goalMetToday ? 0.2 : 0.0
        bonuses.append(MultiplierBonus(
            name: "Meta diaria cumplida",
            value: goalBonus,
            icon: "target",
            isActive: goalBonus > 0
        ))
        total += goalBonus

        // Cap máximo
        total = min(total, 2.5)

        multiplierBreakdown = bonuses
        return MultiplierResult(total: total, breakdown: bonuses)
    }

    // MARK: - Helper Methods

    private func fetchSettings(context: ModelContext) -> UserSettings? {
        let descriptor = FetchDescriptor<UserSettings>()
        return try? context.fetch(descriptor).first
    }

    private func calculateCurrentStreak(context: ModelContext) -> Int {
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
                // Día saltado, racha rota
                break
            }
        }

        return streak
    }

    private func countSubjectsThisWeek(context: ModelContext) -> Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return 0 }

        let descriptor = FetchDescriptor<StudySession>(
            predicate: #Predicate { $0.startTime >= weekAgo }
        )
        guard let sessions = try? context.fetch(descriptor) else { return 0 }

        let uniqueSubjects = Set(sessions.map { $0.subjectId })
        return uniqueSubjects.count
    }

    private func countPerfectQuizzesToday(context: ModelContext) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())

        let descriptor = FetchDescriptor<XPTransaction>(
            predicate: #Predicate {
                $0.timestamp >= startOfDay && $0.sourceRaw == "quiz_perfect"
            }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    private func isDailyGoalMetToday(context: ModelContext) -> Bool {
        guard let settings = fetchSettings(context: context) else { return false }

        let today = Calendar.current.startOfDay(for: Date())
        if let lastGoalDate = settings.lastDailyGoalDate {
            return Calendar.current.startOfDay(for: lastGoalDate) == today
        }
        return false
    }

    // MARK: - Statistics

    /// Obtiene el historial de XP de los últimos N días
    func xpHistory(days: Int, context: ModelContext) -> [(date: Date, xp: Int)] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }

        let descriptor = FetchDescriptor<XPTransaction>(
            predicate: #Predicate { $0.timestamp >= startDate },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        guard let transactions = try? context.fetch(descriptor) else { return [] }

        // Agrupar por día
        var dailyXP: [Date: Int] = [:]
        for transaction in transactions {
            let day = calendar.startOfDay(for: transaction.timestamp)
            dailyXP[day, default: 0] += transaction.amount
        }

        // Convertir a array ordenado
        return dailyXP.map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }

    /// Obtiene el XP ganado hoy
    func xpGainedToday(context: ModelContext) -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())

        let descriptor = FetchDescriptor<XPTransaction>(
            predicate: #Predicate { $0.timestamp >= startOfDay }
        )
        guard let transactions = try? context.fetch(descriptor) else { return 0 }

        return transactions.reduce(0) { $0 + $1.amount }
    }

    /// Obtiene el total de XP por fuente
    func xpBySource(context: ModelContext) -> [XPSource: Int] {
        let descriptor = FetchDescriptor<XPTransaction>()
        guard let transactions = try? context.fetch(descriptor) else { return [:] }

        var bySource: [XPSource: Int] = [:]
        for transaction in transactions {
            bySource[transaction.source, default: 0] += transaction.amount
        }
        return bySource
    }

    // MARK: - Reset State

    /// Resetea el estado observable (llamar después de mostrar animaciones)
    func resetAnimationState() {
        lastXPGained = 0
        didLevelUp = false
        newLevel = 0
    }
}
