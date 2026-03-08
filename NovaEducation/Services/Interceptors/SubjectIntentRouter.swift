import Foundation

// MARK: - SubjectIntentRouter
// Unified router that tests all registered interceptors against user input.
// Sits between RenderIntentRouter (visual) and pure LLM (discussion/creative).
//
// Pipeline order in ChatViewModel.sendMessage():
//   1. RenderIntentRouter.detect()     → visual?        → RenderPipeline
//   2. SubjectIntentRouter.detect()    → computation?   → Interceptor.solve() → Teacher
//   3. Pure LLM                        → discussion     → FoundationModelService

enum SubjectIntentRouter {

    // MARK: - Registered Interceptors

    /// Static array of all subject interceptors, ordered by priority.
    /// MathSolver first because arithmetic is the most common interception.
    private static let interceptors: [any SubjectInterceptor] = [
        MathSolver(),
        PhysicsSolver(),
        ChemistrySolver(),
        SpanishGrammarSolver(),
    ]

    // MARK: - Public API

    /// Finds the first interceptor that can handle this input for the given subject.
    /// For `.open` subject, tests ALL interceptors regardless of their supportedSubjects.
    /// Returns nil if no interceptor matches (→ pure LLM path).
    static func detect(_ text: String, subject: Subject) -> (any SubjectInterceptor)? {
        for interceptor in interceptors {
            // For .open, try all interceptors; otherwise check supported subjects
            let isRelevant = subject == .open || interceptor.supportedSubjects.contains(subject)
            guard isRelevant else { continue }

            if interceptor.detect(text, subject: subject) {
                return interceptor
            }
        }
        return nil
    }

    /// Convenience: detect + solve in one call. Returns nil if no interceptor matches.
    static func process(_ text: String, subject: Subject) async -> (interceptor: any SubjectInterceptor, result: InterceptorResult)? {
        guard let interceptor = detect(text, subject: subject) else { return nil }
        let result = await interceptor.solve(text, subject: subject)

        // If the interceptor fell through, treat as no match
        if result.category == .passthrough {
            return nil
        }

        return (interceptor, result)
    }
}
