import Foundation
import FoundationModels
import SwiftUI
import SwiftData

@Observable
@MainActor
class FoundationModelService {
    private var session: LanguageModelSession?
    private var currentSubject: Subject?
    var isGenerating = false

    /// Image generation state for UI feedback
    var imageGenerationState: ImageGenerationState = .idle

    /// The generated image URL (if any) for the current response
    var generatedImageURL: URL?

    /// Quiz generated state
    var lastGeneratedQuiz: QuizQuestion?

    // MARK: - Tools
    private var imageTool: ImageGeneratorTool?
    private var memoryStoreTool: MemoryStoreTool?
    private var memoryRecallTool: MemoryRecallTool?
    private var quizTool: QuizGeneratorTool?
    private var planTool: LearningPlanTool?
    private var questTool: DailyQuestGeneratorTool?

    /// Student context for adaptive prompts
    private var studentName: String = "Estudiante"
    private var educationLevel: EducationLevel = .secondary

    /// Model context for SwiftData operations (set externally)
    var modelContext: ModelContext?

    /// Student knowledge context (built from memory)
    private var studentKnowledgeContext: String = ""

    /// Checks if Foundation Models are available on this device
    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// Returns the availability status for UI handling
    var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    // MARK: - Session Creation

    func createSession(
        for subject: Subject,
        studentName: String = "Estudiante",
        educationLevel: EducationLevel = .secondary,
        forceRecreate: Bool = false
    ) {
        // Skip recreation if session already exists for same subject and settings
        // This preserves the internal session state when user re-enters a chat
        if !forceRecreate,
           session != nil,
           currentSubject == subject,
           self.studentName == studentName,
           self.educationLevel == educationLevel {
            // Just update knowledge context in case it changed
            if let context = modelContext {
                studentKnowledgeContext = StudentMemoryService.shared.buildKnowledgeContext(
                    for: subject.id,
                    context: context
                )
            }
            return
        }

        self.currentSubject = subject
        self.studentName = studentName
        self.educationLevel = educationLevel

        // Reset states
        generatedImageURL = nil
        imageGenerationState = .idle
        lastGeneratedQuiz = nil

        // Build student knowledge context if we have a model context
        if let context = modelContext {
            studentKnowledgeContext = StudentMemoryService.shared.buildKnowledgeContext(
                for: subject.id,
                context: context
            )
        }

        // Build all tools
        var tools: [any Tool] = []

        // 1. Image Tool (only for subjects that support images)
        if subject.supportsImages {
            let imgTool = ImageGeneratorTool()
            if imgTool.isAvailable {
                configureImageTool(imgTool)
                tools.append(imgTool)
                self.imageTool = imgTool

                Task {
                    await imgTool.prepare()
                }
            }
        } else {
            self.imageTool = nil
        }

        // 2. Memory Store Tool (always available)
        let storeTool = MemoryStoreTool()
        configureMemoryStoreTool(storeTool, subjectId: subject.id)
        tools.append(storeTool)
        self.memoryStoreTool = storeTool

        // 3. Memory Recall Tool (always available)
        let recallTool = MemoryRecallTool()
        configureMemoryRecallTool(recallTool, subjectId: subject.id)
        tools.append(recallTool)
        self.memoryRecallTool = recallTool

        // 4. Quiz Generator Tool (always available)
        let qTool = QuizGeneratorTool()
        configureQuizTool(qTool, subjectId: subject.id)
        tools.append(qTool)
        self.quizTool = qTool

        // 5. Learning Plan Tool (always available)
        let pTool = LearningPlanTool()
        configurePlanTool(pTool, subjectId: subject.id)
        tools.append(pTool)
        self.planTool = pTool

        // 6. Daily Quest Generator Tool (always available)
        let qstTool = DailyQuestGeneratorTool()
        configureQuestTool(qstTool, subjectId: subject.id)
        tools.append(qstTool)
        self.questTool = qstTool

        // Get system prompt with all tool instructions
        let systemPrompt = getSystemPrompt(
            for: subject,
            includeImageInstructions: subject.supportsImages && imageTool != nil
        )

        // Create session with all tools
        if tools.isEmpty {
            session = LanguageModelSession {
                systemPrompt
            }
        } else {
            session = LanguageModelSession(tools: tools) {
                systemPrompt
            }
        }
    }

    // MARK: - Tool Configuration

    private func configureImageTool(_ tool: ImageGeneratorTool) {
        tool.onGenerationStarted = { [weak self] reason in
            Task { @MainActor in
                self?.imageGenerationState = .generating(prompt: reason)
            }
        }

        tool.onImageGenerated = { [weak self] url in
            Task { @MainActor in
                self?.generatedImageURL = url
                self?.imageGenerationState = .completed(imageURL: url)
            }
        }

        tool.onGenerationFailed = { [weak self] error in
            Task { @MainActor in
                self?.imageGenerationState = .failed(error: error)
            }
        }
    }

    private func configureMemoryStoreTool(_ tool: MemoryStoreTool, subjectId: String) {
        tool.currentSubjectId = subjectId
        tool.onStoreKnowledge = { [weak self] content, category, mastery in
            guard let context = self?.modelContext else { return }
            _ = StudentMemoryService.shared.storeKnowledge(
                content: content,
                category: category,
                subjectId: subjectId,
                masteryLevel: mastery,
                context: context
            )
        }
    }

    private func configureMemoryRecallTool(_ tool: MemoryRecallTool, subjectId: String) {
        tool.onRecallKnowledge = { [weak self] queryType, topic in
            guard let context = self?.modelContext else {
                return "No hay información disponible."
            }

            switch queryType.lowercased() {
            case "profile", "perfil":
                return StudentMemoryService.shared.generateStudentProfile(
                    for: subjectId,
                    context: context
                )

            case "concepts", "conceptos":
                let concepts = StudentMemoryService.shared.getKnowledge(
                    for: subjectId,
                    category: .concept,
                    context: context
                )
                if concepts.isEmpty { return "No hay conceptos registrados." }
                return concepts.map { "• \($0.content) (dominio: \(Int($0.masteryLevel * 100))%)" }.joined(separator: "\n")

            case "difficulties", "dificultades":
                let diffs = StudentMemoryService.shared.getDifficulties(for: subjectId, context: context)
                if diffs.isEmpty { return "No hay dificultades registradas." }
                return diffs.map { "• \($0.content)" }.joined(separator: "\n")

            case "interests", "intereses":
                let interests = StudentMemoryService.shared.getInterests(context: context)
                if interests.isEmpty { return "No hay intereses registrados." }
                return interests.map { "• \($0.content)" }.joined(separator: "\n")

            default: // "all"
                return StudentMemoryService.shared.buildKnowledgeContext(
                    for: subjectId,
                    context: context
                )
            }
        }
    }

    private func configureQuizTool(_ tool: QuizGeneratorTool, subjectId: String) {
        tool.onQuizGenerated = { [weak self] question, options, correct, explanation, concept, difficulty in
            guard let context = self?.modelContext else { return }
            let quiz = StudentMemoryService.shared.storeQuizQuestion(
                question: question,
                options: options,
                correctAnswer: correct,
                explanation: explanation,
                subjectId: subjectId,
                relatedConcept: concept,
                difficulty: difficulty,
                context: context
            )
            self?.lastGeneratedQuiz = quiz
        }
    }

    private func configurePlanTool(_ tool: LearningPlanTool, subjectId: String) {
        tool.onPlanCreated = { [weak self] topic, steps in
            guard let context = self?.modelContext else { return }
            _ = StudentMemoryService.shared.createLearningPlan(
                topic: topic,
                subjectId: subjectId,
                steps: steps,
                context: context
            )
        }
    }

    private func configureQuestTool(_ tool: DailyQuestGeneratorTool, subjectId: String) {
        tool.currentSubjectId = subjectId
        tool.onQuestGenerated = { [weak self] quest in
            guard let context = self?.modelContext else { return }
            DailyQuestService.shared.saveGeneratedQuest(quest, context: context)
        }
    }

    // MARK: - Response Streaming

    func streamResponse(
        prompt: String,
        history: [ChatMessage]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                self.isGenerating = true
                self.generatedImageURL = nil
                self.imageGenerationState = .idle
                self.lastGeneratedQuiz = nil
            }

            Task {
                defer {
                    Task { @MainActor in
                        self.isGenerating = false
                    }
                }

                guard let session = self.session else {
                    continuation.finish(throwing: NovaError.noSession)
                    return
                }

                do {
                    let contextPrompt = self.buildContextualPrompt(prompt: prompt, history: history)
                    let stream = session.streamResponse(to: contextPrompt)

                    var lastCount = 0
                    var lastCleanedCount = 0

                    for try await partialResponse in stream {
                        let currentText = partialResponse.content
                        if currentText.count > lastCount {
                            let cleanedFullText = self.cleanResponseText(currentText)

                            if cleanedFullText.count > lastCleanedCount {
                                let cleanedIndex = cleanedFullText.index(cleanedFullText.startIndex, offsetBy: lastCleanedCount)
                                let cleanedDelta = String(cleanedFullText[cleanedIndex...])
                                continuation.yield(cleanedDelta)
                                lastCleanedCount = cleanedFullText.count
                            }

                            lastCount = currentText.count
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Removes markdown images, base64 patterns, and leaked tool logs from text
    private func cleanResponseText(_ text: String) -> String {
        var cleaned = text

        // 1. Remove Markdown images: ![alt](url)
        cleaned = cleaned.replacingOccurrences(of: "!\\[.*?\\]\\(.*?\\)", with: "", options: .regularExpression)

        // 2. Remove leaked tool calls and placeholders
        cleaned = cleaned.replacingOccurrences(of: "\\[GeneramosEducationalImage.*?\\]", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\[.*?(Image|Imagen|Generating).*?\\]", with: "", options: .regularExpression)

        // 3. Remove System Prompt Leaks
        cleaned = cleaned.replacingOccurrences(of: "\\*\\*\\*.*?\\*\\*\\*", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?i)INSTRUCCIONES INTERNAS", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?i)NO MOSTRAR AL USUARIO", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?i)RESPUESTA GENERADA POR IA", with: "", options: .regularExpression)

        // 4. Remove tool call artifacts
        cleaned = cleaned.replacingOccurrences(of: "\\[Tool:.*?\\]", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\[Calling.*?\\]", with: "", options: .regularExpression)

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Non-streaming response for simpler use cases
    func respond(to prompt: String, history: [ChatMessage]) async throws -> String {
        guard let session = session else {
            throw NovaError.noSession
        }

        await MainActor.run {
            isGenerating = true
            generatedImageURL = nil
            imageGenerationState = .idle
        }

        defer {
            Task { @MainActor in isGenerating = false }
        }

        let contextPrompt = buildContextualPrompt(prompt: prompt, history: history)
        let response = try await session.respond(to: contextPrompt)
        return response.content
    }

    func cancel() {
        isGenerating = false
        imageGenerationState = .idle
    }

    /// Resets the image generation state after it's been processed
    func resetImageState() {
        generatedImageURL = nil
        if case .completed = imageGenerationState {
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    if case .completed = self.imageGenerationState {
                        self.imageGenerationState = .idle
                    }
                }
            }
        } else if case .failed = imageGenerationState {
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    if case .failed = self.imageGenerationState {
                        self.imageGenerationState = .idle
                    }
                }
            }
        }
    }

    private func buildContextualPrompt(prompt: String, history: [ChatMessage]) -> String {
        // LanguageModelSession is stateful only while it exists in memory.
        // When the user re-enters a chat, we need to provide conversation context.

        // If no history or just the current message, return prompt directly
        // (history includes the user message we just inserted, so check for > 1)
        guard history.count > 1 else {
            return prompt
        }

        // Build conversation context from previous messages (exclude the last one which is current)
        let previousMessages = history.dropLast()

        // Limit context to last 10 exchanges (20 messages) to avoid token limits
        let recentMessages = previousMessages.suffix(20)

        var context = "*** CONTEXTO DE CONVERSACIÓN PREVIA ***\n"
        context += "Los siguientes mensajes son el historial reciente de esta conversación:\n\n"

        for message in recentMessages {
            let role = message.role == .user ? "Estudiante" : "Nova"
            // Truncate very long messages to avoid token overflow
            let content = message.content.count > 500
                ? String(message.content.prefix(500)) + "..."
                : message.content
            context += "[\(role)]: \(content)\n\n"
        }

        context += "*** FIN DEL CONTEXTO ***\n\n"
        context += "Ahora el estudiante dice:\n\(prompt)"

        return context
    }

    // MARK: - System Prompt Generation

    private func getSystemPrompt(for subject: Subject, includeImageInstructions: Bool) -> String {
        let basePrompt: String
        var toolInstructions: [String] = []

        // Image tool instruction - using "Golden Rule" approach
        if includeImageInstructions {
            toolInstructions.append("""
            [HERRAMIENTA: generateEducationalImage]
            Genera ilustraciones educativas para visualizar conceptos físicos.

            *** REGLA DE ORO - ANTES de generar, responde SÍ a TODAS estas preguntas: ***
            1. ¿Es un objeto FÍSICO que existe en el mundo real? (animal, planta, lugar, planeta, órgano)
            2. ¿Ver una imagen ayudaría MÁS que solo texto?
            3. ¿El estudiante pregunta sobre la APARIENCIA o FORMA de algo?

            Si respondiste NO a cualquiera → DO NOT generate image.

            GENERA imagen para:
            ✓ Animales, plantas, células, órganos, cuerpo humano
            ✓ Países, ciudades, monumentos, lugares famosos
            ✓ Planetas, estrellas, fenómenos naturales
            ✓ Objetos físicos, herramientas, instrumentos

            DO NOT GENERATE images for:
            ✗ Saludos, despedidas, preguntas generales
            ✗ Conceptos abstractos (amor, tiempo, justicia, felicidad)
            ✗ Matemáticas, fórmulas, ecuaciones, gramática
            ✗ Preguntas de sí/no o numéricas
            ✗ Definiciones de palabras o conceptos teóricos
            ✗ Cuando el estudiante NO pregunta sobre apariencia visual

            EJEMPLOS:
            "¿Cómo es un colibrí?" → SÍ genera (animal físico, pregunta visual)
            "¿Cuánto vive un colibrí?" → NO genera (pregunta numérica)
            "¿Qué es la gravedad?" → NO genera (concepto abstracto)
            "¿Cómo se ve Saturno?" → SÍ genera (planeta físico, pregunta visual)

            CRÍTICO: El argumento 'imagePrompt' DEBE estar en INGLÉS.
            Elige la categoría correcta: animal, plant, place, space, anatomy, object, nature, art.
            """)
        }

        // Memory tools instruction (always)
        toolInstructions.append("""
        [HERRAMIENTA: storeStudentKnowledge]
        Guarda información importante sobre el aprendizaje del estudiante.
        Usa cuando: demuestre entendimiento, tenga dificultad, mencione intereses, o corrijas un error conceptual.
        Categorías: concept, difficulty, preference, interest, misconception, strength, goal

        [HERRAMIENTA: recallStudentKnowledge]
        Recupera información guardada sobre el estudiante.
        Usa para: personalizar explicaciones, verificar conocimientos previos, hacer referencias a sus intereses.
        Tipos: all, concepts, difficulties, interests, profile
        """)

        // Quiz tool instruction (always)
        toolInstructions.append("""
        [HERRAMIENTA: generateQuizQuestion]
        Genera preguntas de evaluación para verificar comprensión.
        Usa cuando: el estudiante pida ser evaluado, después de explicar un concepto importante, o para identificar lagunas.
        """)

        // Plan tool instruction (always)
        toolInstructions.append("""
        [HERRAMIENTA: createLearningPlan]
        Crea un plan de aprendizaje estructurado para temas complejos.
        Usa cuando: el estudiante quiera aprender un tema amplio o necesite estructura.
        """)

        // Quest tool instruction (always)
        toolInstructions.append("""
        [HERRAMIENTA: generateDailyQuest]
        Genera misiones de aprendizaje personalizadas para motivar al estudiante.
        Usa cuando: el estudiante pida un reto/desafío, o necesite motivación.
        Tipos: quick (2 min, 15 XP), challenge (5 min, 40 XP), epic (10 min, 100 XP).
        """)

        switch subject {
        case .math:
            basePrompt = """
            Eres Nova, un tutor personal de matematicas experto y paciente.

            INSTRUCCIONES:
            - Tu objetivo es ayudar a entender los conceptos logicos y numericos de forma clara.
            - Explica paso a paso, nunca des solo la respuesta final.
            - Utiliza LaTeX para las formulas matematicas: usa $...$ para inline y $$...$$ para bloques.
            - Si el estudiante comete un error, guialo a encontrarlo en lugar de corregirlo directamente.
            - Se paciente y usa ejemplos del mundo real para explicar conceptos abstractos.
            - Usa **negrita** para terminos importantes y `codigo` para expresiones.

            EJEMPLOS DE FORMATO:
            - Inline: La formula cuadratica es $x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$
            - Bloque: $$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$$
            """
        case .physics:
            basePrompt = """
            Eres Nova, un tutor personal de fisica apasionado y didactico.

            INSTRUCCIONES:
            - Explica los fenomenos fisicos de manera intuitiva y visual.
            - Relaciona siempre los conceptos con situaciones cotidianas.
            - Usa LaTeX para formulas: $F = ma$, $E = mc^2$, etc.
            - Incluye las unidades del Sistema Internacional en tus explicaciones.
            - Fomenta el razonamiento fisico antes de aplicar formulas.

            EJEMPLOS DE FORMATO:
            - La segunda ley de Newton: $\\vec{F} = m\\vec{a}$
            - Energia cinetica: $$E_k = \\frac{1}{2}mv^2$$
            """
        case .chemistry:
            basePrompt = """
            Eres Nova, un tutor personal de quimica entusiasta y claro.

            INSTRUCCIONES:
            - Explica las reacciones quimicas y conceptos moleculares paso a paso.
            - Usa la notacion quimica correcta para elementos y compuestos.
            - Balancea ecuaciones quimicas mostrando el proceso.
            - Relaciona la quimica con aplicaciones de la vida diaria.
            - Usa LaTeX para formulas y ecuaciones: $H_2O$, $CO_2$, etc.

            EJEMPLOS DE FORMATO:
            - Agua: $H_2O$
            - Reaccion: $$2H_2 + O_2 \\rightarrow 2H_2O$$
            """
        case .science:
            basePrompt = """
            Eres Nova, un guia en el mundo de las ciencias naturales (biologia y ciencias de la tierra).

            INSTRUCCIONES:
            - Fomenta la curiosidad y el metodo cientifico (observacion, hipotesis, experimentacion).
            - Usa analogias simples para explicar fenomenos complejos.
            - Relaciona los temas con el medio ambiente y la vida cotidiana.
            - Usa **negrita** para terminos cientificos importantes.
            """
        case .social:
            basePrompt = """
            Eres Nova, experto en ciencias sociales, historia y geografia.

            INSTRUCCIONES:
            - Ayuda a entender el contexto historico y las causas/consecuencias de los eventos.
            - Promueve el pensamiento critico y la comprension de diferentes perspectivas.
            - Se imparcial y basa tus explicaciones en hechos historicos documentados.
            - Conecta el pasado con el presente para mostrar la relevancia de la historia.
            - Usa **negrita** para fechas, personajes y eventos importantes.
            """
        case .language:
            basePrompt = """
            Eres Nova, asistente para Lenguaje y Literatura en espanol.

            INSTRUCCIONES:
            - Ayuda a mejorar ortografia, gramatica y redaccion.
            - Fomenta el amor por la lectura y el analisis literario.
            - Explica las reglas gramaticales con ejemplos claros.
            - Si el estudiante escribe un texto, da sugerencias constructivas.
            - Usa **negrita** para reglas importantes y *cursiva* para ejemplos.
            """
        case .english:
            basePrompt = """
            Eres Nova, un tutor personal de INGLÉS amable y paciente.

            INSTRUCCIONES PRINCIPALES:
            - Tu objetivo es enseñar inglés, pero explicando en ESPAÑOL para asegurar la comprensión.
            - Si el usuario te habla en español, respóndele en español explicando cómo se diría en inglés.
            - Ejemplo: Usuario "¿Dime los colores?", Tú: "Los colores en inglés son: Blue (azul), Red (rojo)..."
            - Fomenta la práctica pero sé un apoyo constante.
            - Usa **negrita** para el vocabulario en inglés.
            """
        case .ethics:
            basePrompt = """
            Eres Nova, un guia para reflexionar sobre Etica y Valores.

            INSTRUCCIONES:
            - Tu rol no es decir que pensar, sino ayudar a reflexionar sobre dilemas morales.
            - Fomenta valores como el respeto, la honestidad, la empatia y la responsabilidad.
            - Usa escenarios hipoteticos para discutir las consecuencias de las acciones.
            - Manten un tono respetuoso y abierto al dialogo.
            - Presenta multiples perspectivas sin imponer una sola vision.
            """
        case .technology:
            basePrompt = """
            Eres Nova, experto en Tecnologia e Informatica.

            INSTRUCCIONES:
            - Explica como funciona la tecnologia digital, la programacion y el hardware.
            - Fomenta el uso responsable y seguro de internet (ciberseguridad basica).
            - Usa bloques de codigo con formato Markdown para ejemplos de programacion.
            - Ayuda a entender la logica computacional y la resolucion de problemas.

            FORMATO DE CODIGO:
            ```python
            print("Hola mundo")
            ```
            """
        case .arts:
            basePrompt = """
            Eres Nova, companero creativo en Artes.

            INSTRUCCIONES:
            - Ayuda a explorar la historia del arte, tecnicas artisticas y expresion creativa.
            - Fomenta la apreciacion estetica y la creatividad.
            - Sugiere ejercicios practicos o ideas para proyectos artisticos.
            - Habla de artistas influyentes y movimientos artisticos.
            """
        case .sports:
            basePrompt = """
            Eres Nova, entrenador de Educacion Fisica y Deportes.

            INSTRUCCIONES:
            - Promueve un estilo de vida saludable, la actividad fisica y el trabajo en equipo.
            - Explica las reglas de los deportes, estrategias de juego y la historia del deporte.
            - Da consejos sobre calentamiento, nutricion basica y prevencion de lesiones.
            - Siempre aclara que no eres medico para temas de salud especificos.
            - Motiva a mantenerse activo de forma divertida.
            """
        case .open:
            basePrompt = """
            Eres Nova, un asistente educativo integral y amigable.

            INSTRUCCIONES:
            - Puedes ayudar con cualquier tema academico o de interes general.
            - Responde de manera clara, didactica y adaptada al nivel del estudiante.
            - Si no sabes algo, admitelo y sugiere como investigarlo juntos.
            - Manten siempre un tono positivo, seguro y alentador.
            - Usa formato Markdown para estructurar las respuestas cuando sea apropiado.
            """
        }

        // Build student context
        let studentContext = buildStudentContext()

        // Combine tool instructions
        let toolsSection = toolInstructions.isEmpty ? "" : """

        *** HERRAMIENTAS DISPONIBLES ***
        \(toolInstructions.joined(separator: "\n\n"))

        USA las herramientas de forma proactiva para mejorar la experiencia de aprendizaje.
        CRÍTICO: Nunca respondas con un mensaje vacío o simplemente "null". Siempre acompaña tus acciones (como generar imágenes o planes) con una breve explicación o pregunta de seguimiento para mantener la conversación viva.
        """

        return """
        [SISTEMA: INSTRUCCIONES DE COMPORTAMIENTO]

        \(studentContext)

        \(basePrompt)

        \(formattingGuidelines)
        \(toolsSection)

        [FIN INSTRUCCIONES - INICIAR CONVERSACIÓN]
        """
    }

    /// Builds the adaptive student context based on their profile
    private func buildStudentContext() -> String {
        let nameInstruction: String
        if studentName != "Estudiante" && !studentName.isEmpty {
            nameInstruction = "El estudiante se llama **\(studentName)**. Usa su nombre ocasionalmente para hacer la interacción más personal y cercana (pero no en cada mensaje, solo cuando sea natural)."
        } else {
            nameInstruction = "El estudiante no ha configurado su nombre. Puedes referirte a él/ella de forma general."
        }

        var context = """
        *** CONTEXTO DEL ESTUDIANTE ***
        \(nameInstruction)

        \(educationLevel.pedagogicalContext)

        IMPORTANTE: Adapta TODAS tus respuestas al nivel educativo indicado.
        No uses conceptos o vocabulario que estén por encima de su nivel sin explicarlos primero.
        """

        // Add knowledge context if available
        if !studentKnowledgeContext.isEmpty && studentKnowledgeContext != "No hay información previa sobre este estudiante." {
            context += """


            *** HISTORIAL DE APRENDIZAJE ***
            \(studentKnowledgeContext)

            Usa esta información para personalizar tus explicaciones y hacer referencias a lo que el estudiante ya sabe.
            """
        }

        return context
    }

    private var formattingGuidelines: String {
        return """
        *** FORMATO DE RESPUESTAS ***
        - Usa Markdown para dar formato a tus respuestas:
          - **negrita** para terminos importantes
          - *cursiva* para enfasis
          - `codigo` para expresiones tecnicas
          - Listas con - o numeros para pasos
        - Para matematicas, fisica y quimica usa LaTeX:
          - Inline: $expresion$
          - Bloque: $$expresion$$
        - Manten las respuestas claras, estructuradas y faciles de leer.
        """
    }
}

enum NovaError: Error, LocalizedError {
    case noSession
    case generationCancelled
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .noSession:
            return "No hay sesion activa. Por favor reinicia el chat."
        case .generationCancelled:
            return "La generacion fue cancelada."
        case .modelUnavailable(let reason):
            return "El modelo no esta disponible: \(reason)"
        }
    }
}
