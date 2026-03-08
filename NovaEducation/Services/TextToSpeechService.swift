import AVFoundation
import Observation
import os

private let logger = Logger(subsystem: "com.nova.education", category: "TextToSpeech")

@Observable
@MainActor
class TextToSpeechService: NSObject, AVSpeechSynthesizerDelegate {
    var isSpeaking = false
    var currentlySpeakingID: UUID?
    private let synthesizer = AVSpeechSynthesizer()

    // Batching & Queue State
    private var isBatching = false
    private var queueCount = 0
    private var didNotifyFinished = false

    override init() {
        super.init()
        synthesizer.delegate = self
        // CRITICAL: Let AVSpeechSynthesizer use the application's audio session.
        // This ensures it shares the .playAndRecord session managed by VoiceModeManager
        // rather than creating its own private session that would conflict with
        // speech recognition. With this set to true (default), the synthesizer
        // uses our configured session, making the transition to recording cleaner.
        synthesizer.usesApplicationAudioSession = true
    }

    // Stream management
    private var isStreaming = false

    func speak(_ text: String, id: UUID) {
        // resetStream() es el único punto de reinicio antes de un nuevo turno.
        // NO llamar stop() aquí — destruye el estado de batch configurado por startBatch().

        currentlySpeakingID = id
        isSpeaking = true
        isStreaming = true

        queueCount += 1

        let utterance = AVSpeechUtterance(string: text)
        configureUtterance(utterance)

        // AVSpeechSynthesizer encola automáticamente si llamamos speak() múltiples veces
        synthesizer.speak(utterance)
    }

    // Configuración de voz en español con Calidad Premium (2026 Standard)
    private func configureUtterance(_ utterance: AVSpeechUtterance) {
        // 1. Define preferred hierarchy
        let preferredLocales = ["es-MX", "es-ES", "es-US"]
        var selectedVoice: AVSpeechSynthesisVoice?

        // 2. Search for Premium/Enhanced voices first
        // We iterate through locales and try to find the best quality for each before moving to the next locale.
        for locale in preferredLocales {
            let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == locale }

            // Try Premium first
            if let premium = voices.first(where: { $0.quality == .premium }) {
                selectedVoice = premium
                break
            }

            // Try Enhanced second
            if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
                selectedVoice = enhanced
                break
            }
        }

        // 3. Fallback: If no premium/enhanced found, just get the default for the preferred locale
        if selectedVoice == nil {
            for locale in preferredLocales {
                if let voice = AVSpeechSynthesisVoice(language: locale) {
                    selectedVoice = voice
                    break
                }
            }
        }

        // 4. Final Fallback (Safety)
        if selectedVoice == nil {
            selectedVoice = AVSpeechSynthesisVoice(language: "es-MX")
        }

        utterance.voice = selectedVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
    }

    func resetStream() {
        isStreaming = false
        queueCount = 0
        isBatching = false
        didNotifyFinished = false
    }

    func startBatch() {
        isBatching = true
    }

    func endBatch() {
        isBatching = false
        // El batch terminó: si la cola ya se vació durante el batching,
        // el delegate no pudo disparar el callback. Lo hacemos aquí incondicionalmente
        // si la cola está vacía y el sintetizador ya no habla.
        if queueCount == 0 && !synthesizer.isSpeaking {
            isSpeaking = false
            currentlySpeakingID = nil
            notifyFinishedIfNeeded()
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        isStreaming = false
        currentlySpeakingID = nil
        queueCount = 0
        isBatching = false
        didNotifyFinished = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    var onSpeechFinished: (() -> Void)?

    /// Fires the onSpeechFinished callback exactly once per batch/utterance cycle.
    /// Adds a small delay to ensure the audio hardware has truly released
    /// the speaker output before the caller tries to reconfigure for microphone input.
    private func notifyFinishedIfNeeded() {
        guard !didNotifyFinished else { return }
        didNotifyFinished = true
        logger.info("TTS finished - will notify after hardware settle delay")

        // CRITICAL: Add a 250ms delay before notifying.
        // AVSpeechSynthesizer's didFinish delegate fires when the last audio buffer
        // has been submitted, but the audio hardware may still be draining.
        // Without this delay, immediately starting AVAudioEngine for recording
        // can find the hardware in a transitional state, causing inputNode to
        // report 0 channels or an invalid format.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            logger.info("TTS hardware settle delay complete - firing onSpeechFinished")
            self.onSpeechFinished?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.queueCount = max(0, self.queueCount - 1)

            // Siempre actualizar estado cuando la cola se vacía,
            // independientemente de si estamos en modo batch o no.
            if self.queueCount == 0 {
                self.isSpeaking = false
                self.currentlySpeakingID = nil

                // Solo disparar el callback si NO estamos en batch.
                // Si estamos en batch, endBatch() se encargará de dispararlo.
                if !self.isBatching {
                    self.notifyFinishedIfNeeded()
                }
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentlySpeakingID = nil
            self.queueCount = 0
            self.isBatching = false
            // Cancelled speech shouldn't trigger the "finished" logic (which restarts listening)
            // because cancellation means "stop".
        }
    }
}
