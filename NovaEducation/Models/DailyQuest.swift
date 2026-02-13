import SwiftData
import Foundation
import SwiftUI

/// Representa una misión diaria generada por la IA
@Model
final class DailyQuest {
    var id: UUID
    var typeRaw: String           // Almacenamiento para QuestType
    var difficultyRaw: String     // Almacenamiento para QuestDifficulty
    var title: String             // "Resuelve 3 problemas de álgebra"
    var questDescription: String  // Descripción detallada
    var xpReward: Int             // XP base (sin multiplicador)
    var estimatedMinutes: Int     // Tiempo estimado
    var relatedConcepts: [String] // Conceptos relacionados
    var subjectId: String         // Materia de la misión
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var expiresAt: Date           // Fin del día (medianoche)

    /// Tipo de misión como enum tipado
    var type: QuestType {
        get { QuestType(rawValue: typeRaw) ?? .quick }
        set { typeRaw = newValue.rawValue }
    }

    /// Dificultad como enum tipado
    var difficulty: QuestDifficulty {
        get { QuestDifficulty(rawValue: difficultyRaw) ?? .medium }
        set { difficultyRaw = newValue.rawValue }
    }

    init(
        type: QuestType,
        difficulty: QuestDifficulty = .medium,
        title: String,
        description: String,
        relatedConcepts: [String] = [],
        subjectId: String
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.title = title
        self.questDescription = description
        self.xpReward = type.xpReward
        self.estimatedMinutes = type.estimatedMinutes
        self.relatedConcepts = relatedConcepts
        self.subjectId = subjectId
        self.isCompleted = false
        self.createdAt = Date()
        self.completedAt = nil

        // Expira a medianoche del día actual
        self.expiresAt = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60)
    }

    /// Marca la misión como completada
    func complete() {
        guard !isCompleted else { return }
        isCompleted = true
        completedAt = Date()
    }

    /// Verifica si la misión ha expirado
    var isExpired: Bool {
        Date() > expiresAt
    }

    /// Verifica si la misión está activa (no completada y no expirada)
    var isActive: Bool {
        !isCompleted && !isExpired
    }
}

/// Tipo de misión diaria
enum QuestType: String, Codable, CaseIterable {
    case quick = "quick"           // Misión rápida
    case challenge = "challenge"   // Misión desafío
    case epic = "epic"             // Misión épica

    /// XP base de la misión
    var xpReward: Int {
        switch self {
        case .quick: return 15
        case .challenge: return 40
        case .epic: return 100
        }
    }

    /// Tiempo estimado en minutos
    var estimatedMinutes: Int {
        switch self {
        case .quick: return 2
        case .challenge: return 5
        case .epic: return 10
        }
    }

    /// Nombre para mostrar en UI
    var displayName: String {
        switch self {
        case .quick: return "Rápida"
        case .challenge: return "Desafío"
        case .epic: return "Épica"
        }
    }

    /// Icono SF Symbol
    var icon: String {
        switch self {
        case .quick: return "bolt.fill"
        case .challenge: return "flame.fill"
        case .epic: return "crown.fill"
        }
    }

    /// Color del tipo de misión
    var color: Color {
        switch self {
        case .quick: return .green
        case .challenge: return .orange
        case .epic: return .purple
        }
    }

    /// Descripción del tipo
    var typeDescription: String {
        switch self {
        case .quick: return "\(estimatedMinutes) min • +\(xpReward) XP"
        case .challenge: return "\(estimatedMinutes) min • +\(xpReward) XP"
        case .epic: return "\(estimatedMinutes) min • +\(xpReward) XP"
        }
    }

    /// XPSource correspondiente
    var xpSource: XPSource {
        switch self {
        case .quick: return .questQuick
        case .challenge: return .questChallenge
        case .epic: return .questEpic
        }
    }
}

/// Dificultad de la misión
enum QuestDifficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"

    var displayName: String {
        switch self {
        case .easy: return "Fácil"
        case .medium: return "Media"
        case .hard: return "Difícil"
        }
    }

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .red
        }
    }
}

// MARK: - Quest Generation Helpers

extension DailyQuest {

    /// Crea un set de misiones para el día actual
    static func createDailySet(
        quickTitle: String,
        quickDescription: String,
        quickConcepts: [String],
        quickSubject: String,
        challengeTitle: String,
        challengeDescription: String,
        challengeConcepts: [String],
        challengeSubject: String,
        epicTitle: String,
        epicDescription: String,
        epicConcepts: [String],
        epicSubject: String
    ) -> [DailyQuest] {
        return [
            DailyQuest(
                type: .quick,
                title: quickTitle,
                description: quickDescription,
                relatedConcepts: quickConcepts,
                subjectId: quickSubject
            ),
            DailyQuest(
                type: .challenge,
                title: challengeTitle,
                description: challengeDescription,
                relatedConcepts: challengeConcepts,
                subjectId: challengeSubject
            ),
            DailyQuest(
                type: .epic,
                title: epicTitle,
                description: epicDescription,
                relatedConcepts: epicConcepts,
                subjectId: epicSubject
            )
        ]
    }

    /// Misiones por defecto cuando no hay contexto del estudiante
    static func defaultQuests() -> [DailyQuest] {
        return [
            DailyQuest(
                type: .quick,
                title: "Pregunta curiosa",
                description: "Haz una pregunta sobre cualquier tema que te genere curiosidad",
                relatedConcepts: ["curiosidad", "exploración"],
                subjectId: "abierta"
            ),
            DailyQuest(
                type: .challenge,
                title: "Aprende algo nuevo",
                description: "Explora una materia que no hayas usado antes y haz al menos 3 preguntas",
                relatedConcepts: ["exploración", "aprendizaje"],
                subjectId: "abierta"
            ),
            DailyQuest(
                type: .epic,
                title: "Conexión de conocimientos",
                description: "Elige dos materias diferentes y pide a Nova que te explique cómo se relacionan",
                relatedConcepts: ["interdisciplinario", "conexiones"],
                subjectId: "abierta"
            )
        ]
    }
}
