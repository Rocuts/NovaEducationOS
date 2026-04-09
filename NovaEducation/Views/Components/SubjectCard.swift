import SwiftUI

struct SubjectCard: View {
    let subject: Subject

    var body: some View {
        VStack(spacing: Nova.Spacing.md) {
            // Icon circle with subject color
            ZStack {
                Circle()
                    .fill(subject.color.gradient)
                    .frame(width: 50, height: 50)

                Image(systemName: subject.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Text(subject.displayName)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .padding(.vertical, Nova.Spacing.md)
        .padding(.horizontal, Nova.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.card))
        .shadow(color: subject.color.opacity(0.08), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subject.displayName)
        .accessibilityHint("Toca dos veces para estudiar \(subject.displayName)")
    }
}

// MARK: - Alternative Compact Card

struct SubjectCardCompact: View {
    let subject: Subject

    var body: some View {
        HStack(spacing: Nova.Spacing.md) {
            ZStack {
                Circle()
                    .fill(subject.color.gradient)
                    .frame(width: 40, height: 40)

                Image(systemName: subject.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Text(subject.displayName)
                .font(.subheadline.weight(.medium))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Nova.Spacing.lg)
        .padding(.vertical, Nova.Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.button))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(subject.displayName)
        .accessibilityHint("Toca dos veces para estudiar \(subject.displayName)")
    }
}

#Preview("Standard Card") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: Nova.Spacing.lg) {
        ForEach(Subject.allCases) { subject in
            SubjectCard(subject: subject)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Compact Card") {
    VStack(spacing: Nova.Spacing.md) {
        ForEach(Subject.allCases.prefix(4)) { subject in
            SubjectCardCompact(subject: subject)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
