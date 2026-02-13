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

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if recentConversations.isEmpty {
                    emptyStateView
                } else {
                    ForEach(recentConversations, id: \.subject.id) { conversation in
                        ConversationRow(
                            subject: conversation.subject,
                            lastMessage: conversation.lastMessage,
                            messageCount: conversation.messageCount
                        ) {
                            selectedSubject = conversation.subject
                        }
                    }
                }
            }
            .padding()
        }
        .contentMargins(.bottom, 100, for: .scrollContent)
        .background(backgroundGradient)
        .navigationTitle("Historial")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Sin conversaciones")
                .font(.headline)

            Text("Tus conversaciones recientes apareceran aqui")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemBackground),
                Color.purple.opacity(0.05),
                Color(uiColor: .systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
            HStack(spacing: 16) {
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
                VStack(alignment: .leading, spacing: 4) {
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

                    HStack(spacing: 4) {
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
