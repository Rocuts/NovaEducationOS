import SwiftUI
import SwiftData

/// Banner that displays the current state of image generation
struct ImageGenerationBanner: View {
    let state: ImageGenerationState
    let subjectColor: Color

    var body: some View {
        if state.isActive {
            HStack(spacing: 12) {
                // Animated icon
                Group {
                    switch state {
                    case .analyzing:
                        Image(systemName: "sparkle.magnifyingglass")
                            .symbolEffect(.pulse, isActive: true)
                    case .generating:
                        Image(systemName: "apple.image.playground")
                            .symbolEffect(.bounce, options: .repeating, value: true)
                    case .completed:
                        Image(systemName: "checkmark.circle.fill")
                            .symbolEffect(.bounce, value: true)
                    case .failed:
                        Image(systemName: "exclamationmark.triangle.fill")
                            .symbolEffect(.pulse, value: true)
                    default:
                        Image(systemName: "photo")
                    }
                }
                .font(.title3)
                .foregroundStyle(state.isFailed ? .red : subjectColor)
                .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bannerTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(state.isFailed ? .red : .primary)

                    Text(state.statusMessage)
                        .font(.caption)
                        .foregroundStyle(state.isFailed ? .red.opacity(0.8) : .secondary)
                }

                Spacer()

                // Progress indicator (only when processing)
                if case .analyzing = state {
                    ProgressView().tint(subjectColor)
                } else if case .generating = state {
                    ProgressView().tint(subjectColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityStateLabel)
            .onChange(of: state) { _, newState in
                if case .generating = newState {
                    AccessibilityNotification.Announcement("Generando imagen educativa").post()
                } else if case .completed = newState {
                    AccessibilityNotification.Announcement("Imagen generada exitosamente").post()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    private var accessibilityStateLabel: String {
        switch state {
        case .analyzing:
            return "Analizando contenido para generar imagen"
        case .generating:
            return "Generando imagen educativa"
        case .completed:
            return "Imagen generada exitosamente"
        case .failed(let error):
            return "Error al generar imagen: \(error)"
        default:
            return ""
        }
    }

    private var bannerTitle: String {
        switch state {
        case .analyzing:
            return "Analizando contenido"
        case .generating:
            return "Creando imagen"
        case .completed:
            return "¡Imagen lista!"
        case .failed:
            return "No se pudo crear"
        default:
            return ""
        }
    }
}

/// Compact version of the banner for inline display
struct ImageGenerationIndicator: View {
    let isActive: Bool
    let subjectColor: Color

    var body: some View {
        if isActive {
            HStack(spacing: 8) {
                Image(systemName: "apple.image.playground")
                    .symbolEffect(.bounce, options: .repeating, value: isActive)
                    .foregroundStyle(subjectColor)

                Text("Generando imagen...")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView()
                    .scaleEffect(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(subjectColor.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

#Preview("Banner - Generating") {
    ImageGenerationBanner(
        state: .generating(prompt: "A realistic planet Saturn"),
        subjectColor: .blue
    )
    .padding()
}

#Preview("Banner - Completed") {
    ImageGenerationBanner(
        state: .completed(imageURL: URL(fileURLWithPath: "/tmp/test.png")),
        subjectColor: .green
    )
    .padding()
}

#Preview("Indicator") {
    ImageGenerationIndicator(
        isActive: true,
        subjectColor: .purple
    )
    .padding()
}
