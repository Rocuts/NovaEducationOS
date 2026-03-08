# Servicios

## FoundationModelService - Apple Intelligence + Tool Calling

```swift
@Observable @MainActor
class FoundationModelService {
    private var session: LanguageModelSession?
    var imageGenerationState: ImageGeneratorService.GenerationState = .idle
    var generatedImageURL: URL?
}
```

- Crea sesión con/sin herramientas según `subject.supportsImages`
- Si `supportsImages`: sesión con `ImageGeneratorTool` + callbacks
- Si no: sesión sin herramientas
- Guard de disponibilidad: `SystemLanguageModel.default.availability`
- Prewarm asíncrono tras creación de sesión
- Aislamiento por modo de interacción (chat vs voz)

### System Prompts
- Incluir nivel educativo y nombre del estudiante
- Idioma español
- Personalidad del tutor por materia
- Instrucciones LaTeX si aplica
- Límites de seguridad
- Instrucciones de herramientas si `supportsImages`

### Sanitización de contexto dinámico
- Nombre/memoria del estudiante van en payload por turno `[CONTEXTO_ESTUDIANTE]`
- Normalización de whitespace y eliminación de control characters
- Límites de longitud para nombre, memoria y prompt

## ImageGeneratorTool (Tool protocol)

```swift
final class ImageGeneratorTool: Tool {
    let name = "generateEducationalImage"
    // Recibe: imagePrompt (inglés), reasonForImage (español)
    // Usa: ImagePlayground (ImageCreator)
    // Retorna: URL de imagen guardada
    // Callbacks: onGenerationStarted, onImageGenerated, onGenerationFailed
}
```

### Flujo
1. Usuario pregunta algo visual → 2. Modelo decide llamar tool → 3. Tool genera con ImageCreator → 4. Guarda imagen → 5. Callback actualiza UI → 6. MessageBubble muestra texto + imagen

### Estados de generación
`idle` → `generating(prompt)` → `completed(imageURL)` | `failed(error)`

### Requisitos
- iOS 18.4+ para ImageCreator
- Dispositivo físico con Apple Intelligence
- iPhone 15 Pro+ / iPad M1+ / Mac Apple Silicon

## ContentSafetyService

Valida entrada del usuario antes de enviar a AI. Detecta PII, contenido dañino, intentos de jailbreak.

## Speech (on-device)

`requiresOnDeviceRecognition = true` — reconocimiento siempre local.

## Frameworks AI

| Framework | Uso | Requisitos |
|-----------|-----|------------|
| Foundation Models | Texto, Tool Calling, @Generable | iOS 26+ |
| ImagePlayground | Generación de imágenes | iOS 18.4+, dispositivo físico |
| Speech | Reconocimiento de voz | iOS 26+, permiso micrófono |
| AVSpeechSynthesizer | Text-to-speech | iOS 26+ |
