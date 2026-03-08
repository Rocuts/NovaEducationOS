import UIKit
import Observation
import AVFoundation
import os
import FoundationModels

enum VoiceModeState: Equatable {
    case idle
    case listening
    case processing
    case speaking
    case error(String)
}

@Observable
@MainActor
class VoiceModeManager {
    // MARK: - Logging
    private let logger = Logger(subsystem: "com.nova.education", category: "VoiceMode")

    // MARK: - State
    var state: VoiceModeState = .idle {
        didSet {
            logger.info("Voice state: \(String(describing: oldValue)) -> \(String(describing: self.state))")
            triggerHaptic(for: state)
        }
    }
    var audioLevel: Float = 0.0
    var currentTranscript: String = ""
    var lastResponse: String = ""

    // MARK: - Dependencies
    private let speechService = SpeechRecognitionService()
    private let ttsService = TextToSpeechService()
    private let llmService = FoundationModelService.shared

    // MARK: - Private Configuration
    private var silenceTask: Task<Void, Never>?
    private let silenceThreshold: Float = 0.05
    private let silenceDuration: TimeInterval = 1.5 // Seconds of silence to trigger end of speech
    private var transitionTask: Task<Void, Never>?
    private var responseTask: Task<Void, Never>?

    // MARK: - Visualization
    private var visualizationTask: Task<Void, Never>?
    private var isSessionActive = false

    /// Tracks the current conversation cycle number.
    /// Used to prevent stale callbacks from old cycles from interfering.
    private var cycleID: UInt = 0

    /// Maximum number of retry attempts for starting the audio engine
    private let maxRetries = 3

    init(studentName: String = "Estudiante", educationLevel: EducationLevel = .secondary) {
        // Always start voice mode with a fresh session to avoid context accumulation
        llmService.createSession(
            for: .open,
            studentName: studentName,
            educationLevel: educationLevel,
            interactionMode: .voice,
            forceRecreate: true
        )
        configureAudioSessionForVoice()
        startVisualizationLoop()

        // Subscription to playback finished to restart loop.
        // This is the CORE of the conversation loop:
        // TTS finishes -> onSpeechFinished fires -> we restart listening.
        ttsService.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            guard self.isSessionActive else {
                self.logger.info("Ignoring TTS finished callback because session is inactive")
                return
            }
            // Only restart listening if we're still in a speaking/processing state.
            // If the user manually stopped (.idle) or there's an error, don't restart.
            switch self.state {
            case .speaking, .processing:
                self.logger.info("TTS finished, transitioning to listening")
                self.transitionToListening()
            default:
                self.logger.info("TTS finished but state is \(String(describing: self.state)), not restarting")
            }
        }
    }

    // MARK: - Audio Session Management

    /// Configures the audio session for voice chat mode.
    /// This sets up .playAndRecord which supports both microphone input and speaker output.
    private func configureAudioSessionForVoice() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            logger.info("Audio session configured for voice chat")
        } catch {
            logger.error("Failed to setup audio session: \(error.localizedDescription)")
            state = .error("Error de audio. Verifica los permisos del micrófono.")
        }
    }

    /// CRITICAL: Resets the audio session between TTS and recognition.
    ///
    /// AVSpeechSynthesizer can internally modify the audio session's routing
    /// and configuration while it speaks. To ensure the microphone input is
    /// properly routed when we start recording again, we:
    /// 1. Deactivate the audio session (releases hardware)
    /// 2. Wait briefly for hardware to settle
    /// 3. Reactivate with our desired configuration
    ///
    /// This is the KEY difference from the previous implementation which only
    /// called setActive(true) without first deactivating.
    private func resetAudioSessionForRecording() throws {
        let session = AVAudioSession.sharedInstance()

        // Step 1: Deactivate to release all audio resources
        // The .notifyOthersOnDeactivation flag tells the system we're done
        // with audio, allowing it to fully reset the audio hardware routing.
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            logger.info("Audio session deactivated")
        } catch {
            // Deactivation can fail if there's still I/O running.
            // This is not fatal - we'll try to reactivate anyway.
            logger.warning("Audio session deactivation failed (non-fatal): \(error.localizedDescription)")
        }

        // Step 2: Reconfigure and reactivate
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.overrideOutputAudioPort(.speaker)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        logger.info("Audio session reactivated for recording")
    }

    // MARK: - Public API

    func startThinking() {
        processUserRequest()
    }

    func startSession() {
        // Allow starting from idle, speaking, or error states (not listening/processing)
        switch state {
        case .idle, .speaking, .error:
            break
        default:
            return
        }

        guard llmService.availability == .available else {
            state = .error("Apple Intelligence no está disponible. Actívalo o espera a que el modelo termine de prepararse.")
            return
        }

        isSessionActive = true
        startVisualizationLoop()
        if case .error = state { state = .idle }
        transitionToListening()
    }

    func stopSession() {
        isSessionActive = false
        // Increment cycle ID to invalidate any pending callbacks
        cycleID &+= 1
        transitionTask?.cancel()
        responseTask?.cancel()
        stopListening()
        llmService.cancel()
        ttsService.stop()
        stopVisualizationLoop()
        state = .idle
    }

    func toggleListening() {
        if state == .listening {
            processUserRequest()
        } else if case .error = state {
            state = .idle
            startSession()
        } else {
            startSession()
        }
    }

    // MARK: - Conversation Loop Core

    /// Transitions from TTS-finished to listening.
    ///
    /// This is the critical transition point where previous implementations failed.
    /// The sequence is:
    /// 1. Reset the audio session (deactivate + reactivate) to clear TTS state
    /// 2. Start recording with a FRESH AVAudioEngine (created inside SpeechRecognitionService)
    /// 3. If it fails, retry up to maxRetries times with increasing delays
    private func transitionToListening() {
        guard isSessionActive else { return }
        let currentCycle = cycleID

        transitionTask?.cancel()
        transitionTask = Task { @MainActor in
            // Guard: if the cycle changed (user stopped), abort
            guard self.isCycleActive(currentCycle) else { return }

            var lastError: Error?

            for attempt in 1...self.maxRetries {
                // Guard: check cycle ID on each retry
                guard self.isCycleActive(currentCycle) else { return }

                do {
                    // Step 1: Reset audio session between TTS and recording
                    try self.resetAudioSessionForRecording()

                    // Step 2: Small delay to let hardware fully settle
                    // This is especially important on physical devices where
                    // the audio hardware routing change needs time to propagate.
                    if attempt > 1 {
                        // Increasing delay for retries
                        let delayMs = 100 * attempt
                        try? await Task.sleep(for: .milliseconds(delayMs))
                        guard self.isCycleActive(currentCycle) else { return }
                    }

                    // Step 3: Start recording (creates a fresh AVAudioEngine internally)
                    try self.speechService.startRecording()

                    // Success!
                    self.state = .listening
                    self.currentTranscript = ""
                    self.startSilenceDetection()
                    self.logger.info("Listening started on attempt \(attempt)")
                    return

                } catch {
                    guard self.isCycleActive(currentCycle) else { return }
                    lastError = error
                    self.logger.warning("startRecording attempt \(attempt)/\(self.maxRetries) failed: \(error.localizedDescription)")

                    // Wait before retrying
                    let retryDelay = 200 * attempt
                    try? await Task.sleep(for: .milliseconds(retryDelay))
                }
            }

            // All retries exhausted
            guard self.isCycleActive(currentCycle) else { return }
            self.logger.error("Failed to start recording after \(self.maxRetries) attempts")
            self.state = .error("No se pudo reactivar el micrófono: \(lastError?.localizedDescription ?? "error desconocido")")
        }
    }

    private func stopListening() {
        speechService.stopRecording()
        stopSilenceDetection()
    }

    // MARK: - Request Processing

    private func processUserRequest() {
        guard isSessionActive else { return }
        stopListening()

        let text = speechService.transcribedText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state = .idle
            return
        }

        // Validate content safety before sending to AI
        let safetyResult = ContentSafetyService.validate(text)
        if case .unsafe(let reason) = safetyResult {
            state = .error(reason)
            return
        }

        currentTranscript = text
        state = .processing

        // Increment cycle ID for this new processing cycle
        cycleID &+= 1
        let processingCycle = cycleID

        responseTask?.cancel()
        responseTask = Task {
            do {
                // Reset TTS stream state
                ttsService.resetStream()
                // Start Batching: tells TTS "I'm about to give you multiple sentences, don't finish yet"
                ttsService.startBatch()

                // Use Streaming Response
                var fullResponse = ""
                var sentenceBuffer = ""
                let sentenceEndRegex = try Regex("[.!?\\n]")

                for try await token in llmService.streamResponse(
                    prompt: text,
                    history: [],
                    interactionMode: .voice
                ) {
                    // Check if this cycle is still active
                    guard self.isCycleActive(processingCycle) else { break }

                    fullResponse += token
                    sentenceBuffer += token

                    // Check if we have a complete sentence or substantial chunk
                    if token.contains(sentenceEndRegex) || sentenceBuffer.count > 50 {
                        let chunkToSpeak = sentenceBuffer
                        sentenceBuffer = ""

                        if state == .processing { state = .speaking }
                        speakStreamedChunk(chunkToSpeak)
                    }
                }

                guard self.isCycleActive(processingCycle) else {
                    self.ttsService.resetStream()
                    return
                }

                // Speak any remaining text
                if !sentenceBuffer.isEmpty {
                    speakStreamedChunk(sentenceBuffer)
                }

                guard self.isCycleActive(processingCycle) else {
                    self.ttsService.resetStream()
                    return
                }
                lastResponse = fullResponse

                // End Batching: tells TTS "That was the last sentence"
                // This will eventually trigger onSpeechFinished -> transitionToListening
                ttsService.endBatch()
            } catch {
                guard self.isCycleActive(processingCycle) else { return }
                if error is CancellationError { return }

                // Speak the error (friendly)
                ttsService.resetStream()
                ttsService.speak("Lo siento, tuve un problema técnico. ¿Puedes repetirlo?", id: UUID())

                state = .error("Error: \(error.localizedDescription)")
            }
        }
    }

    private func speakStreamedChunk(_ text: String) {
        guard isSessionActive else { return }
        let id = UUID()
        let cleanText = sanitizeForSpeech(text)
        if !cleanText.isEmpty {
            state = .speaking
            ttsService.speak(cleanText, id: id)
        }
    }

    // MARK: - Text Sanitization for Speech

    private func sanitizeForSpeech(_ text: String) -> String {
        var clean = text

        // 1. LaTeX blocks -> "formula" (before stripping $ symbols)
        clean = clean.replacingOccurrences(of: "\\$\\$[^$]+\\$\\$", with: " fórmula ", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "\\$[^$]+\\$", with: " fórmula ", options: .regularExpression)

        // 2. Code blocks -> skip
        clean = clean.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "`[^`]+`", with: "", options: .regularExpression)

        // 3. Markdown images ![alt](url) -> remove
        clean = clean.replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^)]*\\)", with: "", options: .regularExpression)

        // 4. Markdown links [text](url) -> keep text only
        clean = clean.replacingOccurrences(of: "\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)

        // 5. Markdown symbols: *, #, _, ~, `, >, |, ^
        clean = clean.replacingOccurrences(of: "[*#_~`>|^]", with: "", options: .regularExpression)

        // 6. Horizontal rules
        clean = clean.replacingOccurrences(of: "-{3,}", with: "", options: .regularExpression)

        // 7. Bullet/numbered list prefixes
        clean = clean.replacingOccurrences(of: "(?m)^\\s*[-\u{2022}\u{25CF}]\\s+", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "(?m)^\\s*\\d+\\.\\s+", with: "", options: .regularExpression)

        // 8. Bracketed artifacts: [Tool:...], [Thinking...], etc.
        clean = clean.replacingOccurrences(of: "\\[[^\\]]{0,50}\\]", with: "", options: .regularExpression)

        // 9. URLs
        clean = clean.replacingOccurrences(of: "https?://\\S+", with: "", options: .regularExpression)

        // 10. Emojis
        clean = clean.unicodeScalars.filter { !isEmoji($0) }.map(String.init).joined()

        // 11. Collapse whitespace
        clean = clean.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)

        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isEmoji(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x1F600...0x1F64F, // Emoticons
             0x1F300...0x1F5FF, // Misc Symbols and Pictographs
             0x1F680...0x1F6FF, // Transport and Map
             0x2600...0x26FF,   // Misc symbols
             0x2700...0x27BF,   // Dingbats
             0xFE00...0xFE0F,   // Variation Selectors
             0x1F900...0x1F9FF, // Supplemental Symbols and Pictographs
             0x1F1E6...0x1F1FF: // Flags
            return true
        default:
            return false
        }
    }

    // MARK: - Silence Detection

    private var lastSpeechTime: Date = Date()
    private var isSpeechDetected: Bool = false

    private func startSilenceDetection() {
        silenceTask?.cancel()
        lastSpeechTime = Date()
        isSpeechDetected = false

        silenceTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }
                guard self.isSessionActive else { break }

                // 1. Check audio level
                let currentLevel = speechService.audioLevel

                // 2. Detect Active Speech
                if currentLevel > silenceThreshold {
                    lastSpeechTime = Date()
                    isSpeechDetected = true
                }

                // 3. Detect Silence AFTER Speech
                if isSpeechDetected {
                    let timeSinceLastSpeech = Date().timeIntervalSince(lastSpeechTime)

                    if timeSinceLastSpeech > silenceDuration {
                        if !speechService.transcribedText.isEmpty, self.isSessionActive {
                            processUserRequest()
                        } else {
                            isSpeechDetected = false
                        }
                    }
                }
            }
        }
    }

    private func stopSilenceDetection() {
        silenceTask?.cancel()
        silenceTask = nil
    }

    // MARK: - Animation Loop

    private func startVisualizationLoop() {
        visualizationTask?.cancel()
        visualizationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(30))
                guard !Task.isCancelled else { break }
                updateAudioLevel()
            }
        }
    }

    private func updateAudioLevel() {
        switch state {
        case .listening:
            audioLevel = speechService.audioLevel

        case .speaking:
            if ttsService.isSpeaking {
                let time = Date().timeIntervalSinceReferenceDate
                let sine = abs(sin(time * 5))
                let noise = Float.random(in: 0.2...0.8)
                audioLevel = Float(sine) * 0.5 + noise * 0.5
            } else {
                audioLevel = 0.0
            }

        case .processing:
            audioLevel = 0.2 + Float(sin(Date().timeIntervalSinceReferenceDate * 10) * 0.1)

        case .idle, .error:
            audioLevel = 0.0
        }
    }

    private func stopVisualizationLoop() {
        visualizationTask?.cancel()
        visualizationTask = nil
    }

    private func isCycleActive(_ cycle: UInt) -> Bool {
        isSessionActive && cycleID == cycle && !Task.isCancelled
    }

    // MARK: - Haptics

    private func triggerHaptic(for state: VoiceModeState) {
        switch state {
        case .listening:
            Nova.Haptics.light()
        case .processing:
            Nova.Haptics.medium()
        case .speaking:
            Nova.Haptics.soft()
        case .error:
            Nova.Haptics.error()
        case .idle:
            break
        }
    }
}
