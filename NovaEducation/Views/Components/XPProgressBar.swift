import SwiftUI

/// Barra de progreso de XP y nivel
struct XPProgressBar: View {
    let currentXP: Int
    let currentLevel: Int
    let progress: Double
    let xpToNextLevel: Int
    let playerTitle: String
    let playerTitleIcon: String

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            // Header con nivel y título
            HStack {
                // Nivel
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(levelGradient)
                            .frame(width: 44, height: 44)

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

                    // Progress
                    RoundedRectangle(cornerRadius: 8)
                        .fill(progressGradient)
                        .frame(width: geometry.size.width * animatedProgress, height: 12)
                }
            }
            .frame(height: 12)
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedProgress = newValue
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

/// Toast que aparece cuando se gana XP
struct XPGainToast: View {
    let amount: Int
    let multiplier: Double

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: isVisible)

            VStack(alignment: .leading, spacing: 2) {
                Text("+\(amount) XP")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)

                if multiplier > 1.0 {
                    Text("x\(String(format: "%.1f", multiplier)) multiplicador")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: .yellow.opacity(0.2), radius: 10)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isVisible = true
            }
        }
    }
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
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Text("\(currentLevel)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * progress, height: 6)
                }
            }
            .frame(width: 60, height: 6)

            Text("\(currentXP)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
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
