import Foundation
import FoundationModels

/// Tool que permite a la IA generar misiones diarias personalizadas
final class DailyQuestGeneratorTool: Tool, @unchecked Sendable {
    let name = "generateDailyQuest"

    typealias Output = String

    let description = """
    Generates a personalized daily learning quest based on the student's knowledge and needs.

    USE THIS TOOL when:
    • Student starts a new day and needs motivation
    • Student asks for a challenge or quest ("Dame un reto", "¿Qué puedo hacer hoy?")
    • You detect an area where the student needs practice
    • Student seems bored and needs engagement

    QUEST TYPES:
    • quick: 2-minute focused task, simple and achievable (15 XP)
    • challenge: 5-minute task requiring more thought (40 XP)
    • epic: 10-minute comprehensive challenge connecting concepts (100 XP)

    IMPORTANT:
    • Base quests on what you know about the student (use recallStudentKnowledge first)
    • Make quests specific and actionable
    • Match difficulty to the student's level
    • Make them fun and engaging

    DO NOT use for: regular conversation, when student is working on something else.
    """

    // MARK: - Generable Types

    @Generable
    enum GeneratedQuestType: String, CaseIterable {
        case quick = "quick"
        case challenge = "challenge"
        case epic = "epic"
    }

    @Generable
    enum GeneratedQuestDifficulty: String, CaseIterable {
        case easy = "easy"
        case medium = "medium"
        case hard = "hard"
    }

    @Generable
    struct Arguments {
        @Guide(description: "Type of quest: 'quick' (2 min, 15 XP), 'challenge' (5 min, 40 XP), or 'epic' (10 min, 100 XP)")
        let questType: GeneratedQuestType

        @Guide(description: "Difficulty level: 'easy', 'medium', or 'hard'")
        let difficulty: GeneratedQuestDifficulty

        @Guide(description: "Short, engaging title for the quest in Spanish. Example: 'Resuelve el misterio de los números primos'")
        let title: String

        @Guide(description: "Detailed description of what the student should do, in Spanish. Be specific and actionable.")
        let description: String

        @Guide(description: "Array of concepts this quest will reinforce. Example: ['fractions', 'division']")
        let relatedConcepts: [String]

        @Guide(description: "Subject ID for this quest: 'matematicas', 'fisica', 'quimica', 'ciencias', 'sociales', 'lenguaje', 'ingles', 'etica', 'tecnologia', 'artes', 'deportes', 'abierta'")
        let subjectId: String
    }

    // MARK: - Callbacks

    /// Callback cuando se genera una misión
    var onQuestGenerated: ((DailyQuest) -> Void)?

    /// Subject ID actual (establecido por FoundationModelService)
    var currentSubjectId: String = "abierta"

    // MARK: - Tool Implementation

    func call(arguments: Arguments) async throws -> String {
        // Convertir tipos generados a tipos de la app
        let questType: QuestType = {
            switch arguments.questType {
            case .quick: return .quick
            case .challenge: return .challenge
            case .epic: return .epic
            }
        }()

        let difficulty: QuestDifficulty = {
            switch arguments.difficulty {
            case .easy: return .easy
            case .medium: return .medium
            case .hard: return .hard
            }
        }()

        // Crear la misión
        let quest = DailyQuest(
            type: questType,
            difficulty: difficulty,
            title: arguments.title,
            description: arguments.description,
            relatedConcepts: arguments.relatedConcepts,
            subjectId: arguments.subjectId
        )

        // Notificar que se generó la misión
        await MainActor.run {
            onQuestGenerated?(quest)
        }

        // Formatear respuesta para el usuario
        let typeEmoji: String = {
            switch questType {
            case .quick: return "⚡"
            case .challenge: return "🔥"
            case .epic: return "👑"
            }
        }()

        let response = """
        \(typeEmoji) **Nueva Misión: \(arguments.title)**

        📋 \(arguments.description)

        ⏱️ Tiempo estimado: \(questType.estimatedMinutes) minutos
        ✨ Recompensa: +\(questType.xpReward) XP
        📚 Materia: \(Subject(rawValue: arguments.subjectId)?.displayName ?? "General")

        _¡Avísame cuando completes la misión para ganar tu XP!_
        """

        return response
    }
}

// MARK: - Quest Generation Helpers

extension DailyQuestGeneratorTool {

    /// Genera el set completo de misiones del día
    @Generable
    struct DailyQuestSet {
        @Guide(description: "Quick quest (2 min)")
        let quickQuest: Arguments

        @Guide(description: "Challenge quest (5 min)")
        let challengeQuest: Arguments

        @Guide(description: "Epic quest (10 min)")
        let epicQuest: Arguments
    }
}

// MARK: - System Prompt Instructions

extension DailyQuestGeneratorTool {

    /// Instrucciones para incluir en el system prompt
    static var systemPromptInstructions: String {
        """
        [HERRAMIENTA: generateDailyQuest]
        Genera misiones de aprendizaje personalizadas para el estudiante.

        USAR cuando:
        - El estudiante inicia sesión y no tiene misiones del día
        - El estudiante pide un desafío, reto o misión
        - Detectas un área donde necesita práctica
        - El estudiante parece aburrido o desmotivado

        TIPOS DE MISIÓN:
        - quick: 2 minutos, tarea rápida y enfocada (15 XP)
          Ejemplo: "Nombra 3 planetas del sistema solar"
        - challenge: 5 minutos, requiere más pensamiento (40 XP)
          Ejemplo: "Explica la diferencia entre mitosis y meiosis"
        - epic: 10 minutos, desafío completo que conecta conceptos (100 XP)
          Ejemplo: "Diseña un experimento para demostrar la fotosíntesis"

        IMPORTANTE:
        - Usa recallStudentKnowledge primero para personalizar las misiones
        - Haz las misiones específicas y accionables
        - Adapta la dificultad al nivel del estudiante
        - ¡Hazlas divertidas y motivadoras!

        EJEMPLO DE USO:
        Estudiante: "¿Qué puedo hacer hoy para practicar?"
        → Usa recallStudentKnowledge para ver sus debilidades
        → Genera una misión enfocada en esas áreas
        """
    }
}
