import Foundation
import FoundationModels
import os

// MARK: - RenderPipeline
// Orchestrates the full render flow: router → catalog/LLM → validate → execute → output.
// Guarantees: every render intent produces an asset. No "I don't know" responses.

@Observable
@MainActor
final class RenderPipeline {
    static let shared = RenderPipeline()
    private init() {}

    private let logger = Logger(subsystem: "com.nova.education", category: "RenderPipeline")

    /// Last successful render request (for modification support)
    private(set) var lastRenderRequest: RenderRequest?

    /// Reusable extraction session (minimal, isolated from teacher pipeline)
    private var extractionSession: LanguageModelSession?

    // MARK: - Main Entry Point

    /// Process a user utterance that has been identified as a render intent.
    /// Guarantees: ALWAYS returns a RenderOutput with an asset. Never fails.
    func process(text: String, routerResult: RouterResult) async -> RenderOutput {
        let startTime = CFAbsoluteTimeGetCurrent()
        var validationErrors: [String] = []
        var catalogHit = false

        // 1. Handle modifications to previous render
        if routerResult.isModification, let previous = lastRenderRequest {
            var modified = previous
            if let newColor = routerResult.modificationColor {
                modified.color = newColor
            }
            if let newSize = routerResult.modificationSize {
                modified.size = newSize
            }
            let output = execute(modified)
            lastRenderRequest = modified

            logMetric(
                text: text, routerResult: routerResult, catalogHit: false,
                extractedRequest: nil, validationErrors: [],
                finalRequest: modified, output: output, startTime: startTime
            )
            return output
        }

        // 2. Try concept catalog (deterministic, no LLM needed)
        var request: RenderRequest?
        if let entry = ConceptCatalog.match(text) {
            catalogHit = true
            let mode = routerResult.intent.defaultMode
            let color = routerResult.detectedColor ?? entry.defaultColor
            request = entry.toRenderRequest(mode: mode, color: color)
            logger.debug("Catalog hit for: \(text, privacy: .private)")
        }

        // 3. Try building from router-detected shape (no LLM needed)
        if request == nil, let primitive = routerResult.detectedPrimitive {
            request = RenderRequest(
                mode: routerResult.intent.defaultMode,
                concept: routerResult.detectedConcept ?? primitive.rawValue,
                preset: nil,
                primitive: primitive,
                color: routerResult.detectedColor ?? .blue,
                material: .matte,
                style: .diagram,
                size: .medium,
                camera: .default,
                lighting: .default,
                animation: .rotateSlow,
                labelText: routerResult.detectedConcept,
                locale: "es"
            )
            logger.debug("Built from router primitive: \(primitive.rawValue)")
        }

        // 4. Try LLM extraction (only if catalog and router didn't resolve)
        if request == nil {
            request = await tryLLMExtraction(text: text, routerResult: routerResult)
            if request == nil {
                logger.warning("LLM extraction failed for: \(text, privacy: .private)")
                validationErrors.append("LLM extraction failed")
            }
        }

        // 5. Validate and normalize (or use fallback)
        var finalRequest = request ?? buildFallbackRequest(
            concept: routerResult.detectedConcept,
            color: routerResult.detectedColor
        )
        let (validated, errors) = validate(finalRequest)
        finalRequest = validated
        validationErrors.append(contentsOf: errors)

        // 6. Execute render
        let output = execute(finalRequest)
        lastRenderRequest = finalRequest

        // 7. Log metrics
        logMetric(
            text: text, routerResult: routerResult, catalogHit: catalogHit,
            extractedRequest: request.map { RenderMetricEntry.RequestSnapshot(from: $0) },
            validationErrors: validationErrors,
            finalRequest: finalRequest, output: output, startTime: startTime
        )

        return output
    }

    // MARK: - LLM Extraction (Render Parser Pipeline)

    /// Uses a minimal, isolated LLM session with guided generation to extract render parameters.
    /// Completely separate from the teacher pipeline to avoid prompt drift.
    private func tryLLMExtraction(
        text: String,
        routerResult: RouterResult
    ) async -> RenderRequest? {
        // Create or reuse extraction session
        if extractionSession == nil {
            extractionSession = LanguageModelSession {
                "Extract render parameters from student requests. Return object name in English, color if mentioned, shape if geometric."
            }
        }

        guard let session = extractionSession else { return nil }

        let prompt = "Student wants to see: \"\(text)\". Extract object, color, shape."

        // First attempt
        do {
            let response = try await session.respond(
                to: prompt,
                generating: RenderExtraction.self
            )
            return buildFromExtraction(response.content, routerResult: routerResult)
        } catch {
            logger.warning("LLM extraction attempt 1 failed: \(error.localizedDescription)")
        }

        // Repair retry with minimal prompt (max 1 retry)
        do {
            // Fresh session for retry to avoid context contamination
            let retrySession = LanguageModelSession {
                "Extract render parameters only."
            }
            let retryResponse = try await retrySession.respond(
                to: "Object to render from: \"\(text)\". Return object name, color, shape.",
                generating: RenderExtraction.self
            )
            return buildFromExtraction(retryResponse.content, routerResult: routerResult)
        } catch {
            logger.error("LLM extraction repair retry also failed: \(error.localizedDescription)")
            // Reset session for next call
            extractionSession = nil
            return nil
        }
    }

    /// Converts LLM extraction result into a RenderRequest
    private func buildFromExtraction(
        _ extraction: RenderExtraction,
        routerResult: RouterResult
    ) -> RenderRequest {
        // Try to find a preset from the extracted object name
        let preset = findPreset(from: extraction.objectName)
        let primitive = extraction.shape ?? preset?.defaultPrimitive ?? routerResult.detectedPrimitive
        let color = extraction.color ?? routerResult.detectedColor ?? preset?.defaultColor ?? .blue

        return RenderRequest(
            mode: routerResult.intent.defaultMode,
            concept: extraction.objectName,
            preset: preset,
            primitive: primitive,
            color: color,
            material: .matte,
            style: .diagram,
            size: .medium,
            camera: .default,
            lighting: .default,
            animation: preset?.defaultAnimation ?? .rotateSlow,
            labelText: preset?.spanishName ?? extraction.objectName,
            locale: "es"
        )
    }

    /// Tries to match an English object name to a RenderPreset
    private func findPreset(from objectName: String) -> RenderPreset? {
        let lower = objectName.lowercased()
        let presetMap: [String: RenderPreset] = [
            "atom": .atom, "molecule": .molecule,
            "water": .waterMolecule, "h2o": .waterMolecule,
            "cell": .cell, "dna": .dna,
            "heart": .heart, "lung": .lung, "eye": .eye, "brain": .brain,
            "flower": .flower, "tree": .tree, "leaf": .leaf,
            "volcano": .volcano, "mountain": .mountain,
            "pendulum": .pendulum, "magnet": .magnet, "wave": .wave,
            "crystal": .crystal,
            "earth": .earth, "mars": .mars, "saturn": .saturn,
            "jupiter": .jupiter, "moon": .moon, "sun": .sun, "star": .star,
            "solar system": .solarSystem,
            "microscope": .microscope, "telescope": .telescope,
            "compass": .compass, "prism": .prism,
            "black hole": .blackHole, "rocket": .rocket,
            "fossil": .fossil, "battery": .battery
        ]
        for (key, preset) in presetMap {
            if lower.contains(key) { return preset }
        }
        return nil
    }

    // MARK: - Validation & Normalization

    /// Validates and normalizes a RenderRequest. Returns the corrected request and any errors found.
    private func validate(_ request: RenderRequest) -> (RenderRequest, [String]) {
        var r = request
        var errors: [String] = []

        // Ensure at least one of preset/primitive is set
        if r.preset == nil && r.primitive == nil {
            r.primitive = .cube
            errors.append("No preset or primitive — defaulted to cube")
        }

        // Enforce label length limit
        if let label = r.labelText, label.count > 40 {
            r.labelText = String(label.prefix(40))
            errors.append("Label truncated to 40 chars")
        }

        // Ensure concept is not empty
        if r.concept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            r.concept = r.preset?.spanishName ?? r.resolvedPrimitive.rawValue
            errors.append("Empty concept — filled from preset/primitive")
        }

        return (r, errors)
    }

    // MARK: - Execution

    /// Executes the render request and produces output.
    /// All rendering is 3D (SceneKit) for guaranteed instant, offline reliability.
    private func execute(_ request: RenderRequest) -> RenderOutput {
        execute3D(request)
    }

    /// Produces a 3D render output (instant, always succeeds)
    private func execute3D(_ request: RenderRequest) -> RenderOutput {
        var config: [String: Any] = [
            "shape": request.resolvedPrimitive.rawValue,
            "color": request.color.sceneKitName,
            "scale": request.size.scaleValue,
            "animation": request.animation.sceneKitName,
            "caption": request.labelText ?? "",
        ]

        // Pass preset name so GeometryView can build composite scenes
        if let preset = request.preset {
            config["preset"] = preset.rawValue
        }

        // Safe serialization — return fallback output if config can't be encoded
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return .fallback
        }

        let summary = buildSpokenSummary(request)

        return RenderOutput(
            assetId: UUID().uuidString,
            spokenSummary: summary,
            renderMode: .object3d,
            controlsEnabled: .init(rotate: true, zoom: true, pan: true),
            attachmentType: "geometry_3d",
            attachmentData: jsonString,
            imageURL: nil
        )
    }

    // MARK: - Spoken Summary

    /// Builds a short Spanish summary for TTS (max 120 chars)
    private func buildSpokenSummary(_ request: RenderRequest) -> String {
        let name = request.preset?.spanishName ?? request.labelText ?? request.concept
        let colorName = spanishColorName(request.color)

        let base = "Aquí tienes: \(name) en \(colorName)"
        let suffix = request.animation != .none ? ". Puedes girarlo con el dedo." : "."
        let full = base + suffix
        return String(full.prefix(120))
    }

    private func spanishColorName(_ color: RenderColor) -> String {
        switch color {
        case .red: return "rojo"
        case .blue: return "azul"
        case .green: return "verde"
        case .yellow: return "amarillo"
        case .orange: return "naranja"
        case .purple: return "morado"
        case .pink: return "rosa"
        case .white: return "blanco"
        case .black: return "negro"
        case .gray: return "gris"
        case .brown: return "marrón"
        case .gold: return "dorado"
        case .silver: return "plateado"
        case .cyan: return "cian"
        }
    }

    // MARK: - Fallback

    /// Builds a safe fallback request that always renders (blue cube + clarification prompt)
    private func buildFallbackRequest(concept: String?, color: RenderColor?) -> RenderRequest {
        RenderRequest(
            mode: .object3d,
            concept: concept ?? "figura",
            preset: nil,
            primitive: .cube,
            color: color ?? .blue,
            material: .matte,
            style: .diagram,
            size: .medium,
            camera: .default,
            lighting: .default,
            animation: .rotateSlow,
            labelText: nil,
            locale: "es"
        )
    }

    // MARK: - Metrics Logging

    private func logMetric(
        text: String,
        routerResult: RouterResult,
        catalogHit: Bool,
        extractedRequest: RenderMetricEntry.RequestSnapshot?,
        validationErrors: [String],
        finalRequest: RenderRequest,
        output: RenderOutput,
        startTime: CFAbsoluteTime
    ) {
        let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        let result: RenderMetricEntry.RenderResult
        if output.assetId.isEmpty {
            result = .failure(error: "No asset produced")
        } else if output.attachmentData == RenderOutput.fallback.attachmentData {
            result = .fallback(reason: "Used default fallback")
        } else {
            result = .success(assetId: output.assetId, mode: output.renderMode.rawValue)
        }

        let entry = RenderMetricEntry(
            id: UUID(),
            timestamp: Date(),
            userUtterance: text,
            routerDecision: .init(from: routerResult, catalogHit: catalogHit),
            extractedRequest: extractedRequest,
            validationErrors: validationErrors,
            finalRequest: .init(from: finalRequest),
            renderResult: result,
            durationMs: durationMs
        )

        RenderMetrics.log(entry)
    }

    // MARK: - Session Reset

    /// Resets the extraction session (call if context overflows)
    func resetExtractionSession() {
        extractionSession = nil
    }
}
