import Foundation
import FoundationModels
import SwiftData

// MARK: - Memory Store Tool

/// Tool that allows the AI to store information about the student's learning
struct MemoryStoreTool: Tool {
    let name = "storeStudentKnowledge"
    let includesSchemaInInstructions = false

    typealias Output = String

    let description = "Stores a learning fact about the student."

    @Generable
    struct Arguments {
        @Guide(description: "Fact to store")
        let knowledge: String

        @Guide(description: "concept, difficulty, interest, or preference")
        let category: String

        @Guide(description: "0.0 to 1.0")
        let masteryLevel: Double
    }

    var onStoreKnowledge: (@Sendable (String, KnowledgeCategory, Double) -> Void)?

    /// Current subject ID (set by FoundationModelService)
    var currentSubjectId: String = "open"

    func call(arguments: Arguments) async throws -> String {
        let category = KnowledgeCategory(rawValue: arguments.category) ?? .concept
        let mastery = max(0, min(1, arguments.masteryLevel))

        let safeKnowledge = String(arguments.knowledge.prefix(500))
            .replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")")

        await MainActor.run {
            onStoreKnowledge?(safeKnowledge, category, mastery)
        }

        return "Stored."
    }
}

// MARK: - Memory Recall Tool

/// Tool that allows the AI to retrieve stored information about the student
struct MemoryRecallTool: Tool {
    let name = "recallStudentKnowledge"
    let includesSchemaInInstructions = false

    typealias Output = String

    let description = "Retrieves stored student knowledge."

    @Generable
    struct Arguments {
        @Guide(description: "all, concepts, difficulties, interests, or profile")
        let queryType: String

        @Guide(description: "Topic filter")
        let topic: String?
    }

    var onRecallKnowledge: (@Sendable @MainActor (String, String?) -> String)?

    func call(arguments: Arguments) async throws -> String {
        guard let callback = onRecallKnowledge else {
            return "No hay información disponible sobre este estudiante."
        }

        let result = await MainActor.run {
            callback(arguments.queryType, arguments.topic)
        }

        return result.isEmpty ? "No hay información almacenada sobre este tema." : result
    }
}

// MARK: - Quiz Generator Tool

/// Tool that allows the AI to generate quiz questions to evaluate the student
struct QuizGeneratorTool: Tool {
    let name = "generateQuizQuestion"
    let includesSchemaInInstructions = false

    typealias Output = String

    let description = "Generates a multiple-choice quiz question."

    @Generable
    struct Arguments {
        @Guide(description: "Question text in Spanish")
        let question: String

        @Guide(description: "Exactly 4 options")
        let options: [String]

        @Guide(description: "Correct option text")
        let correctAnswer: String

        @Guide(description: "Brief explanation")
        let explanation: String

        @Guide(description: "Concept tested")
        let relatedConcept: String

        @Guide(description: "easy, medium, or hard")
        let difficulty: String
    }

    var onQuizGenerated: (@Sendable (String, [String], String, String, String, QuizDifficulty) -> Void)?

    func call(arguments: Arguments) async throws -> String {
        let difficulty = QuizDifficulty(rawValue: arguments.difficulty) ?? .medium

        let safeOptions = Array(arguments.options.prefix(4)).map { String($0.prefix(200)) }
        let safeExplanation = String(arguments.explanation.prefix(500))
        let safeQuestion = String(arguments.question.prefix(500))
        let safeCorrect = String(arguments.correctAnswer.prefix(200))
        let safeConcept = String(arguments.relatedConcept.prefix(200))

        await MainActor.run {
            onQuizGenerated?(
                safeQuestion,
                safeOptions,
                safeCorrect,
                safeExplanation,
                safeConcept,
                difficulty
            )
        }

        return "Quiz ready."
    }
}

