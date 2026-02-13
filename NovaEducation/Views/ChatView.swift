import SwiftUI
import SwiftData
import FoundationModels

struct ChatView: View {
    let subject: Subject
    @State private var viewModel: ChatViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var history: [ChatMessage]
    @Query private var settingsArray: [UserSettings]
    @State private var sessionStartTime: Date?
    @State private var showingModelUnavailableAlert = false

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

                // Image generation banner
                ImageGenerationBanner(
                    state: viewModel.imageGenerationState,
                    subjectColor: subject.color
                )
                .animation(.spring(response: 0.4), value: viewModel.imageGenerationState.isActive)

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
                    onBack: {
                        dismiss()
                    },
                    onDelete: {
                        textToSpeechService.stop()
                        viewModel.clearHistory(context: modelContext, messages: history)
                    }
                )
            }

            // XP Gain Toast Overlay
            if viewModel.showXPToast {
                VStack {
                    XPGainToast(
                        amount: viewModel.lastXPGained,
                        multiplier: viewModel.lastMultiplier
                    )
                    .padding(.horizontal)
                    .padding(.top, 100) // Below header

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.showXPToast)
        .navigationBarHidden(true)
        .onAppear {
            startSession()
            configureSessionWithStudentData()
        }
        .onDisappear {
            textToSpeechService.stop()
            viewModel.stopGenerating()
            endSession()
        }
        .alert("Apple Intelligence no disponible", isPresented: $showingModelUnavailableAlert) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text("Para usar Nova, necesitas activar Apple Intelligence en Configuración > Apple Intelligence y Siri.")
        }
        .fullScreenCover(isPresented: $viewModel.showLevelUpCelebration) {
            LevelUpCelebration(
                newLevel: viewModel.newLevel,
                newTitle: viewModel.newTitle,
                onDismiss: {
                    viewModel.dismissLevelUpCelebration()
                }
            )
        }
    }

    // MARK: - Model Unavailable Banner
    @ViewBuilder
    private func modelUnavailableBanner(reason: SystemLanguageModel.Availability.UnavailableReason) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                subject.color.opacity(0.05),
                Color(uiColor: .systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Messages Scroll View
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Welcome message if empty
                    if history.isEmpty {
                        welcomeMessage
                    }

                    ForEach(history) { msg in
                        MessageBubble(
                            message: msg,
                            isStreaming: viewModel.isGenerating && msg.id == history.last?.id && msg.role == .assistant
                        )
                        .id(msg.id)
                    }

                    // Show thinking bubble when generating image
                    if viewModel.isGeneratingImage {
                        ThinkingBubble(subjectColor: subject.color)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .id("thinking-bubble")
                    }
                }
                .animation(.spring(response: 0.4), value: viewModel.isGeneratingImage)
                .padding()
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: history.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: history.last?.content) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isGeneratingImage) { _, isGenerating in
                if isGenerating {
                    scrollToThinkingBubble(proxy: proxy)
                }
            }
        }
    }

    // MARK: - Welcome Message
    private var welcomeMessage: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(subject.color.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: subject.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(subject.color)
            }

            VStack(spacing: 8) {
                Text("Bienvenido a \(subject.displayName)")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Hazme cualquier pregunta sobre este tema y te ayudare a entenderlo mejor.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Feature hints based on subject
            if subject.hasSpecialKeyboard {
                featureHints
            }

            // Image generation hint for supported subjects
            if subject.supportsImages {
                imageHints
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
    }

    private var imageHints: some View {
        VStack(spacing: 8) {
            if !subject.hasSpecialKeyboard {
                Divider()
                    .padding(.vertical, 8)
            }

            HStack(spacing: 8) {
                Image(systemName: "apple.image.playground")
                    .foregroundStyle(subject.color)
                Text("Puedo generar imagenes para ayudarte a visualizar conceptos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var featureHints: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 8)

            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .foregroundStyle(subject.color)
                Text("Usa el teclado de simbolos para escribir formulas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "function")
                    .foregroundStyle(subject.color)
                Text("Nova puede mostrar formulas matematicas")
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
        HStack(spacing: 12) {
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
                             .padding(8)
                     }
                     
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
                 }
                 .padding(.horizontal, 16)
                 .padding(.vertical, 8)
                 .background(.ultraThinMaterial)
                 .glassEffect(.regular, in: Capsule())
                 .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Standard UI (Original) with Lock Hint
                HStack(spacing: 8) {
                    if speechService.isRecording {
                         // Recording UI
                         HStack(spacing: 12) {
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
                                 
                                 VStack(spacing: 16) {
                                     // Lock Hint
                                     HStack(spacing: 4) {
                                        Image(systemName: "lock.open")
                                            .font(.caption)
                                        Text("Desliza arriba")
                                            .font(.caption)
                                     }
                                     .foregroundStyle(.secondary)
                                     .opacity(verticalDragOffset < -10 ? 1 : 0.5)
                                     .offset(y: verticalDragOffset < -10 ? verticalDragOffset * 0.2 : 0)

                                     // Cancel Hint
                                     HStack(spacing: 4) {
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
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: Capsule())
                .animation(.spring(response: 0.3), value: speechService.isRecording)
                .animation(.spring(response: 0.3), value: isRecordingCancelled)
                
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
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Mic Button (Visible when no text or recording)
                        if !canSend || speechService.isRecording {
                            micButton
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
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
                        .animation(.spring, value: verticalDragOffset)
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
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
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
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } catch {
            print("Error recording: \(error)")
        }
    }

    private func stopGesturedRecording() {
        speechService.stopRecording()
        
        if isRecordingCancelled {
            // Cancelled
            print("Recording cancelled")
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        } else {
            // Success: Send
            processAndSendRecording()
        }
        
        resetRecordingState()
    }
    
    // Locked mode actions
    private func cancelLockedRecording() {
        speechService.stopRecording()
        print("Locked recording cancelled")
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
             
             let generator = UINotificationFeedbackGenerator()
             generator.notificationOccurred(.success)
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
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func scrollToThinkingBubble(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo("thinking-bubble", anchor: .bottom)
        }
    }

    // MARK: - Session Configuration
    private func configureSessionWithStudentData() {
        guard !sessionConfigured else { return }

        // Get student data from settings
        let studentName = settings?.studentName ?? "Estudiante"
        let educationLevel = settings?.educationLevel ?? .secondary

        // Recreate the ViewModel with actual student data
        // This ensures the Foundation Model session has the correct adaptive prompt
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

        // Update Daily Activity
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DailyActivity>(predicate: #Predicate { $0.date == today })

        if (try? modelContext.fetch(descriptor).first) != nil {
            // Already active today
        } else {
            let newActivity = DailyActivity(date: Date(), wasActive: true)
            modelContext.insert(newActivity)
        }

        // Initialize achievements if needed
        AchievementManager.shared.initializeAchievements(context: modelContext)
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
