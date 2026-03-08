# Modelos de Datos (SwiftData)

## ChatMessage

```swift
@Model
class ChatMessage {
    var id: UUID
    var role: MessageRole          // .user | .assistant
    var content: String
    var timestamp: Date
    var subjectId: String
    var imageURLString: String?    // URL como String para SwiftData

    var imageURL: URL? {
        get { guard let s = imageURLString else { return nil }; return URL(string: s) }
        set { imageURLString = newValue?.absoluteString }
    }
    var hasImage: Bool { imageURLString != nil }
}

enum MessageRole: String, Codable { case user, assistant }
```

## UserSettings

```swift
@Model
final class UserSettings {
    var studentName: String
    var educationLevel: EducationLevel  // .primary, .secondary, .highSchool, .university
    var theme: AppTheme                 // .system, .light, .dark
    var notificationsEnabled: Bool
    var studyReminderEnabled: Bool
    var studyReminderTime: Date
    var dailyGoalMinutes: Int
    var soundsEnabled: Bool
    var hapticsEnabled: Bool
    var lastSubjectId: String?
}
```

## Subject (Enum, no persistido)

12 materias: `open`, `math`, `physics`, `chemistry`, `science`, `social`, `language`, `english`, `ethics`, `technology`, `arts`, `sports`

Propiedades: `displayName`, `icon` (SF Symbol), `color`, `hasSpecialKeyboard`, `supportsImages`

### Materias con imágenes (`supportsImages = true`)
open, science, social, language, english, arts, sports

### Sin imágenes
math, physics, chemistry, technology, ethics

## Imágenes generadas

Guardadas en: `Documents/GeneratedImages/nova_image_{UUID}.png`
Referenciadas desde `ChatMessage.imageURLString`.
