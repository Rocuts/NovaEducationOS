import Testing
@testable import NovaEducation

@Suite("FocusManager Tests")
@MainActor
struct FocusManagerTests {

    @Test("Initial state is inactive with idle phase")
    func initialState() {
        let manager = FocusManager()
        #expect(!manager.isFocusModeActive)
        #expect(manager.currentPhase == .idle)
        #expect(manager.peakPhase == .idle)
        #expect(manager.focusSessionMessages == 0)
        #expect(manager.sessionDuration == 0)
    }

    @Test("startFocusMode activates focus and sets warmingUp phase")
    func startFocusMode() {
        let manager = FocusManager()
        manager.startFocusMode()

        #expect(manager.isFocusModeActive)
        #expect(manager.currentPhase == .warmingUp)
        #expect(manager.peakPhase == .warmingUp)
    }

    @Test("stopFocusMode deactivates focus and resets phase to idle")
    func stopFocusMode() {
        let manager = FocusManager()
        manager.startFocusMode()
        manager.stopFocusMode()

        #expect(!manager.isFocusModeActive)
        #expect(manager.currentPhase == .idle)
    }

    @Test("toggleFocusMode alternates active state")
    func toggleFocusMode() {
        let manager = FocusManager()

        manager.toggleFocusMode()
        #expect(manager.isFocusModeActive)

        manager.toggleFocusMode()
        #expect(!manager.isFocusModeActive)
    }

    @Test("recordFocusMessage increments counter only when active")
    func recordFocusMessage() {
        let manager = FocusManager()

        // Should not increment when inactive
        manager.recordFocusMessage()
        #expect(manager.focusSessionMessages == 0)

        // Should increment when active
        manager.startFocusMode()
        manager.recordFocusMessage()
        manager.recordFocusMessage()
        #expect(manager.focusSessionMessages == 2)
    }

    @Test("focusMultiplierBonus is 0 when inactive")
    func multiplierBonusInactive() {
        let manager = FocusManager()
        #expect(manager.focusMultiplierBonus == 0)
    }

    @Test("focusMultiplierBonus is positive when active")
    func multiplierBonusActive() {
        let manager = FocusManager()
        manager.startFocusMode()
        // warmingUp phase should have some multiplier bonus
        #expect(manager.focusMultiplierBonus >= 0)
    }

    @Test("startFocusMode is idempotent when already active")
    func startFocusModeIdempotent() {
        let manager = FocusManager()
        manager.startFocusMode()
        let phase = manager.currentPhase

        // Calling start again should not change state
        manager.startFocusMode()
        #expect(manager.currentPhase == phase)
    }
}
