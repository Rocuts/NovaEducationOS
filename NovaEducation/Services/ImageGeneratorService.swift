import Foundation

/// Lightweight state container for image generation UI feedback.
/// Used by FoundationModelService and ChatViewModel to track generation progress.
enum ImageGeneratorService {

    enum GenerationState: Equatable {
        case idle
        case generating(reason: String)
        case completed(imageURL: URL)
        case failed(error: String)

        var isActive: Bool {
            if case .generating = self { return true }
            return false
        }

        var statusMessage: String {
            switch self {
            case .idle:
                return ""
            case .generating(let reason):
                return reason
            case .completed:
                return "Imagen lista"
            case .failed(let error):
                return error
            }
        }
    }
}
