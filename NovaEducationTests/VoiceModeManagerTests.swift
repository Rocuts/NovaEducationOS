import Testing
@testable import NovaEducation

@Suite("VoiceModeManager Tests")
@MainActor
struct VoiceModeManagerTests {

    @Test("Initialization sets idle state")
    func initialization() {
        let manager = VoiceModeManager(
            studentName: "TestUser",
            educationLevel: .secondary
        )

        #expect(manager.state == .idle)
        #expect(manager.audioLevel == 0.0)
        #expect(manager.currentTranscript == "")
    }

    @Test("State transitions are assignable")
    func stateTransitions() {
        let manager = VoiceModeManager(
            studentName: "TestUser",
            educationLevel: .secondary
        )

        manager.state = .listening
        #expect(manager.state == .listening)

        manager.state = .processing
        #expect(manager.state == .processing)

        manager.state = .speaking
        #expect(manager.state == .speaking)

        manager.state = .idle
        #expect(manager.state == .idle)
    }

    @Test("Error state carries message")
    func errorState() {
        let manager = VoiceModeManager(
            studentName: "TestUser",
            educationLevel: .secondary
        )

        manager.state = .error("Test error")
        if case .error(let message) = manager.state {
            #expect(message == "Test error")
        } else {
            Issue.record("Expected error state")
        }
    }
}
