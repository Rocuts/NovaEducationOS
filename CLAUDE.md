# CLAUDE.md - NovaEducation Development Guide

> Este documento define las directrices, convenciones y mejores prácticas para el desarrollo de NovaEducation. Claude debe seguir estas instrucciones en cada interacción.

---

## 1. VISIÓN GENERAL DEL PROYECTO

**NovaEducation** es una aplicación educativa iOS que utiliza Apple Intelligence para proporcionar tutoría personalizada en 12 materias académicas. La app está diseñada para estudiantes hispanohablantes y utiliza el framework Foundation Models de Apple para generar respuestas educativas contextualizadas.

### Stack Tecnológico
- **Lenguaje:** Swift 6.0+
- **UI Framework:** SwiftUI (iOS 26+)
- **Persistencia:** SwiftData
- **AI:** Apple Foundation Models (on-device)
- **Mínimo Deployment:** iOS 26.0
- **Arquitectura:** MVVM + Services

---

## 2. iOS 26 Y LIQUID GLASS - DIRECTRICES DE DISEÑO

### 2.1 ¿Qué es Liquid Glass?

Liquid Glass es el nuevo sistema de diseño de Apple introducido en WWDC 2025. Es un material adaptativo que combina las propiedades ópticas del vidrio (refracción, reflexión, efecto lente) con la fluidez del líquido (animaciones dinámicas, interfaces que se transforman).

### 2.2 Principios de Diseño Liquid Glass

#### Jerarquía
- Los controles Liquid Glass flotan sobre el contenido como una capa funcional distinta
- Crea profundidad mientras reduce la complejidad visual
- El contenido está en la base, los controles de vidrio flotan encima

#### Armonía
- El diseño balancea hardware, contenido y controles
- Las formas del dispositivo informan el diseño de elementos UI
- Formas redondeadas que siguen patrones naturales de tacto

#### Consistencia
- Diseño universal que simplifica el desarrollo cross-platform
- Mantiene coherencia entre diferentes tamaños de pantalla

### 2.3 Uso Correcto de Liquid Glass

**USAR Liquid Glass para:**
```swift
// ✅ Barras de navegación y toolbars
.toolbarBackgroundVisibility(.visible, for: .navigationBar)

// ✅ Tab bars y bottom accessories
TabView { }
    .tabBarMinimizeBehavior(.onScrollDown)

// ✅ Botones de acción flotantes
Button { } label: { }
    .glassEffect(.regular)

// ✅ Sheets, popovers y menús
.sheet(isPresented: $showSheet) { }

// ✅ Controles de navegación personalizados
HStack { }
    .glassEffect(.regular, in: .capsule)
```

**NO USAR Liquid Glass para:**
```swift
// ❌ Capa de contenido (listas, tablas, media)
List { }  // NO aplicar glassEffect a listas completas

// ❌ Fondos de pantalla completa
ZStack { }
    .glassEffect()  // NO usar como fondo

// ❌ Contenido scrolleable
ScrollView { }  // NO aplicar glass al contenido

// ❌ Capas de vidrio apiladas
// Evitar múltiples efectos glass superpuestos
```

### 2.4 GlassEffectContainer - Agrupación de Elementos

Siempre agrupar elementos Liquid Glass relacionados en un container:

```swift
// ✅ CORRECTO: Elementos agrupados en container
GlassEffectContainer(spacing: 40.0) {
    Button("Acción 1") { }
        .glassEffect(.regular)

    Button("Acción 2") { }
        .glassEffect(.regular)
}

// ❌ INCORRECTO: Elementos glass sin container
VStack {
    Button("Acción 1") { }.glassEffect(.regular)
    Button("Acción 2") { }.glassEffect(.regular)
}
```

### 2.5 glassEffectID para Animaciones de Morphing

Usar `glassEffectID` para transiciones suaves entre estados:

```swift
@Namespace private var glassNamespace

// Estado colapsado
Button("Expandir") { }
    .glassEffect(.regular)
    .glassEffectID("actionButton", in: glassNamespace)

// Estado expandido
HStack {
    Button("Opción A") { }
    Button("Opción B") { }
}
.glassEffect(.regular)
.glassEffectID("actionButton", in: glassNamespace)
```

### 2.6 Tab Bar iOS 26 - Nuevas APIs

```swift
TabView(selection: $selectedTab) {
    Tab("Inicio", systemImage: "house.fill", value: .home) {
        HomeView()
    }

    Tab("Buscar", systemImage: "magnifyingglass", value: .search, role: .search) {
        SearchView()
    }

    Tab("Ajustes", systemImage: "gear", value: .settings) {
        SettingsView()
    }
}
.tabBarMinimizeBehavior(.onScrollDown)  // Minimiza al hacer scroll
.tabViewBottomAccessory {               // Accesorio sobre el tab bar
    MiniPlayerView()
}
```

**Comportamientos de minimización disponibles:**
- `.automatic` - Sistema decide según contexto
- `.never` - Tab bar siempre visible
- `.onScrollDown` - Minimiza al hacer scroll hacia abajo

---

## 3. SWIFTUI iOS 26 - NUEVAS CARACTERÍSTICAS

### 3.1 Mejoras de Rendimiento

iOS 26 reconstruyó el pipeline de renderizado de SwiftUI:
- GPU: reducción del 40% en uso
- Tiempo de render: 39% más rápido
- Memoria: 38% menos uso

### 3.2 Nuevos Componentes

```swift
// WebView nativo en SwiftUI
WebView(url: URL(string: "https://example.com")!)

// Rich Text Editing
TextEditor(text: $richText)
    .textEditorStyle(.richText)

// Section Index en listas
List {
    ForEach(sections) { section in
        Section(section.title) {
            ForEach(section.items) { item in
                Text(item.name)
            }
        }
        .listSectionIndexTitle(section.indexTitle)
    }
}

// SubscriptionOfferView para in-app purchases
SubscriptionOfferView(groupID: "premium_subscription")
```

### 3.3 iPadOS 26 - Barra de Menú

```swift
// Los comandos ahora crean menú bar en iPad
.commands {
    CommandMenu("Archivo") {
        Button("Nuevo") { }
        Button("Abrir") { }
    }
}
```

### 3.4 Detección Automática de Dirección de Texto

```swift
Text(localizedString)
    .writingDirection(.automatic)  // Detecta RTL/LTR automáticamente

TextEditor(text: $content)
    .writingDirection(.automatic)
```

---

## 4. ARQUITECTURA DEL PROYECTO

### 4.1 Estructura de Carpetas

```
NovaEducation/
├── App/
│   └── NovaEducationApp.swift      # Entry point, SwiftData container
├── Models/
│   ├── ChatMessage.swift           # Mensajes de chat (SwiftData)
│   ├── UserSettings.swift          # Configuración de usuario
│   ├── Subject.swift               # Enum de materias
│   ├── Achievement.swift           # Sistema de logros
│   ├── StudySession.swift          # Sesiones de estudio
│   └── DailyActivity.swift         # Tracking de actividad diaria
├── ViewModels/
│   └── ChatViewModel.swift         # Lógica de chat con @Observable
├── Views/
│   ├── MainTabView.swift           # Navegación principal
│   ├── HomeView.swift              # Vista de inicio/materias
│   ├── ChatView.swift              # Interfaz de chat
│   ├── SettingsView.swift          # Configuración
│   └── Components/
│       ├── MessageBubble.swift         # Burbujas de mensaje (con soporte de imágenes)
│       ├── ChatHeaderView.swift        # Header del chat
│       ├── SubjectCard.swift           # Cards de materias
│       ├── MarkdownTextView.swift      # Render de Markdown/LaTeX
│       ├── ImageGenerationBanner.swift # Banner de estado de generación de imágenes
│       └── SubjectKeyboardToolbar.swift
├── Services/
│   ├── FoundationModelService.swift    # Apple Intelligence + Tool Calling
│   ├── ImageGeneratorTool.swift        # Tool para generar imágenes (Tool protocol)
│   ├── ImageGeneratorService.swift     # Estados y tipos de generación
│   ├── ContentSafetyService.swift      # Validación de seguridad
│   ├── AchievementManager.swift        # Gestión de logros
│   ├── NotificationManager.swift       # Notificaciones push
│   ├── SpeechRecognitionService.swift  # Speech-to-text
│   └── TextToSpeechService.swift       # Text-to-speech
├── Utilities/                      # Extensiones y helpers
├── Resources/                      # Recursos estáticos
└── Assets.xcassets/               # Imágenes y colores
```

### 4.2 Patrón MVVM + Services

```
┌─────────────────────────────────────────────────────────┐
│                        VIEW                              │
│  (SwiftUI Views - Declarative UI)                       │
│  • Bindings reactivos con @Observable                   │
│  • Sin lógica de negocio                                │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                    VIEWMODEL                             │
│  (@Observable - State Management)                        │
│  • Gestiona estado de la UI                             │
│  • Coordina entre View y Services                       │
│  • Maneja acciones del usuario                          │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                    SERVICES                              │
│  (Business Logic & External APIs)                        │
│  • FoundationModelService - AI                          │
│  • ContentSafetyService - Seguridad                     │
│  • NotificationManager - Notificaciones                 │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                     MODELS                               │
│  (SwiftData - Data Persistence)                          │
│  • @Model para persistencia automática                  │
│  • Relationships manejadas por SwiftData                │
└─────────────────────────────────────────────────────────┘
```

### 4.3 Convenciones de Código

#### Nombrado
```swift
// Clases y Structs: PascalCase
struct ChatMessage { }
class FoundationModelService { }

// Variables y funciones: camelCase
var isLoading: Bool
func sendMessage() { }

// Constantes globales: camelCase o SCREAMING_SNAKE_CASE para valores fijos
let maxMessageLength = 4000
let API_TIMEOUT = 30.0

// Enums: PascalCase con casos en camelCase
enum MessageRole {
    case user
    case assistant
}
```

#### Organización de Archivos Swift
```swift
import SwiftUI
import SwiftData

// MARK: - Model/View/ViewModel Definition
struct MyView: View {

    // MARK: - Properties
    @State private var isLoading = false
    @Environment(\.modelContext) private var modelContext

    // MARK: - Body
    var body: some View {
        // ...
    }

    // MARK: - Subviews
    private var headerView: some View {
        // ...
    }

    // MARK: - Methods
    private func loadData() {
        // ...
    }
}

// MARK: - Preview
#Preview {
    MyView()
}
```

#### Modificadores SwiftUI - Orden Recomendado
```swift
Text("Hello")
    // 1. Contenido y layout
    .font(.headline)
    .foregroundStyle(.primary)
    .padding()
    .frame(maxWidth: .infinity)

    // 2. Background y efectos visuales
    .background(.regularMaterial)
    .glassEffect(.regular)

    // 3. Forma y bordes
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay { }

    // 4. Sombras y efectos
    .shadow(radius: 4)

    // 5. Animaciones
    .animation(.spring, value: isExpanded)

    // 6. Gestos e interacciones
    .onTapGesture { }

    // 7. Lifecycle
    .onAppear { }
    .task { }
```

---

## 5. MODELOS DE DATOS (SWIFTDATA)

### 5.1 ChatMessage

```swift
@Model
class ChatMessage {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var subjectId: String

    /// URL de imagen generada (String para compatibilidad con SwiftData)
    var imageURLString: String?

    /// Computed property para acceder a la URL
    var imageURL: URL? {
        get { guard let s = imageURLString else { return nil }; return URL(string: s) }
        set { imageURLString = newValue?.absoluteString }
    }

    /// Indica si el mensaje tiene imagen asociada
    var hasImage: Bool { imageURLString != nil }

    init(role: MessageRole, content: String, subjectId: String, imageURL: URL? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.subjectId = subjectId
        self.imageURLString = imageURL?.absoluteString
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}
```

### 5.2 UserSettings

```swift
@Model
final class UserSettings {
    var studentName: String
    var educationLevel: EducationLevel
    var theme: AppTheme
    var notificationsEnabled: Bool
    var studyReminderEnabled: Bool
    var studyReminderTime: Date
    var dailyGoalMinutes: Int
    var soundsEnabled: Bool
    var hapticsEnabled: Bool
    var lastSubjectId: String?
}

enum EducationLevel: String, Codable, CaseIterable {
    case primary = "Primaria"
    case secondary = "Secundaria"
    case highSchool = "Preparatoria"
    case university = "Universidad"
}

enum AppTheme: String, Codable, CaseIterable {
    case system = "Sistema"
    case light = "Claro"
    case dark = "Oscuro"
}
```

### 5.3 Subject (Enum - No persistido)

```swift
enum Subject: String, CaseIterable, Identifiable {
    case open = "abierta"
    case math = "matematicas"
    case physics = "fisica"
    case chemistry = "quimica"
    case science = "ciencias"
    case social = "sociales"
    case language = "lenguaje"
    case english = "ingles"
    case ethics = "etica"
    case technology = "tecnologia"
    case arts = "artes"
    case sports = "deportes"

    var id: String { rawValue }

    var displayName: String { /* ... */ }
    var icon: String { /* SF Symbol */ }
    var color: Color { /* ... */ }
    var hasSpecialKeyboard: Bool { /* math, physics, chemistry */ }

    /// Indica si la materia se beneficia de imágenes generadas por IA
    var supportsImages: Bool {
        switch self {
        case .open, .science, .social, .language, .english, .arts, .sports:
            return true  // Contenido visual ayuda al estudiante
        case .math, .physics, .chemistry, .technology, .ethics:
            return false // Requieren precisión o son abstractas
        }
    }
}
```

---

## 6. SERVICIOS

### 6.1 FoundationModelService - Apple Intelligence con Tool Calling

El servicio principal que gestiona la interacción con Foundation Models, incluyendo generación de texto y llamadas a herramientas (Tool Calling).

```swift
@Observable
@MainActor
class FoundationModelService {
    private var session: LanguageModelSession?
    private var imageTool: ImageGeneratorTool?

    /// Estado de generación de imágenes para UI
    var imageGenerationState: ImageGeneratorService.GenerationState = .idle
    var generatedImageURL: URL?

    // Crear sesión con o sin herramientas según la materia
    func createSession(for subject: Subject) {
        let systemPrompt = getSystemPrompt(for: subject)

        if subject.supportsImages {
            // Sesión con herramienta de imágenes
            let tool = ImageGeneratorTool()
            tool.onGenerationStarted = { reason in /* UI feedback */ }
            tool.onImageGenerated = { url in /* Guardar URL */ }
            tool.onGenerationFailed = { error in /* Manejar error */ }

            session = LanguageModelSession(tools: [tool]) {
                systemPrompt
            }
        } else {
            // Sesión sin herramientas
            session = LanguageModelSession {
                systemPrompt
            }
        }
    }

    // Streaming con soporte automático de Tool Calling
    func streamResponse(prompt: String, history: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}
```

**Directrices para System Prompts:**
- Incluir nivel educativo del estudiante
- Especificar idioma (español)
- Definir personalidad del tutor por materia
- Incluir instrucciones para LaTeX si aplica
- Establecer límites de seguridad
- **Incluir instrucciones de uso de herramientas** si `subject.supportsImages`

### 6.2 ContentSafetyService

```swift
final class ContentSafetyService {
    enum ValidationResult {
        case safe
        case unsafe(reason: String)
    }

    func validate(_ content: String) -> ValidationResult {
        // Verificar PII (información personal)
        // Detectar contenido dañino
        // Identificar intentos de jailbreak
        return .safe
    }
}
```

### 6.3 Patrón Singleton para Managers

```swift
final class AchievementManager {
    static let shared = AchievementManager()
    private init() { }

    func checkAchievements(context: ModelContext) {
        // Verificar condiciones de desbloqueo
    }
}

final class NotificationManager {
    static let shared = NotificationManager()
    private init() { }

    func scheduleStudyReminder(at time: Date) {
        // Programar notificación diaria
    }
}
```

### 6.4 Sistema de Generación de Imágenes con Tool Calling

NovaEducation utiliza **Tool Calling** de Foundation Models para generar imágenes educativas de forma inteligente. El modelo decide autónomamente cuándo una imagen ayudaría al estudiante.

#### 6.4.1 Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│         FoundationModelService                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │  LanguageModelSession(tools: [ImageGeneratorTool])│   │
│  │                                                   │   │
│  │  El modelo decide autónomamente si llamar        │   │
│  │  a generateEducationalImage durante la respuesta │   │
│  └─────────────────────────────────────────────────┘   │
└──────────────────────┬──────────────────────────────────┘
                       │ Tool Call (si decide generar)
                       ▼
┌─────────────────────────────────────────────────────────┐
│         ImageGeneratorTool                               │
│  • Recibe: imagePrompt (inglés), reasonForImage         │
│  • Usa: ImagePlayground (ImageCreator)                  │
│  • Retorna: URL de imagen guardada                      │
│  • Callbacks: onGenerationStarted, onImageGenerated     │
└─────────────────────────────────────────────────────────┘
```

#### 6.4.2 ImageGeneratorTool

Implementa el protocolo `Tool` de Foundation Models:

```swift
final class ImageGeneratorTool: Tool {
    let name = "generateEducationalImage"
    let description = """
    Generates an educational illustration to help the student visualize a concept.
    Use when explaining visual topics like: animals, plants, planets, monuments...
    Do NOT use for abstract concepts, math formulas, or grammar rules.
    """

    @Generable
    struct Arguments {
        @Guide(description: "Descriptive prompt in English for the image")
        let imagePrompt: String

        @Guide(description: "Brief reason in Spanish why this image helps")
        let reasonForImage: String
    }

    // Callbacks para actualizar UI
    var onGenerationStarted: ((String) -> Void)?
    var onImageGenerated: ((URL) -> Void)?
    var onGenerationFailed: ((String) -> Void)?

    nonisolated func call(arguments: Arguments) async throws -> ToolOutput {
        // 1. Notificar inicio de generación
        // 2. Crear imagen con ImagePlayground
        // 3. Guardar en Documents/GeneratedImages/
        // 4. Notificar completado o error
        return ToolOutput("Imagen generada: \(arguments.reasonForImage)")
    }
}
```

#### 6.4.3 Materias con Soporte de Imágenes

La propiedad `Subject.supportsImages` determina qué materias tienen acceso a generación de imágenes:

```swift
var supportsImages: Bool {
    switch self {
    case .open, .science, .social, .language, .english, .arts, .sports:
        return true  // Contenido visual beneficia al estudiante
    case .math, .physics, .chemistry, .technology, .ethics:
        return false // Requieren diagramas precisos o son abstractas
    }
}
```

| ✅ Con imágenes | ❌ Sin imágenes |
|-----------------|-----------------|
| Chat Abierto | Matemáticas |
| Ciencias Naturales | Física |
| Ciencias Sociales | Química |
| Lenguaje | Tecnología |
| Inglés | Ética |
| Artes | |
| Deportes | |

#### 6.4.4 Instrucciones en System Prompt

Para materias con `supportsImages = true`, se agrega al system prompt:

```swift
"""
*** GENERACION DE IMAGENES ***
Tienes acceso a una herramienta para generar imagenes educativas.
USA la herramienta generateEducationalImage cuando:
- El estudiante pregunte sobre algo visual (animales, plantas, planetas, monumentos, etc.)
- Una imagen ayudaria a entender mejor el concepto
- El tema involucra objetos fisicos, lugares, o seres vivos

NO uses la herramienta cuando:
- El tema es abstracto o conceptual
- Es una pregunta simple de si/no
- El estudiante solo saluda o hace preguntas generales

Cuando generes una imagen, menciona brevemente que has creado una ilustracion.
"""
```

#### 6.4.5 Estados de Generación

```swift
enum GenerationState: Equatable {
    case idle                           // Sin actividad
    case analyzing                      // (Deprecated - Tool Calling es directo)
    case generating(prompt: String)     // Generando imagen
    case completed(imageURL: URL)       // Imagen lista
    case failed(error: String)          // Error

    var isActive: Bool { /* .generating */ }
    var statusMessage: String { /* Para UI */ }
}
```

#### 6.4.6 Flujo Completo

```
1. Usuario: "¿Qué es Saturno?"
              ↓
2. FoundationModel procesa con ImageGeneratorTool disponible
              ↓
3. Modelo genera texto: "Saturno es el sexto planeta..."
   Y decide llamar: generateEducationalImage(
       imagePrompt: "Planet Saturn with its rings in space",
       reasonForImage: "Para visualizar el planeta y sus anillos"
   )
              ↓
4. ImageGeneratorTool.call() ejecuta:
   - onGenerationStarted("Para visualizar...")  → Banner aparece
   - ImageCreator genera imagen
   - Guarda en Documents/GeneratedImages/
   - onImageGenerated(url)  → Imagen asociada al mensaje
              ↓
5. ChatMessage.imageURL = url
              ↓
6. MessageBubble muestra texto + imagen
```

#### 6.4.7 Almacenamiento de Imágenes

```swift
// ChatMessage con soporte de imágenes
@Model
class ChatMessage {
    var imageURLString: String?  // SwiftData compatible

    var imageURL: URL? {
        get { URL(string: imageURLString ?? "") }
        set { imageURLString = newValue?.absoluteString }
    }

    var hasImage: Bool { imageURLString != nil }
}

// Imágenes guardadas en:
// Documents/GeneratedImages/nova_image_{UUID}.png
```

#### 6.4.8 Componentes UI

**ImageGenerationBanner** - Muestra estado de generación:
```swift
ImageGenerationBanner(
    state: viewModel.imageGenerationState,
    subjectColor: subject.color
)
```

**MessageBubble** - Muestra imagen si existe:
```swift
if message.hasImage, let imageURL = message.imageURL {
    AsyncImage(url: imageURL) { phase in
        // Manejo de estados: empty, success, failure
    }
}
```

#### 6.4.9 Requisitos

- **iOS 18.4+** para `ImageCreator` (generación programática)
- **Dispositivo físico** con Apple Intelligence habilitado
- **iPhone 15 Pro+** / **iPad con M1+** / **Mac con Apple Silicon**

#### 6.4.10 Ventajas del Tool Calling

| Aspecto | Enfoque Anterior (2 llamadas) | Tool Calling (1 llamada) |
|---------|-------------------------------|--------------------------|
| Latencia | Alta (secuencial) | Baja (paralelo) |
| Contexto | Se pierde entre llamadas | Completo durante decisión |
| Código | 3 servicios separados | 2 servicios integrados |
| Decisión | Heurística + IA separada | IA con contexto total |

---

## 7. VISTAS Y COMPONENTES

### 7.1 MainTabView - Navegación Principal

```swift
struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Inicio", systemImage: "house.fill", value: .home) {
                HomeView()
            }

            Tab("Progreso", systemImage: "chart.bar.fill", value: .progress) {
                ProgressView()
            }

            Tab("Ajustes", systemImage: "gear", value: .settings) {
                SettingsView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
```

### 7.2 Componentes Reutilizables

#### SubjectCard con Liquid Glass
```swift
struct SubjectCard: View {
    let subject: Subject
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: subject.icon)
                    .font(.largeTitle)
                Text(subject.displayName)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .glassEffect(.regular)
    }
}
```

#### MessageBubble
```swift
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            MarkdownTextView(content: message.content)
                .padding()
                .background(bubbleBackground)
                .clipShape(BubbleShape(isUser: message.role == .user))

            if message.role == .assistant { Spacer() }
        }
    }
}
```

### 7.3 Animaciones y Transiciones

```swift
// Animación de aparición de mensajes
.transition(.asymmetric(
    insertion: .move(edge: .bottom).combined(with: .opacity),
    removal: .opacity
))
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: messages.count)

// Animación de símbolos SF
Image(systemName: "sparkles")
    .symbolEffect(.bounce, value: trigger)

// Transición de glass morphing
.glassEffectID("button", in: namespace)
```

---

## 8. ACCESIBILIDAD

### 8.1 Liquid Glass y Accesibilidad

Liquid Glass respeta automáticamente estas configuraciones del sistema:
- **Reduce Transparency** - Glass más opaco
- **Increase Contrast** - Elementos más definidos
- **Reduce Motion** - Menos animaciones

### 8.2 VoiceOver

```swift
// Etiquetas descriptivas
Button { } label: {
    Image(systemName: "paperplane.fill")
}
.accessibilityLabel("Enviar mensaje")

// Hints para acciones
.accessibilityHint("Toca dos veces para enviar tu mensaje")

// Agrupar elementos relacionados
VStack {
    Text("Matemáticas")
    Text("5 sesiones")
}
.accessibilityElement(children: .combine)

// Valores dinámicos
.accessibilityValue("Progreso: \(progress)%")
```

### 8.3 Dynamic Type

```swift
// Usar fuentes dinámicas del sistema
.font(.body)
.font(.headline)
.font(.largeTitle)

// Escalar imágenes con texto
Image(systemName: "star")
    .imageScale(.large)

// Layouts adaptativos
@ScaledMetric var iconSize: CGFloat = 24
```

### 8.4 Contraste de Colores

```swift
// Usar colores semánticos
.foregroundStyle(.primary)
.foregroundStyle(.secondary)
.background(.background)

// Verificar contraste mínimo 4.5:1 para texto
// Verificar contraste mínimo 3:1 para elementos gráficos
```

---

## 9. RENDIMIENTO Y OPTIMIZACIÓN

### 9.1 Lazy Loading

```swift
// Usar LazyVStack para listas largas
ScrollView {
    LazyVStack(spacing: 12) {
        ForEach(messages) { message in
            MessageBubble(message: message)
        }
    }
}

// LazyVGrid para grids
LazyVGrid(columns: columns, spacing: 16) {
    ForEach(subjects) { subject in
        SubjectCard(subject: subject)
    }
}
```

### 9.2 Evitar Re-renders Innecesarios

```swift
// Extraer subviews que no cambian
struct ChatView: View {
    var body: some View {
        VStack {
            HeaderView()  // Componente extraído
            MessageList(messages: messages)
            InputBar(onSend: sendMessage)
        }
    }
}

// Usar @ViewBuilder para computar vistas condicionalmente
@ViewBuilder
private var contentView: some View {
    if isLoading {
        LoadingView()
    } else {
        ContentView()
    }
}
```

### 9.3 Async/Await Patterns

```swift
// Task para operaciones async
.task {
    await loadInitialData()
}

// Task con ID para cancelación automática
.task(id: selectedSubject) {
    await loadMessages(for: selectedSubject)
}

// Streaming de respuestas
func streamResponse() async {
    for try await token in responseStream {
        await MainActor.run {
            currentResponse += token
        }
    }
}
```

---

## 10. TESTING

### 10.1 Unit Tests para ViewModels

```swift
@Test
func testSendMessage() async {
    let viewModel = ChatViewModel()
    viewModel.inputText = "Hola, necesito ayuda con matemáticas"

    await viewModel.sendMessage()

    #expect(viewModel.messages.count == 2)
    #expect(viewModel.messages[0].role == .user)
    #expect(viewModel.messages[1].role == .assistant)
}
```

### 10.2 Tests de Servicios

```swift
@Test
func testContentSafetyValidation() {
    let service = ContentSafetyService()

    // Mensaje seguro
    let safeResult = service.validate("¿Cómo resuelvo una ecuación cuadrática?")
    #expect(safeResult == .safe)

    // Mensaje con PII
    let unsafeResult = service.validate("Mi número es 555-1234")
    #expect(unsafeResult != .safe)
}
```

### 10.3 Preview Tests

```swift
#Preview("HomeView - Default") {
    HomeView()
        .modelContainer(previewContainer)
}

#Preview("HomeView - Dark Mode") {
    HomeView()
        .modelContainer(previewContainer)
        .preferredColorScheme(.dark)
}

#Preview("ChatView - With Messages") {
    ChatView(subject: .math)
        .modelContainer(previewContainerWithMessages)
}
```

---

## 11. LOCALIZACIÓN

### 11.1 Idioma Principal: Español

Toda la interfaz de usuario está en español. Mantener consistencia:

```swift
// Textos de UI
"Inicio" // No "Home"
"Ajustes" // No "Settings"
"Enviar" // No "Send"

// Mensajes de error
"No se pudo enviar el mensaje. Intenta de nuevo."

// Confirmaciones
"¿Estás seguro de que deseas eliminar esta conversación?"
```

### 11.2 Formato de Fechas y Números

```swift
// Fechas
Text(date, format: .dateTime.day().month().year())
// Resultado: "21 de enero de 2026"

// Números
Text(1500, format: .number)
// Resultado: "1.500" (formato español)

// Duración
Text(duration, format: .units(allowed: [.hours, .minutes]))
```

---

## 12. SEGURIDAD Y PRIVACIDAD

### 12.1 Validación de Contenido

Siempre validar entrada del usuario antes de enviar a AI:

```swift
func sendMessage() async {
    // 1. Validar seguridad
    let validation = contentSafetyService.validate(inputText)
    guard case .safe = validation else {
        showSafetyWarning(validation)
        return
    }

    // 2. Procesar mensaje
    await processMessage()
}
```

### 12.2 Datos Sensibles

```swift
// NO guardar en logs
print(userMessage)  // ❌

// Usar redacción en logs de debug
Logger.debug("Message sent: [REDACTED]")  // ✅

// PII a detectar y bloquear:
// - Números de teléfono
// - Direcciones de email
// - Direcciones físicas
// - Números de identificación
```

### 12.3 Speech Recognition On-Device

```swift
// Forzar reconocimiento on-device
recognitionRequest.requiresOnDeviceRecognition = true
```

---

## 13. REQUISITOS DE APP STORE

### 13.1 SDK Mínimo (Abril 2026)

- Apps deben compilar con iOS 26 SDK
- Usar Xcode 26 o superior
- Dispositivos mínimos: iPhone 11+

### 13.2 Privacy Nutrition Labels

Declarar en App Store Connect:
- Datos recopilados (conversaciones locales - no enviadas)
- Uso de Speech Recognition (on-device)
- Uso de Notifications
- Sin tracking de terceros

### 13.3 Age Rating

- Contenido educativo general
- Sin compras in-app (actualmente)
- Sin contenido generado por usuarios externos

---

## 14. COMANDOS ÚTILES

### Build y Run
```bash
# Build del proyecto
xcodebuild -scheme NovaEducation -configuration Debug build

# Run tests
xcodebuild test -scheme NovaEducation -destination 'platform=iOS Simulator,name=iPhone 16'

# Limpiar build
xcodebuild clean -scheme NovaEducation
```

### Git Workflow
```bash
# Feature branch
git checkout -b feature/nombre-feature

# Commit con mensaje descriptivo
git commit -m "feat: descripción corta del cambio"

# Prefijos de commit:
# feat: nueva funcionalidad
# fix: corrección de bug
# refactor: refactorización
# docs: documentación
# style: cambios de estilo/formato
# test: tests
# chore: mantenimiento
```

---

## 15. CHECKLIST PARA NUEVAS FEATURES

Antes de implementar una nueva feature, verificar:

- [ ] ¿Sigue la arquitectura MVVM?
- [ ] ¿Usa Liquid Glass apropiadamente (solo navegación)?
- [ ] ¿Tiene soporte de accesibilidad (VoiceOver, Dynamic Type)?
- [ ] ¿Los textos están en español?
- [ ] ¿Valida contenido de seguridad si interactúa con AI?
- [ ] ¿Usa async/await para operaciones asíncronas?
- [ ] ¿Tiene Previews para Xcode Canvas?
- [ ] ¿Sigue las convenciones de nombrado?
- [ ] ¿Evita over-engineering?
- [ ] ¿Considera Tool Calling si el modelo puede decidir autónomamente?
- [ ] ¿Verifica `subject.supportsImages` antes de generar imágenes?

---

## 16. RECURSOS Y REFERENCIAS

### Documentación Oficial Apple
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Liquid Glass Guidelines](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
- [Foundation Models](https://developer.apple.com/documentation/foundationmodels)
- [Foundation Models - Tool Protocol](https://developer.apple.com/documentation/foundationmodels/tool)
- [ImagePlayground Framework](https://developer.apple.com/documentation/imageplayground)
- [ImageCreator](https://developer.apple.com/documentation/imageplayground/imagecreator)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)

### WWDC 2025 Videos
- [What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2025/256/)
- [Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Meet the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Deep dive into the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/301/)
- [Code-along: Bring on-device AI to your app](https://developer.apple.com/videos/play/wwdc2025/259/)
- [Discover machine learning & AI frameworks](https://developer.apple.com/videos/play/wwdc2025/360/)

### Human Interface Guidelines
- [iOS Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

---

## 17. NOTAS IMPORTANTES PARA CLAUDE

1. **Siempre leer el código existente** antes de proponer cambios
2. **Mantener el idioma español** en toda la UI
3. **Usar Liquid Glass solo para navegación**, nunca para contenido
4. **Validar seguridad** antes de cualquier interacción con AI
5. **Preferir editar** archivos existentes sobre crear nuevos
6. **Evitar over-engineering** - soluciones simples y directas
7. **Seguir MVVM** - separar lógica de negocio de vistas
8. **Usar @Observable** para ViewModels (no ObservableObject)
9. **Incluir accesibilidad** en cada componente nuevo
10. **Probar en Previews** antes de sugerir cambios
11. **Usar Tool Calling** para funcionalidades que el modelo puede invocar autónomamente
12. **Imágenes solo en materias visuales** - verificar `subject.supportsImages` antes de generar

---

## 18. RESUMEN DE FRAMEWORKS DE IA

| Framework | Uso | Requisitos |
|-----------|-----|------------|
| **Foundation Models** | Texto, Tool Calling, @Generable | iOS 26+, Apple Intelligence |
| **ImagePlayground** | Generación de imágenes | iOS 18.4+, dispositivo físico |
| **Speech** | Reconocimiento de voz on-device | iOS 26+, permiso de micrófono |
| **AVSpeechSynthesizer** | Text-to-speech | iOS 26+ |

---

*Última actualización: Enero 2026*
*iOS Target: 26.0+*
*Swift Version: 6.0+*
*Frameworks AI: Foundation Models, ImagePlayground*
