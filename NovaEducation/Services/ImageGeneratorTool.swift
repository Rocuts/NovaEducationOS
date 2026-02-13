import Foundation
import FoundationModels
import ImagePlayground
import UIKit

/// Tool that allows the Foundation Model to generate educational images
/// The model will autonomously decide when to call this tool based on the conversation context
final class ImageGeneratorTool: Tool, @unchecked Sendable {
    /// Tool identifier - must be short and without spaces
    let name = "generateEducationalImage"

    typealias Output = String

    /// Description that helps the model understand when to use this tool
    /// Apple recommends: "One sentence maximum - longer descriptions add tokens and increase latency"
    let description = "Generates an educational illustration of animals, plants, places, landmarks, planets, or anatomy to help visualize physical concepts."

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

    /// Arguments the model will provide when calling this tool
    @Generable
    struct Arguments {
        @Guide(description: "Category of visual content being illustrated")
        let category: ImageCategory

        @Guide(description: "Image description in English only")
        let imagePrompt: String

        @Guide(description: "Brief reason in Spanish (max 8 words)")
        let reasonForImage: String
    }

    /// Callback to notify when an image is being generated
    var onGenerationStarted: ((String) -> Void)?

    /// Callback to deliver the generated image URL
    var onImageGenerated: ((URL) -> Void)?

    /// Callback for generation errors
    var onGenerationFailed: ((String) -> Void)?

    /// The ImagePlayground creator instance
    private var imageCreator: ImageCreator?

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
                    print("✅ ImageCreator initialized successfully")
                } catch {
                    print("❌ Failed to initialize ImageCreator: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Whether image generation is available on this device
    var isAvailable: Bool {
        if #available(iOS 26, *) {
             if let creator = imageCreator {
                return !creator.availableStyles.isEmpty
            }
            // If we are on iOS 26, we assume it SHOULD be available.
            // Returning true encourages the service to try using it.
            return true 
        }
        return false
    }

    /// Called by the Foundation Model when it decides to generate an image
    func call(arguments: Arguments) async throws -> String {
        print("🖼️ ImageGeneratorTool called - Category: \(arguments.category.rawValue)")
        print("🖼️ Prompt: \(arguments.imagePrompt)")

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

        // Initialize creator if needed
        let creator: ImageCreator
        do {
            creator = try await ImageCreator()
        } catch {
            let errorMsg = "ImagePlayground no disponible"
            await MainActor.run {
                onGenerationFailed?(errorMsg)
            }
            return "No se pudo generar la imagen: \(errorMsg)"
        }

        // Generate the image
        do {
            // "NO TEXT" at the start is often more effective for attention mechanisms
            let educationalPrompt = "NO TEXT, NO LABELS. Just a clear educational illustration: \(arguments.imagePrompt). Visual only."

            let concepts: [ImagePlaygroundConcept] = [
                .text(educationalPrompt)
            ]

            let availableStyles = creator.availableStyles
            guard let style = availableStyles.first else {
                return "Error: No se encontró un estilo de imagen válido"
            }

            let imageStream = creator.images(
                for: concepts,
                style: style,
                limit: 1
            )

            for try await generatedImage in imageStream {
                let cgImage = generatedImage.cgImage
                let url = try await saveImage(cgImage)

                await MainActor.run {
                    onImageGenerated?(url)
                }

                return "Imagen generada exitosamente: \(arguments.reasonForImage)"
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
