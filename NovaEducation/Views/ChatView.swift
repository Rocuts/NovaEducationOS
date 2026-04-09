import SwiftUI
import SwiftData
import FoundationModels
import os

private let logger = Logger(subsystem: "com.nova.education", category: "ChatView")

struct ChatView: View {
    let subject: Subject
    @State private var viewModel: ChatViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var history: [ChatMessage]
    @Query private var settingsArray: [UserSettings]
    @State private var sessionStartTime: Date?
    @State private var showingModelUnavailableAlert = false
    @State private var showVoiceMode = false
    @State private var showDeleteConfirmation = false
    @Environment(FocusManager.self) private var focusManager
    @Namespace private var inputGlassNamespace

    private var settings: UserSettings? {
        settingsArray.first
    }

    /// Check if Foundation Models are available
    private var modelAvailability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    /// Flag to track if session has been configured with student data
    @State private var sessionConfigured = false

    init(subject: Subject) {
        self.subject = subject
        let subjectId = subject.id
        _history = Query(filter: #Predicate { $0.subjectId == subjectId }, sort: \.timestamp)
        // Initialize with defaults; will be updated with actual student data in .task
        _viewModel = State(initialValue: ChatViewModel(subject: subject))
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Model unavailable banner
                if case .unavailable(let reason) = modelAvailability {
                    modelUnavailableBanner(reason: reason)
                }

                // Messages
                messagesScrollView

                // Subject-specific Keyboard Toolbar
                if subject.hasSpecialKeyboard {
                    SubjectKeyboardToolbar(
                        text: $viewModel.currentInput,
                        keyboardType: subject.keyboardType
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Input Area
                inputArea
            }
            .environment(textToSpeechService)
            .background(backgroundGradient)
            .safeAreaInset(edge: .top) {
                // Custom Liquid Glass Header
                ChatHeaderView(
                    subject: subject,
                    isThinking: viewModel.isGenerating,
                    isListening: speechService.isRecording,
                    audioLevel: speechService.audioLevel,
                    onBack: {
                        dismiss()
                    },
                    onDelete: {
                        showDeleteConfirmation = true
                    },
                    onVoiceMode: {
                        showVoiceMode = true
                    }
                )
            }

            // Focus Phase Indicator (se muestra durante modo focus)
            if focusManager.isFocusModeActive && focusManager.currentPhase != .idle {
                VStack {
                    Spacer()
                    HStack {
                        FocusPhaseIndicator(
                            phase: focusManager.currentPhase,
                            sessionMinutes: focusManager.focusMinutes
                        )
                        Spacer()
                    }
                    .padding(.horizontal, Nova.Spacing.lg)
                    .padding(.bottom, 80)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(Nova.Animation.entranceMedium, value: focusManager.currentPhase)
                .allowsHitTesting(false)
                .zIndex(50)
            }

            // Particle Explosion for big XP gains or Level Up
            if viewModel.showParticleExplosion {
                ParticleExplosionView(color: subject.color)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                    .zIndex(99)
            }
        }
        .animation(Nova.Animation.springDefault, value: viewModel.showParticleExplosion)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            startSession()
            configureSessionWithStudentData()
            focusManager.startTimer()
        }
        .onDisappear {
            textToSpeechService.stop()
            viewModel.stopGenerating()
            endSession()
            focusManager.stopTimer()
        }
        .alert("Apple Intelligence no disponible", isPresented: $showingModelUnavailableAlert) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text("Para usar Nova, necesitas activar Apple Intelligence en Configuración > Apple Intelligence y Siri.")
        }
        .fullScreenCover(isPresented: $viewModel.showLevelUpCelebration) {
            LevelUpCelebration(
                newLevel: viewModel.newLevel,
                previousLevel: viewModel.previousLevel,
                newTitle: viewModel.newTitle,
                onDismiss: {
                    viewModel.dismissLevelUpCelebration()
                }
            )
        }
        .fullScreenCover(isPresented: $showVoiceMode) {
            VoiceModeView()
        }
        .confirmationDialog("¿Eliminar conversación?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                textToSpeechService.stop()
                viewModel.clearHistory(context: modelContext, messages: history)
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se eliminarán todos los mensajes de esta conversación. Esta acción no se puede deshacer.")
        }
        .onChange(of: viewModel.currentInput) { _, newValue in
            if newValue.count > 4000 {
                viewModel.currentInput = String(newValue.prefix(4000))
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )) {
            Button("Aceptar", role: .cancel) { }
            if let _ = viewModel.errorRecoverySuggestion {
                Button("Reintentar") {
                    viewModel.retryLastFailedMessage(context: modelContext, history: Array(history))
                }
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                if let suggestion = viewModel.errorRecoverySuggestion {
                    Text("\n" + suggestion)
                }
            }
        }
    }
    // MARK: - Model Unavailable Banner
    @ViewBuilder
    private func modelUnavailableBanner(reason: SystemLanguageModel.Availability.UnavailableReason) -> some View {
        HStack(spacing: Nova.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: Nova.Spacing.xxxs) {
                Text("Modelo no disponible")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(unavailableReasonText(reason))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if reason == .appleIntelligenceNotEnabled {
                Button("Activar") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, Nova.Spacing.lg)
        .padding(.vertical, Nova.Spacing.md)
        .background(.orange.opacity(0.1))
    }

    private func unavailableReasonText(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "Tu dispositivo no es compatible con Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Activa Apple Intelligence en Configuración."
        case .modelNotReady:
            return "El modelo se está descargando..."
        @unknown default:
            return "El modelo no está disponible en este momento."
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        AuroraBackgroundView(
            primaryColor: subject.color,
            secondaryColor: subject.color.opacity(0.5),
            intensity: 0.8
        )
        .ignoresSafeArea()
    }

    // MARK: - Messages Scroll View
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Nova.Spacing.lg) {
                    // Welcome message if empty
                    if history.isEmpty {
                        welcomeMessage
                    }

                    ForEach(history) { msg in
                        MessageBubble(
                            message: msg,
                            isStreaming: viewModel.isGenerating && msg.id == history.last?.id && msg.role == .assistant,
                            subjectColor: subject.color
                        )
                        .id(msg.id)
                    }

                }
                .padding()
                .padding(.bottom, Nova.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: history.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: history.last?.content) {
                scrollToBottom(proxy: proxy)
            }
        }
        .mask(
            VStack(spacing: 0) {
                // Fade superior: mensajes se disuelven hacia el header glass
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 28)
                // Contenido visible completo
                Rectangle()
                // Fade inferior: mensajes se disuelven hacia el input area
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 28)
            }
        )
    }

    // MARK: - Welcome Message
    private var welcomeMessage: some View {
        VStack(spacing: Nova.Spacing.lg) {
            NovaAvatarView(state: .idle)
                .frame(width: 115, height: 115)
                .shadow(color: subject.color.opacity(0.2), radius: 25)

            VStack(spacing: Nova.Spacing.sm) {
                if let name = settings?.studentName, name != "Estudiante", !name.isEmpty {
                    Text("Hola \(name), bienvenido a \(subject.displayName)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Bienvenido a \(subject.displayName)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                Text("Soy Nova, tu tutora personal. Preguntame lo que necesites y te ayudare paso a paso.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Feature hints based on subject
            if subject.hasSpecialKeyboard {
                featureHints
            }

            // 3D visualization hint
            renderHints
        }
        .padding(.vertical, Nova.Spacing.jumbo)
        .padding(.horizontal, Nova.Spacing.screenHorizontal)
    }

    private var renderHints: some View {
        VStack(spacing: Nova.Spacing.sm) {
            if !subject.hasSpecialKeyboard {
                Divider()
                    .padding(.vertical, Nova.Spacing.sm)
            }

            HStack(spacing: Nova.Spacing.sm) {
                Image(systemName: "cube.fill")
                    .foregroundStyle(subject.color)
                Text("Pídeme que te muestre figuras y modelos 3D interactivos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var featureHints: some View {
        VStack(spacing: Nova.Spacing.sm) {
            Divider()
                .padding(.vertical, Nova.Spacing.sm)

            HStack(spacing: Nova.Spacing.sm) {
                Image(systemName: "keyboard")
                    .foregroundStyle(subject.color)
                Text("Usa el teclado de símbolos para escribir fórmulas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Nova.Spacing.sm) {
                Image(systemName: "function")
                    .foregroundStyle(subject.color)
                Text("Nova puede mostrar fórmulas matemáticas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }



    @State private var speechService = SpeechRecognitionService()
    @State private var textToSpeechService = TextToSpeechService()
    @State private var dragOffset: CGFloat = 0
    @State private var verticalDragOffset: CGFloat = 0
    @State private var isRecordingCancelled = false
    @State private var isRecordingLocked = false
    
    // ... inside body ...

    // MARK: - Input Area
    private var inputArea: some View {
        GlassEffectContainer(spacing: Nova.Spacing.md) {
            HStack(spacing: Nova.Spacing.md) {
                // Text Input / Recording Locked UI
                if isRecordingLocked {
                     // Locked Recording UI
                     HStack {
                         Button {
                             cancelLockedRecording()
                         } label: {
                             Image(systemName: "trash")
                                 .font(.title2)
                                 .foregroundStyle(.red)
                                 .padding(Nova.Spacing.sm)
                         }
                         .accessibilityLabel("Cancelar grabación")
                         .accessibilityHint("Toca dos veces para cancelar la grabación de voz")

                         Spacer()

                         Text(speechService.transcribedText.isEmpty ? "Grabando..." : speechService.transcribedText)
                             .lineLimit(1)
                             .foregroundStyle(.primary)

                         Spacer()

                         // Stop & Send Button
                         Button {
                             sendLockedRecording()
                         } label: {
                             Image(systemName: "arrow.up.circle.fill")
                                 .font(.system(size: 32))
                                 .foregroundStyle(subject.color)
                         }
                         .accessibilityLabel("Enviar grabación")
                         .accessibilityHint("Toca dos veces para enviar el mensaje de voz")
                     }
                     .padding(.horizontal, Nova.Spacing.lg)
                     .padding(.vertical, Nova.Spacing.sm)
                     .glassEffect(.regular, in: Capsule())
                     .glassEffectID("inputField", in: inputGlassNamespace)
                     .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // Standard UI (Original) with Lock Hint
                    HStack(spacing: Nova.Spacing.sm) {
                        if speechService.isRecording {
                             // Recording UI
                             HStack(spacing: Nova.Spacing.md) {
                                 Image(systemName: "mic.fill")
                                     .symbolEffect(.pulse, isActive: true)
                                     .foregroundStyle(.red)

                                 if isRecordingCancelled {
                                     Text("Suelta para cancelar")
                                         .foregroundStyle(.secondary)
                                         .transition(.opacity)
                                 } else {
                                     Text(speechService.transcribedText.isEmpty ? "Escuchando..." : speechService.transcribedText)
                                         .foregroundStyle(.primary)
                                         .lineLimit(1)
                                         .transition(.opacity)

                                     Spacer()

                                     VStack(spacing: Nova.Spacing.lg) {
                                         // Lock Hint
                                         HStack(spacing: Nova.Spacing.xxs) {
                                            Image(systemName: "lock.open")
                                                .font(.caption)
                                            Text("Desliza arriba")
                                                .font(.caption)
                                         }
                                         .foregroundStyle(.secondary)
                                         .opacity(verticalDragOffset < -10 ? 1 : 0.5)
                                         .offset(y: verticalDragOffset < -10 ? verticalDragOffset * 0.2 : 0)

                                         // Cancel Hint
                                         HStack(spacing: Nova.Spacing.xxs) {
                                             Image(systemName: "chevron.left")
                                                 .font(.caption)
                                             Text("Desliza para cancelar")
                                                 .font(.caption)
                                         }
                                         .foregroundStyle(.secondary)
                                         .opacity(dragOffset < 0 ? 0.5 : 1)
                                     }
                                     .transition(.opacity)
                                 }
                             }
                        } else {
                            // Standard Text Field
                            TextField("Pregunta algo...", text: $viewModel.currentInput, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...5)

                            if !viewModel.currentInput.isEmpty {
                                Button {
                                    viewModel.currentInput = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityLabel("Borrar texto")
                                .accessibilityHint("Toca dos veces para limpiar el campo de texto")
                            }
                        }
                    }
                    .padding(.horizontal, Nova.Spacing.lg)
                    .padding(.vertical, Nova.Spacing.md)
                    .glassEffect(.regular, in: Capsule())
                    .glassEffectID("inputField", in: inputGlassNamespace)
                    .animation(Nova.Animation.springSnappy, value: speechService.isRecording)
                    .animation(Nova.Animation.springSnappy, value: isRecordingCancelled)

                    // Mic / Send Button
                    if !isRecordingLocked {
                        ZStack {
                            // Send Button (Visible when text exists and not recording)
                            if canSend && !speechService.isRecording {
                                Button {
                                    sendMessage()
                                } label: {
                                    Circle()
                                        .fill(subject.color)
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            Image(systemName: "arrow.up")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                }
                                .accessibilityLabel("Enviar mensaje")
                                .accessibilityHint("Toca dos veces para enviar tu mensaje")
                                .transition(.scale.combined(with: .opacity))
                            }

                            // Mic Button (Visible when no text or recording)
                            if !canSend || speechService.isRecording {
                                micButton
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .glassEffectID("actionButton", in: inputGlassNamespace)
                    }
                }
            }
            .padding(.horizontal, Nova.Spacing.lg)
            .padding(.vertical, Nova.Spacing.md)
        }
    }

    private var micButton: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Circle
                Circle()
                    .fill(isRecordingCancelled ? .red : (speechService.isRecording ? subject.color.opacity(0.2) : .secondary.opacity(0.1)))
                    .frame(width: speechService.isRecording ? 80 : 44, height: speechService.isRecording ? 80 : 44)
                
                // Lock Icon Animation (Slides up)
                if speechService.isRecording && !isRecordingCancelled {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .offset(y: -50 + verticalDragOffset) // Moves with drag
                        .opacity(verticalDragOffset < -20 ? 1 : 0)
                        .animation(Nova.Animation.springDefault, value: verticalDragOffset)
                }

                // Mic Icon
                Image(systemName: isRecordingCancelled ? "trash.fill" : (isRecordingLocked ? "mic.fill" : "mic.fill"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isRecordingCancelled ? .white : (speechService.isRecording ? subject.color : .secondary))
                    .symbolEffect(.bounce, value: speechService.isRecording)
                    .scaleEffect(speechService.isRecording ? 1.2 : 1.0)
                    .offset(y: isRecordingLocked ? 0 : (verticalDragOffset < 0 ? verticalDragOffset * 0.1 : 0)) // Slighly moves up
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
        }
        .frame(width: 44, height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grabar mensaje de voz")
        .accessibilityHint("Toca dos veces para grabar un mensaje de voz. Toca dos veces y mantén para grabar continuamente.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            if speechService.isRecording {
                speechService.stopRecording()
                processAndSendRecording()
                resetRecordingState()
            } else {
                startRecording()
            }
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        if !speechService.isRecording && !isRecordingLocked {
            startRecording()
        }
        
        if !isRecordingLocked {
            dragOffset = value.translation.width
            verticalDragOffset = value.translation.height
            
            // 1. Check for Vertical Lock
            // Threshold to lock: -60 points up
            if verticalDragOffset < -60 {
                withAnimation {
                    isRecordingLocked = true
                    verticalDragOffset = 0
                    dragOffset = 0
                    isRecordingCancelled = false
                }
                // Haptic Lock
                Nova.Haptics.heavy()
                return
            }

            // 2. Check for Horizontal Cancel (only if not moving significantly up)
            // Threshold to cancel: -60 points left
            if dragOffset < -60 && verticalDragOffset > -30 {
                withAnimation {
                    isRecordingCancelled = true
                }
            } else {
                withAnimation {
                    isRecordingCancelled = false
                }
            }
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        if isRecordingLocked {
            // Do nothing on release if locked
            return
        }
        stopGesturedRecording()
    }
    
    private func startRecording() {
        do {
            isRecordingCancelled = false
            dragOffset = 0
            verticalDragOffset = 0
            try speechService.startRecording()
            // Haptic feedback
            Nova.Haptics.medium()
        } catch {
            logger.error("Error recording: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func stopGesturedRecording() {
        speechService.stopRecording()
        
        if isRecordingCancelled {
            // Cancelled
            logger.info("Recording cancelled")
            Nova.Haptics.error()
        } else {
            // Success: Send
            processAndSendRecording()
        }
        
        resetRecordingState()
    }
    
    // Locked mode actions
    private func cancelLockedRecording() {
        speechService.stopRecording()
        logger.info("Locked recording cancelled")
        resetRecordingState()
    }
    
    private func sendLockedRecording() {
        speechService.stopRecording()
        processAndSendRecording()
        resetRecordingState()
    }
    
    private func processAndSendRecording() {
        if !speechService.transcribedText.isEmpty {
             if !viewModel.currentInput.isEmpty {
                 viewModel.currentInput += " " + speechService.transcribedText
             } else {
                 viewModel.currentInput = speechService.transcribedText
             }
             
             // Auto-Send
             sendMessage()
             
             Nova.Haptics.success()
        }
    }
    
    private func resetRecordingState() {
        withAnimation {
            isRecordingCancelled = false
            isRecordingLocked = false
            dragOffset = 0
            verticalDragOffset = 0
        }
    }

    private var canSend: Bool {
        !viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        modelAvailability == .available
    }

    private func sendMessage() {
        // Record focus message for session stats
        focusManager.recordFocusMessage()

        // Check model availability first
        guard modelAvailability == .available else {
            showingModelUnavailableAlert = true
            return
        }

        // Pass history to the view model for context
        viewModel.sendMessage(context: modelContext, history: Array(history))
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = history.last {
            withAnimation(Nova.Animation.exitMedium) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }


    // MARK: - Session Configuration
    private func configureSessionWithStudentData() {
        // Get student data from settings
        let studentName = settings?.studentName ?? "Estudiante"
        let educationLevel = settings?.educationLevel ?? .secondary

        if sessionConfigured {
            // Session already exists — reconfigure without replacing the instance
            viewModel.reconfigure(studentName: studentName, educationLevel: educationLevel)
            return
        }

        // First-time setup
        viewModel = ChatViewModel(
            subject: subject,
            studentName: studentName,
            educationLevel: educationLevel
        )

        // Configure with ModelContext for SwiftData operations (memory tools)
        viewModel.configure(with: modelContext)

        sessionConfigured = true
    }

    // MARK: - Tracking Logic
    private func startSession() {
        sessionStartTime = Date()
        
        // Capture container to create a background context
        let container = modelContext.container
        
        Task {
            BackgroundSessionManager.shared.initializeSession(container: container)
        }
    }

    private func endSession() {
        guard let start = sessionStartTime else { return }
        let end = Date()

        // 1. Save Session
        let session = StudySession(startTime: start, endTime: end, subjectId: subject.id)
        modelContext.insert(session)

        // 2. Update Quick Action (Last Subject)
        if let settings = settings {
            settings.lastSubjectId = subject.id
            settings.updatedAt = Date()
        }

        // 3. Check Achievements
        AchievementManager.shared.checkAchievements(context: modelContext)
    }
}

#Preview {
    NavigationStack {
        ChatView(subject: .math)
    }
    .modelContainer(for: [
        ChatMessage.self,
        UserSettings.self,
        StudySession.self,
        DailyActivity.self,
        Achievement.self,
        StudentKnowledge.self,
        QuizQuestion.self,
        LearningPlan.self,
        XPTransaction.self,
        DailyQuest.self
    ], inMemory: true)
}
