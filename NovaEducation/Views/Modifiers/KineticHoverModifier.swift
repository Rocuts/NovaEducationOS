import SwiftUI

/// A modifier that simulates magnetic levitation.
struct KineticHoverModifier: ViewModifier {
    @State private var isHovering = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isHovering ? -5 : 0)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .shadow(
                color: isHovering ? Color.black.opacity(0.15) : Color.clear,
                radius: isHovering ? 20 : 0,
                x: 0,
                y: isHovering ? 10 : 0
            )
            .overlay {
                if isHovering {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .blur(radius: 1)
                }
            }
            .animation(Nova.Animation.hoverFeedback, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            // For touch devices (simulate hover on long press mostly, or just handle touch down elsewhere)
            // Note: In pure touch, "hover" isn't a state, so this is mostly for iPad cursor
            // For touch "lift", usually the ButtonStyle handles the depression, but this can
            // be used for "Selected" states.
    }
}

extension View {
    func kineticHover() -> some View {
        modifier(KineticHoverModifier())
    }
}
