import SwiftUI

/// Badge que muestra la racha actual y el multiplicador de XP
struct StreakMultiplierBadge: View {
    let streakDays: Int
    let multiplier: Double
    let breakdown: [XPManager.MultiplierBonus]

    @State private var isExpanded = false
    @State private var flameAnimation = false
    @State private var multiplierPulse = false
    @State private var flameGlow = false
    @State private var flameTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Main badge (always visible)
            Button {
                withAnimation(Nova.Animation.springDefault) {
                    isExpanded.toggle()
                }
                Nova.Haptics.light()
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: isExpanded ? 20 : 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Racha de \(streakDays) \(streakDays == 1 ? "día" : "días"). Multiplicador de experiencia: \(String(format: "%.1f", multiplier))x")
        .accessibilityHint("Toca dos veces para ver el desglose del multiplicador")
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            flameTask?.cancel()
            flameTask = nil
        }
    }

    private var mainBadge: some View {
        HStack(spacing: 16) {
            // Streak with glow
            HStack(spacing: 6) {
                ZStack {
                    // Flame glow (behind)
                    if streakDays >= 3 {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundStyle(streakDays > 7 ? .red : .orange)
                            .blur(radius: 8)
                            .opacity(flameGlow ? 0.6 : 0.2)
                    }

                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(streakGradient)
                        .symbolEffect(.bounce, value: flameAnimation)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(streakDays)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(value: Double(streakDays)))

                    Text(streakDays == 1 ? "día" : "días")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .frame(height: 36)

            // Multiplier with pulse
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 0) {
                    Text("x\(String(format: "%.1f", multiplier))")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .scaleEffect(multiplierPulse ? 1.08 : 1.0)
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

            ForEach(Array(breakdown.enumerated()), id: \.element.id) { index, bonus in
                HStack {
                    Image(systemName: bonus.icon)
                        .font(.subheadline)
                        .foregroundStyle(bonus.isActive ? Color.primary : Color.secondary.opacity(0.6))
                        .frame(width: 24)

                    Text(bonus.name)
                        .font(.subheadline)
                        .foregroundStyle(bonus.isActive ? Color.primary : Color.secondary.opacity(0.6))

                    Spacer()

                    Text("+\(String(format: "%.1f", bonus.value))x")
                        .font(.subheadline.bold())
                        .foregroundStyle(bonus.isActive ? Color.green : Color.secondary.opacity(0.6))
                }
                .opacity(isExpanded ? 1 : 0)
                .offset(y: isExpanded ? 0 : -5)
                .animation(
                    Nova.Animation.stagger(index: index),
                    value: isExpanded
                )
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

    private func startAnimations() {
        // Flame bounce with managed task
        flameTask?.cancel()
        flameTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { return }
                flameAnimation.toggle()
            }
        }

        // Flame glow pulse
        withAnimation(Nova.Animation.glowPulse) {
            flameGlow = true
        }

        // Multiplier subtle pulse
        if multiplier > 1.0 {
            withAnimation(Nova.Animation.breathe.delay(0.5)) {
                multiplierPulse = true
            }
        }
    }
}

// MARK: - Compact Streak Badge

/// Versión compacta para headers
struct CompactStreakBadge: View {
    let streakDays: Int
    let multiplier: Double

    @State private var flameGlow = false

    var body: some View {
        HStack(spacing: 8) {
            // Streak
            HStack(spacing: 4) {
                ZStack {
                    if streakDays >= 3 {
                        Image(systemName: "flame.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .blur(radius: 4)
                            .opacity(flameGlow ? 0.5 : 0.1)
                    }

                    Image(systemName: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }

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
        .onAppear {
            withAnimation(Nova.Animation.glowPulse) {
                flameGlow = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Racha de \(streakDays) días. Multiplicador \(String(format: "%.1f", multiplier))")
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
