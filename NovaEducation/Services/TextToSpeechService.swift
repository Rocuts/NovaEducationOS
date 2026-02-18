import AVFoundation
import Observation

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
    }

    // Stream management
    private let speechQueue = OperationQueue()
    private var isStreaming = false

    func speak(_ text: String, id: UUID) {
        // Full stop previous if speaking a new distinct thought, 
        // OR if this is the start of a new stream, we clear previous.
        if !isStreaming {
            stop()
        }
        
        currentlySpeakingID = id
        isSpeaking = true
        isStreaming = true // Mark as part of a stream
        
        queueCount += 1
        
        let utterance = AVSpeechUtterance(string: text)
        configureUtterance(utterance)
        
        // AVSpeechSynthesizer automatically queues if we just call speak() multiple times
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
        
        // 2026 Top Tier: Ensure we are using the best quality possible
        // Note: 'prefersAssistiveTechnologySettings' is false by default, which is good for our custom voice/style.
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
        // If we finished batching and queue is empty, we are done.
        // We trigger the delegate logic manually if nothing is currently speaking,
        // OR we let the last utterance finish trigger it.
        if queueCount == 0 && !synthesizer.isSpeaking && !didNotifyFinished {
            didNotifyFinished = true
            onSpeechFinished?()
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

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.queueCount = max(0, self.queueCount - 1)

            // Only notify finished if:
            // 1. Connection isn't "batching" (waiting for more segments)
            // 2. Queue is empty
            if !self.isBatching && self.queueCount == 0 {
                self.isSpeaking = false
                self.currentlySpeakingID = nil
                if !self.didNotifyFinished {
                    self.didNotifyFinished = true
                    self.onSpeechFinished?()
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
            // Cancelled speech shouldn't necessarily trigger the "finished" logic (which restarts listening)
            // unless we want to, but usually cancellation means "stop".
        }
    }
}
