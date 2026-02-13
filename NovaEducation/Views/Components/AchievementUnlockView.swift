import SwiftUI

/// Vista de celebración cuando se desbloquea un logro
struct AchievementUnlockView: View {
    let achievementType: AchievementType
    let onDismiss: () -> Void

    @State private var isAnimating = false
    @State private var showContent = false
    @State private var showBadge = false

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Main content
            VStack(spacing: 24) {
                Spacer()

                // Achievement badge
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [achievementType.tier.color.opacity(0.5), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: 15)
                        .scaleEffect(isAnimating ? 1.2 : 0.9)

                    // Tier ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [achievementType.tier.color, achievementType.tier.color.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))

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

                    // Icon
                    Image(systemName: achievementType.icon)
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: showBadge)
                }
                .scaleEffect(showContent ? 1 : 0.3)
                .opacity(showContent ? 1 : 0)

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
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)

                // Text
                VStack(spacing: 8) {
                    Text("¡Logro Desbloqueado!")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(achievementType.title)
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text(achievementType.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // XP reward
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.subheadline)
                        Text("+\(achievementType.xpReward) XP")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.yellow)
                    .padding(.top, 8)
                }
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)

                Spacer()

                // Dismiss button
                Button(action: dismiss) {
                    Text("¡Conseguido!")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(achievementType.color, in: Capsule())
                }
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Animate content
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
            showContent = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showBadge = true
        }

        // Rotating animation
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            isAnimating = true
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Achievement Unlock Banner

/// Versión más pequeña como banner
struct AchievementUnlockBanner: View {
    let achievementType: AchievementType

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
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
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isVisible = true
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

    var body: some View {
        HStack(spacing: 12) {
            // Icon
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

                    // Tier badge
                    Text(achievementType.tier.emoji)
                        .font(.caption)
                }

                if isUnlocked {
                    Text(achievementType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(achievementType.color)
                                .frame(width: geometry.size.width * progressPercentage, height: 4)
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
