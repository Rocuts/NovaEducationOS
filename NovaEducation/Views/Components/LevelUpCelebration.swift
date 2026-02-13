import SwiftUI

/// Vista de celebración cuando el usuario sube de nivel
struct LevelUpCelebration: View {
    let newLevel: Int
    let newTitle: String
    let onDismiss: () -> Void

    @State private var isAnimating = false
    @State private var showContent = false
    @State private var particleSystem = ParticleSystem()

    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Particles
            ForEach(particleSystem.particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }

            // Main content
            VStack(spacing: 24) {
                Spacer()

                // Level badge
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.5), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)

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
                        .shadow(color: .orange.opacity(0.5), radius: 20)

                    // Level number
                    Text("\(newLevel)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .scaleEffect(showContent ? 1 : 0.3)
                .opacity(showContent ? 1 : 0)

                // Text
                VStack(spacing: 8) {
                    Text("¡NIVEL \(newLevel)!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Ahora eres \(newTitle)")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)

                Spacer()

                // Dismiss button
                Button(action: dismiss) {
                    Text("¡Genial!")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(.white, in: Capsule())
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

        // Start particles
        particleSystem.emit()

        // Animate content
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
            showContent = true
        }

        // Pulsing animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
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

// MARK: - Particle System

struct ParticleSystem {
    var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var color: Color
        var size: CGFloat
        var opacity: Double
    }

    mutating func emit() {
        let colors: [Color] = [.yellow, .orange, .red, .pink, .purple]
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height

        for _ in 0..<50 {
            let particle = Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: CGFloat.random(in: 0...screenHeight)
                ),
                color: colors.randomElement() ?? .yellow,
                size: CGFloat.random(in: 4...12),
                opacity: Double.random(in: 0.5...1)
            )
            particles.append(particle)
        }
    }
}

// MARK: - Level Up Banner (Alternative smaller version)

/// Versión más pequeña como banner
struct LevelUpBanner: View {
    let newLevel: Int

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: isVisible)

            VStack(alignment: .leading, spacing: 2) {
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 2
                )
        }
        .shadow(color: .yellow.opacity(0.3), radius: 10)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Level Up Celebration") {
    LevelUpCelebration(
        newLevel: 10,
        newTitle: "Estudiante",
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
