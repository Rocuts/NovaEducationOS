import Foundation

// MARK: - SubjectInterceptor Protocol
// "App decide, LLM enseña" — interceptors compute deterministic answers
// BEFORE the LLM, which then only explains the result pedagogically.

protocol SubjectInterceptor: Sendable {
    /// Unique identifier for metrics logging
    var interceptorId: String { get }

    /// Which subjects this interceptor handles
    var supportedSubjects: Set<Subject> { get }

    /// O(n) deterministic detection — no LLM involved.
    /// Returns true if this interceptor can handle the input.
    func detect(_ text: String, subject: Subject) -> Bool

    /// Computes the answer deterministically. Always returns a result
    /// (use `.fallthrough` when the interceptor can't solve it).
    func solve(_ text: String, subject: Subject) async -> InterceptorResult
}

// MARK: - InterceptorResult

struct InterceptorResult: Sendable {
    /// Computed answer, max ~300 chars
    let answer: String

    /// Prompt instruction for the teacher LLM to explain the result
    let teacherInstruction: String

    /// How the result was obtained
    let category: Category

    /// Optional attachment type for UI rendering (e.g., "conjugation_table", "formula_result")
    let attachmentType: String?

    /// Optional JSON data for the attachment
    let attachmentData: String?

    /// Confidence: 1.0 = catalog hit, 0.9 = computed, 0.0 = fallthrough
    let confidence: Double

    enum Category: String, Sendable {
        case catalogHit      // Direct lookup from catalog/table
        case computed        // Calculated deterministically
        case grammarRule     // Language rule matched
        case factLookup      // Known fact/constant
        case passthrough      // Could not solve — let LLM handle

        var displayName: String {
            switch self {
            case .catalogHit: return "catalog"
            case .computed: return "computed"
            case .grammarRule: return "grammar"
            case .factLookup: return "fact"
            case .passthrough: return "fallthrough"
            }
        }
    }

    /// Convenience for when the interceptor cannot handle the input
    static func passthrough(_ text: String) -> InterceptorResult {
        InterceptorResult(
            answer: "",
            teacherInstruction: text,
            category: .passthrough,
            attachmentType: nil,
            attachmentData: nil,
            confidence: 0.0
        )
    }
}
