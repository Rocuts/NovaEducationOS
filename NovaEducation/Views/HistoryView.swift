import SwiftUI
import SwiftData

struct HistoryView: View {
    @Binding var selectedSubject: Subject?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatMessage.timestamp, order: .reverse) private var allMessages: [ChatMessage]

    // Group messages by subject and get the most recent for each
    private var recentConversations: [(subject: Subject, lastMessage: ChatMessage, messageCount: Int)] {
        var subjectMessages: [String: [ChatMessage]] = [:]

        for message in allMessages {
            subjectMessages[message.subjectId, default: []].append(message)
        }

        return subjectMessages.compactMap { (subjectId, messages) in
            guard let subject = Subject(rawValue: subjectId),
                  let lastMessage = messages.first else { return nil }
            return (subject: subject, lastMessage: lastMessage, messageCount: messages.count)
        }
        .sorted { $0.lastMessage.timestamp > $1.lastMessage.timestamp }
    }

    @State private var rowsAppeared = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Nova.Spacing.md) {
                if recentConversations.isEmpty {
                    emptyStateView
                } else {
                    ForEach(Array(recentConversations.enumerated()), id: \.element.subject.id) { index, conversation in
                        ConversationRow(
                            subject: conversation.subject,
                            lastMessage: conversation.lastMessage,
                            messageCount: conversation.messageCount
                        ) {
                            selectedSubject = conversation.subject
                        }
                        .opacity(rowsAppeared ? 1 : 0)
                        .offset(y: rowsAppeared ? 0 : 20)
                        .animation(Nova.Animation.stagger(index: index), value: rowsAppeared)
                    }
                }
            }
            .padding()
            .onAppear { rowsAppeared = true }
        }
        .contentMargins(.bottom, Nova.Spacing.tabBarClearance, for: .scrollContent)
        .background(backgroundGradient)
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: Nova.Spacing.lg) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating)

            Text("Sin conversaciones")
                .font(.headline)

            Text("Inicia tu primera conversación eligiendo una materia")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Nova.Spacing.ultra)
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
    }
}

// MARK: - Conversation Row
struct ConversationRow: View {
    let subject: Subject
    let lastMessage: ChatMessage
    let messageCount: Int
    let onTap: () -> Void

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastMessage.timestamp, relativeTo: Date())
    }

    private var previewText: String {
        let text = lastMessage.content
        if text.count > 60 {
            return String(text.prefix(60)) + "..."
        }
        return text
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Nova.Spacing.lg) {
                // Subject Icon
                ZStack {
                    Circle()
                        .fill(subject.color.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: subject.icon)
                        .font(.title3)
                        .foregroundStyle(subject.color)
                }

                // Content
                VStack(alignment: .leading, spacing: Nova.Spacing.xxs) {
                    HStack {
                        Text(subject.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(timeAgo)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Text(previewText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: Nova.Spacing.xxs) {
                        Image(systemName: "message.fill")
                            .font(.caption2)
                        Text("\(messageCount) mensajes")
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                }

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Nova.Radius.lg))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(subject.displayName), \(previewText)")
            .accessibilityHint("Toca dos veces para abrir esta conversación")
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HistoryView(selectedSubject: .constant(nil))
    }
    .modelContainer(for: [ChatMessage.self, UserSettings.self, StudySession.self, DailyActivity.self, Achievement.self], inMemory: true)
}
