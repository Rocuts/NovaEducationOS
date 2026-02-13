import Foundation
import SwiftData

/// Service responsible for managing student memory (knowledge, preferences, progress)
/// Acts as the bridge between AI Tools and SwiftData persistence
@MainActor
final class StudentMemoryService {
    static let shared = StudentMemoryService()

    private init() {}

    // MARK: - Knowledge Storage

    /// Stores a new piece of knowledge about the student
    func storeKnowledge(
        content: String,
        category: KnowledgeCategory,
        subjectId: String,
        masteryLevel: Double = 0.5,
        context: ModelContext
    ) -> StudentKnowledge {
        // Check if similar knowledge already exists
        if let existing = findSimilarKnowledge(content: content, subjectId: subjectId, context: context) {
            existing.markAsReferenced()
            existing.updateMastery(masteryLevel)
            return existing
        }

        let knowledge = StudentKnowledge(
            content: content,
            category: category,
            subjectId: subjectId,
            masteryLevel: masteryLevel
        )
        context.insert(knowledge)
        return knowledge
    }

    /// Finds similar existing knowledge to avoid duplicates
    private func findSimilarKnowledge(content: String, subjectId: String, context: ModelContext) -> StudentKnowledge? {
        let lowercased = content.lowercased()
        let descriptor = FetchDescriptor<StudentKnowledge>(
            predicate: #Predicate { $0.subjectId == subjectId }
        )

        guard let results = try? context.fetch(descriptor) else { return nil }

        // Simple similarity check - if content contains key words
        return results.first { existing in
            let existingLower = existing.content.lowercased()
            // Check if they share significant overlap
            return existingLower.contains(lowercased) || lowercased.contains(existingLower)
        }
    }

    // MARK: - Knowledge Retrieval

    /// Retrieves all knowledge for a specific subject
    func getKnowledge(for subjectId: String, context: ModelContext) -> [StudentKnowledge] {
        let descriptor = FetchDescriptor<StudentKnowledge>(
            predicate: #Predicate { $0.subjectId == subjectId },
            sortBy: [SortDescriptor(\.lastReviewedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Retrieves knowledge by category
    func getKnowledge(for subjectId: String, category: KnowledgeCategory, context: ModelContext) -> [StudentKnowledge] {
        let descriptor = FetchDescriptor<StudentKnowledge>(
            predicate: #Predicate { $0.subjectId == subjectId && $0.category == category },
            sortBy: [SortDescriptor(\.lastReviewedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Gets concepts the student is struggling with
    func getDifficulties(for subjectId: String, context: ModelContext) -> [StudentKnowledge] {
        getKnowledge(for: subjectId, category: .difficulty, context: context) +
        getKnowledge(for: subjectId, category: .misconception, context: context)
    }

    /// Gets concepts the student has mastered (mastery > 0.7)
    func getMasteredConcepts(for subjectId: String, context: ModelContext) -> [StudentKnowledge] {
        let descriptor = FetchDescriptor<StudentKnowledge>(
            predicate: #Predicate { $0.subjectId == subjectId && $0.masteryLevel > 0.7 },
            sortBy: [SortDescriptor(\.masteryLevel, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Gets the student's interests
    func getInterests(context: ModelContext) -> [StudentKnowledge] {
        let category = KnowledgeCategory.interest
        let descriptor = FetchDescriptor<StudentKnowledge>(
            predicate: #Predicate { $0.category == category },
            sortBy: [SortDescriptor(\.timesReferenced, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Builds a context string for the AI with relevant student knowledge
    func buildKnowledgeContext(for subjectId: String, context: ModelContext) -> String {
        let concepts = getKnowledge(for: subjectId, category: .concept, context: context).prefix(5)
        let difficulties = getDifficulties(for: subjectId, context: context).prefix(3)
        let strengths = getKnowledge(for: subjectId, category: .strength, context: context).prefix(3)
        let interests = getInterests(context: context).prefix(3)

        var parts: [String] = []

        if !concepts.isEmpty {
            let conceptList = concepts.map { "• \($0.content)" }.joined(separator: "\n")
            parts.append("Conceptos que domina:\n\(conceptList)")
        }

        if !difficulties.isEmpty {
            let diffList = difficulties.map { "• \($0.content)" }.joined(separator: "\n")
            parts.append("Áreas de dificultad:\n\(diffList)")
        }

        if !strengths.isEmpty {
            let strengthList = strengths.map { "• \($0.content)" }.joined(separator: "\n")
            parts.append("Fortalezas:\n\(strengthList)")
        }

        if !interests.isEmpty {
            let interestList = interests.map { "• \($0.content)" }.joined(separator: "\n")
            parts.append("Intereses:\n\(interestList)")
        }

        guard !parts.isEmpty else {
            return "No hay información previa sobre este estudiante."
        }

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Quiz Management

    /// Stores a generated quiz question
    func storeQuizQuestion(
        question: String,
        options: [String],
        correctAnswer: String,
        explanation: String,
        subjectId: String,
        relatedConcept: String,
        difficulty: QuizDifficulty,
        context: ModelContext
    ) -> QuizQuestion {
        let quiz = QuizQuestion(
            question: question,
            options: options,
            correctAnswer: correctAnswer,
            explanation: explanation,
            subjectId: subjectId,
            relatedConcept: relatedConcept,
            difficulty: difficulty
        )
        context.insert(quiz)
        return quiz
    }

    /// Gets unanswered quiz questions for a subject
    func getPendingQuizzes(for subjectId: String, context: ModelContext) -> [QuizQuestion] {
        let descriptor = FetchDescriptor<QuizQuestion>(
            predicate: #Predicate { $0.subjectId == subjectId && $0.answeredAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Gets quiz performance statistics
    func getQuizStats(for subjectId: String, context: ModelContext) -> (total: Int, correct: Int, accuracy: Double) {
        let descriptor = FetchDescriptor<QuizQuestion>(
            predicate: #Predicate { $0.subjectId == subjectId && $0.answeredAt != nil }
        )
        guard let results = try? context.fetch(descriptor) else {
            return (0, 0, 0)
        }

        let total = results.count
        let correct = results.filter { $0.wasAnsweredCorrectly == true }.count
        let accuracy = total > 0 ? Double(correct) / Double(total) : 0

        return (total, correct, accuracy)
    }

    // MARK: - Learning Plans

    /// Creates a new learning plan
    func createLearningPlan(
        topic: String,
        subjectId: String,
        steps: [LearningStep],
        context: ModelContext
    ) -> LearningPlan {
        let plan = LearningPlan(topic: topic, subjectId: subjectId, steps: steps)
        context.insert(plan)
        return plan
    }

    /// Gets active (incomplete) learning plans
    func getActivePlans(for subjectId: String, context: ModelContext) -> [LearningPlan] {
        let descriptor = FetchDescriptor<LearningPlan>(
            predicate: #Predicate { $0.subjectId == subjectId && $0.isCompleted == false },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Summary for AI

    /// Generates a comprehensive summary of the student's learning profile for AI context
    func generateStudentProfile(for subjectId: String, context: ModelContext) -> String {
        let knowledgeContext = buildKnowledgeContext(for: subjectId, context: context)
        let quizStats = getQuizStats(for: subjectId, context: context)
        let activePlans = getActivePlans(for: subjectId, context: context)

        var profile = "*** PERFIL DE APRENDIZAJE DEL ESTUDIANTE ***\n\n"
        profile += knowledgeContext

        if quizStats.total > 0 {
            let percentage = Int(quizStats.accuracy * 100)
            profile += "\n\nEstadísticas de evaluaciones: \(quizStats.correct)/\(quizStats.total) correctas (\(percentage)%)"
        }

        if let currentPlan = activePlans.first {
            let progress = Int(currentPlan.progress * 100)
            profile += "\n\nPlan de aprendizaje activo: \"\(currentPlan.topic)\" - \(progress)% completado"
            if let step = currentPlan.currentStep {
                profile += "\nPaso actual: \(step.title)"
            }
        }

        return profile
    }
}
