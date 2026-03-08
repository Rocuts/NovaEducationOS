import SwiftUI
import SwiftData
import AVFoundation

struct VoiceModeView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query private var userSettings: [UserSettings]
    @State private var voiceManager = VoiceModeManager()
    @State private var showControls = true
    @State private var didConfigure = false

    // MARK: - Adaptive Colors
    private var backgroundGradientColors: [Color] {
        [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground)]
    }

    private var auroraIntensity: Double {
        colorScheme == .dark ? 0.4 : 0.25
    }

    private var primaryTextStyle: Color {
        .primary
    }

    private var closeButtonForeground: Color {
        .secondary
    }

    var body: some View {
        ZStack {
            // Background - Adaptive immersive gradient
            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Nebula effect (subtle, reduced in light mode)
            AuroraBackgroundView(
                primaryColor: .purple.opacity(0.3),
                secondaryColor: .blue.opacity(0.2),
                intensity: auroraIntensity
            )
            .blur(radius: 50)

            VStack {
                // Header (Close button)
                HStack {
                    Spacer()
                    Button {
                        voiceManager.stopSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(closeButtonForeground)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 10, x: 0, y: 5)
                            )
                    }
                    .accessibilityLabel("Cerrar modo de voz")
                    .accessibilityHint("Toca dos veces para salir del modo de voz")
                    .padding(.top, Nova.Spacing.xl)
                    .padding(.trailing, Nova.Spacing.xl)
                }

                Spacer()

                // Central Avatar
                ZStack {
                    NovaAvatarView(
                        state: {
                            switch voiceManager.state {
                            case .processing: return .thinking
                            case .listening: return .listening
                            case .speaking: return .speaking
                            case .error(_): return .error
                            case .idle: return .idle
                            }
                        }(),
                        audioLevel: voiceManager.audioLevel
                    )
                    .frame(width: 250, height: 250)
                    .scaleEffect(voiceManager.state == .listening ? 1.05 : 1.0)
                    .animation(Nova.Animation.hoverFeedback, value: voiceManager.state)
                    .onTapGesture {
                        voiceManager.toggleListening()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel({
                        switch voiceManager.state {
                        case .idle: return "Nova, inactiva"
                        case .listening: return "Nova, escuchando"
                        case .processing: return "Nova, procesando"
                        case .speaking: return "Nova, hablando"
                        case .error(let msg): return "Nova, error: \(msg)"
                        }
                    }())
                    .accessibilityHint({
                        switch voiceManager.state {
                        case .listening: return "Toca dos veces para enviar tu mensaje"
                        case .idle, .error: return "Toca dos veces para empezar a hablar"
                        case .speaking, .processing: return "Espera mientras Nova responde"
                        }
                    }())
                }

                Spacer()

                // Zero UI: No "Status Text". Trust the Avatar.
                // Just refined Captions.
                if !voiceManager.currentTranscript.isEmpty && voiceManager.state == .listening {
                    Text(voiceManager.currentTranscript)
                        .font(.body)
                        .fontDesign(.rounded)
                        .fontWeight(.medium)
                        .foregroundStyle(primaryTextStyle)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Nova.Spacing.jumbo)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id("MainTranscript")
                }

                // ERROR DISPLAY
                if case .error(let errorMessage) = voiceManager.state {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: Nova.Radius.sm))
                }
            }
            .safeAreaPadding(.bottom, Nova.Spacing.xl)
        }
        .onChange(of: voiceManager.currentTranscript) { _, newValue in
            if !newValue.isEmpty {
                AccessibilityNotification.Announcement(newValue).post()
            }
        }
        .task {
            // Reconfigure with actual student settings if available
            if !didConfigure, let settings = userSettings.first {
                voiceManager = VoiceModeManager(
                    studentName: settings.studentName,
                    educationLevel: settings.educationLevel
                )
                didConfigure = true
            }
            try? await Task.sleep(for: .seconds(0.5))
            voiceManager.startSession()
        }
        .onDisappear {
            voiceManager.stopSession()
        }
    }
    
    private var stateColor: Color {
        switch voiceManager.state {
        case .idle: return .gray
        case .listening: return .cyan
        case .processing: return .purple
        case .speaking: return .green // Or orange/warm for Nova voice
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch voiceManager.state {
        case .idle: return "Toca para hablar"
        case .listening: return "Escuchando..."
        case .processing: return "Pensando..."
        case .speaking: return "Nova" // Or speaking indicator
        case .error(let msg): return msg
        }
    }
}
