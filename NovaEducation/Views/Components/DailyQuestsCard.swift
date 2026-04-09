import SwiftUI
import AVFoundation

/// Card que muestra las misiones diarias
struct DailyQuestsCard: View {
    let quests: [DailyQuest]
    let onQuestTap: (DailyQuest) -> Void

    @State private var visibleQuests: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Nova.Spacing.lg) {
            header
            questsContent
            xpSummary
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.card))
    }

    private var header: some View {
        HStack {
            Image(systemName: "target")
                .font(.title2)
                .foregroundStyle(.blue)

            Text("Misiones de Hoy")
                .font(.headline)

            Spacer()

            if !quests.isEmpty {
                let completed = quests.filter { $0.isCompleted }.count
                QuestProgressRing(completed: completed, total: quests.count)
            }
        }
    }

    @ViewBuilder
    private var questsContent: some View {
        if quests.isEmpty {
            emptyState
        } else {
            VStack(spacing: Nova.Spacing.md) {
                ForEach(Array(quests.enumerated()), id: \.element.id) { index, quest in
                    AnimatedQuestRow(
                        quest: quest,
                        index: index,
                        visibleQuests: $visibleQuests,
                        onTap: { onQuestTap(quest) }
                    )
                }
            }
        }
    }

    private var pendingXP: Int {
        quests.filter { $0.isActive }.reduce(0) { $0 + $1.xpReward }
    }

    @ViewBuilder
    private var xpSummary: some View {
        if !quests.isEmpty, pendingXP > 0 {
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
    private var emptyState: some View {
        VStack(spacing: Nova.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .nonRepeating)

            Text("¡Todas las misiones completadas!")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Vuelve mañana para nuevos desafíos")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Nova.Spacing.xl)
    }
}

struct AnimatedQuestRow: View {
    let quest: DailyQuest
    let index: Int
    @Binding var visibleQuests: Set<UUID>
    let onTap: () -> Void

    var body: some View {
        QuestRow(quest: quest, onTap: onTap)
            .opacity(visibleQuests.contains(quest.id) ? 1 : 0)
            .offset(y: visibleQuests.contains(quest.id) ? 0 : 15)
            .onAppear {
                withAnimation(
                    Nova.Animation.entranceMedium
                    .delay(Double(index) * 0.1)
                ) {
                    _ = visibleQuests.insert(quest.id)
                }
            }
    }
}

// MARK: - Quest Progress Ring

struct QuestProgressRing: View {
    let completed: Int
    let total: Int

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 3)
                .frame(width: 30, height: 30)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(colors: [.blue, .green], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(-90))

            Text("\(completed)")
                .font(.caption2.bold())
                .fontDesign(.rounded)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completed) de \(total) misiones completadas")
        .accessibilityValue("\(Int(progress * 100)) por ciento")
        .onAppear {
            withAnimation(Nova.Animation.entranceSlow.delay(0.3)) {
                animatedProgress = progress
            }
        }
        .onChange(of: completed) { _, _ in
            withAnimation(Nova.Animation.springBouncy) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Quest Row

struct QuestRow: View {
    let quest: DailyQuest
    let onTap: () -> Void

    @State private var isPressed = false
    @State private var justCompleted = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var completionGlow = false
    @ScaledMetric(relativeTo: .body) private var questIconSize: CGFloat = 44

    var body: some View {
        Button(action: {
            if !quest.isCompleted {
                triggerCompletionAnimation()
            }
            onTap()
        }) {
            HStack(spacing: Nova.Spacing.md) {
                // Type icon with completion animation
                ZStack {
                    Circle()
                        .fill(quest.isCompleted ? Color.green.opacity(0.2) : quest.type.color.opacity(0.2))
                        .frame(width: questIconSize, height: questIconSize)

                    // Completion glow ring
                    if justCompleted {
                        Circle()
                            .stroke(Color.green.opacity(completionGlow ? 0 : 0.6), lineWidth: 2)
                            .frame(width: completionGlow ? questIconSize + 16 : questIconSize, height: completionGlow ? questIconSize + 16 : questIconSize)
                    }

                    if quest.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                            .scaleEffect(quest.isCompleted && checkmarkScale > 0 ? checkmarkScale : 1)
                    } else {
                        Image(systemName: quest.type.icon)
                            .font(.title3)
                            .foregroundStyle(quest.type.color)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: Nova.Spacing.xxs) {
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
                            .padding(.horizontal, Nova.Spacing.xs)
                            .padding(.vertical, Nova.Spacing.xxxs)
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
            .padding(Nova.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Nova.Radius.md)
                    .fill(quest.isCompleted ? Color.green.opacity(0.05) : Color.primary.opacity(0.03))
            )
            .overlay {
                RoundedRectangle(cornerRadius: Nova.Radius.md)
                    .stroke(quest.isCompleted ? Color.green.opacity(0.2) : Color.clear, lineWidth: 1)
            }
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .disabled(quest.isCompleted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(quest.title). \(quest.type.displayName), \(quest.estimatedMinutes) minutos. Recompensa: \(quest.xpReward) puntos de experiencia. \(quest.isCompleted ? "Completada" : "Pendiente")")
        .accessibilityHint(quest.isCompleted ? "" : "Toca dos veces para completar esta misión")
        .sensoryFeedback(.selection, trigger: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            withAnimation(Nova.Animation.springSnappy) {
                isPressed = pressing
            }
        }, perform: {})
        .onAppear {
            if quest.isCompleted {
                checkmarkScale = 1
            }
        }
    }

    private func triggerCompletionAnimation() {
        justCompleted = true

        // Checkmark bounce in
        withAnimation(Nova.Animation.springBouncy) {
            checkmarkScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(Nova.Animation.springSnappy) {
                checkmarkScale = 1
            }
        }

        // Expanding glow ring
        withAnimation(Nova.Animation.exitMedium) {
            completionGlow = true
        }

        // Haptic + Sound
        Nova.Haptics.success()
        CelebrationSoundService.shared.play(.questComplete)
    }
}

// MARK: - Compact Quest Card

/// Versión compacta para HomeView
struct CompactQuestsCard: View {
    let quests: [DailyQuest]
    let onTap: () -> Void
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 44

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Nova.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: iconSize, height: iconSize)

                    Image(systemName: "target")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: Nova.Spacing.xxs) {
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Misiones de Hoy. \(quests.filter { $0.isCompleted }.count) de \(quests.count) completadas")
        .accessibilityHint("Toca dos veces para ver las misiones")
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
