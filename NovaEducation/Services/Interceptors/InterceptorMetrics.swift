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

    // MARK: - Counters (all access through lock)

    private static var _totalRequests: Int = 0
    private static var _totalIntercepted: Int = 0
    private static var _totalPassthrough: Int = 0
    private static var _catalogHits: Int = 0
    private static var _computedResults: Int = 0
    private static var _grammarResults: Int = 0
    private static var _factLookups: Int = 0

    static var totalRequests: Int { lock.withLock { _totalRequests } }
    static var totalIntercepted: Int { lock.withLock { _totalIntercepted } }
    static var totalPassthrough: Int { lock.withLock { _totalPassthrough } }
    static var catalogHits: Int { lock.withLock { _catalogHits } }
    static var computedResults: Int { lock.withLock { _computedResults } }
    static var grammarResults: Int { lock.withLock { _grammarResults } }
    static var factLookups: Int { lock.withLock { _factLookups } }

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

        _totalRequests += 1

        switch result.category {
        case .catalogHit:
            _totalIntercepted += 1
            _catalogHits += 1
        case .computed:
            _totalIntercepted += 1
            _computedResults += 1
        case .grammarRule:
            _totalIntercepted += 1
            _grammarResults += 1
        case .factLookup:
            _totalIntercepted += 1
            _factLookups += 1
        case .passthrough:
            _totalPassthrough += 1
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
            guard _totalRequests > 0 else { return 0 }
            return Double(_totalIntercepted) / Double(_totalRequests) * 100
        }
    }

    static var summary: String {
        lock.withLock {
            let rate = _totalRequests > 0
                ? Double(_totalIntercepted) / Double(_totalRequests) * 100
                : 0.0
            return """
            InterceptorMetrics: \(_totalRequests) requests, \
            \(_totalIntercepted) intercepted (\(String(format: "%.1f", rate))%), \
            \(_totalPassthrough) passthrough | \
            catalog=\(_catalogHits) computed=\(_computedResults) \
            grammar=\(_grammarResults) fact=\(_factLookups)
            """
        }
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll()
        _totalRequests = 0
        _totalIntercepted = 0
        _totalPassthrough = 0
        _catalogHits = 0
        _computedResults = 0
        _grammarResults = 0
        _factLookups = 0
    }
}
