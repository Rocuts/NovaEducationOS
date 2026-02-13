import SwiftUI

struct ChatHeaderView: View {
    let subject: Subject
    let onBack: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Content area - uses safe area automatically
            HStack {
                // Back Button
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }

                Spacer()

                // Title - Liquid Glass pill
                VStack(spacing: 2) {
                    Text(subject.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Chat con IA")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: Capsule())

                Spacer()

                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        )
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
            onBack: {},
            onDelete: {}
        )
    }
}
