import UIKit
import Observation
import AVFoundation
import os

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

    // MARK: - Visualization
    private var visualizationTask: Task<Void, Never>?

    init(studentName: String = "Estudiante", educationLevel: EducationLevel = .secondary) {
        // Always start voice mode with a fresh session to avoid context accumulation
        llmService.createSession(
            for: .open,
            studentName: studentName,
            educationLevel: educationLevel,
            interactionMode: .voice,
            forceRecreate: true
        )
        setupAudioSession()
        startVisualizationLoop()
        
        // Subscription to playback finished to restart loop
        ttsService.onSpeechFinished = { [weak self] in
            guard let self = self else { return }
            // Only restart if we are still in a valid state (e.g. not idle due to stop pressed)
            // If state is speaking, it means we just finished speaking, so we loop back to listening.
            if self.state == .speaking {
                self.startListening()
            }
        }
    }


    // MARK: - Audio Session Management

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.overrideOutputAudioPort(.speaker) // FORCE SPEAKER OUTPUT
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Failed to setup audio session")
            state = .error("Error de audio. Verifica los permisos del micrófono.")
        }
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
        if case .error = state { state = .idle }
        startListening()
    }
    
    func stopSession() {
        stopListening()
        stopVisualizationLoop()
        ttsService.stop()
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
    
    // MARK: - Internal Logic
    
    private func startListening() {
        // TTS stops automatically when speaking finishes or is interrupted by logic
        // We trust the global session configuration (.playAndRecord)
        
        do {
            try speechService.startRecording()
            state = .listening
            currentTranscript = ""
            startSilenceDetection()
        } catch {
            state = .error("No se pudo iniciar el micrófono: \(error.localizedDescription)")
        }
    }
    
    private func stopListening() {
        speechService.stopRecording()
        stopSilenceDetection()
    }

    private func processUserRequest() {
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

        Task {
            do {
                // Reset TTS stream state (Task inherits @MainActor - no MainActor.run needed)
                ttsService.resetStream()
                // Start Batching: tells TTS "I'm about to give you multiple sentences, don't finish yet"
                ttsService.startBatch()

                // Use Streaming Response
                var fullResponse = ""
                var sentenceBuffer = ""
                // Regex for sentence endings (., !, ?, etc.)
                let sentenceEndRegex = try Regex("[.!?\\n]")

                for try await token in llmService.streamResponse(prompt: text, history: []) {
                    fullResponse += token
                    sentenceBuffer += token

                    // Check if we have a complete sentence or substantial pause
                    if token.contains(sentenceEndRegex) || sentenceBuffer.count > 50 {
                        let chunkToSpeak = sentenceBuffer
                        sentenceBuffer = ""

                        if state == .processing { state = .speaking } // Switch to speaking ASAP
                        speakStreamedChunk(chunkToSpeak)
                    }
                }

                // Speak any remaining text
                if !sentenceBuffer.isEmpty {
                    speakStreamedChunk(sentenceBuffer)
                }

                lastResponse = fullResponse

                // End Batching: tells TTS "That was the last sentence"
                ttsService.endBatch()
            } catch {
                // Speak the error (friendly)
                ttsService.speak("Lo siento, tuve un problema técnico. ¿Puedes repetirlo?", id: UUID())

                state = .error("Error: \(error.localizedDescription)")
                // Ensure we end batch nicely on error
                ttsService.endBatch()

                // Reset to idle after a delay so they can try again?
                // Or keep error state. The avatar tap resets it.
            }
        }
    }
    
    private func speakStreamedChunk(_ text: String) {
        state = .speaking
        let id = UUID()
        let cleanText = sanitizeForSpeech(text)
        if !cleanText.isEmpty {
            ttsService.speak(cleanText, id: id)
        }
    }
    

    
    private func sanitizeForSpeech(_ text: String) -> String {
        var clean = text

        // 1. LaTeX blocks → "fórmula" (before stripping $ symbols)
        clean = clean.replacingOccurrences(of: "\\$\\$[^$]+\\$\\$", with: " fórmula ", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "\\$[^$]+\\$", with: " fórmula ", options: .regularExpression)

        // 2. Code blocks → skip
        clean = clean.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "`[^`]+`", with: "", options: .regularExpression)

        // 3. Markdown images ![alt](url) → remove
        clean = clean.replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^)]*\\)", with: "", options: .regularExpression)

        // 4. Markdown links [text](url) → keep text only
        clean = clean.replacingOccurrences(of: "\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)

        // 5. Markdown symbols: *, #, _, ~, `, >, |, ^
        clean = clean.replacingOccurrences(of: "[*#_~`>|^]", with: "", options: .regularExpression)

        // 6. Horizontal rules
        clean = clean.replacingOccurrences(of: "-{3,}", with: "", options: .regularExpression)

        // 7. Bullet/numbered list prefixes
        clean = clean.replacingOccurrences(of: "(?m)^\\s*[-•●]\\s+", with: "", options: .regularExpression)
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
    
    // MARK: - Silence Detection & Visualization
    
    // MARK: - internal State
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
                        if !speechService.transcribedText.isEmpty {
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
