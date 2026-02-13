import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    var isStreaming: Bool = false
    @Environment(TextToSpeechService.self) private var textToSpeech

    var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            // Avatar for assistant
            if !isUser {
                assistantAvatar
            }

            // Message content
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                messageContent

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    // MARK: - Assistant Avatar
    private var assistantAvatar: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFill()
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    // MARK: - Message Content
    private var messageContent: some View {
        Group {
            if isUser {
                userBubble
            } else {
                assistantBubble
            }
        }
    }

    // MARK: - User Bubble
    private var userBubble: some View {
        Text(message.content)
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(BubbleShape(isUser: true))
            .shadow(color: .blue.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    // MARK: - Assistant Bubble with Markdown/LaTeX support
    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MarkdownTextView handles both plain markdown and LaTeX automatically
            MarkdownTextView(content: message.content, isUser: false)
                .font(.body)

            // Generated image if available
            if message.hasImage, let imageURL = message.imageURL {
                generatedImageView(url: imageURL)
                    .padding(.top, 12)
            }

            // Action buttons (only show when message is complete)
            if !isStreaming {
                HStack(spacing: 12) {
                    // Text-to-speech button
                    if textToSpeech.isSpeaking && textToSpeech.currentlySpeakingID == message.id {
                        Button {
                            textToSpeech.stop()
                        } label: {
                            Label("Detenerse", systemImage: "stop.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(.red.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    } else {
                        Button {
                            textToSpeech.speak(message.content, id: message.id)
                        } label: {
                            Label("Leer", systemImage: "speaker.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(.primary)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(BubbleShape(isUser: false))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay {
            BubbleShape(isUser: false)
                .stroke(
                    Color.primary.opacity(0.05),
                    lineWidth: 0.5
                )
        }
    }

    // MARK: - Generated Image View
    @ViewBuilder
    private func generatedImageView(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image label
            HStack(spacing: 4) {
                Image(systemName: "apple.image.playground")
                    .font(.caption2)
                Text("Imagen generada")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            // Async image loading
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 200)
                        .overlay {
                            SwiftUI.ProgressView()
                        }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                case .failure:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 100)
                        .overlay {
                            VStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.secondary)
                                Text("No se pudo cargar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Custom Bubble Shape
struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6

        var path = Path()

        if isUser {
            // User bubble - tail on right
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            // Tail
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX + tailSize, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        } else {
            // Assistant bubble - tail on left
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            // Tail
            path.addQuadCurve(
                to: CGPoint(x: rect.minX - tailSize, y: rect.maxY),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview Helper
/// A preview-only wrapper for MessageBubble that doesn't require SwiftData
private struct MessageBubblePreviewWrapper: View {
    let role: MessageRole
    let content: String
    @State private var textToSpeech = TextToSpeechService()

    var body: some View {
        let message = ChatMessage(role: role, content: content, subjectId: "math")
        MessageBubble(message: message)
            .environment(textToSpeech)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            MessageBubblePreviewWrapper(
                role: .user,
                content: "Hola, como puedo resolver esta ecuacion?"
            )

            MessageBubblePreviewWrapper(
                role: .assistant,
                content: "Claro, te explico paso a paso como resolver esa ecuacion. Primero necesitamos identificar los **terminos**..."
            )

            MessageBubblePreviewWrapper(
                role: .assistant,
                content: "La fórmula cuadrática es $x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$"
            )

            MessageBubblePreviewWrapper(
                role: .assistant,
                content: """
                Para resolver esta ecuación:

                $$x^2 + 5x + 6 = 0$$

                Factorizamos: $(x + 2)(x + 3) = 0$

                Por lo tanto: $x = -2$ o $x = -3$
                """
            )
        }
        .padding()
    }
    .background(Color(uiColor: .systemBackground))
}
