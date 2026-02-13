import SwiftUI

/// Card que muestra las misiones diarias
struct DailyQuestsCard: View {
    let quests: [DailyQuest]
    let onQuestTap: (DailyQuest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "target")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text("Misiones de Hoy")
                    .font(.headline)

                Spacer()

                // Progress indicator
                if !quests.isEmpty {
                    let completed = quests.filter { $0.isCompleted }.count
                    Text("\(completed)/\(quests.count)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
            }

            // Quests list
            if quests.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(quests, id: \.id) { quest in
                        QuestRow(quest: quest, onTap: { onQuestTap(quest) })
                    }
                }
            }

            // Total XP available
            if !quests.isEmpty {
                let pendingXP = quests.filter { $0.isActive }.reduce(0) { $0 + $1.xpReward }
                if pendingXP > 0 {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.yellow)

                        Text("\(pendingXP) XP disponibles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text("¡Todas las misiones completadas!")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Vuelve mañana para nuevos desafíos")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Quest Row

struct QuestRow: View {
    let quest: DailyQuest
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Type icon
                ZStack {
                    Circle()
                        .fill(quest.isCompleted ? Color.green.opacity(0.2) : quest.type.color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    if quest.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: quest.type.icon)
                            .font(.title3)
                            .foregroundStyle(quest.type.color)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(quest.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(quest.isCompleted ? .secondary : .primary)
                            .strikethrough(quest.isCompleted)

                        Spacer()

                        // XP reward
                        Text("+\(quest.xpReward) XP")
                            .font(.caption.bold())
                            .foregroundStyle(quest.isCompleted ? .secondary : quest.type.color)
                    }

                    HStack {
                        // Type badge
                        Text(quest.type.displayName)
                            .font(.caption2.bold())
                            .foregroundStyle(quest.type.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(quest.type.color.opacity(0.15), in: Capsule())

                        Text("•")
                            .foregroundStyle(.tertiary)

                        // Time estimate
                        Text("\(quest.estimatedMinutes) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let subject = Subject(rawValue: quest.subjectId) {
                            Text("•")
                                .foregroundStyle(.tertiary)

                            Text(subject.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(quest.isCompleted ? Color.green.opacity(0.05) : Color.primary.opacity(0.03))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(quest.isCompleted ? Color.green.opacity(0.2) : Color.clear, lineWidth: 1)
            }
            .scaleEffect(isPressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .disabled(quest.isCompleted)
        .sensoryFeedback(.selection, trigger: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Compact Quest Card

/// Versión compacta para HomeView
struct CompactQuestsCard: View {
    let quests: [DailyQuest]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)

                    Image(systemName: "target")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Misiones de Hoy")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    let completed = quests.filter { $0.isCompleted }.count
                    let total = quests.count
                    let pendingXP = quests.filter { $0.isActive }.reduce(0) { $0 + $1.xpReward }

                    HStack {
                        Text("\(completed)/\(total) completadas")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if pendingXP > 0 {
                            Text("•")
                                .foregroundStyle(.tertiary)

                            Text("\(pendingXP) XP")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Daily Quests Card") {
    ScrollView {
        VStack(spacing: 20) {
            DailyQuestsCard(
                quests: [
                    DailyQuest(type: .quick, title: "Pregunta curiosa", description: "Haz una pregunta", subjectId: "abierta"),
                    DailyQuest(type: .challenge, title: "Resuelve 3 problemas", description: "Practica álgebra", subjectId: "matematicas"),
                    DailyQuest(type: .epic, title: "Conexión de conocimientos", description: "Conecta dos materias", subjectId: "abierta")
                ],
                onQuestTap: { _ in }
            )

            CompactQuestsCard(
                quests: [
                    DailyQuest(type: .quick, title: "Test", description: "Test", subjectId: "abierta"),
                    DailyQuest(type: .challenge, title: "Test", description: "Test", subjectId: "abierta")
                ],
                onTap: {}
            )
        }
        .padding()
    }
    .background(Color(uiColor: .systemBackground))
}
