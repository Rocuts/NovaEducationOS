import SwiftUI
import AVFoundation

/// Vista de celebración cuando se desbloquea un logro
/// Usa Canvas + TimelineView para renderizado GPU-smooth de partículas
struct AchievementUnlockView: View {
    let achievementType: AchievementType
    let onDismiss: () -> Void

    @State private var showOverlay = false
    @State private var showBadge = false
    @State private var showTierBadge = false
    @State private var showUnlockText = false
    @State private var showAchievementTitle = false
    @State private var showDescription = false
    @State private var showXP = false
    @State private var showButton = false
    @State private var ringRotation: Double = 0
    @State private var glowPulse = false
    @State private var shimmerOffset: CGFloat = -150
    @State private var displayedXP: Int = 0
    @State private var iconBounce = false
    @State private var starEngine = StarFieldEngine()
    @State private var animationStartDate: Date?

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(showOverlay ? 0.7 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // MARK: - Canvas Stars (GPU-rendered)
            if animationStartDate != nil {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let elapsed = animationStartDate.map { timeline.date.timeIntervalSince($0) } ?? 0
                        starEngine.update(elapsed: elapsed, size: size)

                        for star in starEngine.stars where star.opacity > 0 {
                            let dim = star.size
                            let rect = CGRect(
                                x: star.x - dim / 2,
                                y: star.y - dim / 2,
                                width: dim,
                                height: dim
                            )
                            context.opacity = star.opacity

                            // Draw star shapes
                            switch star.shape {
                            case .circle:
                                context.fill(
                                    Circle().path(in: rect),
                                    with: .color(star.color)
                                )
                            case .diamond:
                                context.rotate(by: .degrees(45 + star.rotation))
                                context.fill(
                                    Rectangle().path(in: rect.insetBy(dx: dim * 0.15, dy: dim * 0.15)),
                                    with: .color(star.color)
                                )
                                context.rotate(by: .degrees(-(45 + star.rotation)))
                            case .fourPoint:
                                // Four-point star using two overlapping rects
                                context.rotate(by: .degrees(star.rotation))
                                let thin = CGRect(
                                    x: star.x - dim * 0.12,
                                    y: star.y - dim / 2,
                                    width: dim * 0.24,
                                    height: dim
                                )
                                let wide = CGRect(
                                    x: star.x - dim / 2,
                                    y: star.y - dim * 0.12,
                                    width: dim,
                                    height: dim * 0.24
                                )
                                context.fill(
                                    RoundedRectangle(cornerRadius: dim * 0.1).path(in: thin),
                                    with: .color(star.color)
                                )
                                context.fill(
                                    RoundedRectangle(cornerRadius: dim * 0.1).path(in: wide),
                                    with: .color(star.color)
                                )
                                context.rotate(by: .degrees(-star.rotation))
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                }
            }

            // Main content
            VStack(spacing: 20) {
                Spacer()

                // Achievement badge
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [achievementType.tier.color.opacity(0.5), achievementType.color.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 220, height: 220)
                        .blur(radius: 20)
                        .scaleEffect(glowPulse ? 1.3 : 0.85)
                        .opacity(showBadge ? 1 : 0)

                    // Tier ring (rotating)
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    achievementType.tier.color,
                                    achievementType.tier.color.opacity(0.3),
                                    achievementType.color,
                                    achievementType.tier.color.opacity(0.3),
                                    achievementType.tier.color
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 125, height: 125)
                        .rotationEffect(.degrees(ringRotation))
                        .opacity(showBadge ? 0.9 : 0)

                    // Main circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [achievementType.color, achievementType.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: achievementType.color.opacity(0.5), radius: 15)
                        .shadow(color: achievementType.color.opacity(0.3), radius: 30)

                    // Shimmer overlay
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.25), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .offset(x: shimmerOffset * 0.5, y: shimmerOffset * 0.3)
                        .clipShape(Circle())

                    // Icon
                    Image(systemName: achievementType.icon)
                        .font(.largeTitle)
                        .imageScale(.large)
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: iconBounce)
                }
                .scaleEffect(showBadge ? 1 : 0.1)
                .opacity(showBadge ? 1 : 0)

                // Tier badge
                HStack(spacing: 6) {
                    Image(systemName: "medal.fill")
                        .font(.caption)
                    Text(achievementType.tier.displayName)
                        .font(.caption.bold())
                }
                .foregroundStyle(achievementType.tier.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(achievementType.tier.color.opacity(0.2), in: Capsule())
                .scaleEffect(showTierBadge ? 1 : 0.3)
                .opacity(showTierBadge ? 1 : 0)

                // Text - staggered entrance
                VStack(spacing: 8) {
                    Text("¡Logro Desbloqueado!")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))
                        .offset(y: showUnlockText ? 0 : 15)
                        .opacity(showUnlockText ? 1 : 0)

                    Text(achievementType.title)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .offset(y: showAchievementTitle ? 0 : 15)
                        .opacity(showAchievementTitle ? 1 : 0)

                    Text(achievementType.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .offset(y: showDescription ? 0 : 10)
                        .opacity(showDescription ? 1 : 0)

                    // XP reward with counting animation
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.subheadline)
                        Text("+\(displayedXP) XP")
                            .font(.headline.bold())
                            .contentTransition(.numericText(value: Double(displayedXP)))
                    }
                    .foregroundStyle(.yellow)
                    .padding(.top, 8)
                    .scaleEffect(showXP ? 1 : 0.5)
                    .opacity(showXP ? 1 : 0)
                }

                Spacer()

                // Dismiss button
                Button(action: dismiss) {
                    Text("¡Conseguido!")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(achievementType.color, in: Capsule())
                        .shadow(color: achievementType.color.opacity(0.4), radius: 15)
                }
                .scaleEffect(showButton ? 1 : 0.5)
                .opacity(showButton ? 1 : 0)
                .padding(.bottom, 50)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Logro desbloqueado: \(achievementType.title). \(achievementType.description). Recompensa: \(achievementType.xpReward) puntos de experiencia. Tier \(achievementType.tier.displayName).")
        .accessibilityAction(named: "Cerrar") { dismiss() }
        .onAppear {
            startCelebration()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                UIAccessibility.post(notification: .announcement, argument: "¡Logro desbloqueado! \(achievementType.title)")
            }
        }
    }

    // MARK: - Animation Sequence

    private func startCelebration() {
        // Sound
        CelebrationSoundService.shared.play(.achievementUnlock)

        // Phase 1: Overlay
        withAnimation(Nova.Animation.exitMedium) {
            showOverlay = true
        }

        // Phase 2: Badge entrance
        withAnimation(Nova.Animation.springBouncy.delay(0.15)) {
            showBadge = true
        }

        // Phase 2b: Star field + haptics (consolidated into single timed Task)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.25))
            starEngine.emit(
                count: 30,
                tierColor: achievementType.tier.color,
                accentColor: achievementType.color
            )
            animationStartDate = Date()

            try? await Task.sleep(for: .seconds(0.05))
            Nova.Haptics.heavy()
        }

        // Phase 3: Tier badge
        withAnimation(Nova.Animation.springBouncy.delay(0.4)) {
            showTierBadge = true
        }

        // Phase 4: Staggered text + icon bounce + haptic success
        withAnimation(Nova.Animation.entranceMedium.delay(0.5)) {
            showUnlockText = true
        }
        withAnimation(Nova.Animation.entranceMedium.delay(0.65)) {
            showAchievementTitle = true
        }
        withAnimation(Nova.Animation.entranceMedium.delay(0.8)) {
            showDescription = true
        }

        // Icon bounce + haptic success at 0.5s (single Task for both side effects)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            iconBounce = true
            Nova.Haptics.success()
        }

        // Phase 5: XP counter
        withAnimation(Nova.Animation.entranceMedium.delay(0.9)) {
            showXP = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            countUpXP()
        }

        // Phase 6: Button
        withAnimation(Nova.Animation.entranceMedium.delay(1.1)) {
            showButton = true
        }

        // Phase 7: Shimmer sweep
        withAnimation(Nova.Animation.shimmer.delay(0.6)) {
            shimmerOffset = 150
        }

        // Continuous: Glow pulse
        withAnimation(Nova.Animation.glowPulse.delay(0.3)) {
            glowPulse = true
        }

        // Continuous: Ring rotation
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
    }

    // MARK: - XP Counter

    private func countUpXP() {
        let target = achievementType.xpReward
        let steps = min(target, 20)
        let stepValue = max(1, target / steps)

        Task { @MainActor in
            for i in 0...steps {
                if i > 0 {
                    try? await Task.sleep(for: .seconds(0.04))
                }
                withAnimation(.spring(duration: 0.22, bounce: 0.2)) {
                    displayedXP = min(stepValue * (i + 1), target)
                }
                if i == steps {
                    Nova.Haptics.light()
                    CelebrationSoundService.shared.play(.xpGain)
                }
            }
        }
    }

    // MARK: - Dismiss (reverse cascade)

    private func dismiss() {
        // Stop infinite animations and TimelineView
        animationStartDate = nil
        starEngine.clear()

        // Reverse cascade: button → XP → text → badge → overlay
        withAnimation(Nova.Animation.exitFast) {
            showButton = false
        }
        withAnimation(Nova.Animation.exitFast.delay(0.06)) {
            showXP = false
        }
        withAnimation(Nova.Animation.exitFast.delay(0.12)) {
            showDescription = false
        }
        withAnimation(Nova.Animation.exitFast.delay(0.16)) {
            showAchievementTitle = false
            showUnlockText = false
        }
        withAnimation(Nova.Animation.exitFast.delay(0.2)) {
            showTierBadge = false
        }
        withAnimation(Nova.Animation.exitMedium.delay(0.22)) {
            showBadge = false
            glowPulse = false
            ringRotation = 0
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

// MARK: - Star Field Engine (Canvas-powered)

/// Motor de estrellas flotantes de alto rendimiento.
/// Renderiza estrellas con drift, fade in/out y rotación en un solo Canvas.
/// NO usar @Observable - TimelineView ya fuerza el redibujado por frame,
/// y la observación causaría re-evaluaciones innecesarias del body (~60/seg).
final class StarFieldEngine {
    enum StarShape {
        case circle
        case diamond
        case fourPoint
    }

    struct Star {
        var x: Double
        var y: Double
        var vx: Double
        var vy: Double
        var size: Double
        var rotation: Double
        var rotationSpeed: Double
        var opacity: Double
        var targetOpacity: Double
        var color: Color
        var shape: StarShape
        var fadeInDelay: Double
        var lifetime: Double
    }

    private(set) var stars: [Star] = []
    private var lastElapsed: Double = 0
    private let maxStars = 30

    private static let shapes: [StarShape] = [.circle, .diamond, .fourPoint]

    func emit(count: Int, tierColor: Color, accentColor: Color) {
        stars.removeAll()
        let cappedCount = min(count, maxStars)
        stars.reserveCapacity(cappedCount)
        lastElapsed = 0

        let colors: [Color] = [tierColor, accentColor, .yellow, .white]

        for i in 0..<cappedCount {
            stars.append(Star(
                x: 0, // Set in first update based on Canvas size
                y: 0,
                vx: Double.random(in: -15 ... 15),
                vy: Double.random(in: -30 ... -8),
                size: Double.random(in: 6 ... 18),
                rotation: Double.random(in: 0 ... 360),
                rotationSpeed: Double.random(in: -60 ... 60),
                opacity: 0,
                targetOpacity: Double.random(in: 0.4 ... 0.95),
                color: colors[i % colors.count],
                shape: Self.shapes[i % Self.shapes.count],
                fadeInDelay: Double.random(in: 0 ... 1.0),
                lifetime: Double.random(in: 2.5 ... 4.5)
            ))
        }
    }

    func clear() {
        stars.removeAll()
    }

    func update(elapsed: Double, size: CGSize) {
        let dt = min(elapsed - lastElapsed, 1.0 / 30.0)
        lastElapsed = elapsed

        for i in stars.indices {
            // Initialize position on first meaningful update
            if elapsed < 0.02 && stars[i].x == 0 {
                stars[i].x = Double.random(in: 30...(size.width - 30))
                stars[i].y = Double.random(in: size.height * 0.15...size.height * 0.55)
            }

            let age = elapsed - stars[i].fadeInDelay
            guard age > 0 else { continue }

            // Drift
            stars[i].x += stars[i].vx * dt
            stars[i].y += stars[i].vy * dt
            stars[i].rotation += stars[i].rotationSpeed * dt

            // Gentle wave motion
            stars[i].x += sin(elapsed * 1.5 + Double(i)) * 0.3

            // Opacity lifecycle: fade in → hold → fade out
            let fadeInDuration = 0.5
            let fadeOutStart = stars[i].lifetime * 0.6

            if age < fadeInDuration {
                stars[i].opacity = (age / fadeInDuration) * stars[i].targetOpacity
            } else if age > fadeOutStart {
                let fadeProgress = (age - fadeOutStart) / (stars[i].lifetime - fadeOutStart)
                stars[i].opacity = max(0, stars[i].targetOpacity * (1 - fadeProgress))
            } else {
                // Subtle twinkle during hold
                let twinkle = sin(elapsed * 3 + Double(i) * 0.7) * 0.15
                stars[i].opacity = stars[i].targetOpacity + twinkle
            }

            // Kill old stars
            if age > stars[i].lifetime {
                stars[i].opacity = 0
            }
        }

        // Cleanup dead stars to free memory
        let maxLifetime = stars.map(\.lifetime).max() ?? 5.0
        if elapsed > maxLifetime + 1.0 {
            stars.removeAll(where: { $0.opacity <= 0 })
        }
    }
}

// MARK: - Achievement Unlock Banner

/// Versión más pequeña como banner
struct AchievementUnlockBanner: View {
    let achievementType: AchievementType

    @State private var isVisible = false
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(achievementType.color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: achievementType.icon)
                    .font(.title3)
                    .foregroundStyle(achievementType.color)
                    .symbolEffect(.bounce, value: isVisible)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("¡Logro desbloqueado!")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(achievementType.tier.emoji)
                        .font(.caption)
                }

                Text(achievementType.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text("+\(achievementType.xpReward)")
                .font(.subheadline.bold())
                .foregroundStyle(.yellow)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(achievementType.tier.color.opacity(0.5), lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.12), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: shimmerOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            CelebrationSoundService.shared.play(.achievementUnlock)
            withAnimation(.spring(duration: 0.75, bounce: 0.4)) {
                isVisible = true
            }
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                shimmerOffset = 400
            }
        }
    }
}

// MARK: - Achievement Progress Row

/// Fila que muestra el progreso hacia un logro
struct AchievementProgressRow: View {
    let achievementType: AchievementType
    let currentProgress: Int
    let isUnlocked: Bool

    @State private var animatedProgress: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? achievementType.color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)

                if isUnlocked {
                    Image(systemName: achievementType.icon)
                        .font(.title3)
                        .foregroundStyle(achievementType.color)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(achievementType.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(isUnlocked ? .primary : .secondary)

                    Spacer()

                    Text(achievementType.tier.emoji)
                        .font(.caption)
                }

                if isUnlocked {
                    Text(achievementType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [achievementType.color, achievementType.color.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * animatedProgress, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(currentProgress)/\(achievementType.targetValue)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            withAnimation(.spring(duration: 1.2, bounce: 0.3).delay(0.2)) {
                animatedProgress = progressPercentage
            }
        }
    }

    private var progressPercentage: Double {
        guard achievementType.targetValue > 0 else { return 0 }
        return min(Double(currentProgress) / Double(achievementType.targetValue), 1.0)
    }
}

// MARK: - Preview

#Preview("Achievement Unlock View") {
    AchievementUnlockView(
        achievementType: .streak7,
        onDismiss: {}
    )
}

#Preview("Achievement Unlock Banner") {
    VStack {
        Spacer()
        AchievementUnlockBanner(achievementType: .streak7)
            .padding()
        Spacer()
    }
    .background(Color(uiColor: .systemBackground))
}

#Preview("Achievement Progress Row") {
    VStack(spacing: 16) {
        AchievementProgressRow(achievementType: .streak7, currentProgress: 7, isUnlocked: true)
        AchievementProgressRow(achievementType: .streak30, currentProgress: 12, isUnlocked: false)
        AchievementProgressRow(achievementType: .curious100, currentProgress: 45, isUnlocked: false)
    }
    .padding()
}
