import SwiftUI

/// A button style that provides "Tactile Maximalism" feedback.
/// Elements feel like they are made of soft rubber/jelly.
struct SquishyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(
                Nova.Animation.springBouncy,
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    Nova.Haptics.soft()
                } else {
                    Nova.Haptics.medium()
                }
            }
    }
}

extension ButtonStyle where Self == SquishyButtonStyle {
    static var squishy: SquishyButtonStyle {
        SquishyButtonStyle()
    }
}
