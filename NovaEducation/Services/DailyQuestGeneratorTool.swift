import Foundation
import FoundationModels

/// Tool that allows the AI to generate personalized daily quests
final class DailyQuestGeneratorTool: Tool, @unchecked Sendable {
    let name = "generateDailyQuest"
    let includesSchemaInInstructions = false

    typealias Output = String

    let description = "Generates a daily learning quest."

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
        @Guide(description: "Quest type")
        let questType: GeneratedQuestType

        @Guide(description: "Difficulty")
        let difficulty: GeneratedQuestDifficulty

        @Guide(description: "Title in Spanish")
        let title: String

        @Guide(description: "Description in Spanish")
        let description: String

        @Guide(description: "Related concepts")
        let relatedConcepts: [String]

        @Guide(description: "Subject ID")
        let subjectId: String
    }

    // MARK: - Callbacks

    /// Set once from @MainActor before any call() invocation. Read in call() via MainActor.run.
    nonisolated(unsafe) var onQuestGenerated: ((DailyQuest) -> Void)?

    /// Subject ID actual (establecido por FoundationModelService)
    nonisolated(unsafe) var currentSubjectId: String = "abierta"

    // MARK: - Tool Implementation

    func call(arguments: Arguments) async throws -> String {
        return await MainActor.run {
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

            // Notificar
            onQuestGenerated?(quest)

            return "Quest created: \(arguments.title)"
        }
    }
}

