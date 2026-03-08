import SwiftUI

// MARK: - Nova Avatar State

/// Animation state for the Nova avatar.
/// Drives facial expressions, hat motion, bubble scale, and breathing offsets.
/// `blink` is handled internally as an overlay event, not an explicit state.
enum NovaAvatarState: Equatable {
    case idle
    case listening
    case thinking
    case speaking
    case error
    case success
}

// MARK: - Anchor Box (1024×1024 coordinate space)

/// A bounding box in the 1024×1024 logo canvas coordinate space.
/// Derived from logo_morphology.json `bounding_boxes_px`.
struct AnchorBox: Equatable {
    let x0: CGFloat
    let y0: CGFloat
    let x1: CGFloat
    let y1: CGFloat

    var center: CGPoint {
        CGPoint(x: (x0 + x1) / 2, y: (y0 + y1) / 2)
    }

    var size: CGSize {
        CGSize(width: x1 - x0, height: y1 - y0)
    }
}

// MARK: - Nova Anchors (from logo_morphology.json)

/// All anchor bounding boxes from the logo morphology JSON.
/// Coordinates are in the 1024×1024 pixel-perfect canvas space.
enum NovaAnchors {
    static let overallNonwhite    = AnchorBox(x0: 239, y0: 111, x1: 784, y1: 912)
    static let topHatPlusBubble   = AnchorBox(x0: 239, y0: 111, x1: 784, y1: 704)
    static let hatApprox          = AnchorBox(x0: 271, y0: 111, x1: 752, y1: 280)
    static let speechBubbleApprox = AnchorBox(x0: 239, y0: 280, x1: 784, y1: 704)
    static let book               = AnchorBox(x0: 239, y0: 687, x1: 784, y1: 912)
    static let leftEyeApprox     = AnchorBox(x0: 388, y0: 415, x1: 454, y1: 481)
    static let rightEyeApprox    = AnchorBox(x0: 571, y0: 415, x1: 637, y1: 481)
    static let smileApprox        = AnchorBox(x0: 449, y0: 512, x1: 576, y1: 559)

    /// All named anchors for programmatic iteration.
    static let all: [String: AnchorBox] = [
        "hat_approx": hatApprox,
        "speech_bubble_approx": speechBubbleApprox,
        "book": book,
        "left_eye_approx": leftEyeApprox,
        "right_eye_approx": rightEyeApprox,
        "smile_approx": smileApprox,
    ]
}

// MARK: - Coordinate Mapping Utilities

/// Maps a point from the 1024×1024 logo canvas to view coordinates.
/// - Parameters:
///   - point: Point in 1024×1024 space.
///   - scale: `min(viewWidth, viewHeight) / 1024 * paddingFactor`
///   - offset: Translation to center the content in the view.
func mapPointFrom1024ToView(_ point: CGPoint, scale: CGFloat, offset: CGPoint) -> CGPoint {
    CGPoint(
        x: point.x * scale + offset.x,
        y: point.y * scale + offset.y
    )
}

/// Maps an AnchorBox from the 1024×1024 canvas to a view-space CGRect.
func mapAnchorBoxToView(_ box: AnchorBox, scale: CGFloat, offset: CGPoint) -> CGRect {
    let origin = mapPointFrom1024ToView(CGPoint(x: box.x0, y: box.y0), scale: scale, offset: offset)
    return CGRect(
        origin: origin,
        size: CGSize(width: box.size.width * scale, height: box.size.height * scale)
    )
}

// MARK: - Nova Avatar View

struct NovaAvatarView: View {
    // MARK: - Public API
    var state: NovaAvatarState = .idle
    var audioLevel: Float = 0.0

    // MARK: - Brand Colors (from logo_morphology.json dominant_palette_hex)
    private let mintFill     = Color(hex: "ACE6DA") // Main mint fill
    private let outlineBlue  = Color(hex: "0B4060") // Primary outline / facial features
    private let mintShadow   = Color(hex: "A6E3D1") // Secondary mint (shadow)
    private let hatTeal      = Color(hex: "31708F") // Hat mid-teal
    private let hatHighlight = Color(hex: "367392") // Hat highlight/variation

    // MARK: - Internal State
    @State private var blinkState: Bool = false
    @State private var blinkTask: Task<Void, Never>?

    // MARK: - Halo Animation State
    @State private var errorFlashOpacity: Double = 0
    @Environment(\.colorScheme) private var colorScheme

    /// Halo intensity boost: glows look great on dark backgrounds naturally (neon effect)
    /// but need higher opacity on light backgrounds to remain visible.
    private var haloBoost: Double { colorScheme == .dark ? 1.0 : 1.4 }

    // MARK: - Derived convenience (from state)
    private var isThinking: Bool { state == .thinking }
    private var isListening: Bool { state == .listening }
    private var isSpeaking: Bool { state == .speaking }
    private var isSmiling: Bool { state == .success }
    private var isError: Bool { state == .error }

    var body: some View {
        GeometryReader { geo in
            // MARK: - Responsive Scaling
            // scale = min(width, height) / 1024, with ~8% padding to avoid clipping
            let paddingFactor: CGFloat = 0.92
            let scale = min(geo.size.width, geo.size.height) / 1024 * paddingFactor

            // Center using overall_nonwhite bbox center (511.5, 511.5)
            let contentCenter = NovaAnchors.overallNonwhite.center
            let offsetX = geo.size.width / 2 - contentCenter.x * scale
            let offsetY = geo.size.height / 2 - contentCenter.y * scale

            // Base stroke width scaled from 1024 canvas (~12px)
            let strokeWidth = 12.0 * scale

            // MARK: - Animation: Breathing / Floating
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                // MARK: Animation Hook — Breathing vertical offset (per state)
                // idle: gentle float ±3px @2Hz | listening: faster ±2px @3Hz
                // thinking/error: static (no breathing) | speaking: subtle ±2px @2Hz
                // success: gentle float ±3px @2Hz (same as idle)
                let breathingOffset: CGFloat = {
                    switch state {
                    case .thinking, .error:
                        return 0
                    case .listening:
                        return CGFloat(sin(time * 3)) * 2.0 * scale
                    case .speaking:
                        return CGFloat(sin(time * 2)) * 2.0 * scale
                    case .idle, .success:
                        return CGFloat(sin(time * 2)) * 3.0 * scale
                    }
                }()

                // MARK: Animation Hook — Bubble scale (per state)
                // Range: 1.00–1.03, centered on bubble. Never deforms contour.
                let bubbleScale: CGFloat = {
                    switch state {
                    case .listening:
                        return 1.0 + 0.015 * CGFloat(sin(time * 3))  // ±1.5%
                    case .speaking:
                        return 1.0 + 0.01 * CGFloat(min(effectiveAudioLevel(at: time), 1.0)) // up to +1%
                    case .success:
                        return 1.02  // slight swell
                    case .error:
                        return 0.98  // slight shrink
                    case .idle, .thinking:
                        return 1.0
                    }
                }()

                // MARK: Animation Hook — Effective audio level for mouth
                // When speaking and external audioLevel is near zero, simulate with sine wave.
                // This ensures the mouth always animates during speaking state.
                let resolvedAudioLevel = effectiveAudioLevel(at: time)

                ZStack(alignment: .topLeading) {

                    // MARK: — State Halo (behind everything)
                    // Positioned centered on the speech bubble, which is the avatar's visual mass.
                    stateHaloView(time: time, scale: scale)
                        .position(
                            x: NovaAnchors.speechBubbleApprox.center.x * scale,
                            y: NovaAnchors.speechBubbleApprox.center.y * scale
                        )

                    // MARK: — Book Cover (Backing/Bottom layer) (bottom layer)
                    BookBottomCoverShape()
                        .fill(mintFill)
                        .overlay(
                            BookBottomCoverShape()
                                .stroke(outlineBlue, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                        )
                        .frame(
                            width: NovaAnchors.book.size.width * scale,
                            height: NovaAnchors.book.size.height * scale
                        )
                        .position(
                            x: NovaAnchors.book.center.x * scale,
                            y: NovaAnchors.book.center.y * scale
                        )
                    
                    // MARK: — Book Stack Pages (Top Tier Detail)
                    BookStackLinesShape()
                        .stroke(outlineBlue, style: StrokeStyle(lineWidth: strokeWidth * 0.4, lineCap: .round, lineJoin: .round))
                        .frame(
                            width: NovaAnchors.book.size.width * scale,
                            height: NovaAnchors.book.size.height * scale
                        )
                        .position(
                            x: NovaAnchors.book.center.x * scale,
                            y: NovaAnchors.book.center.y * scale
                        )
                    
                    // MARK: — Book Pages (top layer)
                    // Anchor: NovaAnchors.book (239,687)-(784,912)
                    BookTopPagesShape()
                        .fill(mintFill)
                        .overlay(
                            BookTopPagesShape()
                                .stroke(outlineBlue, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                        )
                        .frame(
                            width: NovaAnchors.book.size.width * scale,
                            height: NovaAnchors.book.size.height * scale
                        )
                        .position(
                            x: NovaAnchors.book.center.x * scale,
                            y: NovaAnchors.book.center.y * scale
                        )

                    // MARK: — Speech Bubble (middle layer)
                    // Anchor: NovaAnchors.speechBubbleApprox (239,280)-(784,704)
                    // MARK: Animation Hook — Bubble scaleEffect (listening/speaking/success/error)
                    SpeechBubble1to1Shape()
                        .fill(mintFill)
                        .overlay(
                            SpeechBubble1to1Shape()
                                .stroke(outlineBlue, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
                        )
                        .frame(
                            width: NovaAnchors.speechBubbleApprox.size.width * scale,
                            height: NovaAnchors.speechBubbleApprox.size.height * scale
                        )
                        .scaleEffect(bubbleScale, anchor: .center)
                        .position(
                            x: NovaAnchors.speechBubbleApprox.center.x * scale,
                            y: NovaAnchors.speechBubbleApprox.center.y * scale
                        )
                        .animation(Nova.Animation.microInteraction, value: state)

                    // MARK: — Facial Features (inside bubble)

                    // Left Eye
                    // Anchor: NovaAnchors.leftEyeApprox (388,415)-(454,481)
                    // MARK: Animation Hook — Eye expression (blink overlay, thinking, success, error)
                    Eye1to1View(
                        isBlinking: blinkState,
                        isThinking: isThinking,
                        isSmiling: isSmiling,
                        isError: isError,
                        color: outlineBlue
                    )
                    .frame(
                        width: NovaAnchors.leftEyeApprox.size.width * scale,
                        height: NovaAnchors.leftEyeApprox.size.height * scale
                    )
                    .position(
                        x: NovaAnchors.leftEyeApprox.center.x * scale,
                        y: NovaAnchors.leftEyeApprox.center.y * scale
                    )

                    // Right Eye
                    // Anchor: NovaAnchors.rightEyeApprox (571,415)-(637,481)
                    Eye1to1View(
                        isBlinking: blinkState,
                        isThinking: isThinking,
                        isSmiling: isSmiling,
                        isError: isError,
                        color: outlineBlue
                    )
                    .frame(
                        width: NovaAnchors.rightEyeApprox.size.width * scale,
                        height: NovaAnchors.rightEyeApprox.size.height * scale
                    )
                    .position(
                        x: NovaAnchors.rightEyeApprox.center.x * scale,
                        y: NovaAnchors.rightEyeApprox.center.y * scale
                    )

                    // Mouth
                    // Anchor: NovaAnchors.smileApprox (449,512)-(576,559)
                    // MARK: Animation Hook — Mouth shape (speaking/thinking/success/error)
                    Mouth1to1View(
                        isSpeaking: isSpeaking,
                        isThinking: isThinking,
                        isSmiling: isSmiling,
                        isError: isError,
                        audioLevel: CGFloat(resolvedAudioLevel),
                        color: outlineBlue,
                        strokeWidth: strokeWidth
                    )
                    .frame(
                        width: NovaAnchors.smileApprox.size.width * scale * 1.1,
                        height: 80 * scale
                    )
                    .position(
                        x: NovaAnchors.smileApprox.center.x * scale,
                        y: (NovaAnchors.smileApprox.y0 + 40.0) * scale
                    )

                    // MARK: — Graduation Hat (top layer)
                    // Anchor: NovaAnchors.hatApprox (271,111)-(752,280)
                    // MARK: Animation Hook — Hat offset/rotation (thinking: lift+tilt, error: tilt opposite)
                    GraduationHat1to1View(
                        baseColor: hatTeal,
                        highlightColor: hatHighlight,
                        outlineColor: outlineBlue,
                        tasselFillColor: mintFill,
                        strokeWidth: strokeWidth
                    )
                    .frame(
                        width: NovaAnchors.hatApprox.size.width * scale,
                        height: (NovaAnchors.hatApprox.size.height + 50) * scale
                    )
                    .position(
                        x: NovaAnchors.hatApprox.center.x * scale,
                        y: (NovaAnchors.hatApprox.center.y - 15) * scale
                    )
                    // thinking: lift 6px + tilt 5° (repeating)
                    // error: tilt -8° (static)
                    // success: lift 4px (static)
                    .offset(y: isThinking ? -6 * scale : (isSmiling ? -4 * scale : 0))
                    .rotationEffect(
                        .degrees(isThinking ? 5 : (isError ? -8 : 0)),
                        anchor: .bottom
                    )
                    .animation(
                        isThinking
                            ? Nova.Animation.modeTransition.repeatForever(autoreverses: true)
                            : Nova.Animation.microInteraction,
                        value: isThinking
                    )
                    .animation(Nova.Animation.microInteraction, value: state)
                }
                // MARK: Animation Hook — Global breathing offset
                .offset(y: breathingOffset)
            }
            .offset(x: offsetX, y: offsetY)
        }
        .onAppear {
            startBlinkLoop()
        }
        .onDisappear {
            blinkTask?.cancel()
            blinkTask = nil
        }
        .onChange(of: state) { oldState, newState in
            handleStateTransition(from: oldState, to: newState)
        }
    }

    // MARK: - Effective Audio Level

    /// Returns the audio level to use for mouth animation.
    /// When speaking and the external audioLevel is near zero (no real audio data),
    /// falls back to a simulated sine wave oscillation for natural talking animation.
    private func effectiveAudioLevel(at time: TimeInterval) -> Float {
        guard isSpeaking else { return 0.0 }

        // If external audio level is being provided (> small threshold), use it directly
        if audioLevel > 0.05 {
            return audioLevel
        }

        // Simulate natural speech rhythm with dramatic mouth movement and word pauses.
        // Syllable rhythm ~3.5Hz produces ~7 syllables/sec — natural conversational speed.
        let syllable = Float(abs(sin(time * 3.5 * .pi)))
        // Word envelope: ~1.2Hz creates natural gaps between "words" (0..1 range)
        let wordEnvelope = Float(max(sin(time * 1.2 * .pi), 0.0))
        // Emphasis variation: ~0.6Hz creates sentence-level stress patterns
        let emphasis = Float(sin(time * 0.6 * .pi) * 0.3 + 0.7)
        // Sharp syllable attack: power curve makes open/close more snappy
        let sharpSyllable = powf(syllable, 1.5)
        // Combine: word envelope gates the syllables, emphasis modulates amplitude
        let combined = sharpSyllable * wordEnvelope * emphasis
        // Scale to 0.08..0.95 — the mouth should clearly open and clearly close
        return min(max(combined * 1.1, 0.08), 0.95)
    }

    // MARK: - State Halo View

    /// Renders a colored halo/glow ring behind the avatar indicating the current state.
    /// - idle: Very subtle, nearly invisible breathing glow
    /// - listening: Blue pulsing halo that reacts to audio input level
    /// - thinking: Purple rotating angular gradient (smooth loading spinner)
    /// - speaking: Green glow that pulses with speech audio level
    /// - error: Red brief flash, then fade
    /// - success: Gold brief celebratory glow
    @ViewBuilder
    private func stateHaloView(time: TimeInterval, scale: CGFloat) -> some View {
        let bubbleSize = NovaAnchors.speechBubbleApprox.size
        // 130% of the avatar bubble — large enough to be unmistakable
        let haloSize = max(bubbleSize.width, bubbleSize.height) * scale * 1.30

        ZStack {
            switch state {
            case .idle:
                // Very subtle breathing glow — just a faint hint of presence
                let idleOpacity = 0.05 + 0.03 * sin(time * 1.2)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [mintFill.opacity(idleOpacity), .clear],
                            center: .center,
                            startRadius: haloSize * 0.3,
                            endRadius: haloSize * 0.55
                        )
                    )
                    .frame(width: haloSize, height: haloSize)

            case .listening:
                // ---- LISTENING: Prominent blue pulsing halo ----
                let listenPulse = CGFloat(max(audioLevel, 0.2))
                // Dramatic scale pulse: 1.0 to 1.15
                let breathScale = 1.0 + 0.15 * sin(time * 2.5)
                let dynamicOpacity = min((0.35 + 0.35 * Double(listenPulse)) * haloBoost, 1.0)

                // Inner radial glow — strong and saturated
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Nova.Colors.novaBlue.opacity(dynamicOpacity),
                                Nova.Colors.novaBlue.opacity(dynamicOpacity * 0.5),
                                Nova.Colors.novaBlue.opacity(dynamicOpacity * 0.15),
                                .clear
                            ],
                            center: .center,
                            startRadius: haloSize * 0.25,
                            endRadius: haloSize * 0.55
                        )
                    )
                    .frame(width: haloSize, height: haloSize)
                    .scaleEffect(breathScale + Double(listenPulse) * 0.08)
                    .blur(radius: 18)

                // Primary visible ring stroke — thick and clear
                Circle()
                    .stroke(
                        Nova.Colors.novaBlue.opacity(min((0.5 + 0.3 * Double(listenPulse)) * haloBoost, 1.0)),
                        lineWidth: 3.5 * scale
                    )
                    .frame(width: haloSize * 0.88, height: haloSize * 0.88)
                    .scaleEffect(breathScale)

                // Secondary outer glow ring — soft halo edge
                Circle()
                    .stroke(
                        Nova.Colors.novaBlue.opacity(min((0.2 + 0.15 * Double(listenPulse)) * haloBoost, 1.0)),
                        lineWidth: 2.0 * scale
                    )
                    .frame(width: haloSize * 0.96, height: haloSize * 0.96)
                    .scaleEffect(breathScale + 0.03)
                    .blur(radius: 6)

            case .thinking:
                // ---- THINKING: Prominent purple rotating spinner ----
                let rotationDeg = time.truncatingRemainder(dividingBy: 360.0 / 60.0) * 60.0

                // Inner purple glow — visible background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Nova.Colors.novaPurple.opacity(0.25 * haloBoost),
                                Nova.Colors.novaIndigo.opacity(0.12 * haloBoost),
                                .clear
                            ],
                            center: .center,
                            startRadius: haloSize * 0.28,
                            endRadius: haloSize * 0.55
                        )
                    )
                    .frame(width: haloSize, height: haloSize)
                    .blur(radius: 12)

                // Rotating angular gradient ring — thick and clearly visible
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                .clear,
                                Nova.Colors.novaPurple.opacity(min(0.7 * haloBoost, 1.0)),
                                Nova.Colors.novaIndigo.opacity(min(0.6 * haloBoost, 1.0)),
                                Nova.Colors.novaPurple.opacity(min(0.4 * haloBoost, 1.0)),
                                .clear
                            ],
                            center: .center
                        ),
                        lineWidth: 4.0 * scale
                    )
                    .frame(width: haloSize * 0.86, height: haloSize * 0.86)
                    .rotationEffect(.degrees(rotationDeg))

                // Glow behind the spinning ring for extra depth
                Circle()
                    .stroke(
                        Nova.Colors.novaPurple.opacity(0.25 * haloBoost),
                        lineWidth: 6.0 * scale
                    )
                    .frame(width: haloSize * 0.86, height: haloSize * 0.86)
                    .rotationEffect(.degrees(rotationDeg))
                    .blur(radius: 10)

            case .speaking:
                // ---- SPEAKING: Vivid green glow pulsing with audio ----
                let speakLevel = CGFloat(effectiveAudioLevel(at: time))
                let speakOpacity = min((0.3 + 0.35 * Double(speakLevel)) * haloBoost, 1.0)
                let speakScale = 1.0 + 0.08 * Double(speakLevel)

                // Inner radial glow — saturated green
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Nova.Colors.successGreen.opacity(speakOpacity),
                                Nova.Colors.successGreen.opacity(speakOpacity * 0.4),
                                Nova.Colors.successGreen.opacity(speakOpacity * 0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: haloSize * 0.25,
                            endRadius: haloSize * 0.55
                        )
                    )
                    .frame(width: haloSize, height: haloSize)
                    .scaleEffect(speakScale)
                    .blur(radius: 15)

                // Visible ring stroke that scales with audio level
                Circle()
                    .stroke(
                        Nova.Colors.successGreen.opacity(min((0.4 + 0.35 * Double(speakLevel)) * haloBoost, 1.0)),
                        lineWidth: (2.5 + 1.5 * Double(speakLevel)) * scale
                    )
                    .frame(width: haloSize * 0.88, height: haloSize * 0.88)
                    .scaleEffect(speakScale)

                // Soft outer glow for depth
                Circle()
                    .stroke(
                        Nova.Colors.successGreen.opacity(min((0.15 + 0.2 * Double(speakLevel)) * haloBoost, 1.0)),
                        lineWidth: 2.0 * scale
                    )
                    .frame(width: haloSize * 0.95, height: haloSize * 0.95)
                    .scaleEffect(speakScale)
                    .blur(radius: 8)

            case .error:
                // Red flash that fades out
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.red.opacity(0.35 * errorFlashOpacity * haloBoost),
                                Color.red.opacity(0.12 * errorFlashOpacity * haloBoost),
                                .clear
                            ],
                            center: .center,
                            startRadius: haloSize * 0.22,
                            endRadius: haloSize * 0.55
                        )
                    )
                    .frame(width: haloSize, height: haloSize)
                    .blur(radius: 10)
                Circle()
                    .stroke(
                        Color.red.opacity(min(0.45 * errorFlashOpacity * haloBoost, 1.0)),
                        lineWidth: 3.0 * scale
                    )
                    .frame(width: haloSize * 0.88, height: haloSize * 0.88)

            case .success:
                // Gold celebratory glow
                let successPulse = 0.6 + 0.4 * sin(time * 2.0)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Nova.Colors.xpGold.opacity(0.25 * successPulse * haloBoost),
                                Nova.Colors.xpGold.opacity(0.1 * successPulse * haloBoost),
                                .clear
                            ],
                            center: .center,
                            startRadius: haloSize * 0.25,
                            endRadius: haloSize * 0.55
                        )
                    )
                    .frame(width: haloSize, height: haloSize)
                    .blur(radius: 10)
                Circle()
                    .stroke(
                        Nova.Colors.xpGold.opacity(min(0.3 * successPulse * haloBoost, 1.0)),
                        lineWidth: 2.5 * scale
                    )
                    .frame(width: haloSize * 0.88, height: haloSize * 0.88)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - State Transition Handling

    /// Handles animated transitions when the avatar state changes.
    private func handleStateTransition(from oldState: NovaAvatarState, to newState: NovaAvatarState) {
        // Error flash: animate in, then auto-fade after 0.8s
        if newState == .error {
            withAnimation(.easeIn(duration: 0.15)) {
                errorFlashOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.6)) {
                    errorFlashOpacity = 0.3
                }
            }
        } else {
            // Reset error flash when leaving error state
            withAnimation(.easeOut(duration: 0.3)) {
                errorFlashOpacity = 0.0
            }
        }
    }

    // MARK: - Blink Logic

    /// Blink: 90–140ms cycle, random interval every 2.5–5.5s in idle.
    private func startBlinkLoop() {
        blinkTask?.cancel()
        blinkTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.5...5.5)))
                guard !Task.isCancelled else { return }
                triggerBlink()
            }
        }
    }

    /// Single blink: ~130ms total (close 45ms + hold 40ms + open 45ms).
    private func triggerBlink() {
        guard !blinkState else { return }
        withAnimation(.linear(duration: 0.045)) { blinkState = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            withAnimation(.linear(duration: 0.045)) { blinkState = false }
        }
    }
}

// MARK: - 1:1 Shapes (geometry preserved from original)

struct GraduationHat1to1View: View {
    var baseColor: Color
    var highlightColor: Color // Kept for API compatibility, though base color is used for mortarboard
    var outlineColor: Color
    var tasselFillColor: Color
    var strokeWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let sw = strokeWidth
            
            // 1. Cap Base (skull cap) - matches outline color conceptually
            var base = Path()
            // Upper corners tuck under the mortarboard
            base.move(to: CGPoint(x: w * 0.35, y: h * 0.45))
            base.addLine(to: CGPoint(x: w * 0.65, y: h * 0.45))
            // Sides taper down
            base.addLine(to: CGPoint(x: w * 0.58, y: h * 0.7))
            // Bottom edge curves slightly to sit on bubble
            base.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.7), control: CGPoint(x: w * 0.5, y: h * 0.75))
            base.closeSubpath()
            
            context.fill(base, with: .color(outlineColor))
            context.stroke(base, with: .color(outlineColor),
                          style: StrokeStyle(lineWidth: sw, lineCap: .round, lineJoin: .round))

            // 2. Mortarboard Diamond
            var diamond = Path()
            diamond.move(to: CGPoint(x: w * 0.5, y: h * 0.05)) // Top (higher)
            diamond.addQuadCurve(to: CGPoint(x: w * 0.98, y: h * 0.35), control: CGPoint(x: w * 0.75, y: h * 0.15)) // Right (wider)
            diamond.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.65), control: CGPoint(x: w * 0.75, y: h * 0.55)) // Bottom (lower)
            diamond.addQuadCurve(to: CGPoint(x: w * 0.02, y: h * 0.35), control: CGPoint(x: w * 0.25, y: h * 0.55)) // Left (wider)
            diamond.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.05), control: CGPoint(x: w * 0.25, y: h * 0.15)) // Top
            diamond.closeSubpath()
            
            context.fill(diamond, with: .color(baseColor))
            context.stroke(diamond, with: .color(outlineColor),
                          style: StrokeStyle(lineWidth: sw, lineCap: .round, lineJoin: .round))

            // 3. Tassel String
            var tassel = Path()
            tassel.move(to: CGPoint(x: w * 0.5, y: h * 0.35)) // From center
            // Falls almost straight down then slightly right to dangle
            tassel.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.65), control: CGPoint(x: w * 0.65, y: h * 0.5))
            context.stroke(tassel, with: .color(outlineColor),
                          style: StrokeStyle(lineWidth: sw * 0.7, lineCap: .round, lineJoin: .round))
            
            // 4. Center button
            let buttonPath = Path(ellipseIn: CGRect(x: w * 0.46, y: h * 0.31, width: w * 0.08, height: h * 0.08))
            context.fill(buttonPath, with: .color(outlineColor))

            // 5. Tassel brush (triangle shape like in logo)
            var block = Path()
            let brushTop = CGPoint(x: w * 0.78, y: h * 0.65)
            block.move(to: brushTop)
            block.addLine(to: CGPoint(x: brushTop.x + w * 0.05, y: brushTop.y + h * 0.2)) // Right corner
            // Slight curve on bottom of brush
            block.addQuadCurve(
                to: CGPoint(x: brushTop.x - w * 0.03, y: brushTop.y + h * 0.2), // Left corner
                control: CGPoint(x: brushTop.x + w * 0.01, y: brushTop.y + h * 0.22)
            )
            block.closeSubpath()
            
            context.fill(block, with: .color(tasselFillColor))
            context.stroke(block, with: .color(outlineColor),
                          style: StrokeStyle(lineWidth: sw * 0.8, lineCap: .round, lineJoin: .round))
        }
    }
}

struct SpeechBubble1to1Shape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cr = w * 0.12 // Smooth proportional corners matching logo
        let tailHeight = h * 0.16
        let bubbleB = h - tailHeight
        
        let leftWallX = w * 0.05
        let rightWallX = w * 0.95
        
        var path = Path()
        
        // Start top left after corner
        path.move(to: CGPoint(x: leftWallX + cr, y: 0))
        path.addLine(to: CGPoint(x: rightWallX - cr, y: 0))
        path.addArc(center: CGPoint(x: rightWallX - cr, y: cr), radius: cr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        
        path.addLine(to: CGPoint(x: rightWallX, y: bubbleB - cr))
        path.addArc(center: CGPoint(x: rightWallX - cr, y: bubbleB - cr), radius: cr, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        
        // Bottom edge heading left
        let tailRightX = leftWallX + cr * 2.0
        path.addLine(to: CGPoint(x: tailRightX, y: bubbleB))
        
        // Curve sweeping down to tail tip
        let tailTip = CGPoint(x: 0, y: bubbleB + tailHeight * 0.8) // Tip hits left edge
        path.addQuadCurve(
            to: tailTip,
            control: CGPoint(x: tailRightX - cr * 0.8, y: bubbleB + tailHeight * 0.2)
        )
        
        // Straight line cleanly back up to left wall
        let leftWallJoinY = bubbleB - cr * 0.3
        path.addLine(to: CGPoint(x: leftWallX, y: leftWallJoinY))
        
        // Go back up left edge
        path.addLine(to: CGPoint(x: leftWallX, y: cr))
        path.addArc(center: CGPoint(x: leftWallX + cr, y: cr), radius: cr, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        
        path.closeSubpath()
        return path
    }
}

struct BookTopPagesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        
        let spineTop = CGPoint(x: w * 0.5, y: h * 0.15)
        let spineBottom = CGPoint(x: w * 0.5, y: h * 0.55) // Much shallower, closer to the gap
        
        // Flatter top edges like the logo
        let leftTip = CGPoint(x: w * 0.05, y: h * 0.35)
        let rightTip = CGPoint(x: w * 0.95, y: h * 0.35)
        
        // Top edge Left
        path.move(to: spineTop)
        path.addQuadCurve(to: leftTip, control: CGPoint(x: w * 0.25, y: h * 0.02))
        // Bottom edge Left
        path.addQuadCurve(to: spineBottom, control: CGPoint(x: w * 0.25, y: h * 0.65))
        path.addLine(to: spineTop)
        
        // Top edge Right
        path.move(to: spineTop)
        path.addQuadCurve(to: rightTip, control: CGPoint(x: w * 0.75, y: h * 0.02))
        // Bottom edge Right
        path.addQuadCurve(to: spineBottom, control: CGPoint(x: w * 0.75, y: h * 0.65))
        path.addLine(to: spineTop)
        
        return path
    }
}

struct BookStackLinesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        
        let leftTip = CGPoint(x: w * 0.05, y: h * 0.35)
        let rightTip = CGPoint(x: w * 0.95, y: h * 0.35)
        let topSpineBottom = CGPoint(x: w * 0.5, y: h * 0.55)
        
        let coverThickness = h * 0.16
        let halfThick = coverThickness * 0.5
        let baseControlY = h * 0.65
        
        // Single central page line
        path.move(to: CGPoint(x: leftTip.x, y: leftTip.y + halfThick))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: topSpineBottom.y + halfThick),
            control: CGPoint(x: w * 0.25, y: baseControlY + halfThick)
        )
        path.addQuadCurve(
            to: CGPoint(x: rightTip.x, y: rightTip.y + halfThick),
            control: CGPoint(x: w * 0.75, y: baseControlY + halfThick)
        )
        
        // Center spine division straight down through the block
        path.move(to: topSpineBottom)
        path.addLine(to: CGPoint(x: w * 0.5, y: topSpineBottom.y + coverThickness))
        
        return path
    }
}

struct BookBottomCoverShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        
        let leftTip = CGPoint(x: w * 0.05, y: h * 0.35)
        let rightTip = CGPoint(x: w * 0.95, y: h * 0.35)
        let topSpineBottom = CGPoint(x: w * 0.5, y: h * 0.55)
        
        let coverThickness = h * 0.16
        let baseControlY = h * 0.65
        
        // Top boundary of the solid block (hugging underneath the top covers)
        path.move(to: leftTip)
        path.addQuadCurve(
            to: topSpineBottom,
            control: CGPoint(x: w * 0.25, y: baseControlY)
        )
        path.addQuadCurve(
            to: rightTip,
            control: CGPoint(x: w * 0.75, y: baseControlY)
        )
        
        // Right side thickness outer edge
        path.addLine(to: CGPoint(x: rightTip.x, y: rightTip.y + coverThickness))
        
        // Bottom edge strokes backwards to Left
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: topSpineBottom.y + coverThickness),
            control: CGPoint(x: w * 0.75, y: baseControlY + coverThickness)
        )
        path.addQuadCurve(
            to: CGPoint(x: leftTip.x, y: leftTip.y + coverThickness),
            control: CGPoint(x: w * 0.25, y: baseControlY + coverThickness)
        )
        
        // Close the subpath (returns up to leftTip)
        path.closeSubpath()
        return path
    }
}

struct Eye1to1View: View {
    var isBlinking: Bool
    var isThinking: Bool
    var isSmiling: Bool
    var isError: Bool
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let lw = max(s * 0.06, 1.5) // stroke width proportional to eye size

            if isBlinking {
                // Blink: thin horizontal capsule at vertical center
                Capsule()
                    .fill(color)
                    .frame(width: s * 0.9, height: max(s * 0.12, 2))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            } else if isError {
                // Concern: downward arch
                ErrorEyeShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
                    .frame(width: s * 0.7, height: s * 0.4)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            } else if isThinking {
                // Thoughtful: half-circle arching up
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    .frame(width: s * 0.6, height: s * 0.3)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            } else if isSmiling {
                // Happy: caret ^ ^
                HappyEyeShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
                    .frame(width: s * 0.7, height: s * 0.35)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            } else {
                // Default: filled circle (75% of frame — prominent like original logo)
                Circle()
                    .fill(color)
                    .frame(width: s * 0.75, height: s * 0.75)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }
}

struct HappyEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: rect.height),
            control: CGPoint(x: rect.width / 2, y: -rect.height * 0.5)
        )
        return path
    }
}

struct ErrorEyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: 0),
            control: CGPoint(x: rect.width / 2, y: rect.height)
        )
        return path
    }
}

struct Mouth1to1View: View {
    var isSpeaking: Bool
    var isThinking: Bool
    var isSmiling: Bool
    var isError: Bool
    var audioLevel: CGFloat
    var color: Color
    var strokeWidth: CGFloat

    var body: some View {
        let mouthShape = Mouth1to1Shape(
            isSpeaking: isSpeaking,
            isThinking: isThinking,
            isSmiling: isSmiling,
            isError: isError,
            audioLevel: audioLevel
        )

        ZStack {
            if isSpeaking && audioLevel > 0.1 {
                // Fill the open mouth shape for a realistic look
                mouthShape
                    .fill(color)
            }
            mouthShape
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
        }
        .animation(Nova.Animation.hoverFeedback, value: audioLevel)
        .animation(Nova.Animation.microInteraction, value: isThinking)
        .animation(Nova.Animation.microInteraction, value: isSmiling)
        .animation(Nova.Animation.microInteraction, value: isError)
    }
}

struct Mouth1to1Shape: Shape {
    var isSpeaking: Bool
    var isThinking: Bool
    var isSmiling: Bool
    var isError: Bool
    var audioLevel: CGFloat

    var animatableData: CGFloat {
        get { audioLevel }
        set { audioLevel = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        let baseY = h * 0.35

        if isSpeaking {
            let openAmount = audioLevel
            let inward = openAmount * w * 0.06
            let s = CGPoint(x: inward, y: baseY)
            let e = CGPoint(x: w - inward, y: baseY)

            path.move(to: s)
            // Top lip
            path.addQuadCurve(
                to: e,
                control: CGPoint(x: w / 2, y: baseY - h * 0.08 * openAmount)
            )
            // Bottom lip drops dynamically
            path.addQuadCurve(
                to: s,
                control: CGPoint(x: w / 2, y: baseY + h * 0.55 * openAmount + h * 0.3)
            )
            path.closeSubpath()
        } else if isError {
            // Frown: Inverted arc
            let start = CGPoint(x: w * 0.2, y: baseY)
            let end = CGPoint(x: w * 0.8, y: baseY)
            path.move(to: start)
            path.addQuadCurve(to: end, control: CGPoint(x: w / 2, y: baseY - h * 0.35))
        } else if isThinking {
            // Puzzled: Smaller, flatter arc
            path.move(to: CGPoint(x: w * 0.25, y: baseY))
            path.addQuadCurve(to: CGPoint(x: w * 0.75, y: baseY), control: CGPoint(x: w / 2, y: baseY + h * 0.1))
        } else if isSmiling {
            // Big Smile (Success): Deep U-shape
            let padding: CGFloat = 0
            path.move(to: CGPoint(x: padding, y: baseY))
            path.addQuadCurve(to: CGPoint(x: w - padding, y: baseY), control: CGPoint(x: w / 2, y: baseY + h * 0.65))
        } else {
            // Default: Smooth perfect smile matching the friendly curve of the mascot
            let padding: CGFloat = w * 0.15
            path.move(to: CGPoint(x: padding, y: baseY))
            path.addQuadCurve(to: CGPoint(x: w - padding, y: baseY), control: CGPoint(x: w / 2, y: baseY + h * 0.45))
        }

        return path
    }
}

// MARK: - Previews

#Preview("Idle") {
    ZStack {
        Color.white.ignoresSafeArea()
        NovaAvatarView(state: .idle)
            .frame(width: 300, height: 300)
    }
}

#Preview("Listening") {
    ZStack {
        Color(uiColor: .systemBackground).ignoresSafeArea()
        NovaAvatarView(state: .listening, audioLevel: 0.4)
            .frame(width: 300, height: 300)
    }
}

#Preview("Thinking") {
    ZStack {
        Color(uiColor: .systemBackground).ignoresSafeArea()
        NovaAvatarView(state: .thinking)
            .frame(width: 300, height: 300)
    }
}

#Preview("Speaking - Simulated") {
    // Speaking with audioLevel = 0 triggers internal sine wave simulation
    ZStack {
        Color(uiColor: .systemBackground).ignoresSafeArea()
        NovaAvatarView(state: .speaking, audioLevel: 0.0)
            .frame(width: 300, height: 300)
    }
}

#Preview("Speaking - External Audio") {
    ZStack {
        Color(uiColor: .systemBackground).ignoresSafeArea()
        NovaAvatarView(state: .speaking, audioLevel: 0.6)
            .frame(width: 300, height: 300)
    }
}

#Preview("Success") {
    ZStack {
        Color(uiColor: .systemBackground).ignoresSafeArea()
        NovaAvatarView(state: .success)
            .frame(width: 200, height: 200)
    }
}

#Preview("Error") {
    ZStack {
        Color(uiColor: .systemBackground).ignoresSafeArea()
        NovaAvatarView(state: .error)
            .frame(width: 200, height: 200)
    }
}

#Preview("All States Grid") {
    let states: [(String, NovaAvatarState, Float)] = [
        ("Idle", .idle, 0),
        ("Listening", .listening, 0.4),
        ("Thinking", .thinking, 0),
        ("Speaking", .speaking, 0),
        ("Success", .success, 0),
        ("Error", .error, 0),
    ]
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
            ForEach(states, id: \.0) { name, avatarState, level in
                VStack(spacing: 8) {
                    NovaAvatarView(state: avatarState, audioLevel: level)
                        .frame(width: 150, height: 150)
                    Text(name)
                        .font(Nova.Typography.labelMedium)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
