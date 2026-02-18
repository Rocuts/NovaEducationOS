import Foundation
import ImagePlayground
import os
import SwiftUI

/// State of image generation - defined at module level for accessibility
enum ImageGenerationState: Equatable {
    case idle
    case analyzing
    case generating(prompt: String)
    case completed(imageURL: URL)
    case failed(error: String)

    var isActive: Bool {
        switch self {
        case .analyzing, .generating, .completed, .failed:
            return true
        default:
            return false
        }
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var statusMessage: String {
        switch self {
        case .idle:
            return ""
        case .analyzing:
            return "Analizando si una imagen ayudaría..."
        case .generating:
            return "Generando imagen educativa..."
        case .completed:
            return "Imagen generada"
        case .failed(let error):
            return "Error: \(error)"
        }
    }
}

/// Service responsible for generating educational images using Apple's ImagePlayground framework
@Observable
@MainActor
final class ImageGeneratorService {
    private let logger = Logger(subsystem: "com.nova.education", category: "ImageGeneratorService")

    /// Type alias for backward compatibility
    typealias GenerationState = ImageGenerationState

    /// Current generation state
    var state: ImageGenerationState = .idle

    /// The ImagePlayground creator for programmatic generation
    private var imageCreator: ImageCreator?

    /// Whether ImagePlayground is available on this device
    var isAvailable: Bool {
        if #available(iOS 26, *) {
            // Check if creator is initialized or can be temporarily checked
            // If instance is available, check its styles
            if let creator = imageCreator {
                return !creator.availableStyles.isEmpty
            }
            // Fallback: Assume available if OS version matches (initialization will verify)
            return true
        }
        return false
    }



    /// Initialize the service and prepare the ImageCreator
    func initialize() async {
        guard imageCreator == nil else { return }

        if #available(iOS 26, *) {
            do {
                imageCreator = try await ImageCreator()
            } catch {
                logger.error("Failed to initialize ImageCreator")
            }
        }
    }

    /// Generates an educational image based on the provided prompt
    /// - Parameters:
    ///   - prompt: English description of the image to generate
    /// - Returns: URL to the saved image, or nil if generation failed
    func generateImage(
        prompt: String
    ) async -> URL? {
        guard #available(iOS 26, *) else {
            state = .failed(error: "Requiere iOS 26 o superior")
            return nil
        }

        // Ensure creator is initialized
        if imageCreator == nil {
            await initialize()
        }

        guard let creator = imageCreator else {
            state = .failed(error: "ImagePlayground no disponible")
            return nil
        }

        // Select style internally
        // PRIORITY: Illustration > Sketch > Animation (Avoid 3D/Animation if possible)
        let styles = creator.availableStyles
        
        let selectedStyle: ImagePlaygroundStyle
        if let illustration = styles.first(where: { $0 == .illustration }) {
            selectedStyle = illustration
        } else if let sketch = styles.first(where: { $0 == .sketch }) {
            selectedStyle = sketch
        } else if let first = styles.first {
            selectedStyle = first
        } else {
             state = .failed(error: "Estilo de imagen no disponible")
             return nil
        }

        state = .generating(prompt: prompt)

        do {
            // Create educational-focused concept
            // Force 2D styles by prompt engineering + style selection
            let educationalPrompt = "NO TEXT, NO LABELS. FLAT 2D ILLUSTRATION. Educational illustration for students: \(prompt). Clear, simple, and easy to understand."

            let concepts: [ImagePlaygroundConcept] = [
                .text(educationalPrompt)
            ]

            // Generate the image
            let imageStream = creator.images(
                for: concepts,
                style: selectedStyle,
                limit: 1
            )

            // Get the first generated image
            for try await generatedImage in imageStream {
                let cgImage = generatedImage.cgImage
                // Save to documents directory
                let url = try saveImage(cgImage)
                state = .completed(imageURL: url)
                return url
            }

            state = .failed(error: "No se pudo generar la imagen")
            return nil

        } catch {
            state = .failed(error: error.localizedDescription)
            return nil
        }
    }

    /// Saves a CGImage to the documents directory
    private func saveImage(_ cgImage: CGImage) throws -> URL {
        let uiImage = UIImage(cgImage: cgImage)

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

    /// Resets the generation state
    func reset() {
        state = .idle
    }

    /// Cleans up old generated images (optional maintenance)
    static func cleanupOldImages(olderThan days: Int = 7) {
        let directory = URL.documentsDirectory.appending(path: "GeneratedImages")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        for file in files {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

/// Errors specific to image generation
enum ImageGeneratorError: Error, LocalizedError {
    case notAvailable
    case failedToConvert
    case failedToSave

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "ImagePlayground no está disponible en este dispositivo"
        case .failedToConvert:
            return "No se pudo convertir la imagen"
        case .failedToSave:
            return "No se pudo guardar la imagen"
        }
    }
}
