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

enum RenderMetrics {
    private static let logger = Logger(subsystem: "com.nova.education", category: "RenderPipeline")

    /// In-memory ring buffer for recent metrics (last 100 entries)
    private static var recentEntries: [RenderMetricEntry] = []
    private static let maxEntries = 100

    // MARK: - Counters

    private(set) static var totalRequests = 0
    private(set) static var totalSuccesses = 0
    private(set) static var totalFallbacks = 0
    private(set) static var totalFailures = 0
    private(set) static var catalogHits = 0
    private(set) static var llmExtractions = 0

    /// Success rate as percentage
    static var successRate: Double {
        guard totalRequests > 0 else { return 100.0 }
        return Double(totalSuccesses + totalFallbacks) / Double(totalRequests) * 100.0
    }

    /// Catalog hit rate as percentage
    static var catalogHitRate: Double {
        guard totalRequests > 0 else { return 0.0 }
        return Double(catalogHits) / Double(totalRequests) * 100.0
    }

    // MARK: - Logging

    static func log(_ entry: RenderMetricEntry) {
        totalRequests += 1

        switch entry.renderResult {
        case .success:
            totalSuccesses += 1
        case .fallback:
            totalFallbacks += 1
        case .failure:
            totalFailures += 1
        }

        if entry.routerDecision.catalogHit {
            catalogHits += 1
        } else {
            llmExtractions += 1
        }

        // Store in ring buffer
        recentEntries.append(entry)
        if recentEntries.count > maxEntries {
            recentEntries.removeFirst()
        }

        // Log to system console
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
        recentEntries
    }

    /// Resets all counters (for testing)
    static func reset() {
        totalRequests = 0
        totalSuccesses = 0
        totalFallbacks = 0
        totalFailures = 0
        catalogHits = 0
        llmExtractions = 0
        recentEntries.removeAll()
    }

    /// Summary string for debugging
    static var summary: String {
        """
        Render Pipeline Metrics:
          Total: \(totalRequests) | Success: \(totalSuccesses) | Fallback: \(totalFallbacks) | Failure: \(totalFailures)
          Success Rate: \(String(format: "%.1f", successRate))%
          Catalog Hits: \(catalogHits) (\(String(format: "%.1f", catalogHitRate))%)
          LLM Extractions: \(llmExtractions)
        """
    }
}
