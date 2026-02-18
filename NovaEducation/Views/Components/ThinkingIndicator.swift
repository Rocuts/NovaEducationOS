import SwiftUI

/// Animated thinking indicator with three bouncing dots.
/// Uses PhaseAnimator for lifecycle-safe animations instead of Timer.scheduledTimer.
struct ThinkingIndicator: View {
    let color: Color

    private let dotSize: CGFloat = 8

    /// Phases cycle through highlighting each dot, then a brief pause.
    private enum Phase: CaseIterable {
        case dot0, dot1, dot2, pause
    }

    var body: some View {
        PhaseAnimator(Phase.allCases) { phase in
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(color.opacity(dotOpacity(for: index, in: phase)))
                        .frame(width: dotSize, height: dotSize)
                        .offset(y: dotOffset(for: index, in: phase))
                }
            }
        } animation: { phase in
            switch phase {
            case .pause:
                Nova.Animation.exitMedium
            default:
                Nova.Animation.dotBounce
            }
        }
    }

    private func dotOpacity(for index: Int, in phase: Phase) -> Double {
        switch phase {
        case .dot0: index == 0 ? 1.0 : 0.4
        case .dot1: index == 1 ? 1.0 : 0.4
        case .dot2: index == 2 ? 1.0 : 0.4
        case .pause: 0.4
        }
    }

    private func dotOffset(for index: Int, in phase: Phase) -> CGFloat {
        switch phase {
        case .dot0: index == 0 ? -4 : 0
        case .dot1: index == 1 ? -4 : 0
        case .dot2: index == 2 ? -4 : 0
        case .pause: 0
        }
    }
}

/// Bubble-style thinking indicator that matches the assistant message style
struct ThinkingBubble: View {
    let subjectColor: Color
    var message: String = "Creando imagen"

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar
            Image("AppLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            // Bubble content
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "apple.image.playground")
                        .font(.subheadline)
                        .foregroundStyle(subjectColor)
                        .symbolEffect(.bounce, options: .repeating, value: true)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ThinkingIndicator(color: subjectColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(BubbleShape(isUser: false))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

            Spacer(minLength: 60)
        }
    }
}

#Preview("Thinking Indicator") {
    VStack(spacing: 40) {
        ThinkingIndicator(color: .blue)
        ThinkingIndicator(color: .green)
        ThinkingIndicator(color: .purple)
    }
    .padding()
}

#Preview("Thinking Bubble") {
    VStack(spacing: 20) {
        ThinkingBubble(subjectColor: .blue)
        ThinkingBubble(subjectColor: .green, message: "Pensando")
    }
    .padding()
}
