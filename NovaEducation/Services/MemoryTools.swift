import Foundation
import FoundationModels
import SwiftData

// MARK: - Memory Store Tool

/// Tool that allows the AI to store information about the student's learning
final class MemoryStoreTool: Tool, @unchecked Sendable {
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

    /// Set once from @MainActor before any call() invocation. Read in call() via MainActor.run.
    nonisolated(unsafe) var onStoreKnowledge: ((String, KnowledgeCategory, Double) -> Void)?

    /// Current subject ID (set by FoundationModelService)
    nonisolated(unsafe) var currentSubjectId: String = "open"

    func call(arguments: Arguments) async throws -> String {
        let category = KnowledgeCategory(rawValue: arguments.category) ?? .concept
        let mastery = max(0, min(1, arguments.masteryLevel))

        await MainActor.run {
            onStoreKnowledge?(arguments.knowledge, category, mastery)
        }

        return "Stored."
    }
}

// MARK: - Memory Recall Tool

/// Tool that allows the AI to retrieve stored information about the student
final class MemoryRecallTool: Tool, @unchecked Sendable {
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

    /// Set once from @MainActor before any call() invocation. Read in call() via MainActor.run.
    nonisolated(unsafe) var onRecallKnowledge: (@MainActor (String, String?) -> String)?

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
final class QuizGeneratorTool: Tool, @unchecked Sendable {
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

    /// Set once from @MainActor before any call() invocation. Read in call() via MainActor.run.
    nonisolated(unsafe) var onQuizGenerated: ((String, [String], String, String, String, QuizDifficulty) -> Void)?

    func call(arguments: Arguments) async throws -> String {
        let difficulty = QuizDifficulty(rawValue: arguments.difficulty) ?? .medium

        await MainActor.run {
            onQuizGenerated?(
                arguments.question,
                arguments.options,
                arguments.correctAnswer,
                arguments.explanation,
                arguments.relatedConcept,
                difficulty
            )
        }

        return "Quiz ready."
    }
}

