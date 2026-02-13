import SwiftUI

struct SubjectCard: View {
    let subject: Subject
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 12) {
            // Icon with gradient background
            ZStack {
                // Glow effect
                Circle()
                    .fill(subject.color.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .blur(radius: 12)

                // Icon circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                subject.color,
                                subject.color.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: subject.color.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: subject.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .speed(1.5), value: isHovered)
            }

            // Text
            VStack(spacing: 4) {
                Text(subject.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.3),
                            .white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .sensoryFeedback(.selection, trigger: isHovered)
    }
}

// MARK: - Alternative Compact Card
struct SubjectCardCompact: View {
    let subject: Subject

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [subject.color, subject.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: subject.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(subject.displayName)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("Standard Card") {
    ZStack {
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
            ForEach(Subject.allCases) { subject in
                SubjectCard(subject: subject)
            }
        }
        .padding()
    }
}

#Preview("Compact Card") {
    ZStack {
        Color(uiColor: .systemBackground)
            .ignoresSafeArea()

        VStack(spacing: 12) {
            ForEach(Subject.allCases.prefix(4)) { subject in
                SubjectCardCompact(subject: subject)
            }
        }
        .padding()
    }
}
