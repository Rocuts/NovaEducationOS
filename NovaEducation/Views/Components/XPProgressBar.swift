import SwiftUI
import AVFoundation

/// Barra de progreso de XP y nivel
struct XPProgressBar: View {
    let currentXP: Int
    let currentLevel: Int
    let progress: Double
    let xpToNextLevel: Int
    let playerTitle: String
    let playerTitleIcon: String

    @State private var animatedProgress: Double = 0
    @State private var showShine = false
    @State private var shineOffset: CGFloat = -300
    @ScaledMetric(relativeTo: .title) private var levelBadgeSize: CGFloat = 44

    var body: some View {
        VStack(spacing: 16) {
            // Header con nivel y título
            HStack {
                // Nivel
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(levelGradient)
                            .frame(width: levelBadgeSize, height: levelBadgeSize)
                            .shadow(color: .blue.opacity(0.3), radius: 8)

                        Text("\(currentLevel)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nivel \(currentLevel)")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(spacing: 4) {
                            Image(systemName: playerTitleIcon)
                                .font(.caption)
                            Text(playerTitle)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // XP Total
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(currentXP) XP")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(value: Double(currentXP)))

                    Text("\(xpToNextLevel) para nivel \(currentLevel + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Barra de progreso
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 12)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 8)
                        .fill(progressGradient)
                        .frame(width: geometry.size.width * animatedProgress, height: 12)

                    // Shine sweep on progress bar
                    if animatedProgress > 0.05 {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.3), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 40, height: 12)
                            .offset(x: shineOffset)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 8)
                                    .size(width: geometry.size.width * animatedProgress, height: 12)
                            )
                    }
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nivel \(currentLevel), \(playerTitle). \(currentXP) puntos de experiencia totales. \(xpToNextLevel) puntos para el siguiente nivel.")
        .accessibilityValue("\(Int(progress * 100)) por ciento completado")
        .onAppear {
            withAnimation(.spring(duration: 1.2, bounce: 0.3)) {
                animatedProgress = progress
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.easeInOut(duration: 0.8)) {
                    shineOffset = 400
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(duration: 0.75, bounce: 0.3)) {
                animatedProgress = newValue
            }
            shineOffset = -300
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.easeInOut(duration: 0.6)) {
                    shineOffset = 400
                }
            }
        }
    }

    private var levelGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .cyan, .green],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - XP Gain Toast

/// Toast que aparece cuando se gana XP — spring physics + drag-to-dismiss + Canvas sparkles
struct XPGainToast: View {
    let amount: Int
    let multiplier: Double
    var onDismiss: (() -> Void)?

    @State private var isVisible = false
    @State private var floatOffset: CGFloat = 0
    @State private var dragOffset: CGSize = .zero
    @State private var displayedAmount: Int = 0
    @State private var shimmerOffset: CGFloat = -300
    @State private var glowPulse = false
    @State private var iconBounce = false
    @State private var sparkleEngine = SparkleEngine()
    @State private var sparkleStartDate: Date?
    @State private var dismissTask: Task<Void, Never>?
    @State private var progressFraction: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Canvas sparkles (GPU-rendered)
            if sparkleStartDate != nil {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let elapsed = sparkleStartDate.map { timeline.date.timeIntervalSince($0) } ?? 0
                        sparkleEngine.update(elapsed: elapsed, size: size)

                        if sparkleEngine.isFinished {
                            DispatchQueue.main.async {
                                sparkleStartDate = nil
                            }
                            return
                        }

                        for particle in sparkleEngine.particles where particle.opacity > 0 {
                            let rect = CGRect(
                                x: particle.x - particle.size / 2,
                                y: particle.y - particle.size / 2,
                                width: particle.size,
                                height: particle.size
                            )
                            context.opacity = particle.opacity
                            context.fill(
                                Circle().path(in: rect),
                                with: .color(particle.color)
                            )
                        }
                    }
                    .allowsHitTesting(false)
                }
                .frame(height: 80)
            }

            // Toast content
            HStack(spacing: 14) {
                // Icon con glow
                ZStack {
                    // Glow aura
                    Circle()
                        .fill(.yellow.opacity(0.25))
                        .frame(width: 48, height: 48)
                        .blur(radius: 8)
                        .scaleEffect(glowPulse ? 1.3 : 0.8)

                    Circle()
                        .fill(.yellow.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .symbolEffect(.bounce, value: iconBounce)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("+\(displayedAmount) XP")
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(value: Double(displayedAmount)))

                    if multiplier > 1.0 {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                            Text("x\(String(format: "%.1f", multiplier)) multiplicador")
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.yellow.opacity(0.05))
                    }
                    .overlay(alignment: .leading) {
                        UnevenRoundedRectangle(
                            cornerRadii: .init(topLeading: 18, bottomLeading: 18)
                        )
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3.5)
                    }
                    .overlay {
                        // Shimmer sweep
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.1), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: shimmerOffset)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .overlay(alignment: .bottom) {
                // Progress bar countdown
                GeometryReader { geo in
                    Capsule()
                        .fill(.yellow.opacity(0.25))
                        .frame(width: geo.size.width * progressFraction, height: 2.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 2.5)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
            }
            .shadow(color: .yellow.opacity(0.15), radius: 16, y: 6)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
        .scaleEffect(isVisible ? 1 : 0.75)
        .opacity(isVisible ? 1 : 0)
        .offset(x: dragOffset.width, y: floatOffset + min(0, dragOffset.height))
        .opacity(dragDismissOpacity)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    if abs(value.translation.width) > 80 || value.translation.height < -40 {
                        dismissWithVelocity(value)
                    } else {
                        withAnimation(.spring(duration: 0.6, bounce: 0.45)) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ganaste \(amount) puntos de experiencia\(multiplier > 1.0 ? " con multiplicador de \(String(format: "%.1f", multiplier))" : "")")
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            dismissTask?.cancel()
            sparkleStartDate = nil
            sparkleEngine.stop()
        }
    }

    private var dragDismissOpacity: Double {
        let distance = abs(dragOffset.width) + abs(min(0, dragOffset.height))
        return max(0, 1.0 - distance / 200.0)
    }

    private func startAnimations() {
        // Spring entrance
        withAnimation(.spring(duration: 0.65, bounce: 0.4)) {
            isVisible = true
        }

        // Haptic + Sound
        Nova.Haptics.light()
        CelebrationSoundService.shared.play(.xpGain)

        // Icon bounce
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            iconBounce.toggle()
        }

        // Canvas sparkle burst
        sparkleEngine.emit(count: 16)
        sparkleStartDate = Date()

        // Count up number
        countUpAmount()

        // Shimmer sweep
        withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
            shimmerOffset = 400
        }

        // Glow pulse
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            glowPulse = true
        }

        // Float up gently
        withAnimation(.easeOut(duration: 2.5).delay(0.2)) {
            floatOffset = -12
        }

        // Progress bar countdown
        withAnimation(.linear(duration: 2.5)) {
            progressFraction = 0
        }

        // Auto-dismiss
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                isVisible = false
                floatOffset = -50
            }
            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled else { return }
            onDismiss?()
        }
    }

    private func countUpAmount() {
        let steps = min(amount, 15)
        guard steps > 0 else {
            displayedAmount = amount
            return
        }
        let stepValue = max(1, amount / steps)
        Task { @MainActor in
            for i in 0...steps {
                if i > 0 {
                    try? await Task.sleep(for: .seconds(0.03))
                }
                withAnimation(.spring(duration: 0.22, bounce: 0.2)) {
                    displayedAmount = min(stepValue * (i + 1), amount)
                }
            }
        }
    }

    private func dismissWithVelocity(_ value: DragGesture.Value) {
        dismissTask?.cancel()
        sparkleStartDate = nil
        sparkleEngine.stop()

        withAnimation(.spring(duration: 0.38, bounce: 0.3)) {
            dragOffset = CGSize(
                width: value.translation.width > 0 ? 400 : (abs(value.translation.width) > 80 ? -400 : 0),
                height: value.translation.height < -40 ? -200 : 0
            )
            isVisible = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            onDismiss?()
        }
    }
}

// MARK: - Sparkle Engine (Canvas-powered)

/// Motor de sparkles de alto rendimiento para el toast de XP.
/// NO usar @Observable - TimelineView ya fuerza el redibujado por frame,
/// y la observación causaría re-evaluaciones innecesarias del body (~60/seg).
final class SparkleEngine {
    struct Particle {
        var x: Double
        var y: Double
        var vx: Double
        var vy: Double
        var size: Double
        var opacity: Double
        var color: Color
        var spawnTime: Double
    }

    private(set) var particles: [Particle] = []
    private(set) var isFinished = false
    private var lastElapsed: Double = 0
    private let gravity: Double = 200
    private let drag: Double = 0.98
    private let lifetime: Double = 1.2
    private let maxParticles = 20

    private static let colors: [Color] = [
        .yellow, .orange, .white, .yellow.opacity(0.7)
    ]

    func stop() {
        particles.removeAll()
        isFinished = true
    }

    func emit(count: Int) {
        particles.removeAll()
        isFinished = false
        lastElapsed = 0
        let cappedCount = min(count, maxParticles)
        particles.reserveCapacity(cappedCount)

        for i in 0..<cappedCount {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 80...200)
            particles.append(Particle(
                x: 0, y: 0,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed - 120,
                size: Double.random(in: 3...7),
                opacity: 1,
                color: Self.colors[i % Self.colors.count],
                spawnTime: 0
            ))
        }
    }

    func update(elapsed: Double, size: CGSize) {
        let dt = min(elapsed - lastElapsed, 1.0 / 30.0)
        lastElapsed = elapsed

        let centerX = 44.0
        let centerY = size.height * 0.5

        for i in particles.indices {
            guard particles[i].opacity > 0 else { continue }

            let age = elapsed - particles[i].spawnTime

            if age > lifetime {
                particles[i].opacity = 0
                continue
            }

            particles[i].vy += gravity * dt
            particles[i].vx *= drag
            particles[i].vy *= drag
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt

            // Fade out in last 40% of lifetime
            let fadeStart = lifetime * 0.6
            if age > fadeStart {
                particles[i].opacity = max(0, 1.0 - (age - fadeStart) / (lifetime - fadeStart))
            }
        }

        // Offset to icon center
        if elapsed < 0.02 {
            for i in particles.indices {
                particles[i].x += centerX
                particles[i].y += centerY
            }
        }

        if elapsed > lifetime + 0.3 {
            particles.removeAll(where: { $0.opacity <= 0 })
            if particles.isEmpty {
                isFinished = true
            }
        }
    }
}

// MARK: - Mini Sparkle (legacy support for QuestsDetailSheet)

struct MiniSparkle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: Color
    var size: CGFloat
    var opacity: Double
}

// MARK: - Compact XP Display

/// Versión compacta para mostrar en headers
struct CompactXPDisplay: View {
    let currentXP: Int
    let currentLevel: Int
    let progress: Double

    var body: some View {
        HStack(spacing: 8) {
            // Level badge
            ZStack {
                Circle()
                    .fill(.blue.gradient)
                    .frame(width: 26, height: 26)

                Text("\(currentLevel)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.fill.tertiary)
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(.blue.gradient)
                        .frame(width: geometry.size.width * progress, height: 5)
                }
            }
            .frame(width: 50, height: 5)

            Text("\(currentXP)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nivel \(currentLevel), \(currentXP) puntos de experiencia")
        .accessibilityValue("\(Int(progress * 100)) por ciento completado")
    }
}

// MARK: - Preview

#Preview("XP Progress Bar") {
    VStack(spacing: 20) {
        XPProgressBar(
            currentXP: 1250,
            currentLevel: 7,
            progress: 0.65,
            xpToNextLevel: 450,
            playerTitle: "Explorador",
            playerTitleIcon: "binoculars.fill"
        )

        XPGainToast(amount: 45, multiplier: 1.5)

        CompactXPDisplay(currentXP: 1250, currentLevel: 7, progress: 0.65)
    }
    .padding()
    .background(Color(uiColor: .systemBackground))
}
