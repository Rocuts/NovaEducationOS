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

    // CRITICAL FIX: AVAudioEngine is now a var that gets recreated each cycle.
    // After AVSpeechSynthesizer uses the audio hardware, the engine's inputNode
    // format can become stale (0 channels, wrong sample rate). The only reliable
    // workaround is to create a fresh AVAudioEngine instance for each recording
    // session so the inputNode picks up the current hardware configuration.
    private var audioEngine: AVAudioEngine?

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
        // Defensive: tear down any leftover state from a previous cycle
        tearDownAudioPipeline()

        // Reset transcript and error state
        transcribedText = ""
        errorMessage = nil

        // Create a fresh AVAudioEngine instance.
        // This is the KEY FIX: after AVSpeechSynthesizer finishes speaking,
        // the previous engine's inputNode may have an invalid format.
        // A new engine queries the current hardware state correctly.
        let engine = AVAudioEngine()
        self.audioEngine = engine

        // Create Recognition Request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.recognitionRequest = request

        // Get input format from the FRESH engine's inputNode
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Validate the format - if it's 0 channels or unsupported sample rate, the hardware isn't ready
        guard recordingFormat.channelCount > 0, recordingFormat.sampleRate >= 16000 else {
            logger.error("Input format is invalid (channels: \(recordingFormat.channelCount), sampleRate: \(recordingFormat.sampleRate))")
            throw SpeechRecognitionError.hardwareNotReady
        }

        // Install audio tap on the input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            self?.updateAudioLevel(buffer: buffer)
        }

        // Prepare and start the engine
        engine.prepare()
        try engine.start()

        // Start the recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
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
        logger.info("Recording started successfully with fresh audio engine")
    }

    @MainActor
    func stopRecording() {
        stopRecordingInternal()
    }

    @MainActor
    private func stopRecordingInternal() {
        guard isRecording else { return }
        tearDownAudioPipeline()
        isRecording = false
        logger.info("Recording stopped")
    }

    /// Tears down ALL audio pipeline resources so the next cycle starts clean.
    /// Safe to call multiple times (idempotent).
    @MainActor
    private func tearDownAudioPipeline() {
        // 1. Stop the audio engine first (stops I/O)
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
        }

        // 2. Remove the tap (modifies the audio graph - must happen after stop)
        audioEngine?.inputNode.removeTap(onBus: 0)

        // 3. Signal end of audio to the recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // 4. Cancel the recognition task to prevent its completion handler
        //    from calling stopRecordingInternal again
        recognitionTask?.cancel()
        recognitionTask = nil

        // 5. Release the engine so next cycle creates a fresh one
        audioEngine = nil
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

// MARK: - Errors

enum SpeechRecognitionError: Error, LocalizedError {
    case hardwareNotReady
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .hardwareNotReady:
            return "El micrófono no está disponible. Intenta de nuevo."
        case .permissionDenied:
            return "No se tiene permiso para usar el micrófono."
        }
    }
}
