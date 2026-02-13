import SwiftUI
import SwiftData

enum MessageRole: String, Codable {
    case user
    case assistant
}

@Model
class ChatMessage {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var subjectId: String

    /// Optional URL path to an associated generated image (stored as String for SwiftData compatibility)
    var imageURLString: String?

    /// Convenience computed property to get the image URL
    var imageURL: URL? {
        get {
            guard let filename = imageURLString else { return nil }
            // Check if it's already a full file URL (legacy support)
            if filename.hasPrefix("file://") {
                 return URL(string: filename)
            }
            // Construct full path from Documents directory
            return URL.documentsDirectory.appending(path: "GeneratedImages").appending(path: filename)
        }
        set {
            // Store only the filename/last component
            imageURLString = newValue?.lastPathComponent
        }
    }

    /// Whether this message has an associated image
    var hasImage: Bool {
        imageURLString != nil
    }

    init(role: MessageRole, content: String, subjectId: String, imageURL: URL? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.subjectId = subjectId
        self.imageURLString = imageURL?.absoluteString
    }
}
