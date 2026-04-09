import SwiftUI

/// A view that renders a living, breathing "Aurora" background using Metal shaders.
/// This replaces static gradients with a fluid, liquid-like mesh of colors that
/// reacts to time.
struct AuroraBackgroundView: View {
    var primaryColor: Color
    var secondaryColor: Color
    var intensity: Double = 1.0
    var isActive: Bool = true

    /// The start time of the animation to calculate delta
    @State private var startTime = Date().addingTimeInterval(-8)

    var body: some View {
        let start = startTime
        TimelineView(.animation(paused: !isActive)) { context in
            Rectangle()
                .fill(.black) // Base canvas
                .visualEffect { content, proxy in
                    content
                        .colorEffect(
                            ShaderLibrary.auroraGradient(
                                .float2(proxy.size),
                                .float(context.date.timeIntervalSince(start)),
                                .color(primaryColor),
                                .color(secondaryColor)
                            )
                        )
                }
        }
        .ignoresSafeArea()
        .opacity(intensity)
        .accessibilityHidden(true)
    }
}

#Preview {
    AuroraBackgroundView(
        primaryColor: .blue,
        secondaryColor: .purple
    )
}
