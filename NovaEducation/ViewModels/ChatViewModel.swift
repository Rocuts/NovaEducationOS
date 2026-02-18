import SwiftUI
import SwiftData

@Observable
@MainActor
class ChatViewModel {
    var currentInput: String = ""
    var subject: Subject
    var isGenerating: Bool = false

    private let modelService = FoundationModelService.shared
    private var currentTask: Task<Void, Never>?
    private var xpToastDismissTask: Task<Void, Never>?

    /// Student profile for adaptive prompts
    private let studentName: String
    private let educationLevel: EducationLevel

    // MARK: - Gamification State

    /// XP ganado en la última interacción
    var lastXPGained: Int = 0

    /// Multiplicador aplicado
    var lastMultiplier: Double = 1.0

    /// Si hubo level up
    var didLevelUp: Bool = false

    /// Nuevo nivel si hubo level up
    var newLevel: Int = 1

    /// Nivel anterior antes del level up
    var previousLevel: Int = 0

    /// Nuevo título si hubo level up
    var newTitle: String = ""

    /// Si debemos mostrar toast de XP (deprecated - ahora usa IslandNotification)
    var showXPToast: Bool = false

    /// Si debemos mostrar explosion de particulas para XP grandes o level up
    var showParticleExplosion: Bool = false

    /// Error message para mostrar al usuario (nil = sin error)
    var errorMessage: String? = nil

    /// Sugerencia de recuperación para el error actual
    var errorRecoverySuggestion: String? = nil

    /// Si debemos mostrar celebración de level up
    var showLevelUpCelebration: Bool = false

    /// Exposes image generation state from the model service
    var imageGenerationState: ImageGenerationState {
        modelService.imageGenerationState
    }

    init(subject: Subject, studentName: String = "Estudiante", educationLevel: EducationLevel = .secondary) {
        self.subject = subject
        self.studentName = studentName
        self.educationLevel = educationLevel
        // Session will be created when modelContext is set
    }

    /// Sets the model context for SwiftData operations (call this before using the ViewModel)
    func configure(with context: ModelContext) {
        modelService.modelContext = context
        modelService.createSession(for: subject, studentName: studentName, educationLevel: educationLevel)
    }

    func sendMessage(context: ModelContext, history: [ChatMessage] = []) {
        // Ensure model context is set
        if modelService.modelContext == nil {
            modelService.modelContext = context
        }
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Limpiar error previo al enviar nuevo mensaje
        dismissError()

        // Validar seguridad del contenido antes de enviar a AI
        let safetyResult = ContentSafetyService.validate(trimmed)
        if case .unsafe(let reason) = safetyResult {
            self.errorMessage = reason
            return
        }

        let userMsg = ChatMessage(role: .user, content: trimmed, subjectId: subject.id)
        context.insert(userMsg)

        currentInput = ""

        generateResponse(for: userMsg, context: context, history: history)
    }

    private func generateResponse(for userMessage: ChatMessage, context: ModelContext, history: [ChatMessage]) {
        let assistantMsg = ChatMessage(role: .assistant, content: "", subjectId: subject.id)
        context.insert(assistantMsg)

        isGenerating = true

        // Cancel previous generation to prevent race conditions
        currentTask?.cancel()
        currentTask = Task {
            var responseSuccessful = false

            do {
                let stream = modelService.streamResponse(prompt: userMessage.content, history: history)

                for try await delta in stream {
                    guard !Task.isCancelled else { break }
                    assistantMsg.content += delta
                }

                // Check if an image was generated via Tool Calling
                // Check if an image was generated via Tool Calling
                if let imageURL = modelService.generatedImageURL {
                    assistantMsg.imageURL = imageURL
                    modelService.resetImageState()
                }
                
                // Check if an interactive attachment was generated via Tool Calling
                if let attachment = modelService.generatedAttachment {
                    assistantMsg.attachmentType = attachment.type
                    assistantMsg.attachmentData = attachment.data
                }

                // Cleanup common placeholder text unconditionally
                // (The model might hallucinate this text even if the tool wasn't called or failed)
                let placeholders = [
                    "[Generated Educational Image]",
                    "[Imagen generada]",
                    "[Generating image for educational illustration]",
                    "[Generando imagen para ilustración educativa]",
                    "Generando imagen...",
                    "Generating image...",
                    "Aquí tienes una imagen...",
                    "Aquí tienes una ilustración...",
                    "Aquí hay una imagen...",
                    "He generado una imagen...",
                    "generateEducationalImage",
                    "null",
                    "[]",
                    "{}"
                ]

                var cleanContent = assistantMsg.content
                for placeholder in placeholders {
                    cleanContent = cleanContent.replacingOccurrences(of: placeholder, with: "")
                }
                assistantMsg.content = cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)

                responseSuccessful = !assistantMsg.content.isEmpty

            } catch {
                if assistantMsg.content.isEmpty {
                    // Eliminar mensaje vacío y mostrar error como estado separado
                    context.delete(assistantMsg)
                    let novaError = error as? NovaError
                    self.errorMessage = novaError?.errorDescription ?? "Lo siento, hubo un error al generar la respuesta. Por favor intenta de nuevo."
                    self.errorRecoverySuggestion = novaError?.recoverySuggestion
                } else {
                    // Respuesta parcial recibida — no agregar error crudo al contenido
                    self.errorMessage = "La respuesta se interrumpió. Puedes intentar de nuevo."
                }
            }

            isGenerating = false

            // Award XP for successful message exchange
            if responseSuccessful {
                awardMessageXP(context: context)
            }
        }
    }

    // MARK: - Gamification Methods

    /// Otorga XP por enviar un mensaje
    private func awardMessageXP(context: ModelContext) {
        // Determinar si es el primer mensaje del día
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<XPTransaction>(
            predicate: #Predicate { $0.timestamp >= startOfDay && $0.sourceRaw == "message" }
        )
        let messagesCountToday = (try? context.fetchCount(descriptor)) ?? 0

        // Primer mensaje del día tiene bonus
        let source: XPSource = messagesCountToday == 0 ? .firstOfDay : .message

        // Otorgar XP
        let result = XPManager.shared.awardXP(
            source: source,
            subjectId: subject.id,
            context: context
        )

        // Actualizar estado para UI
        lastXPGained = result.xpGained
        lastMultiplier = XPManager.shared.currentMultiplier
        didLevelUp = result.leveledUp

        if result.leveledUp {
            let level = XPManager.shared.newLevel
            guard level > 0 else { return }
            previousLevel = XPManager.shared.previousLevel
            newLevel = level
            newTitle = PlayerLevel.title(forLevel: newLevel)
            showLevelUpCelebration = true
        }

        // Mostrar notificación de XP via Island Notification
        if result.xpGained > 0 {
            IslandNotificationManager.shared.show(
                .xpGain(amount: lastXPGained, multiplier: lastMultiplier)
            )

            // Mostrar explosion de particulas para XP grandes o level up
            if lastXPGained >= 15 || result.leveledUp {
                showParticleExplosion = true
                xpToastDismissTask?.cancel()
                xpToastDismissTask = Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    guard !Task.isCancelled else { return }
                    showParticleExplosion = false
                }
            }
        }
    }

    /// Resetea el estado de celebración de level up
    func dismissLevelUpCelebration() {
        showLevelUpCelebration = false
        didLevelUp = false
        previousLevel = 0
        XPManager.shared.resetAnimationState()
    }

    /// Resetea el toast de XP
    func dismissXPToast() {
        showXPToast = false
    }

    /// Limpia el estado de error
    func dismissError() {
        errorMessage = nil
        errorRecoverySuggestion = nil
    }

    func stopGenerating() {
        currentTask?.cancel()
        modelService.cancel()
        isGenerating = false
    }

    func clearHistory(context: ModelContext, messages: [ChatMessage]) {
        for msg in messages {
            // Also delete associated images
            if let imageURL = msg.imageURL {
                try? FileManager.default.removeItem(at: imageURL)
            }
            context.delete(msg)
        }
        // Force reset session for fresh context after clearing history
        modelService.modelContext = context
        modelService.createSession(for: subject, studentName: studentName, educationLevel: educationLevel, forceRecreate: true)
    }

    func resetSession(context: ModelContext) {
        modelService.modelContext = context
        modelService.createSession(for: subject, studentName: studentName, educationLevel: educationLevel, forceRecreate: true)
    }

    /// Whether image generation is currently in progress
    var isGeneratingImage: Bool {
        imageGenerationState.isActive
    }
}
