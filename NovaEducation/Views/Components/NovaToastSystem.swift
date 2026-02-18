import SwiftUI

// MARK: - Focus Phase

/// Fases progresivas del modo focus — el estudiante "sube de nivel" de concentración
enum FocusPhase: Int, CaseIterable, Comparable, Sendable {
    case idle = 0
    case warmingUp = 1     // 0–5 min
    case focused = 2       // 5–15 min
    case deepFocus = 3     // 15–30 min
    case flowState = 4     // 30+ min

    var displayName: String {
        switch self {
        case .idle: return "Inactivo"
        case .warmingUp: return "Calentando"
        case .focused: return "Concentrado"
        case .deepFocus: return "¡Enfoque Profundo!"
        case .flowState: return "¡Estado Flow!"
        }
    }

    var subtitle: String {
        switch self {
        case .idle: return ""
        case .warmingUp: return "Tu mente se está preparando"
        case .focused: return "Estás ganando concentración"
        case .deepFocus: return "Tu productividad está en su punto más alto"
        case .flowState: return "¡Eres imparable! Máxima concentración"
        }
    }

    var icon: String {
        switch self {
        case .idle: return "moon.zzz"
        case .warmingUp: return "flame"
        case .focused: return "brain.head.profile.fill"
        case .deepFocus: return "bolt.fill"
        case .flowState: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .gray
        case .warmingUp: return .orange
        case .focused: return .blue
        case .deepFocus: return .purple
        case .flowState: return .indigo
        }
    }

    var xpBonus: Int {
        switch self {
        case .idle: return 0
        case .warmingUp: return 5
        case .focused: return 10
        case .deepFocus: return 25
        case .flowState: return 40
        }
    }

    var multiplierBonus: Double {
        switch self {
        case .idle: return 0
        case .warmingUp: return 0
        case .focused: return 0.05
        case .deepFocus: return 0.15
        case .flowState: return 0.25
        }
    }

    static func phase(forSeconds seconds: TimeInterval) -> FocusPhase {
        let minutes = Int(seconds) / 60
        switch minutes {
        case 0..<5: return .warmingUp
        case 5..<15: return .focused
        case 15..<30: return .deepFocus
        default: return .flowState
        }
    }

    static func < (lhs: FocusPhase, rhs: FocusPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Toast Model

/// Un toast individual en el sistema de notificaciones
struct NovaToast: Identifiable, Equatable {
    let id = UUID()
    let style: Style
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    let accentColor: Color
    let duration: TimeInterval
    let xpAmount: Int?

    static func == (lhs: NovaToast, rhs: NovaToast) -> Bool {
        lhs.id == rhs.id
    }

    enum Style: Equatable {
        case xpGain
        case focusMilestone
        case focusPhaseUp
        case focusSummary
        case breakReminder
        case questComplete
        case streakBonus
        case info
    }

    // MARK: - Factory Methods

    /// Toast de XP ganado
    static func xpGain(amount: Int, multiplier: Double) -> NovaToast {
        NovaToast(
            style: .xpGain,
            title: "+\(amount) XP",
            subtitle: multiplier > 1.0 ? "x\(String(format: "%.1f", multiplier)) multiplicador" : nil,
            icon: "sparkles",
            iconColor: .yellow,
            accentColor: .yellow,
            duration: 2.5,
            xpAmount: amount
        )
    }

    /// Toast de fase de focus alcanzada
    static func focusPhaseUp(_ phase: FocusPhase) -> NovaToast {
        NovaToast(
            style: .focusPhaseUp,
            title: phase.displayName,
            subtitle: phase.subtitle,
            icon: phase.icon,
            iconColor: phase.color,
            accentColor: phase.color,
            duration: 4.0,
            xpAmount: phase.xpBonus > 0 ? phase.xpBonus : nil
        )
    }

    /// Toast de milestone de focus (minutos específicos)
    static func focusMilestone(minutes: Int) -> NovaToast {
        let messages: [Int: (String, String)] = [
            5: ("5 minutos enfocado", "¡Buen comienzo! Sigue así"),
            15: ("15 minutos de estudio", "Tu concentración crece"),
            30: ("¡30 minutos de focus!", "Zona de productividad"),
            45: ("¡45 minutos increíbles!", "Considera una breve pausa"),
            60: ("¡1 hora de estudio!", "¡Disciplina de campeón!")
        ]
        let (title, subtitle) = messages[minutes] ?? ("\(minutes) min enfocado", "¡Sigue así!")

        return NovaToast(
            style: .focusMilestone,
            title: title,
            subtitle: subtitle,
            icon: "timer",
            iconColor: .indigo,
            accentColor: .indigo,
            duration: 3.5,
            xpAmount: nil
        )
    }

    /// Toast de resumen al terminar sesión focus
    static func focusSummary(minutes: Int, phase: FocusPhase) -> NovaToast {
        NovaToast(
            style: .focusSummary,
            title: "Sesión de \(minutes) min completada",
            subtitle: "Nivel máximo: \(phase.displayName)",
            icon: "checkmark.circle.fill",
            iconColor: .green,
            accentColor: .green,
            duration: 4.0,
            xpAmount: nil
        )
    }

    /// Toast de recordatorio de descanso
    static func breakReminder() -> NovaToast {
        NovaToast(
            style: .breakReminder,
            title: "Momento de descansar",
            subtitle: "Una pausa corta mejora el aprendizaje",
            icon: "cup.and.heat.waves.fill",
            iconColor: .green,
            accentColor: .green,
            duration: 5.0,
            xpAmount: nil
        )
    }

    /// Toast de misión completada
    static func questComplete(title: String, xp: Int) -> NovaToast {
        NovaToast(
            style: .questComplete,
            title: "¡Misión completada!",
            subtitle: "\(title) · +\(xp) XP",
            icon: "checkmark.seal.fill",
            iconColor: .green,
            accentColor: .green,
            duration: 3.0,
            xpAmount: xp
        )
    }

    /// Toast de racha
    static func streakBonus(days: Int) -> NovaToast {
        NovaToast(
            style: .streakBonus,
            title: "¡Racha de \(days) días!",
            subtitle: "Tu dedicación es admirable",
            icon: "flame.fill",
            iconColor: .orange,
            accentColor: .orange,
            duration: 3.5,
            xpAmount: nil
        )
    }

    /// Toast informativo genérico
    static func info(title: String, message: String? = nil) -> NovaToast {
        NovaToast(
            style: .info,
            title: title,
            subtitle: message,
            icon: "info.circle.fill",
            iconColor: .blue,
            accentColor: .blue,
            duration: 3.0,
            xpAmount: nil
        )
    }
}

// MARK: - Toast Manager

/// Manager central de toasts con cola y spring physics
@Observable
@MainActor
final class NovaToastManager {
    static let shared = NovaToastManager()
    private init() {}

    /// Toasts actualmente visibles (máximo 3)
    var activeToasts: [NovaToast] = []

    /// Cola de toasts pendientes
    private var queue: [NovaToast] = []

    /// Tasks de auto-dismiss activas
    private var dismissTasks: [UUID: Task<Void, Never>] = [:]

    /// Máximo de toasts visibles simultáneamente
    private let maxVisible = 3

    // MARK: - Public API

    /// Muestra un toast con animación spring
    func show(_ toast: NovaToast) {
        triggerHaptic(for: toast)

        if activeToasts.count < maxVisible {
            withAnimation(.spring(duration: 0.75, bounce: 0.35)) {
                activeToasts.append(toast)
            }
            scheduleDismiss(toast)
        } else {
            queue.append(toast)
        }
    }

    /// Dismiss manual de un toast
    func dismiss(_ toast: NovaToast) {
        dismissTasks[toast.id]?.cancel()
        dismissTasks.removeValue(forKey: toast.id)

        withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
            activeToasts.removeAll { $0.id == toast.id }
        }

        Task {
            try? await Task.sleep(for: .seconds(0.15))
            processQueue()
        }
    }

    /// Limpia todos los toasts
    func dismissAll() {
        for task in dismissTasks.values { task.cancel() }
        dismissTasks.removeAll()
        queue.removeAll()

        withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
            activeToasts.removeAll()
        }
    }

    // MARK: - Private

    private func scheduleDismiss(_ toast: NovaToast) {
        let task = Task {
            try? await Task.sleep(for: .seconds(toast.duration))
            guard !Task.isCancelled else { return }
            dismiss(toast)
        }
        dismissTasks[toast.id] = task
    }

    private func processQueue() {
        guard !queue.isEmpty, activeToasts.count < maxVisible else { return }
        let next = queue.removeFirst()

        withAnimation(.spring(duration: 0.75, bounce: 0.35)) {
            activeToasts.append(next)
        }
        scheduleDismiss(next)
    }

    private func triggerHaptic(for toast: NovaToast) {
        switch toast.style {
        case .xpGain:
            Nova.Haptics.light()
        case .focusPhaseUp:
            Nova.Haptics.medium()
        case .focusMilestone:
            Nova.Haptics.soft()
        case .questComplete:
            Nova.Haptics.success()
        case .focusSummary:
            Nova.Haptics.success()
        case .breakReminder:
            Nova.Haptics.soft()
        case .streakBonus:
            Nova.Haptics.medium()
        case .info:
            break
        }
    }
}

// MARK: - Toast Container

/// Overlay que renderiza los toasts activos — colocar en la raíz de la app.
/// Aparece en la parte superior, debajo del safe area (mismo nivel que el XP toast).
struct NovaToastContainer: View {
    let toastManager = NovaToastManager.shared

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(toastManager.activeToasts.enumerated()), id: \.element.id) { index, toast in
                NovaToastView(toast: toast)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.85, anchor: .top)),
                        removal: .move(edge: .top)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.9, anchor: .top))
                    ))
                    .zIndex(Double(toastManager.activeToasts.count - index))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 52) // Justo debajo del navigation bar
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(!toastManager.activeToasts.isEmpty)
    }
}

// MARK: - Individual Toast View

/// Vista de un toast individual con spring physics y drag-to-dismiss
struct NovaToastView: View {
    let toast: NovaToast

    @State private var dragOffset: CGSize = .zero
    @State private var shimmerOffset: CGFloat = -300
    @State private var iconBounce = false
    @State private var progressFraction: CGFloat = 1.0
    @State private var xpDisplayed: Int = 0
    @State private var glowPulse = false
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon con glow
            iconView

            // Content
            contentView

            Spacer(minLength: 0)

            // XP badge lateral (para phase up y quests)
            if let xp = toast.xpAmount, toast.style != .xpGain {
                xpBadge(xp: xp)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { toastBackground }
        .overlay(alignment: .bottom) { progressBar }
        .shadow(color: toast.accentColor.opacity(0.12), radius: 16, y: 6)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .offset(x: dragOffset.width, y: min(0, dragOffset.height))
        .opacity(dragOpacity)
        .scaleEffect(appeared ? 1 : 0.92)
        .gesture(dragGesture)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAction(named: "Cerrar") {
            NovaToastManager.shared.dismiss(toast)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                appeared = true
            }
            startAnimations()
        }
    }

    // MARK: - Icon

    private var iconView: some View {
        ZStack {
            // Glow aura (pulsa para focus phases)
            if toast.style == .focusPhaseUp || toast.style == .focusSummary {
                Circle()
                    .fill(toast.iconColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .blur(radius: 6)
                    .scaleEffect(glowPulse ? 1.2 : 0.9)
            }

            Circle()
                .fill(toast.iconColor.opacity(0.12))
                .frame(width: 40, height: 40)

            Image(systemName: toast.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(toast.iconColor)
                .symbolEffect(.bounce, value: iconBounce)
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if toast.xpAmount != nil, toast.style == .xpGain {
                Text("+\(xpDisplayed) XP")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: Double(xpDisplayed)))
            } else {
                Text(toast.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            if let subtitle = toast.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - XP Badge

    private func xpBadge(xp: Int) -> some View {
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
    }

    // MARK: - Background

    private var toastBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(.ultraThinMaterial)
            .overlay {
                // Tinte sutil del color accent
                RoundedRectangle(cornerRadius: 18)
                    .fill(toast.accentColor.opacity(0.06))
            }
            .overlay(alignment: .leading) {
                // Línea accent lateral
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 18, bottomLeading: 18)
                )
                .fill(toast.accentColor)
                .frame(width: 3.5)
            }
            .overlay {
                // Shimmer sweep
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.08), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            Capsule()
                .fill(toast.accentColor.opacity(0.25))
                .frame(width: geo.size.width * progressFraction, height: 2.5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 2.5)
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let horizontalDismiss = abs(value.translation.width) > 100
                let verticalDismiss = value.translation.height < -50
                let velocity = abs(value.velocity.width) > 500 || value.velocity.height < -300

                if horizontalDismiss || verticalDismiss || velocity {
                    withAnimation(.spring(duration: 0.38, bounce: 0.3)) {
                        dragOffset = CGSize(
                            width: value.translation.width > 0 ? 500 : (horizontalDismiss ? -500 : 0),
                            height: verticalDismiss ? -300 : 0
                        )
                    }
                    NovaToastManager.shared.dismiss(toast)
                } else {
                    withAnimation(.spring(duration: 0.6, bounce: 0.45)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private var dragOpacity: Double {
        let distance = abs(dragOffset.width) + abs(min(0, dragOffset.height))
        return max(0, 1.0 - distance / 250.0)
    }

    private var accessibilityText: String {
        var text = toast.title
        if let subtitle = toast.subtitle {
            text += ". \(subtitle)"
        }
        if let xp = toast.xpAmount {
            text += ". \(xp) puntos de experiencia"
        }
        return text
    }

    // MARK: - Animations

    private func startAnimations() {
        // Icon bounce
        Task {
            try? await Task.sleep(for: .seconds(0.25))
            iconBounce.toggle()
        }

        // Shimmer sweep
        withAnimation(.easeInOut(duration: 0.9).delay(0.2)) {
            shimmerOffset = 400
        }

        // XP count up
        if let xp = toast.xpAmount, toast.style == .xpGain {
            countUpXP(target: xp)
        }

        // Progress bar countdown
        withAnimation(.linear(duration: toast.duration)) {
            progressFraction = 0
        }

        // Glow pulse for focus phases
        if toast.style == .focusPhaseUp || toast.style == .focusSummary {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }

        // Sound
        switch toast.style {
        case .xpGain:
            CelebrationSoundService.shared.play(.xpGain)
        case .focusPhaseUp:
            CelebrationSoundService.shared.play(.streakMilestone)
        case .questComplete:
            CelebrationSoundService.shared.play(.questComplete)
        default:
            break
        }
    }

    private func countUpXP(target: Int) {
        let steps = min(target, 15)
        let stepValue = max(1, target / steps)
        Task {
            for i in 0...steps {
                if i > 0 {
                    try? await Task.sleep(for: .seconds(0.03))
                }
                withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                    xpDisplayed = min(stepValue * (i + 1), target)
                }
            }
        }
    }
}

// MARK: - Focus Mode Indicator

/// Indicador flotante del estado de focus — se muestra durante sesiones activas
struct FocusPhaseIndicator: View {
    let phase: FocusPhase
    let sessionMinutes: Int

    @State private var pulsing = false
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 8) {
            // Phase icon con glow
            ZStack {
                Circle()
                    .fill(phase.color.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .blur(radius: 4)
                    .scaleEffect(pulsing ? 1.3 : 0.9)

                Image(systemName: phase.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(phase.color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(phase.displayName)
                    .font(.caption2.bold())
                    .foregroundStyle(phase.color)

                Text("\(sessionMinutes) min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(phase.color.opacity(0.3), lineWidth: 1)
        }
        .scaleEffect(appeared ? 1 : 0.7)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.75, bounce: 0.4)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Focus Summary Card

/// Card resumen al terminar una sesión de focus
struct FocusSummaryCard: View {
    let totalMinutes: Int
    let maxPhase: FocusPhase
    let messagesCount: Int
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var ringProgress: Double = 0
    @State private var showStats = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Resumen de Sesión")
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
                        appeared = false
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(0.3))
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            // Phase ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 8)
                    .frame(width: 100, height: 100)

                // Progress ring
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        AngularGradient(
                            colors: [maxPhase.color, maxPhase.color.opacity(0.5)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Image(systemName: maxPhase.icon)
                        .font(.title2)
                        .foregroundStyle(maxPhase.color)

                    Text("\(totalMinutes)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats grid
            if showStats {
                HStack(spacing: 20) {
                    statItem(
                        icon: "brain.head.profile.fill",
                        value: maxPhase.displayName,
                        label: "Nivel máximo",
                        color: maxPhase.color
                    )

                    Divider()
                        .frame(height: 40)

                    statItem(
                        icon: "bubble.left.and.bubble.right.fill",
                        value: "\(messagesCount)",
                        label: "Mensajes",
                        color: .blue
                    )

                    Divider()
                        .frame(height: 40)

                    statItem(
                        icon: "sparkles",
                        value: "+\(maxPhase.xpBonus)",
                        label: "XP Bonus",
                        color: .yellow
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(maxPhase.color.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: maxPhase.color.opacity(0.1), radius: 20, y: 8)
        .padding(.horizontal, 20)
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.75, bounce: 0.35)) {
                appeared = true
            }

            // Animate ring
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                ringProgress = min(Double(totalMinutes) / 60.0, 1.0)
            }

            // Show stats
            withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.6)) {
                showStats = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Resumen de sesión. \(totalMinutes) minutos. Nivel máximo: \(maxPhase.displayName). \(messagesCount) mensajes.")
        .accessibilityAction(named: "Cerrar") { onDismiss() }
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview("Toast - XP Gain") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()

        VStack(spacing: 12) {
            NovaToastView(toast: .xpGain(amount: 45, multiplier: 1.5))
            NovaToastView(toast: .focusPhaseUp(.deepFocus))
            NovaToastView(toast: .focusMilestone(minutes: 15))
            NovaToastView(toast: .breakReminder())
            NovaToastView(toast: .questComplete(title: "Enviar 5 mensajes", xp: 50))
        }
        .padding()
    }
}

#Preview("Focus Phase Indicator") {
    VStack(spacing: 20) {
        FocusPhaseIndicator(phase: .warmingUp, sessionMinutes: 3)
        FocusPhaseIndicator(phase: .focused, sessionMinutes: 12)
        FocusPhaseIndicator(phase: .deepFocus, sessionMinutes: 22)
        FocusPhaseIndicator(phase: .flowState, sessionMinutes: 45)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Focus Summary Card") {
    ZStack {
        Color.black.opacity(0.3).ignoresSafeArea()
        FocusSummaryCard(totalMinutes: 32, maxPhase: .deepFocus, messagesCount: 14) { }
    }
}
