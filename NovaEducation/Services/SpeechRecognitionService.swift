import Speech
import SwiftUI
import Observation
import os

private let logger = Logger(subsystem: "com.nova.education", category: "SpeechRecognition")

@Observable
@MainActor
class SpeechRecognitionService {
    var isRecording = false
    var transcribedText = ""
    var permissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var errorMessage: String?
    
    // Private properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.autoupdatingCurrent)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    var audioLevel: Float = 0.0

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
        
        // Configure Audio Session - MANAGED BY VoiceModeManager
        // let audioSession = AVAudioSession.sharedInstance()
        // try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
        // try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
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
        
        // Install Tap - capture recognitionRequest locally to avoid accessing @MainActor state from audio thread
        let request = recognitionRequest
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            self?.updateAudioLevel(buffer: buffer)
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
                Task { @MainActor in
                    self.stopRecordingInternal()
                }
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
    
    nonisolated private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)

        var sum: Float = 0.0
        for i in 0..<frames {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frames))
        let normalized = min(rms * 5.0, 1.0)

        Task { @MainActor in
            self.audioLevel = normalized
        }
    }
}
