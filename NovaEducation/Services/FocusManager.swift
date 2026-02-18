import SwiftUI

/// Gestor del modo Focus con fases progresivas, milestones y notificaciones.
///
/// El estudiante "sube de nivel" de concentración conforme estudia:
/// idle → warmingUp (0-5 min) → focused (5-15 min) → deepFocus (15-30 min) → flowState (30+ min)
///
/// Cada transición de fase emite una notificación via IslandNotificationManager y otorga XP bonus.
@Observable
@MainActor
final class FocusManager {

    // MARK: - Public State

    /// Si el modo focus está activo (UI simplificada, tab bar oculto)
    var isFocusModeActive: Bool = false

    /// Tiempo total de la sesión actual (en segundos)
    var sessionDuration: TimeInterval = 0

    /// Fase actual de concentración
    var currentPhase: FocusPhase = .idle

    /// Fase más alta alcanzada en la sesión actual
    var peakPhase: FocusPhase = .idle

    /// Mensajes enviados durante la sesión focus actual
    var focusSessionMessages: Int = 0

    /// Si el resumen de sesión se debe mostrar
    var showFocusSummary: Bool = false

    /// Minutos del resumen
    var summaryMinutes: Int = 0

    /// Fase del resumen
    var summaryPhase: FocusPhase = .idle

    // MARK: - Private State

    /// Task del timer (reemplaza Timer para compatibilidad MainActor/Swift 6)
    private var timerTask: Task<Void, Never>?

    /// Milestones ya notificados (en minutos) para no repetir
    private var notifiedMilestones: Set<Int> = []

    /// Si ya se envió el recordatorio de descanso
    private var breakReminderSent = false

    /// Timestamp de inicio del focus mode
    private var focusStartTime: Date?

    /// Si el usuario desactivó manualmente el focus (no re-activar automáticamente)
    private var userDismissedFocus = false

    // MARK: - Configuration

    /// Minutos para auto-activar focus mode (si no fue activado manualmente)
    private let autoFocusMinutes: Int = 10

    /// Minutos en los que se muestran milestone toasts
    private let milestoneMinutes: [Int] = [5, 15, 30, 45, 60]

    /// Minutos para sugerir un descanso
    private let breakReminderMinutes: Int = 45

    // MARK: - Lifecycle

    init() {}

    // MARK: - Timer

    /// Start the session tracker (call when entering a chat)
    func startTimer() {
        guard timerTask == nil else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    /// Stop the session tracker (call when leaving a chat)
    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func tick() {
        sessionDuration += 1

        guard isFocusModeActive else {
            // Auto-enable focus si el estudiante lleva suficiente tiempo y no lo desactivó
            let minutes = Int(sessionDuration) / 60
            if minutes >= autoFocusMinutes && !userDismissedFocus {
                startFocusMode()
            }
            return
        }

        // Update phase
        updatePhase()

        // Check milestones
        checkMilestones()

        // Check break reminder
        checkBreakReminder()
    }

    // MARK: - Phase Management

    private func updatePhase() {
        guard let start = focusStartTime else { return }
        let focusDuration = Date().timeIntervalSince(start)
        let newPhase = FocusPhase.phase(forSeconds: focusDuration)

        if newPhase > currentPhase {
            let previousPhase = currentPhase
            currentPhase = newPhase

            // Track peak
            if newPhase > peakPhase {
                peakPhase = newPhase
            }

            // Emit phase-up toast
            if previousPhase != .idle {
                IslandNotificationManager.shared.show(.focusPhaseUp(newPhase))
            }
        }
    }

    private func checkMilestones() {
        guard let start = focusStartTime else { return }
        let focusMinutes = Int(Date().timeIntervalSince(start)) / 60

        for milestone in milestoneMinutes {
            if focusMinutes >= milestone && !notifiedMilestones.contains(milestone) {
                notifiedMilestones.insert(milestone)
                IslandNotificationManager.shared.show(.focusMilestone(minutes: milestone))
            }
        }
    }

    private func checkBreakReminder() {
        guard !breakReminderSent, let start = focusStartTime else { return }
        let focusMinutes = Int(Date().timeIntervalSince(start)) / 60

        if focusMinutes >= breakReminderMinutes {
            breakReminderSent = true
            IslandNotificationManager.shared.show(.breakReminder())
        }
    }

    // MARK: - Public API

    /// Activa el modo focus
    func startFocusMode() {
        guard !isFocusModeActive else { return }

        withAnimation(Nova.Animation.entranceSlow) {
            isFocusModeActive = true
        }

        // Prevent screen dimming during focus
        UIApplication.shared.isIdleTimerDisabled = true

        focusStartTime = Date()
        currentPhase = .warmingUp
        peakPhase = .warmingUp
        focusSessionMessages = 0
        notifiedMilestones = []
        breakReminderSent = false
        userDismissedFocus = false

        Nova.Haptics.medium()

        // Toast de inicio
        IslandNotificationManager.shared.show(
            .focusModeActivated(phase: .warmingUp)
        )
    }

    /// Desactiva el modo focus y muestra resumen
    func stopFocusMode() {
        guard isFocusModeActive else { return }

        let focusMinutes: Int
        if let start = focusStartTime {
            focusMinutes = max(1, Int(Date().timeIntervalSince(start)) / 60)
        } else {
            focusMinutes = 0
        }

        withAnimation(Nova.Animation.entranceMedium) {
            isFocusModeActive = false
        }

        // Re-enable screen dimming
        UIApplication.shared.isIdleTimerDisabled = false

        // Show summary if session was meaningful (> 2 min)
        if focusMinutes >= 2 {
            summaryMinutes = focusMinutes
            summaryPhase = peakPhase

            // Small delay to let focus mode transition finish
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                IslandNotificationManager.shared.show(
                    .focusSummary(minutes: focusMinutes, phase: peakPhase)
                )
            }
        }

        // Reset phase
        currentPhase = .idle
        focusStartTime = nil
    }

    /// Toggle con tracking de intención del usuario
    func toggleFocusMode() {
        if isFocusModeActive {
            userDismissedFocus = true
            stopFocusMode()
        } else {
            startFocusMode()
        }
    }

    /// Registra un mensaje enviado durante focus (para stats del resumen)
    func recordFocusMessage() {
        if isFocusModeActive {
            focusSessionMessages += 1
        }
    }

    /// Bonus de multiplicador por la fase actual de focus
    var focusMultiplierBonus: Double {
        guard isFocusModeActive else { return 0 }
        return currentPhase.multiplierBonus
    }

    /// Minutos transcurridos en la sesión focus actual
    var focusMinutes: Int {
        guard let start = focusStartTime else { return 0 }
        return Int(Date().timeIntervalSince(start)) / 60
    }

    /// Resetea todo al cambiar de contexto (e.g. cambiar de tab principal)
    func resetFocusState() {
        if isFocusModeActive {
            stopFocusMode()
        }
    }

    /// Dismiss del resumen
    func dismissSummary() {
        showFocusSummary = false
    }
}
