import SwiftUI

/// Animated thinking indicator with three bouncing dots
struct ThinkingIndicator: View {
    let color: Color
    @State private var animatingDot = 0

    private let dotSize: CGFloat = 8
    private let animationDuration: Double = 0.4

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color.opacity(animatingDot == index ? 1 : 0.4))
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: animatingDot == index ? -4 : 0)
                    .animation(
                        .easeInOut(duration: animationDuration),
                        value: animatingDot
                    )
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: animationDuration, repeats: true) { _ in
            withAnimation {
                animatingDot = (animatingDot + 1) % 3
            }
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
