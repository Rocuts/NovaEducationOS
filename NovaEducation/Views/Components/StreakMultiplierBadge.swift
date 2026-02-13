import SwiftUI

/// Badge que muestra la racha actual y el multiplicador de XP
struct StreakMultiplierBadge: View {
    let streakDays: Int
    let multiplier: Double
    let breakdown: [XPManager.MultiplierBonus]

    @State private var isExpanded = false
    @State private var flameAnimation = false

    var body: some View {
        VStack(spacing: 0) {
            // Main badge (always visible)
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                mainBadge
            }
            .buttonStyle(.plain)

            // Expanded breakdown
            if isExpanded {
                breakdownView
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: isExpanded ? 20 : 16))
        .onAppear {
            startFlameAnimation()
        }
    }

    private var mainBadge: some View {
        HStack(spacing: 16) {
            // Streak
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(streakGradient)
                    .symbolEffect(.bounce, value: flameAnimation)

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(streakDays)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text(streakDays == 1 ? "día" : "días")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .frame(height: 36)

            // Multiplier
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 0) {
                    Text("x\(String(format: "%.1f", multiplier))")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text("multiplicador")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Expand indicator
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding()
    }

    private var breakdownView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text("Desglose del multiplicador")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            ForEach(breakdown) { bonus in
                HStack {
                    Image(systemName: bonus.icon)
                        .font(.subheadline)
                        .foregroundStyle(bonus.isActive ? .primary : .tertiary)
                        .frame(width: 24)

                    Text(bonus.name)
                        .font(.subheadline)
                        .foregroundStyle(bonus.isActive ? .primary : .tertiary)

                    Spacer()

                    Text("+\(String(format: "%.1f", bonus.value))x")
                        .font(.subheadline.bold())
                        .foregroundStyle(bonus.isActive ? .green : .tertiary)
                }
            }

            // Tips
            if multiplier < 2.0 {
                Divider()

                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)

                    Text(nextBonusTip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var streakGradient: LinearGradient {
        LinearGradient(
            colors: streakDays > 7 ? [.orange, .red] : [.orange, .yellow],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var nextBonusTip: String {
        let inactiveBonus = breakdown.first { !$0.isActive }
        if let bonus = inactiveBonus {
            switch bonus.icon {
            case "flame.fill":
                return "Mantén tu racha para aumentar el multiplicador"
            case "books.vertical.fill":
                return "Explora más materias esta semana"
            case "checkmark.seal.fill":
                return "Consigue un quiz perfecto hoy"
            case "target":
                return "Cumple tu meta diaria"
            default:
                return "Sigue estudiando para más bonificaciones"
            }
        }
        return "¡Excelente trabajo! Mantén tu ritmo"
    }

    private func startFlameAnimation() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            flameAnimation.toggle()
        }
    }
}

// MARK: - Compact Streak Badge

/// Versión compacta para headers
struct CompactStreakBadge: View {
    let streakDays: Int
    let multiplier: Double

    var body: some View {
        HStack(spacing: 8) {
            // Streak
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)

                Text("\(streakDays)")
                    .font(.subheadline.bold())
            }

            // Multiplier
            if multiplier > 1.0 {
                Text("x\(String(format: "%.1f", multiplier))")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.yellow.opacity(0.2), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Preview

#Preview("Streak Multiplier Badge") {
    VStack(spacing: 20) {
        StreakMultiplierBadge(
            streakDays: 12,
            multiplier: 2.1,
            breakdown: [
                .init(name: "10+ días consecutivos", value: 1.0, icon: "flame.fill", isActive: true),
                .init(name: "4 materias esta semana", value: 0.3, icon: "books.vertical.fill", isActive: true),
                .init(name: "Quiz perfecto hoy", value: 0.1, icon: "checkmark.seal.fill", isActive: true),
                .init(name: "Meta diaria cumplida", value: 0.0, icon: "target", isActive: false)
            ]
        )

        CompactStreakBadge(streakDays: 12, multiplier: 2.1)
    }
    .padding()
    .background(Color(uiColor: .systemBackground))
}
