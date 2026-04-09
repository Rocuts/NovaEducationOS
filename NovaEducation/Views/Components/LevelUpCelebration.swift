import SwiftUI
import AVFoundation

/// Vista de celebración cuando el usuario sube de nivel
/// Usa Canvas + TimelineView para renderizado GPU-smooth de partículas
struct LevelUpCelebration: View {
    let newLevel: Int
    let previousLevel: Int
    let newTitle: String
    let onDismiss: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var levelSize: CGFloat = 56
    @State private var showOverlay = false
    @State private var showBadge = false
    @State private var showText = false
    @State private var showTitle = false
    @State private var showButton = false
    @State private var glowPulse = false
    @State private var ringExpand1 = false
    @State private var ringExpand2 = false
    @State private var ringExpand3 = false
    @State private var shakeTrigger = 0
    @State private var displayedLevel: Int = 1
    @State private var badgeRotation: Double = 0
    @State private var confettiEngine = ConfettiEngine()
    @State private var animationStartDate: Date?
    @State private var isDismissed = false

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(showOverlay ? 0.7 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Expanding rings
            expandingRings

            // MARK: - Canvas Confetti (GPU-rendered, single layer)
            if animationStartDate != nil {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let now = timeline.date
                        let elapsed = animationStartDate.map { now.timeIntervalSince($0) } ?? 0
                        confettiEngine.update(elapsed: elapsed, size: size)

                        // Stop TimelineView once all particles are done
                        if confettiEngine.isFinished {
                            DispatchQueue.main.async { [self] in
                                animationStartDate = nil
                            }
                            return
                        }

                        for particle in confettiEngine.particles where particle.opacity > 0 {
                            let rect = CGRect(
                                x: particle.x - particle.size / 2,
                                y: particle.y - particle.size / 2,
                                width: particle.isCircle ? particle.size : particle.size * 0.6,
                                height: particle.size
                            )
                            context.opacity = particle.opacity
                            context.rotate(by: .degrees(particle.rotation))

                            if particle.isCircle {
                                context.fill(
                                    Circle().path(in: rect),
                                    with: .color(particle.color)
                                )
                            } else {
                                context.fill(
                                    RoundedRectangle(cornerRadius: 2).path(in: rect),
                                    with: .color(particle.color)
                                )
                            }

                            // Reset transform for next particle
                            context.rotate(by: .degrees(-particle.rotation))
                        }
                    }
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                }
            }

            // Main content
            VStack(spacing: Nova.Spacing.xxl) {
                Spacer()

                // Level badge
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.6), .orange.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .blur(radius: 25)
                        .scaleEffect(glowPulse ? 1.3 : 0.9)
                        .opacity(showBadge ? 1 : 0)

                    // Inner ring glow
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.yellow, .orange, .red, .pink, .orange, .yellow],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 140, height: 140)
                        .blur(radius: 4)
                        .rotationEffect(.degrees(badgeRotation))
                        .opacity(showBadge ? 0.8 : 0)

                    // Main circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .orange.opacity(0.6), radius: 25)
                        .shadow(color: .yellow.opacity(0.3), radius: 50)

                    // Level number
                    Text("\(displayedLevel)")
                        .font(.system(size: levelSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(displayedLevel)))
                }
                .scaleEffect(showBadge ? 1 : 0.1)
                .opacity(showBadge ? 1 : 0)

                // Text - staggered entrance
                VStack(spacing: Nova.Spacing.sm) {
                    Text("¡NIVEL \(newLevel)!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .offset(y: showText ? 0 : 30)
                        .opacity(showText ? 1 : 0)

                    Text("Ahora eres \(newTitle)")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                        .offset(y: showTitle ? 0 : 20)
                        .opacity(showTitle ? 1 : 0)
                }

                Spacer()

                // Dismiss button
                Button(action: dismiss) {
                    Text("¡Genial!")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, Nova.Spacing.jumbo)
                        .padding(.vertical, Nova.Spacing.lg)
                        .background(.white, in: Capsule())
                        .shadow(color: .white.opacity(0.3), radius: 15)
                }
                .scaleEffect(showButton ? 1 : 0.5)
                .opacity(showButton ? 1 : 0)
                .padding(.bottom, Nova.Spacing.mega)
            }
        }
        .keyframeAnimator(initialValue: ShakeValues(), trigger: shakeTrigger) { content, value in
            content.offset(x: value.offsetX)
        } keyframes: { _ in
            KeyframeTrack(\.offsetX) {
                // Impact shake: sharp hit → rapid decay
                SpringKeyframe(8, duration: 0.05, spring: .init(duration: 0.08, bounce: 0.7))
                SpringKeyframe(-6, duration: 0.05, spring: .init(duration: 0.08, bounce: 0.7))
                SpringKeyframe(5, duration: 0.05, spring: .init(duration: 0.08, bounce: 0.6))
                SpringKeyframe(-3, duration: 0.05, spring: .init(duration: 0.08, bounce: 0.5))
                SpringKeyframe(2, duration: 0.05, spring: .init(duration: 0.08, bounce: 0.4))
                SpringKeyframe(0, duration: 0.06, spring: .init(duration: 0.09, bounce: 0.1))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Celebración de subida de nivel. Has alcanzado el nivel \(newLevel). Ahora eres \(newTitle).")
        .accessibilityAction(named: "Cerrar") { dismiss() }
        .onAppear {
            displayedLevel = max(1, previousLevel)
            startCelebration()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                UIAccessibility.post(notification: .announcement, argument: "¡Subiste al nivel \(newLevel)! Ahora eres \(newTitle).")
            }
        }
    }

    // MARK: - Expanding Rings

    private var expandingRings: some View {
        ZStack {
            Circle()
                .stroke(Color.yellow.opacity(ringExpand1 ? 0 : 0.4), lineWidth: 2)
                .frame(width: ringExpand1 ? 500 : 50, height: ringExpand1 ? 500 : 50)

            Circle()
                .stroke(Color.orange.opacity(ringExpand2 ? 0 : 0.3), lineWidth: 2)
                .frame(width: ringExpand2 ? 600 : 50, height: ringExpand2 ? 600 : 50)

            Circle()
                .stroke(Color.red.opacity(ringExpand3 ? 0 : 0.2), lineWidth: 2)
                .frame(width: ringExpand3 ? 700 : 50, height: ringExpand3 ? 700 : 50)
        }
    }

    // MARK: - Animation Sequence

    private func startCelebration() {
        // Sound
        CelebrationSoundService.shared.play(.levelUp)

        // Phase 1: Overlay fade in
        withAnimation(Nova.Animation.exitMedium) {
            showOverlay = true
        }

        // Phase 2: Badge entrance with spring bounce
        withAnimation(Nova.Animation.springBouncy.delay(0.2)) {
            showBadge = true
        }

        // Phase 2b: Screen shake (KeyframeAnimator) + haptics at impact
        Task { @MainActor [self] in
            try? await Task.sleep(for: .seconds(0.35))
            guard !isDismissed else { return }
            shakeTrigger += 1
            triggerHapticSequence()
        }

        // Phase 3: Level number counts up
        Task { @MainActor [self] in
            try? await Task.sleep(for: .seconds(0.5))
            guard !isDismissed else { return }
            countUpLevel()
        }

        // Phase 4: Expanding rings cascade
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            ringExpand1 = true
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.55)) {
            ringExpand2 = true
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.7)) {
            ringExpand3 = true
        }

        // Phase 5: Text staggered entrance
        withAnimation(Nova.Animation.entranceMedium.delay(0.6)) {
            showText = true
        }
        withAnimation(Nova.Animation.entranceMedium.delay(0.8)) {
            showTitle = true
        }

        // Phase 6: Confetti burst via Canvas
        Task { @MainActor [self] in
            try? await Task.sleep(for: .seconds(0.35))
            guard !isDismissed else { return }
            CelebrationSoundService.shared.play(.confettiBurst)
            confettiEngine.emit(count: 50)
            animationStartDate = Date()
        }

        // Phase 7: Button entrance
        withAnimation(Nova.Animation.entranceMedium.delay(1.0)) {
            showButton = true
        }

        // Continuous: Glow pulse
        withAnimation(Nova.Animation.glowPulse.delay(0.5)) {
            glowPulse = true
        }

        // Continuous: Badge ring rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            badgeRotation = 360
        }
    }

    // MARK: - Haptic Sequence

    private func triggerHapticSequence() {
        Nova.Haptics.heavy()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.15))
            Nova.Haptics.medium()
            try? await Task.sleep(for: .seconds(0.25))
            Nova.Haptics.success()
        }
    }

    // MARK: - Level Counter

    private func countUpLevel() {
        let safeLevel = max(1, newLevel)
        let start = max(1, previousLevel)
        let steps = safeLevel - start
        guard steps > 0 else {
            displayedLevel = safeLevel
            return
        }
        Task { @MainActor [self] in
            for i in 0...steps {
                guard !isDismissed else { return }
                withAnimation(Nova.Animation.springBouncy) {
                    displayedLevel = start + i
                }
                if i < steps {
                    try? await Task.sleep(for: .seconds(0.08))
                }
            }
        }
    }

    // MARK: - Dismiss

    private func dismiss() {
        guard !isDismissed else { return }
        isDismissed = true

        // Stop infinite animations and TimelineView immediately
        animationStartDate = nil
        confettiEngine.stop()

        // Reverse cascade: button → title → text → badge → overlay
        withAnimation(Nova.Animation.exitFast) {
            showButton = false
        }
        withAnimation(Nova.Animation.exitFast.delay(0.08)) {
            showTitle = false
        }
        withAnimation(Nova.Animation.exitFast.delay(0.15)) {
            showText = false
        }
        withAnimation(Nova.Animation.exitMedium.delay(0.2)) {
            showBadge = false
            glowPulse = false
            badgeRotation = 0
        }
        withAnimation(Nova.Animation.exitMedium.delay(0.3)) {
            showOverlay = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.55))
            onDismiss()
        }
    }
}

// MARK: - KeyframeAnimator Values

/// Animated values for the screen shake KeyframeAnimator
private struct ShakeValues {
    var offsetX: CGFloat = 0
}

// MARK: - Confetti Engine (Canvas-powered)

/// Motor de confetti de alto rendimiento que calcula posiciones
/// para ser renderizadas por Canvas en un solo draw call.
/// NO usar @Observable - TimelineView ya fuerza el redibujado por frame,
/// y la observación causaría re-evaluaciones innecesarias del body (~60/seg).
final class ConfettiEngine {
    struct Particle {
        var x: Double
        var y: Double
        var vx: Double
        var vy: Double
        var size: Double
        var rotation: Double
        var rotationSpeed: Double
        var opacity: Double
        var color: Color
        var isCircle: Bool
        var spawnTime: Double // seconds from emit
    }

    private(set) var particles: [Particle] = []
    private(set) var isFinished = false
    private var lastElapsed: Double = 0
    private let gravity: Double = 600
    private let drag: Double = 0.985
    private let lifetime: Double = 3.5
    private let maxParticles = 50

    private static let colors: [Color] = [
        .yellow, .orange, .red, .pink, .purple,
        .blue, .cyan, .green, .mint
    ]

    func stop() {
        particles.removeAll()
        isFinished = true
    }

    func emit(count: Int) {
        particles.removeAll()
        isFinished = false
        let cappedCount = min(count, maxParticles)
        particles.reserveCapacity(cappedCount)
        lastElapsed = 0

        for i in 0..<cappedCount {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 300...700)
            particles.append(Particle(
                x: 0, y: 0, // Centered; will offset by size/2 in update
                vx: cos(angle) * speed,
                vy: sin(angle) * speed - 400,
                size: Double.random(in: 5...13),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -400...400),
                opacity: 1,
                color: Self.colors[i % Self.colors.count],
                isCircle: Bool.random(),
                spawnTime: 0
            ))
        }
    }

    func update(elapsed: Double, size: CGSize) {
        let dt = min(elapsed - lastElapsed, 1.0 / 30.0) // Cap dt to avoid jumps
        lastElapsed = elapsed

        let centerX = size.width / 2
        let centerY = size.height * 0.35

        for i in particles.indices {
            guard particles[i].opacity > 0 else { continue }

            let age = elapsed - particles[i].spawnTime

            if age > lifetime {
                particles[i].opacity = 0
                continue
            }

            // Physics
            particles[i].vy += gravity * dt
            particles[i].vx *= drag
            particles[i].vy *= drag
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
            particles[i].rotation += particles[i].rotationSpeed * dt

            // Fade out in last 30% of lifetime
            let fadeStart = lifetime * 0.7
            if age > fadeStart {
                particles[i].opacity = max(0, 1.0 - (age - fadeStart) / (lifetime - fadeStart))
            }
        }

        // Offset to screen center (first frame only sets initial positions)
        if elapsed < 0.02 {
            for i in particles.indices {
                particles[i].x += centerX
                particles[i].y += centerY
            }
        }

        // Cleanup dead particles to free memory
        if elapsed > lifetime + 0.5 {
            particles.removeAll(where: { $0.opacity <= 0 })
            if particles.isEmpty {
                isFinished = true
            }
        }
    }
}

// MARK: - Level Up Banner

/// Versión más pequeña como banner
struct LevelUpBanner: View {
    let newLevel: Int

    @State private var isVisible = false
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        HStack(spacing: Nova.Spacing.md) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: isVisible)

            VStack(alignment: .leading, spacing: Nova.Spacing.xxxs) {
                Text("¡Subiste de nivel!")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text("Ahora eres nivel \(newLevel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("🎉")
                .font(.title)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Nova.Radius.lg)
                .stroke(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 2
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: Nova.Radius.lg)
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: shimmerOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: Nova.Radius.lg))
        .shadow(color: .yellow.opacity(0.3), radius: 10)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(Nova.Animation.springBouncy) {
                isVisible = true
            }
            withAnimation(.easeInOut(duration: 1.0).delay(0.3)) {
                shimmerOffset = 400
            }
        }
    }
}

// MARK: - Preview

#Preview("Level Up Celebration") {
    LevelUpCelebration(
        newLevel: 10,
        previousLevel: 9,
        newTitle: "Explorador Avanzado",
        onDismiss: {}
    )
}

#Preview("Level Up Banner") {
    VStack {
        Spacer()
        LevelUpBanner(newLevel: 10)
            .padding()
        Spacer()
    }
    .background(Color(uiColor: .systemBackground))
}
