import Foundation
import os

// MARK: - Render Metrics
// Logs every step of the render pipeline for debugging and reliability tracking.

struct RenderMetricEntry: Sendable {
    let id: UUID
    let timestamp: Date
    let userUtterance: String
    let routerDecision: RouterDecision
    let extractedRequest: RequestSnapshot?
    let validationErrors: [String]
    let finalRequest: RequestSnapshot?
    let renderResult: RenderResult
    let durationMs: Int

    struct RouterDecision: Sendable {
        let intent: String
        let detectedColor: String?
        let detectedPrimitive: String?
        let detectedConcept: String?
        let isModification: Bool
        let catalogHit: Bool
    }

    struct RequestSnapshot: Sendable {
        let mode: String
        let concept: String
        let preset: String?
        let primitive: String?
        let color: String
        let size: String
        let animation: String
    }

    enum RenderResult: Sendable {
        case success(assetId: String, mode: String)
        case fallback(reason: String)
        case failure(error: String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }
}

// MARK: - Metric Snapshots

extension RenderMetricEntry.RequestSnapshot {
    init(from request: RenderRequest) {
        self.mode = request.mode.rawValue
        self.concept = request.concept
        self.preset = request.preset?.rawValue
        self.primitive = request.primitive?.rawValue ?? request.resolvedPrimitive.rawValue
        self.color = request.color.rawValue
        self.size = request.size.rawValue
        self.animation = request.animation.rawValue
    }
}

extension RenderMetricEntry.RouterDecision {
    init(from result: RouterResult, catalogHit: Bool) {
        self.intent = String(describing: result.intent)
        self.detectedColor = result.detectedColor?.rawValue
        self.detectedPrimitive = result.detectedPrimitive?.rawValue
        self.detectedConcept = result.detectedConcept
        self.isModification = result.isModification
        self.catalogHit = catalogHit
    }
}

// MARK: - RenderMetrics Logger
// Thread-safe via NSLock — same pattern as InterceptorMetrics.
// All reads and writes to mutable static state are protected by the lock.

enum RenderMetrics {
    private static let logger = Logger(subsystem: "com.nova.education", category: "RenderPipeline")

    private static let lock = NSLock()

    /// In-memory ring buffer for recent metrics (last 100 entries)
    private static var buffer: [RenderMetricEntry] = []
    private static let maxEntries = 100

    // MARK: - Counters (all access guarded by `lock`)

    private static var _totalRequests = 0
    private static var _totalSuccesses = 0
    private static var _totalFallbacks = 0
    private static var _totalFailures = 0
    private static var _catalogHits = 0
    private static var _llmExtractions = 0

    static var totalRequests: Int { lock.withLock { _totalRequests } }
    static var totalSuccesses: Int { lock.withLock { _totalSuccesses } }
    static var totalFallbacks: Int { lock.withLock { _totalFallbacks } }
    static var totalFailures: Int { lock.withLock { _totalFailures } }
    static var catalogHits: Int { lock.withLock { _catalogHits } }
    static var llmExtractions: Int { lock.withLock { _llmExtractions } }

    /// Success rate as percentage
    static var successRate: Double {
        lock.withLock {
            guard _totalRequests > 0 else { return 100.0 }
            return Double(_totalSuccesses + _totalFallbacks) / Double(_totalRequests) * 100.0
        }
    }

    /// Catalog hit rate as percentage
    static var catalogHitRate: Double {
        lock.withLock {
            guard _totalRequests > 0 else { return 0.0 }
            return Double(_catalogHits) / Double(_totalRequests) * 100.0
        }
    }

    // MARK: - Logging

    static func log(_ entry: RenderMetricEntry) {
        lock.lock()

        _totalRequests += 1

        switch entry.renderResult {
        case .success:
            _totalSuccesses += 1
        case .fallback:
            _totalFallbacks += 1
        case .failure:
            _totalFailures += 1
        }

        if entry.routerDecision.catalogHit {
            _catalogHits += 1
        } else {
            _llmExtractions += 1
        }

        // Store in ring buffer
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst()
        }

        lock.unlock()

        // Log to system console (no lock needed — Logger is thread-safe)
        let resultStr: String
        switch entry.renderResult {
        case .success(let id, let mode):
            resultStr = "SUCCESS [\(mode)] id=\(id)"
        case .fallback(let reason):
            resultStr = "FALLBACK: \(reason)"
        case .failure(let error):
            resultStr = "FAILURE: \(error)"
        }

        logger.info("""
        RENDER [\(entry.durationMs)ms] \(resultStr)
          utterance: \(entry.userUtterance, privacy: .private)
          router: intent=\(entry.routerDecision.intent) \
        catalog=\(entry.routerDecision.catalogHit) \
        concept=\(entry.routerDecision.detectedConcept ?? "nil", privacy: .private)
          final: mode=\(entry.finalRequest?.mode ?? "nil") \
        primitive=\(entry.finalRequest?.primitive ?? "nil") \
        color=\(entry.finalRequest?.color ?? "nil")
        """)

        if !entry.validationErrors.isEmpty {
            logger.warning("  validation errors: \(entry.validationErrors.joined(separator: ", "))")
        }
    }

    /// Returns recent entries for debugging UI
    static func getRecentEntries() -> [RenderMetricEntry] {
        lock.withLock { buffer }
    }

    /// Resets all counters (for testing)
    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _totalRequests = 0
        _totalSuccesses = 0
        _totalFallbacks = 0
        _totalFailures = 0
        _catalogHits = 0
        _llmExtractions = 0
        buffer.removeAll()
    }

    /// Summary string for debugging
    static var summary: String {
        lock.withLock {
            """
            Render Pipeline Metrics:
              Total: \(_totalRequests) | Success: \(_totalSuccesses) | Fallback: \(_totalFallbacks) | Failure: \(_totalFailures)
              Success Rate: \(String(format: "%.1f", _totalRequests > 0 ? Double(_totalSuccesses + _totalFallbacks) / Double(_totalRequests) * 100.0 : 100.0))%
              Catalog Hits: \(_catalogHits) (\(String(format: "%.1f", _totalRequests > 0 ? Double(_catalogHits) / Double(_totalRequests) * 100.0 : 0.0))%)
              LLM Extractions: \(_llmExtractions)
            """
        }
    }
}
