import Speech
import SwiftUI
import Observation

@Observable
class SpeechRecognitionService {
    var isRecording = false
    var transcribedText = ""
    var permissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var errorMessage: String?
    
    // Private properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    init() {
        requestPermission()
    }
    
    private func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            Task { @MainActor in
                self.permissionStatus = status
            }
        }
    }
    
    @MainActor
    func startRecording() throws {
        // Reset previous state
        transcribedText = ""
        errorMessage = nil
        
        // Cancel existing task if any
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Configure Audio Session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create Request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        // CRITICAL: Enforce on-device recognition for privacy
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // Setup Audio Engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install Tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start Engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start Task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.stopRecordingInternal()
            }
        }
        
        isRecording = true
    }
    
    @MainActor
    func stopRecording() {
        stopRecordingInternal()
    }
    
    @MainActor
    private func stopRecordingInternal() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // We don't cancel the task here immediately if we want the final result,
        // but for a smooth UI toggle, we consider recording 'done'.
        isRecording = false
    }
}
