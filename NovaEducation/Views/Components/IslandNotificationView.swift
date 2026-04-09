import SwiftUI
import Accessibility

// MARK: - Island Notification Model

/// Notificación premium que emerge del Dynamic Island con físicas de spring y material Liquid Glass.
/// Reemplaza NovaToast como sistema de notificaciones principal.
struct IslandNotification: Identifiable, Equatable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    let accentColor: Color
    let duration: TimeInterval
    let xpAmount: Int?

    static func == (lhs: IslandNotification, rhs: IslandNotification) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Notification Types

    enum NotificationType: Equatable {
        case xpGain
        case levelUp
        case questComplete
        case achievementUnlock
        case focusModeActivated
        case streakMilestone
        case focusPhaseUp
        case focusMilestone
        case focusSummary
        case breakReminder
        case info
    }

    // MARK: - Factory Methods

    /// Notificación de XP ganado
    static func xpGain(amount: Int, multiplier: Double) -> IslandNotification {
        IslandNotification(
            type: .xpGain,
            title: "+\(amount) XP",
            subtitle: multiplier > 1.0 ? "x\(String(format: "%.1f", multiplier)) multiplicador" : nil,
            icon: "sparkles",
            iconColor: .yellow,
            accentColor: .yellow,
            duration: 2.5,
            xpAmount: amount
        )
    }

    /// Notificación de subida de nivel
    static func levelUp(level: Int, title: String) -> IslandNotification {
        IslandNotification(
            type: .levelUp,
            title: "Nivel \(level)",
            subtitle: title,
            icon: "arrow.up.circle.fill",
            iconColor: .orange,
            accentColor: .orange,
            duration: 3.5,
            xpAmount: nil
        )
    }

    /// Notificación de misión completada
    static func questComplete(questTitle: String, xp: Int) -> IslandNotification {
        IslandNotification(
            type: .questComplete,
            title: "Misión Completada",
            subtitle: "\(questTitle) · +\(xp) XP",
            icon: "checkmark.seal.fill",
            iconColor: .green,
            accentColor: .green,
            duration: 3.0,
            xpAmount: xp
        )
    }

    /// Notificación de logro desbloqueado
    static func achievementUnlock(name: String, description: String, tierColor: Color) -> IslandNotification {
        IslandNotification(
            type: .achievementUnlock,
            title: name,
            subtitle: description,
            icon: "trophy.fill",
            iconColor: tierColor,
            accentColor: tierColor,
            duration: 3.5,
            xpAmount: nil
        )
    }

    /// Notificación de modo enfoque activado
    static func focusModeActivated(phase: FocusPhase) -> IslandNotification {
        IslandNotification(
            type: .focusModeActivated,
            title: "Modo Enfoque Activado",
            subtitle: phase.subtitle,
            icon: "moon.stars.fill",
            iconColor: .indigo,
            accentColor: .indigo,
            duration: 3.0,
            xpAmount: nil
        )
    }

    /// Notificación de racha de días
    static func streakMilestone(days: Int) -> IslandNotification {
        IslandNotification(
            type: .streakMilestone,
            title: "Racha de \(days) días",
            subtitle: streakMotivation(for: days),
            icon: "flame.fill",
            iconColor: .orange,
            accentColor: .orange,
            duration: 3.5,
            xpAmount: nil
        )
    }

    /// Notificación de fase de focus
    static func focusPhaseUp(_ phase: FocusPhase) -> IslandNotification {
        IslandNotification(
            type: .focusPhaseUp,
            title: phase.displayName,
            subtitle: phase.subtitle,
            icon: phase.icon,
            iconColor: phase.color,
            accentColor: phase.color,
            duration: 3.5,
            xpAmount: phase.xpBonus > 0 ? phase.xpBonus : nil
        )
    }

    /// Notificación de milestone de focus
    static func focusMilestone(minutes: Int) -> IslandNotification {
        let messages: [Int: (String, String)] = [
            5: ("5 minutos enfocado", "Buen comienzo, sigue así"),
            15: ("15 minutos de estudio", "Tu concentración crece"),
            30: ("30 minutos de focus", "Zona de productividad"),
            45: ("45 minutos increíbles", "Considera una breve pausa"),
            60: ("1 hora de estudio", "Disciplina de campeón")
        ]
        let (title, subtitle) = messages[minutes] ?? ("\(minutes) min enfocado", "Sigue así")

        return IslandNotification(
            type: .focusMilestone,
            title: title,
            subtitle: subtitle,
            icon: "timer",
            iconColor: .indigo,
            accentColor: .indigo,
            duration: 3.0,
            xpAmount: nil
        )
    }

    /// Notificación de resumen de focus
    static func focusSummary(minutes: Int, phase: FocusPhase) -> IslandNotification {
        IslandNotification(
            type: .focusSummary,
            title: "Sesión de \(minutes) min completada",
            subtitle: "Nivel máximo: \(phase.displayName)",
            icon: "checkmark.circle.fill",
            iconColor: .green,
            accentColor: .green,
            duration: 4.0,
            xpAmount: nil
        )
    }

    /// Notificación de recordatorio de descanso
    static func breakReminder() -> IslandNotification {
        IslandNotification(
            type: .breakReminder,
            title: "Momento de descansar",
            subtitle: "Una pausa corta mejora el aprendizaje",
            icon: "cup.and.heat.waves.fill",
            iconColor: .green,
            accentColor: .green,
            duration: 4.0,
            xpAmount: nil
        )
    }

    /// Notificación informativa genérica
    static func info(title: String, message: String? = nil) -> IslandNotification {
        IslandNotification(
            type: .info,
            title: title,
            subtitle: message,
            icon: "info.circle.fill",
            iconColor: .blue,
            accentColor: .blue,
            duration: 3.0,
            xpAmount: nil
        )
    }

    // MARK: - Helpers

    private static func streakMotivation(for days: Int) -> String {
        switch days {
        case 1...3: return "El hábito está naciendo"
        case 4...6: return "La constancia es tu superpoder"
        case 7...13: return "Una semana de dedicación"
        case 14...29: return "Tu disciplina es admirable"
        case 30...59: return "Un mes de aprendizaje continuo"
        case 60...99: return "Eres imparable"
        default: return "Leyenda del aprendizaje"
        }
    }
}

// MARK: - Island Notification Manager

/// Manager central de notificaciones premium con cola serializada.
/// Máximo 1 visible a la vez — premium significa enfocado, no saturado.
@Observable
@MainActor
final class IslandNotificationManager {
    static let shared = IslandNotificationManager()
    private init() {}

    /// Notificación actualmente visible (nil = nada visible)
    var currentNotification: IslandNotification?

    /// Señal para que la view inicie la animación de dismiss
    var isDismissing = false

    /// Cola de notificaciones pendientes
    private var queue: [IslandNotification] = []

    /// Task de auto-dismiss activa
    private var dismissTask: Task<Void, Never>?

    // MARK: - Public API

    /// Muestra una notificación. Si ya hay una visible, la encola.
    func show(_ notification: IslandNotification) {
        if currentNotification == nil {
            present(notification)
        } else {
            queue.append(notification)
        }
    }

    /// Dismiss con animación premium — la view escucha isDismissing y ejecuta la secuencia
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        guard currentNotification != nil else { return }

        isDismissing = true

        // La view tiene 400ms para animar el contract. Luego removemos la notificación.
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }
            isDismissing = false
            withAnimation(SwiftUI.Animation.spring(duration: 0.22, bounce: 0.05)) {
                currentNotification = nil
            }
            scheduleNext()
        }
    }

    /// Limpia todo inmediatamente
    func dismissAll() {
        dismissTask?.cancel()
        dismissTask = nil
        queue.removeAll()
        isDismissing = false

        withAnimation(SwiftUI.Animation.spring(duration: 0.38, bounce: 0.15)) {
            currentNotification = nil
        }
    }

    // MARK: - Private

    private func present(_ notification: IslandNotification) {
        triggerHaptic(for: notification)
        triggerSound(for: notification)

        withAnimation(SwiftUI.Animation.spring(duration: 0.63, bounce: 0.28)) {
            currentNotification = notification
        }

        // Accessibility announcement
        AccessibilityNotification.Announcement(accessibilityText(for: notification)).post()

        scheduleDismiss(notification)
    }

    private func scheduleDismiss(_ notification: IslandNotification) {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(notification.duration))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    private func scheduleNext() {
        Task {
            // Brief pause between notifications for visual breathing room
            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }
            guard currentNotification == nil, !queue.isEmpty else { return }
            let next = queue.removeFirst()
            present(next)
        }
    }

    private func triggerHaptic(for notification: IslandNotification) {
        switch notification.type {
        case .xpGain:
            Nova.Haptics.light()
        case .levelUp:
            Nova.Haptics.success()
        case .questComplete:
            Nova.Haptics.success()
        case .achievementUnlock:
            Nova.Haptics.success()
        case .focusModeActivated:
            Nova.Haptics.medium()
        case .streakMilestone:
            Nova.Haptics.medium()
        case .focusPhaseUp:
            Nova.Haptics.medium()
        case .focusMilestone:
            Nova.Haptics.soft()
        case .focusSummary:
            Nova.Haptics.success()
        case .breakReminder:
            Nova.Haptics.soft()
        case .info:
            break
        }
    }

    private func triggerSound(for notification: IslandNotification) {
        switch notification.type {
        case .xpGain:
            CelebrationSoundService.shared.play(.xpGain)
        case .levelUp:
            CelebrationSoundService.shared.play(.levelUp)
        case .questComplete:
            CelebrationSoundService.shared.play(.questComplete)
        case .achievementUnlock:
            CelebrationSoundService.shared.play(.achievementUnlock)
        case .streakMilestone:
            CelebrationSoundService.shared.play(.streakMilestone)
        case .focusPhaseUp:
            CelebrationSoundService.shared.play(.streakMilestone)
        default:
            break
        }
    }

    private func accessibilityText(for notification: IslandNotification) -> String {
        var text = notification.title
        if let subtitle = notification.subtitle {
            text += ". \(subtitle)"
        }
        if let xp = notification.xpAmount {
            text += ". \(xp) puntos de experiencia"
        }
        return text
    }
}

// MARK: - Island Notification Container

/// Overlay raíz que renderiza la notificación activa con animación de Dynamic Island.
/// Colocar como .overlay en la vista raiz de la app.
/// Trabaja CON el safe area del sistema — no lo ignora. El safe area ya incluye
/// el espacio del Dynamic Island/notch, así que solo se necesita un pequeño padding
/// adicional para separación visual.
struct IslandNotificationContainer: View {
    let manager = IslandNotificationManager.shared

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if let notification = manager.currentNotification {
                    IslandNotificationView(
                        notification: notification,
                        screenWidth: proxy.size.width
                    )
                    .transition(.identity) // Custom animation handled internally
                    .zIndex(9999)
                }
                Spacer()
            }
            // El safe area del sistema ya posiciona el contenido debajo del
            // Dynamic Island/notch. Solo agregamos 8pt de separación visual
            // para que la notificación no quede pegada al borde inferior del DI.
            .padding(.top, 8)
        }
        .allowsHitTesting(manager.currentNotification != nil)
    }
}

// MARK: - KeyframeAnimator Values

/// Animated values for the dismiss KeyframeAnimator sequence
private struct DismissValues {
    var offsetY: CGFloat = 0
    var scale: CGFloat = 1.0
    var blur: CGFloat = 0
}

// MARK: - Island Notification View

/// Vista individual de notificación con la secuencia de animación de 4 fases.
struct IslandNotificationView: View {
    let notification: IslandNotification
    let screenWidth: CGFloat

    // MARK: - Animation Phase State

    @State private var phase: AnimationPhase = .seed
    @State private var capsuleWidth: CGFloat = 126
    @State private var capsuleHeight: CGFloat = 36
    @State private var capsuleScale: CGFloat = 0.3
    @State private var capsuleOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.8

    // MARK: - Content Animation State

    @State private var iconBounce = false
    @State private var xpDisplayed: Int = 0
    @State private var progressFraction: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -200

    // MARK: - Dismiss Animation State

    @State private var dismissTrigger = 0

    // MARK: - Drag State

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private enum AnimationPhase {
        case seed      // Phase 1: tiny capsule appears at safe area position
        case expand    // Phase 2: expands to full width with content
        case display   // Phase 3: content visible, countdown active
        case contract  // Phase 4: shrinks back
    }

    // MARK: - Layout Constants

    /// Seed capsule width (mimics Dynamic Island compact size)
    private let islandWidth: CGFloat = 126
    /// Seed capsule height
    private let islandHeight: CGFloat = 36
    /// Expanded notification height
    private let expandedHeight: CGFloat = 72
    /// Horizontal padding from screen edges when expanded
    private let horizontalPadding: CGFloat = 16

    private var expandedWidth: CGFloat {
        screenWidth - (horizontalPadding * 2)
    }

    var body: some View {
        ZStack {
            // Glow aura behind notification
            glowAura

            // The notification capsule
            notificationCapsule
        }
        .offset(y: dragOffset)
        .keyframeAnimator(initialValue: DismissValues(), trigger: dismissTrigger) { content, value in
            content
                .offset(y: value.offsetY)
                .scaleEffect(value.scale)
                .blur(radius: value.blur)
        } keyframes: { _ in
            KeyframeTrack(\.offsetY) {
                // Fase 1 (0-120ms): Hold position
                LinearKeyframe(0, duration: 0.12)
                // Fase 2 (120-280ms): Float up slightly
                SpringKeyframe(-12, duration: 0.16, spring: .init(duration: 0.38, bounce: 0.18))
                // Fase 3 (280-400ms): Continue up
                LinearKeyframe(-20, duration: 0.12)
            }
            KeyframeTrack(\.scale) {
                // Fase 1: Hold
                LinearKeyframe(1.0, duration: 0.12)
                // Fase 2: Slight shrink
                SpringKeyframe(0.92, duration: 0.16, spring: .init(duration: 0.38, bounce: 0.18))
                // Fase 3: Scale down
                LinearKeyframe(0.6, duration: 0.12)
            }
            KeyframeTrack(\.blur) {
                // Fase 1-2: No blur
                LinearKeyframe(0, duration: 0.28)
                // Fase 3: Subtle blur
                LinearKeyframe(4, duration: 0.12)
            }
        }
        .opacity(dragDismissOpacity)
        .gesture(swipeToDismissGesture)
        .onAppear {
            startAnimationSequence()
        }
        .onChange(of: IslandNotificationManager.shared.isDismissing) { _, isDismissing in
            if isDismissing {
                startDismissSequence()
            }
        }
    }

    // MARK: - Glow Aura

    private var glowAura: some View {
        Capsule()
            .fill(notification.accentColor.opacity(0.15))
            .frame(width: capsuleWidth + 20, height: capsuleHeight + 16)
            .blur(radius: 20)
            .opacity(glowOpacity)
            .scaleEffect(glowScale)
    }

    // MARK: - Notification Capsule

    private var notificationCapsule: some View {
        HStack(spacing: 12) {
            if contentOpacity > 0 {
                // Icon
                notificationIcon

                // Text content
                notificationContent

                Spacer(minLength: 0)

                // XP badge for non-xpGain types
                if let xp = notification.xpAmount, notification.type != .xpGain {
                    xpSideBadge(xp: xp)
                }
            }
        }
        .padding(.horizontal, contentOpacity > 0 ? 16 : 0)
        .padding(.vertical, contentOpacity > 0 ? 12 : 0)
        .frame(width: capsuleWidth, height: capsuleHeight)
        .glassEffect(.regular.tint(notification.accentColor.opacity(0.15)), in: .capsule)
        .overlay(alignment: .bottom) {
            // Progress countdown bar
            if contentOpacity > 0 {
                progressCountdown
            }
        }
        .scaleEffect(capsuleScale)
        .opacity(capsuleOpacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityAction(named: "Cerrar") {
            IslandNotificationManager.shared.dismiss()
        }
    }

    // MARK: - Icon

    private var notificationIcon: some View {
        ZStack {
            // Subtle glow ring behind icon
            Circle()
                .fill(notification.iconColor.opacity(0.12))
                .frame(width: 36, height: 36)

            Image(systemName: notification.icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(notification.iconColor)
                .symbolEffect(.bounce, value: iconBounce)
        }
        .opacity(contentOpacity)
    }

    // MARK: - Content

    private var notificationContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            if notification.type == .xpGain, notification.xpAmount != nil {
                Text("+\(xpDisplayed) XP")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: Double(xpDisplayed)))
            } else {
                Text(notification.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            if let subtitle = notification.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .opacity(contentOpacity)
    }

    // MARK: - XP Side Badge

    private func xpSideBadge(xp: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.caption2)
            Text("+\(xp)")
                .font(.caption.bold())
        }
        .foregroundStyle(.yellow)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.yellow.opacity(0.12), in: Capsule())
        .opacity(contentOpacity)
    }

    // MARK: - Progress Countdown

    private var progressCountdown: some View {
        GeometryReader { geo in
            Capsule()
                .fill(notification.accentColor.opacity(0.3))
                .frame(
                    width: max(0, geo.size.width * progressFraction),
                    height: 2
                )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 2)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .opacity(contentOpacity)
    }

    // MARK: - Swipe to Dismiss Gesture

    private var swipeToDismissGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let translation = min(0, value.translation.height)
                withAnimation(SwiftUI.Animation.spring(duration: 0.38, bounce: 0.14)) {
                    dragOffset = translation
                    isDragging = true
                }
            }
            .onEnded { value in
                isDragging = false
                let velocity = value.velocity.height
                let distance = abs(value.translation.height)

                if velocity < -300 || distance > 30 {
                    // Swipe dismiss: float up con scale down y blur
                    withAnimation(SwiftUI.Animation.spring(duration: 0.45, bounce: 0.18)) {
                        dragOffset = -80
                        capsuleScale = 0.85
                        contentOpacity = 0
                        glowOpacity = 0
                    }
                    withAnimation(SwiftUI.Animation.easeOut(duration: 0.25).delay(0.08)) {
                        capsuleOpacity = 0
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        IslandNotificationManager.shared.dismissAll()
                        // Reset para la siguiente notificación
                        IslandNotificationManager.shared.isDismissing = false
                        if !IslandNotificationManager.shared.isDismissing {
                            let mgr = IslandNotificationManager.shared
                            mgr.currentNotification = nil
                        }
                    }
                } else {
                    withAnimation(SwiftUI.Animation.spring(duration: 0.5, bounce: 0.35)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private var dragDismissOpacity: Double {
        let distance = abs(dragOffset)
        return max(0, 1.0 - distance / 100.0)
    }

    // MARK: - Premium Dismiss Sequence

    private func startDismissSequence() {
        // Trigger KeyframeAnimator for offset/scale/blur (replaces Task.sleep chains)
        dismissTrigger += 1

        // Fase 1 (0-120ms): Content fades out, glow pulsa y desaparece
        withAnimation(SwiftUI.Animation.easeOut(duration: 0.12)) {
            contentOpacity = 0
            progressFraction = 0
        }
        withAnimation(SwiftUI.Animation.easeOut(duration: 0.2)) {
            glowOpacity = 0
            glowScale = 1.3
        }

        // Fase 2 (120-280ms): Capsule contrae a pill pequeño
        withAnimation(SwiftUI.Animation.spring(duration: 0.38, bounce: 0.18).delay(0.12)) {
            capsuleWidth = islandWidth * 0.8
            capsuleHeight = islandHeight * 0.7
        }

        // Fase 3 (280-400ms): Pill se desvanece
        withAnimation(SwiftUI.Animation.easeIn(duration: 0.14).delay(0.28)) {
            capsuleOpacity = 0
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var text = notification.title
        if let subtitle = notification.subtitle {
            text += ". \(subtitle)"
        }
        if let xp = notification.xpAmount {
            text += ". \(xp) puntos de experiencia"
        }
        return text
    }

    // MARK: - Animation Sequence

    private func startAnimationSequence() {
        // Phase 1: SEED (0ms) — capsule appears at Dynamic Island position
        capsuleWidth = islandWidth
        capsuleHeight = islandHeight
        capsuleScale = 0.3
        capsuleOpacity = 0
        contentOpacity = 0

        withAnimation(SwiftUI.Animation.spring(duration: 0.12, bounce: 0.1)) {
            capsuleOpacity = 1
            capsuleScale = 1.0
        }

        // Phase 2: EXPAND — delayed withAnimation eliminates Task.sleep chain
        withAnimation(SwiftUI.Animation.spring(duration: 0.5, bounce: 0.22).delay(0.08)) {
            capsuleWidth = expandedWidth
            capsuleHeight = expandedHeight
            capsuleScale = 1.02 // Subtle overshoot
        }

        // Content fades in at 140ms (80 + 60)
        withAnimation(SwiftUI.Animation.easeOut(duration: 0.18).delay(0.14)) {
            contentOpacity = 1
        }

        // Settle scale overshoot at 260ms (80 + 60 + 120)
        withAnimation(SwiftUI.Animation.spring(duration: 0.3, bounce: 0.15).delay(0.26)) {
            capsuleScale = 1.0
        }

        // Phase 3: DISPLAY — starts at ~350ms
        // Single Task.sleep for display-phase side effects (icon bounce, glow, countdown)
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            phase = .display

            // Icon bounce
            iconBounce.toggle()

            // Glow aura pulse
            withAnimation(SwiftUI.Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.6
                glowScale = 1.1
            }

            // Shimmer sweep
            withAnimation(SwiftUI.Animation.easeInOut(duration: 0.7)) {
                shimmerOffset = 400
            }

            // XP count up
            if notification.type == .xpGain, let target = notification.xpAmount {
                countUpXP(target: target)
            }

            // Progress bar countdown
            withAnimation(SwiftUI.Animation.linear(duration: notification.duration)) {
                progressFraction = 0
            }
        }
    }

    // MARK: - XP Count Up

    private func countUpXP(target: Int) {
        let steps = min(target, 15)
        guard steps > 0 else {
            xpDisplayed = target
            return
        }
        let stepValue = max(1, target / steps)

        Task {
            for i in 0...steps {
                if i > 0 {
                    try? await Task.sleep(for: .milliseconds(30))
                }
                guard !Task.isCancelled else { return }
                withAnimation(SwiftUI.Animation.spring(duration: 0.22, bounce: 0.3)) {
                    xpDisplayed = min(stepValue * (i + 1), target)
                }
            }
        }
    }
}

// MARK: - Backward Compatibility Bridge

/// Extension en NovaToastManager que redirige al sistema Island.
/// Permite migración gradual — los call-sites existentes siguen funcionando.
extension IslandNotificationManager {

    /// Convierte un NovaToast al nuevo sistema y lo muestra
    func show(legacyToast toast: NovaToast) {
        let notification: IslandNotification

        switch toast.style {
        case .xpGain:
            notification = .xpGain(
                amount: toast.xpAmount ?? 0,
                multiplier: toast.subtitle != nil ? 1.5 : 1.0
            )
        case .focusPhaseUp:
            notification = IslandNotification(
                type: .focusPhaseUp,
                title: toast.title,
                subtitle: toast.subtitle,
                icon: toast.icon,
                iconColor: toast.iconColor,
                accentColor: toast.accentColor,
                duration: toast.duration,
                xpAmount: toast.xpAmount
            )
        case .focusMilestone:
            notification = IslandNotification(
                type: .focusMilestone,
                title: toast.title,
                subtitle: toast.subtitle,
                icon: toast.icon,
                iconColor: toast.iconColor,
                accentColor: toast.accentColor,
                duration: toast.duration,
                xpAmount: nil
            )
        case .focusSummary:
            notification = IslandNotification(
                type: .focusSummary,
                title: toast.title,
                subtitle: toast.subtitle,
                icon: toast.icon,
                iconColor: toast.iconColor,
                accentColor: toast.accentColor,
                duration: toast.duration,
                xpAmount: nil
            )
        case .breakReminder:
            notification = .breakReminder()
        case .questComplete:
            notification = IslandNotification(
                type: .questComplete,
                title: toast.title,
                subtitle: toast.subtitle,
                icon: toast.icon,
                iconColor: toast.iconColor,
                accentColor: toast.accentColor,
                duration: toast.duration,
                xpAmount: toast.xpAmount
            )
        case .streakBonus:
            notification = IslandNotification(
                type: .streakMilestone,
                title: toast.title,
                subtitle: toast.subtitle,
                icon: toast.icon,
                iconColor: toast.iconColor,
                accentColor: toast.accentColor,
                duration: toast.duration,
                xpAmount: nil
            )
        case .info:
            notification = .info(title: toast.title, message: toast.subtitle)
        }

        show(notification)
    }
}

// MARK: - Previews

#Preview("Island Notification - XP Gain") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        Text("Contenido de la app")
            .font(.title)
            .foregroundStyle(.secondary)
    }
    .overlay {
        IslandNotificationContainer()
    }
    .onAppear {
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            IslandNotificationManager.shared.show(
                .xpGain(amount: 45, multiplier: 1.5)
            )
        }
    }
}

#Preview("Island Notification - Level Up") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        Text("Contenido de la app")
    }
    .overlay {
        IslandNotificationContainer()
    }
    .onAppear {
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            IslandNotificationManager.shared.show(
                .levelUp(level: 12, title: "Explorador Avanzado")
            )
        }
    }
}

#Preview("Island Notification - Quest Complete") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        Text("Contenido de la app")
    }
    .overlay {
        IslandNotificationContainer()
    }
    .onAppear {
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            IslandNotificationManager.shared.show(
                .questComplete(questTitle: "Enviar 5 mensajes", xp: 50)
            )
        }
    }
}

#Preview("Island Notification - Achievement") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        Text("Contenido de la app")
    }
    .overlay {
        IslandNotificationContainer()
    }
    .onAppear {
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            IslandNotificationManager.shared.show(
                .achievementUnlock(
                    name: "Primer Paso",
                    description: "Envia tu primer mensaje",
                    tierColor: .yellow
                )
            )
        }
    }
}

#Preview("Island Notification - Streak") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        Text("Contenido de la app")
    }
    .overlay {
        IslandNotificationContainer()
    }
    .onAppear {
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            IslandNotificationManager.shared.show(
                .streakMilestone(days: 7)
            )
        }
    }
}

#Preview("Island Notification - Queue") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        VStack(spacing: 20) {
            Text("Cola de notificaciones")
                .font(.title2)
            Text("Se muestran una a la vez")
                .foregroundStyle(.secondary)
        }
    }
    .overlay {
        IslandNotificationContainer()
    }
    .onAppear {
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            IslandNotificationManager.shared.show(.xpGain(amount: 25, multiplier: 1.0))
            IslandNotificationManager.shared.show(.questComplete(questTitle: "Estudiar 10 min", xp: 30))
            IslandNotificationManager.shared.show(.streakMilestone(days: 5))
        }
    }
}
