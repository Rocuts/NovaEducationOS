import Foundation
import SwiftData
import SwiftUI

/// Servicio para gestionar las misiones diarias
@Observable
@MainActor
final class DailyQuestService {
    static let shared = DailyQuestService()

    // MARK: - Published State

    /// Misiones del día actual
    var todayQuests: [DailyQuest] = []

    /// Si las misiones están cargadas
    var isLoaded: Bool = false

    /// Si hay misiones pendientes para completar
    var hasPendingQuests: Bool {
        todayQuests.contains { $0.isActive }
    }

    /// Número de misiones completadas hoy
    var completedCount: Int {
        todayQuests.filter { $0.isCompleted }.count
    }

    /// XP total disponible en misiones pendientes
    var pendingXP: Int {
        todayQuests.filter { $0.isActive }.reduce(0) { $0 + $1.xpReward }
    }

    private init() {}

    // MARK: - Quest Management

    /// Carga las misiones del día actual
    func loadTodayQuests(context: ModelContext) {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let descriptor = FetchDescriptor<DailyQuest>(
            predicate: #Predicate { $0.createdAt >= startOfDay && $0.createdAt < endOfDay },
            sortBy: [SortDescriptor(\.typeRaw)]
        )

        if let quests = try? context.fetch(descriptor) {
            todayQuests = quests
        } else {
            todayQuests = []
        }

        isLoaded = true
    }

    /// Verifica si necesitamos generar nuevas misiones
    func needsQuestGeneration(context: ModelContext) -> Bool {
        loadTodayQuests(context: context)

        // Si no hay misiones para hoy, necesitamos generar
        if todayQuests.isEmpty {
            return true
        }

        // Si todas las misiones expiraron, necesitamos generar
        if todayQuests.allSatisfy({ $0.isExpired }) {
            return true
        }

        return false
    }

    /// Genera misiones por defecto si no hay misiones del día
    func generateDefaultQuests(context: ModelContext) {
        guard needsQuestGeneration(context: context) else { return }

        // Limpiar misiones expiradas
        cleanupExpiredQuests(context: context)

        // Crear misiones por defecto
        let defaultQuests = DailyQuest.defaultQuests()
        for quest in defaultQuests {
            context.insert(quest)
        }

        todayQuests = defaultQuests
    }

    /// Guarda una misión generada por la IA
    func saveGeneratedQuest(_ quest: DailyQuest, context: ModelContext) {
        context.insert(quest)

        // Actualizar lista local
        if let index = todayQuests.firstIndex(where: { $0.type == quest.type }) {
            todayQuests[index] = quest
        } else {
            todayQuests.append(quest)
        }

        // Ordenar por tipo
        todayQuests.sort { $0.typeRaw < $1.typeRaw }
    }

    /// Completa una misión y otorga XP
    func completeQuest(_ quest: DailyQuest, context: ModelContext) -> (xpGained: Int, leveledUp: Bool) {
        guard !quest.isCompleted else { return (0, false) }

        quest.complete()

        // Otorgar XP
        let result = XPManager.shared.awardQuestXP(quest: quest, context: context)

        // Actualizar lista local
        if let index = todayQuests.firstIndex(where: { $0.id == quest.id }) {
            todayQuests[index] = quest
        }

        return result
    }

    /// Limpia misiones expiradas de la base de datos
    func cleanupExpiredQuests(context: ModelContext) {
        let now = Date()
        let descriptor = FetchDescriptor<DailyQuest>(
            predicate: #Predicate { $0.expiresAt < now }
        )

        if let expiredQuests = try? context.fetch(descriptor) {
            for quest in expiredQuests {
                context.delete(quest)
            }
        }
    }

    /// Obtiene la misión de un tipo específico para hoy
    func quest(ofType type: QuestType) -> DailyQuest? {
        todayQuests.first { $0.type == type }
    }

    /// Verifica si todas las misiones del día están completadas
    var allQuestsCompleted: Bool {
        guard !todayQuests.isEmpty else { return false }
        return todayQuests.allSatisfy { $0.isCompleted }
    }

    // MARK: - Statistics

    /// Obtiene el historial de misiones completadas
    func completedQuestsHistory(days: Int, context: ModelContext) -> [DailyQuest] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return []
        }

        let descriptor = FetchDescriptor<DailyQuest>(
            predicate: #Predicate { $0.isCompleted && $0.completedAt != nil && $0.createdAt >= startDate },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    /// Cuenta misiones completadas por tipo
    func completedCountByType(context: ModelContext) -> [QuestType: Int] {
        let descriptor = FetchDescriptor<DailyQuest>(
            predicate: #Predicate { $0.isCompleted }
        )
        guard let quests = try? context.fetch(descriptor) else { return [:] }

        var counts: [QuestType: Int] = [:]
        for quest in quests {
            counts[quest.type, default: 0] += 1
        }
        return counts
    }

    /// XP total ganado por misiones
    func totalQuestXP(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<DailyQuest>(
            predicate: #Predicate { $0.isCompleted }
        )
        guard let quests = try? context.fetch(descriptor) else { return 0 }

        return quests.reduce(0) { $0 + $1.xpReward }
    }

    /// Días con al menos una misión completada
    func daysWithCompletedQuests(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<DailyQuest>(
            predicate: #Predicate { $0.isCompleted && $0.completedAt != nil }
        )
        guard let quests = try? context.fetch(descriptor) else { return 0 }

        let uniqueDays = Set(quests.compactMap { quest -> Date? in
            guard let completedAt = quest.completedAt else { return nil }
            return Calendar.current.startOfDay(for: completedAt)
        })

        return uniqueDays.count
    }

    // MARK: - Quest Suggestions

    /// Sugiere materias para misiones basado en actividad reciente
    func suggestSubjectsForQuests(context: ModelContext) -> [String] {
        // Obtener materias con menos actividad reciente
        let descriptor = FetchDescriptor<StudySession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        guard let sessions = try? context.fetch(descriptor) else {
            return ["abierta", "matematicas", "ciencias"]
        }

        // Contar sesiones por materia
        var subjectCounts: [String: Int] = [:]
        for session in sessions.prefix(50) {
            subjectCounts[session.subjectId, default: 0] += 1
        }

        // Materias con menos actividad
        let allSubjects = Subject.allCases.map { $0.rawValue }
        let sortedByActivity = allSubjects.sorted {
            (subjectCounts[$0] ?? 0) < (subjectCounts[$1] ?? 0)
        }

        return Array(sortedByActivity.prefix(3))
    }
}
