# Arquitectura del Proyecto

## Estructura de Carpetas

```
NovaEducation/
├── App/                        # Entry point, SwiftData container
├── Models/                     # SwiftData models (ChatMessage, UserSettings, Subject, Achievement, StudySession, DailyActivity)
├── ViewModels/                 # @Observable ViewModels (ChatViewModel)
├── Views/                      # SwiftUI Views (HomeView, ChatView, SettingsView)
│   └── Components/             # MessageBubble, MarkdownTextView, SubjectCard, etc.
├── Services/                   # FoundationModelService, ImageGeneratorTool, ContentSafetyService, Speech, TTS
├── Utilities/                  # Extensiones y helpers
├── Resources/                  # Recursos estáticos
└── Assets.xcassets/
```

## Patrón MVVM + Services

```
VIEW (SwiftUI, bindings reactivos, sin lógica de negocio)
  ↓
VIEWMODEL (@Observable, gestiona estado UI, coordina services)
  ↓
SERVICES (FoundationModelService, ContentSafetyService, NotificationManager)
  ↓
MODELS (SwiftData, @Model, persistencia automática)
```

## Convenciones de Código

### Nombrado
- Clases/Structs: `PascalCase` → `ChatMessage`, `FoundationModelService`
- Variables/funciones: `camelCase` → `isLoading`, `sendMessage()`
- Constantes: `camelCase` o `SCREAMING_SNAKE_CASE` → `maxMessageLength`, `API_TIMEOUT`
- Enums: `PascalCase` con casos `camelCase` → `MessageRole.user`

### Organización de Archivos Swift

```swift
import SwiftUI
import SwiftData

// MARK: - Definition
struct MyView: View {
    // MARK: - Properties
    // MARK: - Body
    // MARK: - Subviews
    // MARK: - Methods
}

// MARK: - Preview
```

### Orden de Modificadores SwiftUI

1. Contenido y layout (font, foregroundStyle, padding, frame)
2. Background y efectos visuales (background, glassEffect)
3. Forma y bordes (clipShape, overlay)
4. Sombras y efectos (shadow)
5. Animaciones (animation)
6. Gestos e interacciones (onTapGesture)
7. Lifecycle (onAppear, task)

## Patrón Singleton para Managers

```swift
final class AchievementManager {
    static let shared = AchievementManager()
    private init() { }
}
```
