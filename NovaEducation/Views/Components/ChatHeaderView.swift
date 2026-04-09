import SwiftUI

struct ChatHeaderView: View {
    let subject: Subject
    let isThinking: Bool
    let isListening: Bool
    let audioLevel: Float
    let onBack: () -> Void
    let onDelete: () -> Void
    let onVoiceMode: () -> Void

    @Namespace private var headerGlassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 40.0) {
            HStack {
                // Back Button
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular, in: .circle)
                }
                .glassEffectID("backButton", in: headerGlassNamespace)
                .accessibilityLabel("Regresar")
                .accessibilityHint("Toca dos veces para volver al inicio")

                Spacer()

                // Title - Liquid Glass pill (Interactive for Voice Mode)
                Button(action: onVoiceMode) {
                    HStack(spacing: 8) {
                        NovaAvatarView(
                            state: isThinking ? .thinking : (isListening ? .listening : .idle),
                            audioLevel: audioLevel
                        )
                        .frame(width: 32, height: 32)

                        Text(subject.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 16)
                    .padding(.vertical, 6)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .glassEffectID("titlePill", in: headerGlassNamespace)
                .buttonStyle(.squishy)
                .accessibilityLabel("Modo de voz")
                .accessibilityHint("Toca dos veces para activar el modo de voz")

                Spacer()

                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.red.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular, in: .circle)
                }
                .glassEffectID("deleteButton", in: headerGlassNamespace)
                .accessibilityLabel("Borrar conversación")
                .accessibilityHint("Toca dos veces para eliminar esta conversación")
            }
        }
        .padding(.horizontal, Nova.Spacing.lg)
        .padding(.vertical, Nova.Spacing.sm)
    }
}

#Preview {
    VStack {
        Text("Contenido de ejemplo")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue.opacity(0.1))
    }
    .safeAreaInset(edge: .top) {
        ChatHeaderView(
            subject: .math,
            isThinking: false,
            isListening: true,
            audioLevel: 0.5,
            onBack: {},
            onDelete: {},
            onVoiceMode: {}
        )
    }
}
