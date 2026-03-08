import SwiftUI
import SwiftData
import FoundationModels

@Observable
@MainActor
class ChatViewModel {
    var currentInput: String = ""
    var subject: Subject
    var isGenerating: Bool = false

    private let modelService = FoundationModelService.shared
    private var currentTask: Task<Void, Never>?
    private var xpToastDismissTask: Task<Void, Never>?

    private var studentName: String
    private var educationLevel: EducationLevel
    private var lastFailedPrompt: String?

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

    var currentIdentity: (studentName: String, educationLevel: EducationLevel) {
        (studentName, educationLevel)
    }

    init(subject: Subject, studentName: String = "Estudiante", educationLevel: EducationLevel = .secondary) {
        self.subject = subject
        self.studentName = studentName
        self.educationLevel = educationLevel
    // Session will be created when modelContext is set
    }

    /// Reconfigures the ViewModel with new student data without dropping in-flight state
    func reconfigure(studentName: String, educationLevel: EducationLevel) {
        // Only trigger a reconfiguration if the data actually changed
        if self.studentName != studentName || self.educationLevel != educationLevel {
            self.studentName = studentName
            self.educationLevel = educationLevel

            // Re-create the session on the service with the new identity context,
            // but don't reset other fields on this ViewModel.
            modelService.createSession(
                for: subject,
                studentName: studentName,
                educationLevel: educationLevel,
                forceRecreate: true
            )
        }
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
        let rawTrimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawTrimmed.isEmpty else { return }

        // Cap message length to prevent excessive input
        let trimmed = String(rawTrimmed.prefix(4000))

        // Limpiar error previo al enviar nuevo mensaje
        dismissError()

        // Validar seguridad del contenido antes de enviar a AI
        let safetyResult = ContentSafetyService.validate(trimmed)
        if case .unsafe(let reason) = safetyResult {
            self.errorMessage = reason
            return
        }

        // Re-check model availability right before dispatching generation.
        if modelService.availability != .available {
            self.errorMessage = "Apple Intelligence no está disponible en este momento."
            self.errorRecoverySuggestion = "Activa Apple Intelligence en Configuración o espera a que el modelo termine de prepararse."
            return
        }

        // Nuevo ciclo de envío: limpiar prompt fallido previo
        lastFailedPrompt = nil

        let userMsg = ChatMessage(role: .user, content: trimmed, subjectId: subject.id)
        context.insert(userMsg)

        currentInput = ""

        // Three-way deterministic routing — "App decide, LLM enseña"

        // 1. Render intent (visual: 3D models, images)
        let routerResult = RenderIntentRouter.detect(trimmed)
        if routerResult.hasRenderIntent {
            generateRenderResponse(for: userMsg, routerResult: routerResult, context: context, history: history)
            return
        }

        // 2. Subject interceptor (computation, facts, grammar)
        if let interceptor = SubjectIntentRouter.detect(trimmed, subject: subject) {
            generateInterceptedResponse(for: userMsg, interceptor: interceptor, context: context, history: history)
            return
        }

        // 3. Pure LLM (discussion, creative, open-ended)
        generateResponse(for: userMsg, context: context, history: history)
    }

    // MARK: - Render Pipeline Response

    /// Handles messages identified as render intents.
    /// Flow: RenderPipeline produces asset → teacher explains → message gets both.
    private func generateRenderResponse(
        for userMessage: ChatMessage,
        routerResult: RouterResult,
        context: ModelContext,
        history: [ChatMessage]
    ) {
        let assistantMsg = ChatMessage(role: .assistant, content: "", subjectId: subject.id)
        context.insert(assistantMsg)

        isGenerating = true

        let previousTask = currentTask
        previousTask?.cancel()
        currentTask = Task {
            _ = await previousTask?.value
            // 1. Execute render pipeline (deterministic + optional LLM extraction)
            let renderOutput = await RenderPipeline.shared.process(
                text: userMessage.content,
                routerResult: routerResult
            )
            if self.finishCancelledGenerationIfNeeded(assistantMsg: assistantMsg, context: context) {
                return
            }

            // 2. Attach render result to message
            assistantMsg.attachmentType = renderOutput.attachmentType
            assistantMsg.attachmentData = renderOutput.attachmentData
            if let imageURL = renderOutput.imageURL {
                assistantMsg.imageURL = imageURL
            }

            // 3. Stream teacher response about the rendered content
            // The app already rendered the 3D model — tell teacher to explain only
            let teacherPrompt = """
            [El estudiante pidió ver "\(userMessage.content)" y la app ya le mostró un modelo 3D interactivo: \(renderOutput.spokenSummary)]
            Explica el concepto educativo de forma breve y clara. El modelo 3D ya es visible para el estudiante. Solo enseña sobre el tema.
            """

            do {
                let stream = modelService.streamResponse(
                    prompt: teacherPrompt,
                    history: history,
                    interactionMode: .text
                )
                var parts: [String] = []
                var flushCounter = 0
                for try await delta in stream {
                    guard !Task.isCancelled else { break }
                    parts.append(delta)
                    flushCounter += 1
                    if flushCounter % 4 == 0 {
                        assistantMsg.content = parts.joined()
                    }
                }
                assistantMsg.content = parts.joined()

                // Cleanup tool artifacts from teacher response
                assistantMsg.content = assistantMsg.content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if self.finishCancelledGenerationIfNeeded(assistantMsg: assistantMsg, context: context) {
                    return
                }
            } catch {
                if Task.isCancelled || error is CancellationError {
                    self.finishCancelledGeneration(assistantMsg: assistantMsg, context: context)
                    return
                }
                // Teacher failed — use spoken summary as fallback text
                if assistantMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    assistantMsg.content = renderOutput.spokenSummary
                }
            }

            if self.finishCancelledGenerationIfNeeded(assistantMsg: assistantMsg, context: context) {
                return
            }

            // Ensure message is never empty
            if assistantMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                assistantMsg.content = renderOutput.spokenSummary
            }

            isGenerating = false
            awardMessageXP(context: context)
        }
    }

    // MARK: - Interceptor Pipeline Response

    /// Handles messages intercepted by a SubjectInterceptor.
    /// Flow: Interceptor.solve() computes answer → teacher LLM explains → message gets both.
    private func generateInterceptedResponse(
        for userMessage: ChatMessage,
        interceptor: any SubjectInterceptor,
        context: ModelContext,
        history: [ChatMessage]
    ) {
        let assistantMsg = ChatMessage(role: .assistant, content: "", subjectId: subject.id)
        context.insert(assistantMsg)

        isGenerating = true

        let previousTask = currentTask
        previousTask?.cancel()
        currentTask = Task {
            _ = await previousTask?.value
            let start = ContinuousClock.now

            // 1. Execute interceptor (deterministic, fast)
            let result = await interceptor.solve(userMessage.content, subject: subject)
            if self.finishCancelledGenerationIfNeeded(assistantMsg: assistantMsg, context: context) {
                return
            }

            let elapsed = start.duration(to: .now)
            let durationMs = Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
                + Int(elapsed.components.seconds) * 1000

            // 2. Log metrics
            InterceptorMetrics.log(
                utterance: userMessage.content,
                subject: subject.id,
                interceptorId: interceptor.interceptorId,
                result: result,
                durationMs: durationMs
            )

            // 3. If fallthrough, delegate to pure LLM path
            if result.category == .passthrough {
                isGenerating = false
                context.delete(assistantMsg)
                generateResponse(for: userMessage, context: context, history: history)
                return
            }

            // 4. Attach interceptor data to message
            assistantMsg.attachmentType = result.attachmentType
            assistantMsg.attachmentData = result.attachmentData

            // 5. Stream teacher response — LLM explains, never recomputes
            let teacherPrompt = "[RESULTADO: \(result.answer)] \(result.teacherInstruction)"

            do {
                let stream = modelService.streamResponse(
                    prompt: teacherPrompt,
                    history: history,
                    interactionMode: .text
                )
                var parts: [String] = []
                var flushCounter = 0
                for try await delta in stream {
                    guard !Task.isCancelled else { break }
                    parts.append(delta)
                    flushCounter += 1
                    if flushCounter % 4 == 0 {
                        assistantMsg.content = parts.joined()
                    }
                }
                assistantMsg.content = parts.joined()

                assistantMsg.content = assistantMsg.content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if self.finishCancelledGenerationIfNeeded(assistantMsg: assistantMsg, context: context) {
                    return
                }
            } catch {
                if Task.isCancelled || error is CancellationError {
                    self.finishCancelledGeneration(assistantMsg: assistantMsg, context: context)
                    return
                }
                // Teacher failed — use computed answer as fallback
                if assistantMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    assistantMsg.content = result.answer
                }
            }

            if self.finishCancelledGenerationIfNeeded(assistantMsg: assistantMsg, context: context) {
                return
            }

            // Ensure message is never empty
            if assistantMsg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                assistantMsg.content = result.answer
            }

            isGenerating = false
            awardMessageXP(context: context)
        }
    }

    private func generateResponse(for userMessage: ChatMessage, context: ModelContext, history: [ChatMessage]) {
        let assistantMsg = ChatMessage(role: .assistant, content: "", subjectId: subject.id)
        context.insert(assistantMsg)

        isGenerating = true

        // Cancel previous generation to prevent race conditions
        let previousTask = currentTask
        previousTask?.cancel()
        currentTask = Task {
            _ = await previousTask?.value
            var responseSuccessful = false

            do {
                let stream = modelService.streamResponse(
                    prompt: userMessage.content,
                    history: history,
                    interactionMode: .text
                )

                var parts: [String] = []
                var flushCounter = 0
                for try await delta in stream {
                    guard !Task.isCancelled else { break }
                    parts.append(delta)
                    flushCounter += 1
                    if flushCounter % 4 == 0 {
                        assistantMsg.content = parts.joined()
                    }
                }
                assistantMsg.content = parts.joined()
                if self.finishCancelledGenerationIfNeeded(assistantMsg: assistantMsg, context: context) {
                    return
                }

                // Associate generated image if the ImageGeneratorTool produced one during streaming.
                // The tool callback sets generatedImageURL on FoundationModelService.
                if let imageURL = self.modelService.state.image.generatedImageURL {
                    assistantMsg.imageURL = imageURL
                    self.modelService.state.image.generatedImageURL = nil
                    self.modelService.state.image.status = .idle
                }

                assistantMsg.content = assistantMsg.content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if self.finishCancelledGenerationIfNeeded(assistantMsg: assistantMsg, context: context) {
                    return
                }

                // Defense in depth: if the model returned a useless rejection response,
                // retry once with a simplified prompt that avoids confusion.
                if FoundationModelService.isUselessResponse(assistantMsg.content) {
                    assistantMsg.content = ""
                    let retryPrompt = "Responde esta pregunta de \(subject.displayName): \(userMessage.content)"
                    let retryStream = modelService.streamResponse(
                        prompt: retryPrompt,
                        history: [],
                        interactionMode: .text
                    )
                    var retryParts: [String] = []
                    var retryFlushCounter = 0
                    for try await delta in retryStream {
                        guard !Task.isCancelled else { break }
                        retryParts.append(delta)
                        retryFlushCounter += 1
                        if retryFlushCounter % 4 == 0 {
                            assistantMsg.content = retryParts.joined()
                        }
                    }
                    assistantMsg.content = retryParts.joined()
                    assistantMsg.content = assistantMsg.content
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if self.finishCancelledGenerationIfNeeded(assistantMsg: assistantMsg, context: context) {
                        return
                    }

                    // If retry also failed, use a hardcoded fallback
                    if FoundationModelService.isUselessResponse(assistantMsg.content) || assistantMsg.content.isEmpty {
                        assistantMsg.content = generateFallbackResponse(for: userMessage.content)
                    }
                }

                responseSuccessful = !assistantMsg.content.isEmpty

            } catch {
                if Task.isCancelled || error is CancellationError {
                    self.finishCancelledGeneration(assistantMsg: assistantMsg, context: context)
                    return
                }

                recordFailedPrompt(userMessage.content)

                if assistantMsg.content.isEmpty {
                    // Eliminar mensaje vacío y mostrar error como estado separado
                    context.delete(assistantMsg)
                    let novaError = error as? NovaError
                    self.errorMessage = novaError?.errorDescription ?? "Lo siento, hubo un error al generar la respuesta. Por favor intenta de nuevo."
                    self.errorRecoverySuggestion = novaError?.recoverySuggestion
                } else {
                    // Respuesta parcial recibida
                    if let novaError = error as? NovaError, case .repetitionDetected = novaError {
                        self.errorMessage = novaError.errorDescription
                        self.errorRecoverySuggestion = novaError.recoverySuggestion
                    } else {
                        self.errorMessage = "La respuesta se interrumpió. Puedes intentar de nuevo."
                    }
                }
            }

            isGenerating = false

            // Award XP for successful message exchange
            if responseSuccessful {
                awardMessageXP(context: context)
            }
        }
    }

    /// Last-resort fallback when the model refuses to answer. Returns a helpful
    /// response that encourages the student to rephrase their question.
    private func generateFallbackResponse(for input: String) -> String {
        let subjectName = subject.displayName
        return "Vamos a resolver esto juntos, \(studentName). ¿Podrías reformular tu pregunta sobre \(subjectName)? Así puedo darte una mejor explicación."
    }

    // MARK: - Gamification Methods

    /// Otorga XP por enviar un mensaje
    private func awardMessageXP(context: ModelContext) {
        let messagesCountToday = Self.messageTransactionCountToday(in: context)
        let source = Self.xpSourceForMessageCount(messagesCountToday)

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

    func retryLastFailedMessage(context: ModelContext, history: [ChatMessage] = []) {
        guard let failedPrompt = lastFailedPrompt?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !failedPrompt.isEmpty else {
            return
        }
        currentInput = failedPrompt
        sendMessage(context: context, history: history)
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

    static func messageTransactionCountToday(
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let startOfDay = calendar.startOfDay(for: now)
        let descriptor = FetchDescriptor<XPTransaction>(
            predicate: #Predicate {
                $0.timestamp >= startOfDay
                    && ($0.sourceRaw == "message" || $0.sourceRaw == "first_of_day")
            }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    static func xpSourceForMessageCount(_ messagesCountToday: Int) -> XPSource {
        messagesCountToday == 0 ? .firstOfDay : .message
    }

    private func recordFailedPrompt(_ prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastFailedPrompt = trimmed
    }

    @discardableResult
    private func finishCancelledGenerationIfNeeded(assistantMsg: ChatMessage, context: ModelContext) -> Bool {
        guard Task.isCancelled else { return false }
        finishCancelledGeneration(assistantMsg: assistantMsg, context: context)
        return true
    }

    private func finishCancelledGeneration(assistantMsg: ChatMessage, context: ModelContext) {
        assistantMsg.content = assistantMsg.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if assistantMsg.content.isEmpty {
            context.delete(assistantMsg)
        }
        isGenerating = false
    }
}
