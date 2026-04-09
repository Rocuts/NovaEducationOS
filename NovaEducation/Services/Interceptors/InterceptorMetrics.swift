import Foundation
import os

// MARK: - InterceptorMetrics
// Ring-buffer logger for subject interceptor pipeline events.
// Same pattern as RenderMetrics — lightweight, thread-safe, no persistence.

enum InterceptorMetrics {

    // MARK: - Metric Entry

    struct Entry: Sendable {
        let id: UUID
        let timestamp: Date
        let userUtterance: String
        let subject: String
        let interceptorId: String
        let category: InterceptorResult.Category
        let confidence: Double
        let answerPreview: String
        let durationMs: Int

        init(
            userUtterance: String,
            subject: String,
            interceptorId: String,
            category: InterceptorResult.Category,
            confidence: Double,
            answerPreview: String,
            durationMs: Int
        ) {
            self.id = UUID()
            self.timestamp = Date()
            self.userUtterance = userUtterance
            self.subject = subject
            self.interceptorId = interceptorId
            self.category = category
            self.confidence = confidence
            self.answerPreview = String(answerPreview.prefix(80))
            self.durationMs = durationMs
        }
    }

    // MARK: - Storage (ring buffer, last 100)

    private static let lock = NSLock()
    private static var buffer: [Entry] = []
    private static let maxEntries = 100

    // MARK: - Counters

    private(set) static var totalRequests: Int = 0
    private(set) static var totalIntercepted: Int = 0
    private(set) static var totalPassthrough: Int = 0
    private(set) static var catalogHits: Int = 0
    private(set) static var computedResults: Int = 0
    private(set) static var grammarResults: Int = 0
    private(set) static var factLookups: Int = 0

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.nova.education",
        category: "InterceptorMetrics"
    )

    // MARK: - Public API

    static func log(
        utterance: String,
        subject: String,
        interceptorId: String,
        result: InterceptorResult,
        durationMs: Int
    ) {
        let entry = Entry(
            userUtterance: utterance,
            subject: subject,
            interceptorId: interceptorId,
            category: result.category,
            confidence: result.confidence,
            answerPreview: result.answer,
            durationMs: durationMs
        )

        lock.lock()
        defer { lock.unlock() }

        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }

        totalRequests += 1

        switch result.category {
        case .catalogHit:
            totalIntercepted += 1
            catalogHits += 1
        case .computed:
            totalIntercepted += 1
            computedResults += 1
        case .grammarRule:
            totalIntercepted += 1
            grammarResults += 1
        case .factLookup:
            totalIntercepted += 1
            factLookups += 1
        case .passthrough:
            totalPassthrough += 1
        }

        logger.info(
            "[\(interceptorId)] \(result.category.displayName) conf=\(String(format: "%.1f", result.confidence)) \(durationMs)ms — \(String(utterance.prefix(50)), privacy: .private)"
        )
    }

    static func getRecentEntries() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    /// Percentage of requests successfully intercepted (not passthrough)
    static var interceptRate: Double {
        lock.withLock {
            guard totalRequests > 0 else { return 0 }
            return Double(totalIntercepted) / Double(totalRequests) * 100
        }
    }

    static var summary: String {
        lock.withLock {
            let rate = totalRequests > 0
                ? Double(totalIntercepted) / Double(totalRequests) * 100
                : 0.0
            return """
            InterceptorMetrics: \(totalRequests) requests, \
            \(totalIntercepted) intercepted (\(String(format: "%.1f", rate))%), \
            \(totalPassthrough) passthrough | \
            catalog=\(catalogHits) computed=\(computedResults) \
            grammar=\(grammarResults) fact=\(factLookups)
            """
        }
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll()
        totalRequests = 0
        totalIntercepted = 0
        totalPassthrough = 0
        catalogHits = 0
        computedResults = 0
        grammarResults = 0
        factLookups = 0
    }
}
