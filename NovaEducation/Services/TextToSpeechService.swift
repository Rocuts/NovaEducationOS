import AVFoundation
import SwiftUI
import Observation

@Observable
class TextToSpeechService: NSObject, AVSpeechSynthesizerDelegate {
    var isSpeaking = false
    var currentlySpeakingID: UUID?
    private let synthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error configuring audio session: \(error)")
        }
    }
    
    func speak(_ text: String, id: UUID) {
        // Stop previous if speaking
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        currentlySpeakingID = id
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Configuración de voz en español
        // Preferencias: MX (Latinoamérica) > ES (España) > US (Español neutro en US)
        let preferredIdentifiers = ["es-MX", "es-ES", "es-US"]
        var selectedVoice: AVSpeechSynthesisVoice?
        
        for identifier in preferredIdentifiers {
            if let voice = AVSpeechSynthesisVoice(language: identifier) {
                selectedVoice = voice
                break
            }
        }
        
        // Fallback a cualquier voz en español
        if selectedVoice == nil {
            selectedVoice = AVSpeechSynthesisVoice(language: "es-MX")
        }
        
        utterance.voice = selectedVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
        isSpeaking = true
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        currentlySpeakingID = nil
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        currentlySpeakingID = nil
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        currentlySpeakingID = nil
    }
}
