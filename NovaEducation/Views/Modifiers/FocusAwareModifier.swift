import SwiftUI

struct FocusAwareModifier: ViewModifier {
    @Environment(FocusManager.self) private var focusManager
    
    // If true, this element completely disappears in focus mode.
    // If false, it simply dims.
    var hideCompletely: Bool = false
    
    func body(content: Content) -> some View {
        content
            .opacity(focusManager.isFocusModeActive ? (hideCompletely ? 0 : 0.3) : 1)
            .blur(radius: focusManager.isFocusModeActive ? (hideCompletely ? 10 : 0) : 0)
            .animation(Nova.Animation.modeTransition, value: focusManager.isFocusModeActive)
            // Disable interaction if hidden
            .allowsHitTesting(!focusManager.isFocusModeActive || !hideCompletely)
    }
}

extension View {
    /// Applies Zen Mode styling.
    /// - Parameter hideCompletely: If true, the view effectively vanishes. If false, it dims.
    func focusAware(hideCompletely: Bool = false) -> some View {
        modifier(FocusAwareModifier(hideCompletely: hideCompletely))
    }
}
