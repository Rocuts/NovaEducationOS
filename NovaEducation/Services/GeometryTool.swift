import Foundation
import FoundationModels

final class GeometryTool: Tool, @unchecked Sendable {
    let name = "generate3DGeometry"
    let includesSchemaInInstructions = false
    let description = "Generates a 3D shape visualization."

    typealias Output = String

    @Generable
    enum ShapeType: String, CaseIterable {
        case sphere
        case cube
        case cylinder
        case pyramid
        case torus
        case cone
        case capsule
    }

    @Generable
    enum AnimationType: String, CaseIterable {
        case none
        case rotate
        case pulse
        case bounce
    }

    @Generable
    struct Arguments {
        @Guide(description: "Shape")
        let shape: ShapeType

        @Guide(description: "Color name")
        let color: String

        @Guide(description: "0.5 to 2.0")
        let scale: Double?

        @Guide(description: "Animation")
        let animation: AnimationType?

        @Guide(description: "Caption")
        let caption: String?
    }

    /// Set once from @MainActor before any call() invocation. Read in call() via MainActor.run.
    nonisolated(unsafe) var onGeometryGenerated: ((_ attachmentData: String) -> Void)?

    func call(arguments: Arguments) async throws -> String {
        // Construct the JSON configuration for the view
        let config: [String: Any] = [
            "shape": arguments.shape.rawValue,
            "color": arguments.color,
            "scale": arguments.scale ?? 1.0,
            "animation": arguments.animation?.rawValue ?? "none",
            "caption": arguments.caption ?? ""
        ]
        
        // Serialize to JSON string
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw GeometryToolError.encodingFailed
        }
        
        // Notify listener (FoundationModelService) to attach this to the message
        await MainActor.run {
            onGeometryGenerated?(jsonString)
        }
        
        return "Shape rendered."
    }
}

enum GeometryToolError: Error {
    case encodingFailed
}
