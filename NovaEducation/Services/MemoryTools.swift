import Foundation
import FoundationModels
import SwiftData

// MARK: - Memory Store Tool

/// Tool that allows the AI to store information about the student's learning
final class MemoryStoreTool: Tool, @unchecked Sendable {
    let name = "storeStudentKnowledge"

    typealias Output = String

    let description = """
    Stores important information about the student's learning progress.

    USE THIS TOOL when the student:
    • Demonstrates understanding of a concept ("Ya entiendo las fracciones")
    • Shows difficulty with something ("No entiendo los logaritmos")
    • Mentions their interests ("Me gusta la astronomía")
    • Has a misconception you corrected
    • Shows a particular strength
    • Mentions their academic goals

    EXAMPLES:
    - Student says "¡Ahora sí entiendo!" after explaining derivatives → store as "concept"
    - Student struggles repeatedly with fractions → store as "difficulty"
    - Student asks many questions about space → store as "interest"
    - Student confuses velocity with acceleration → store as "misconception"

    DO NOT store: greetings, off-topic chat, temporary confusion during explanation.
    """

    @Generable
    struct Arguments {
        @Guide(description: "What to remember about the student. Be specific and concise. Example: 'Understands how to solve quadratic equations using the formula'")
        let knowledge: String

        @Guide(description: "Category: 'concept' (learned), 'difficulty' (struggles with), 'preference' (learning style), 'interest' (topics they like), 'misconception' (wrong understanding), 'strength' (good at), 'goal' (academic objective)")
        let category: String

        @Guide(description: "Mastery level from 0.0 to 1.0. Use 0.8+ for mastered, 0.5 for learning, 0.3 for struggling")
        let masteryLevel: Double
    }

    /// Callback to store knowledge (will be set by FoundationModelService)
    var onStoreKnowledge: ((String, KnowledgeCategory, Double) -> Void)?

    /// Current subject ID (set by FoundationModelService)
    var currentSubjectId: String = "open"

    func call(arguments: Arguments) async throws -> String {
        let category = KnowledgeCategory(rawValue: arguments.category) ?? .concept
        let mastery = max(0, min(1, arguments.masteryLevel))

        let resultText = await MainActor.run {
            onStoreKnowledge?(arguments.knowledge, category, mastery)
            return "Guardado: \(arguments.knowledge) (categoría: \(category.displayName), dominio: \(Int(mastery * 100))%)"
        }

        return resultText
    }
}

// MARK: - Memory Recall Tool

/// Tool that allows the AI to retrieve stored information about the student
final class MemoryRecallTool: Tool, @unchecked Sendable {
    let name = "recallStudentKnowledge"

    typealias Output = String

    let description = """
    Retrieves stored information about the student's learning history.

    USE THIS TOOL when you need to:
    • Check what the student already knows before explaining
    • Review their difficulties to provide targeted help
    • Reference their interests to make examples more engaging
    • Build on previously learned concepts

    EXAMPLES:
    - Before teaching algebra, check if they understand arithmetic
    - When student seems lost, recall their known difficulties
    - Make examples about their interests (e.g., if they like soccer, use sports examples)

    This helps you personalize your teaching to this specific student.
    """

    @Generable
    struct Arguments {
        @Guide(description: "What type of information to recall: 'all' (everything), 'concepts' (what they know), 'difficulties' (what they struggle with), 'interests' (what they like), 'profile' (full summary)")
        let queryType: String

        @Guide(description: "Optional: specific topic to search for, e.g., 'fractions', 'algebra'. Leave empty for general recall.")
        let topic: String?
    }

    /// Callback to recall knowledge (will be set by FoundationModelService)
    var onRecallKnowledge: ((String, String?) -> String)?

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

    typealias Output = String

    let description = """
    Generates a quiz question to evaluate the student's understanding.

    USE THIS TOOL when:
    • Student asks to be tested ("Hazme una pregunta", "Evalúame")
    • After explaining a concept, to verify understanding
    • Student says they're ready to practice
    • You want to identify gaps in their knowledge

    The quiz will be stored and tracked for progress monitoring.

    DO NOT use for: regular explanations, casual conversation, when student is frustrated.
    """

    @Generable
    struct Arguments {
        @Guide(description: "The question to ask the student")
        let question: String

        @Guide(description: "Array of 4 possible answers for multiple choice")
        let options: [String]

        @Guide(description: "The correct answer (must match one of the options exactly)")
        let correctAnswer: String

        @Guide(description: "Brief explanation of why the answer is correct")
        let explanation: String

        @Guide(description: "The concept being tested, e.g., 'quadratic equations', 'photosynthesis'")
        let relatedConcept: String

        @Guide(description: "Difficulty: 'easy', 'medium', or 'hard'")
        let difficulty: String
    }

    /// Callback to store the quiz question
    var onQuizGenerated: ((String, [String], String, String, String, QuizDifficulty) -> Void)?

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

        // Format the quiz for display
        var quizText = "📝 **Pregunta de evaluación**\n\n"
        quizText += "\(arguments.question)\n\n"

        for (index, option) in arguments.options.enumerated() {
            let letter = ["A", "B", "C", "D"][index]
            quizText += "**\(letter).** \(option)\n"
        }

        quizText += "\n_Responde con la letra de tu respuesta._"

        return quizText
    }
}

// MARK: - Learning Plan Tool

/// Tool that allows the AI to create a structured learning plan
final class LearningPlanTool: Tool, @unchecked Sendable {
    let name = "createLearningPlan"

    typealias Output = String

    let description = """
    Creates a structured learning plan for a complex topic.

    USE THIS TOOL when:
    • Student asks to learn a broad topic ("Enséñame cálculo", "Quiero aprender química orgánica")
    • Topic requires multiple prerequisite concepts
    • Student seems overwhelmed and needs structure
    • Long-term learning goal is identified

    The plan breaks down the topic into sequential, manageable steps.

    DO NOT use for: simple questions, single-concept explanations, quick help.
    """

    @Generable
    struct Arguments {
        @Guide(description: "The main topic the plan covers, e.g., 'Cálculo diferencial', 'Gramática inglesa'")
        let topic: String

        @Guide(description: "Array of learning steps, each with 'title', 'description', and optional 'prerequisite'")
        let steps: [PlanStep]
    }

    @Generable
    struct PlanStep {
        @Guide(description: "Short title for this step, e.g., 'Límites'")
        let title: String

        @Guide(description: "What will be learned in this step")
        let description: String

        @Guide(description: "Optional: what needs to be understood first")
        let prerequisite: String?
    }

    /// Callback to store the learning plan
    var onPlanCreated: ((String, [LearningStep]) -> Void)?

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            let steps = arguments.steps.map { step in
                LearningStep(
                    title: step.title,
                    description: step.description,
                    prerequisite: step.prerequisite
                )
            }
            onPlanCreated?(arguments.topic, steps)
        }

        // Format the plan for display
        var planText = "📋 **Plan de aprendizaje: \(arguments.topic)**\n\n"

        for (index, step) in arguments.steps.enumerated() {
            planText += "**\(index + 1). \(step.title)**\n"
            planText += "   \(step.description)\n"
            if let prereq = step.prerequisite, !prereq.isEmpty {
                planText += "   _Requiere: \(prereq)_\n"
            }
            planText += "\n"
        }

        planText += "---\n_¿Empezamos con el paso 1?_"

        return planText
    }
}
