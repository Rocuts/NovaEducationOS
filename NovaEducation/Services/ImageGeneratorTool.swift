import Foundation
import FoundationModels
import ImagePlayground
import os
import UIKit

/// Tool that allows the Foundation Model to generate educational images
/// The model will autonomously decide when to call this tool based on the conversation context
final class ImageGeneratorTool: Tool, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.nova.education", category: "ImageGenerator")

    /// Tool identifier - must be short and without spaces
    let name = "generateEducationalImage"
    let includesSchemaInInstructions = false

    typealias Output = String

    let description = "Generates an educational illustration for visual concepts like animals, plants, places, or planets."

    /// Categories that justify image generation - the model MUST choose one
    @Generable
    enum ImageCategory: String, CaseIterable {
        case animal      // Animals, insects, marine life
        case plant       // Plants, trees, flowers, ecosystems
        case place       // Countries, cities, landmarks, monuments
        case space       // Planets, stars, galaxies, astronomical objects
        case anatomy     // Organs, cells, body systems, biological structures
        case object      // Tools, instruments, equipment, physical objects
        case nature      // Landscapes, natural phenomena, weather
        case art         // Artworks, sculptures, artistic styles
    }

    @Generable
    struct Arguments {
        @Guide(description: "Content category")
        let category: ImageCategory

        @Guide(description: "English prompt for the image")
        let imagePrompt: String

        @Guide(description: "Reason in Spanish")
        let reasonForImage: String
    }

    /// Set once from @MainActor before any call() invocation
    nonisolated(unsafe) var onGenerationStarted: ((String) -> Void)?

    /// Set once from @MainActor before any call() invocation
    nonisolated(unsafe) var onImageGenerated: ((URL) -> Void)?

    /// Set once from @MainActor before any call() invocation
    nonisolated(unsafe) var onGenerationFailed: ((String) -> Void)?

    /// The ImagePlayground creator instance
    nonisolated(unsafe) private var imageCreator: ImageCreator?

    /// Initialize the tool
    init() {
        // ImageCreator will be initialized lazily when needed
    }

    /// Prepare the image creator (call this before using the tool)
    func prepare() async {
        if #available(iOS 26, *) {
            if imageCreator == nil {
                do {
                    imageCreator = try await ImageCreator()
                    logger.info("ImageCreator initialized successfully")
                } catch {
                    logger.error("Failed to initialize ImageCreator")
                }
            }
        }
    }

    /// Whether image generation is available on this device.
    /// Returns true if the OS supports ImagePlayground — the actual ImageCreator
    /// is initialized lazily inside call() so this check must NOT depend on it.
    var isAvailable: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }

    /// Called by the Foundation Model when it decides to generate an image
    func call(arguments: Arguments) async throws -> String {
        logger.debug("ImageGeneratorTool called")
        logger.debug("Image prompt: \(arguments.imagePrompt, privacy: .private)")

        // Notify that generation is starting
        await MainActor.run {
            onGenerationStarted?(arguments.reasonForImage)
        }

        // HEURISTIC: Check if the prompt is in Spanish
        // Framework throws "The language used in the concepts is not currently supported"
        let spanishIndicators = [" el ", " la ", " los ", " las ", " un ", " una ", " para ", " con ", " sobre ", " mostrar "]
        let lowerPrompt = arguments.imagePrompt.lowercased()
        let isLikelySpanish = spanishIndicators.contains { lowerPrompt.contains($0) } || lowerPrompt.hasPrefix("un ") || lowerPrompt.hasPrefix("una ")

        if isLikelySpanish {
             let errorMsg = "The imagePrompt MUST be in English. You provided: '\(arguments.imagePrompt)'. Please retry using the English translation."
             await MainActor.run {
                 onGenerationFailed?("Error: El prompt debe estar en inglés (Framework restriction)")
             }
             return "ERROR: \(errorMsg)"
        }

        guard #available(iOS 26, *) else {
            let error = "Requiere iOS 26 o superior"
            await MainActor.run {
                onGenerationFailed?(error)
            }
            return "No se pudo generar la imagen: \(error)"
        }

        // Reuse prepared creator or initialize if needed (synchronize via MainActor)
        let creator: ImageCreator
        let existingCreator = await MainActor.run { self.imageCreator }
        if let existing = existingCreator {
            creator = existing
        } else {
            do {
                let newCreator = try await ImageCreator()
                await MainActor.run { self.imageCreator = newCreator }
                creator = newCreator
            } catch {
                let errorMsg = "ImagePlayground no disponible"
                await MainActor.run {
                    onGenerationFailed?(errorMsg)
                }
                return "No se pudo generar la imagen: \(errorMsg)"
            }
        }

        // Generate the image
        do {
            // "NO TEXT" at the start is often more effective for attention mechanisms
            // Force 2D styles by prompt engineering + style selection
            let educationalPrompt = "NO TEXT, NO LABELS. FLAT 2D ILLUSTRATION. Just a clear educational illustration: \(arguments.imagePrompt). Visual only."

            let concepts: [ImagePlaygroundConcept] = [
                .text(educationalPrompt)
            ]

            let availableStyles = creator.availableStyles
            
            // PRIORITY: Illustration > Sketch > Animation (Avoid 3D/Animation if possible to prevent "I" artifact)
            let selectedStyle: ImagePlaygroundStyle
            if let illustration = availableStyles.first(where: { $0 == .illustration }) {
                selectedStyle = illustration
            } else if let sketch = availableStyles.first(where: { $0 == .sketch }) {
                selectedStyle = sketch
            } else if let first = availableStyles.first {
                selectedStyle = first
                logger.warning("Preferred styles (Illustration/Sketch) not available, using fallback")
            } else {
                 return "Error: No se encontró un estilo de imagen válido"
            }

            let imageStream = creator.images(
                for: concepts,
                style: selectedStyle,
                limit: 1
            )

            for try await generatedImage in imageStream {
                let cgImage = generatedImage.cgImage
                let url = try await saveImage(cgImage)

                await MainActor.run {
                    onImageGenerated?(url)
                }

                return "Image created."
            }

            await MainActor.run {
                onGenerationFailed?("No se generó ninguna imagen")
            }
            return "No se pudo generar la imagen"

        } catch {
            let errorMsg = error.localizedDescription
            await MainActor.run {
                onGenerationFailed?(errorMsg)
            }
            return "Error al generar imagen: \(errorMsg)"
        }
    }

    /// Saves a CGImage to the documents directory
    private func saveImage(_ cgImage: CGImage) async throws -> URL {
        let uiImage = await MainActor.run {
            UIImage(cgImage: cgImage)
        }

        guard let data = uiImage.pngData() else {
            throw ImageGeneratorError.failedToConvert
        }

        let filename = "nova_image_\(UUID().uuidString).png"
        let url = URL.documentsDirectory.appending(path: "GeneratedImages/\(filename)")

        // Create directory if needed
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Write file
        try data.write(to: url)

        return url
    }
}
