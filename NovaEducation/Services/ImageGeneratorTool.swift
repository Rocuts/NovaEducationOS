import UIKit
import FoundationModels
import ImagePlayground

/// Tool that allows the AI to generate educational images to help students visualize concepts.
/// Uses Apple's ImagePlayground framework (ImageCreator) for on-device image generation.
///
/// Thread safety: `@unchecked Sendable` is justified because all mutable state (callbacks)
/// is protected by an NSLock. Callbacks are set once from @MainActor before any `call()`
/// invocation, and read inside `call()` under the lock before being dispatched on MainActor.
final class ImageGeneratorTool: Tool, @unchecked Sendable {
    let name = "generateEducationalImage"
    let includesSchemaInInstructions = false

    typealias Output = String

    let description = """
    Generates an educational illustration to help the student visualize a concept. \
    Use when explaining visual topics like: animals, plants, planets, monuments, landscapes, historical scenes, artwork. \
    Do NOT use for abstract concepts, math formulas, or grammar rules.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Descriptive prompt in English for the image")
        let imagePrompt: String

        @Guide(description: "Brief reason in Spanish why this image helps the student")
        let reasonForImage: String
    }

    // MARK: - Thread-safe Callback Storage

    private let _lock = NSLock()
    private var _onGenerationStarted: (@Sendable (String) -> Void)?
    private var _onImageGenerated: (@Sendable (URL) -> Void)?
    private var _onGenerationFailed: (@Sendable (String) -> Void)?

    /// Set once from @MainActor before any call() invocation.
    var onGenerationStarted: (@Sendable (String) -> Void)? {
        get { _lock.withLock { _onGenerationStarted } }
        set { _lock.withLock { _onGenerationStarted = newValue } }
    }

    /// Called when image has been generated and saved to disk
    var onImageGenerated: (@Sendable (URL) -> Void)? {
        get { _lock.withLock { _onImageGenerated } }
        set { _lock.withLock { _onImageGenerated = newValue } }
    }

    /// Called when generation fails
    var onGenerationFailed: (@Sendable (String) -> Void)? {
        get { _lock.withLock { _onGenerationFailed } }
        set { _lock.withLock { _onGenerationFailed = newValue } }
    }

    // MARK: - Tool Implementation

    func call(arguments: Arguments) async throws -> String {
        // 1. Notify UI that generation started
        await MainActor.run {
            onGenerationStarted?(arguments.reasonForImage)
        }

        do {
            // 2. Generate image using ImagePlayground (ImageCreator)
            let creator = try await ImageCreator()

            let images = creator.images(
                for: [.text(arguments.imagePrompt)],
                style: .illustration,
                limit: 1
            )

            var generatedCGImage: CGImage?
            for try await image in images {
                generatedCGImage = image.cgImage
                break // We only need the first image
            }

            guard let cgImage = generatedCGImage else {
                await MainActor.run {
                    onGenerationFailed?("No se pudo generar la imagen.")
                }
                return "Image generation produced no results."
            }

            // 3. Save image to Documents/GeneratedImages/
            let imageURL = try saveImage(cgImage)

            // 4. Notify UI with the saved URL
            await MainActor.run {
                onImageGenerated?(imageURL)
            }

            return "Imagen educativa generada: \(arguments.reasonForImage)"

        } catch {
            let errorMessage = "Error al generar imagen: \(error.localizedDescription)"
            await MainActor.run {
                onGenerationFailed?(errorMessage)
            }
            return "Image generation failed. Continue explaining the topic with text only."
        }
    }

    // MARK: - Image Storage

    /// Saves a CGImage to the GeneratedImages directory and returns the file URL
    private func saveImage(_ cgImage: CGImage) throws -> URL {
        // Enforce maximum dimensions (2048x2048) to avoid OOM
        let maxDimension: CGFloat = 2048.0
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        var finalCGImage = cgImage

        if originalWidth > maxDimension || originalHeight > maxDimension {
            let scale = min(maxDimension / originalWidth, maxDimension / originalHeight)
            let newWidth = Int(originalWidth * scale)
            let newHeight = Int(originalHeight * scale)

            let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0, // Auto compute
                space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: cgImage.bitmapInfo.rawValue
            )

            context?.interpolationQuality = .high
            if let context = context {
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                if let scaledImage = context.makeImage() {
                    finalCGImage = scaledImage
                }
            }
        }

        let uiImage = UIImage(cgImage: finalCGImage)
        guard let pngData = uiImage.pngData() else {
            throw ImageGeneratorError.encodingFailed
        }

        // Validate available disk space (require at least 50MB)
        do {
            let values = try URL.documentsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let available = values.volumeAvailableCapacityForImportantUsage, available < 50_000_000 {
                throw ImageGeneratorError.insufficientDiskSpace
            }
        } catch {
            // Ignore if we can't read resource values, let it try to write
        }

        // Ensure GeneratedImages directory exists
        let imagesDir = URL.documentsDirectory.appending(path: "GeneratedImages")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // Save with unique filename
        let filename = "nova_image_\(UUID().uuidString).png"
        let fileURL = imagesDir.appending(path: filename)
        try pngData.write(to: fileURL, options: .completeFileProtection)

        return fileURL
    }
}

// MARK: - Errors

enum ImageGeneratorError: Error {
    case encodingFailed
    case saveFailed
    case insufficientDiskSpace
}
