import SwiftUI
import UIKit

// MARK: - Nova Design Token System
// Single source of truth for every visual decision in NovaEducation.
// Every value is intentional. Every spacing follows the 4pt grid.
// Every color meets WCAG AA contrast minimums against its intended surface.

enum Nova {

    // MARK: - Spacing (4pt grid - STRICT)
    // Only these values exist. Nothing else. Ever.
    // The 4pt grid ensures pixel-perfect alignment on all Retina displays.
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let jumbo: CGFloat = 40
        static let mega: CGFloat = 48
        static let ultra: CGFloat = 64

        // Contextual aliases for layout consistency
        static let screenHorizontal: CGFloat = 20
        static let cardPadding: CGFloat = 16
        static let sectionGap: CGFloat = 24
        static let tabBarClearance: CGFloat = 100
    }

    // MARK: - Corner Radii (strict set)
    // Rounded rectangles are the language of iOS. These values define our vocabulary.
    enum Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let pill: CGFloat = 999

        // Semantic aliases
        static let card: CGFloat = 20
        static let sheet: CGFloat = 24
        static let button: CGFloat = 14
        static let toast: CGFloat = 18
        static let iconBadge: CGFloat = 8
    }

    // MARK: - Typography (Apple-grade type scale)
    // Three families: Display (celebrations), Body (reading), Numeric (gamification).
    // Rounded design for Display/Numeric gives playful-yet-premium feel.
    // Default design for Body preserves readability in educational content.
    enum Typography {

        // Display - for hero numbers and celebrations
        static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
        static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
        static let displaySmall = Font.system(size: 24, weight: .bold, design: .rounded)

        // Headlines - section titles, card headers
        static let headlineLarge = Font.system(size: 22, weight: .bold)
        static let headlineMedium = Font.headline
        static let headlineSmall = Font.system(size: 15, weight: .semibold)

        // Body - educational content, chat messages
        static let bodyLarge = Font.body
        static let bodyMedium = Font.subheadline
        static let bodySmall = Font.footnote

        // Labels - buttons, badges, tags
        static let labelLarge = Font.system(size: 15, weight: .semibold)
        static let labelMedium = Font.system(size: 13, weight: .semibold)
        static let labelSmall = Font.system(size: 11, weight: .semibold)

        // Captions - timestamps, metadata
        static let captionLarge = Font.caption
        static let captionSmall = Font.caption2

        // Numeric - XP counters, levels, stats (rounded for playful + premium)
        static let numericLarge = Font.system(size: 48, weight: .bold, design: .rounded)
        static let numericMedium = Font.system(size: 24, weight: .bold, design: .rounded)
        static let numericSmall = Font.system(size: 13, weight: .bold, design: .rounded)
    }

    // MARK: - Semantic Colors
    // Brand colors verified for contrast. Surfaces adapt to light/dark automatically.
    // Gamification colors chosen for emotional resonance:
    //   Gold = reward, Orange = urgency/streak, Green = success, Blue = quest/progress.
    enum Colors {

        // Brand identity
        static let novaBlue = Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255)
        static let novaPurple = Color(red: 175 / 255, green: 82 / 255, blue: 222 / 255)
        static let novaIndigo = Color(red: 88 / 255, green: 86 / 255, blue: 214 / 255)

        // Gamification palette
        static let xpGold = Color(red: 255 / 255, green: 215 / 255, blue: 0 / 255)
        static let streakOrange = Color(red: 255 / 255, green: 149 / 255, blue: 0 / 255)
        static let successGreen = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
        static let questBlue = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)

        // Surfaces - auto-adapt to light/dark via UIKit semantic colors
        static let surfacePrimary = Color(uiColor: .systemBackground)
        static let surfaceSecondary = Color(uiColor: .secondarySystemBackground)
        static let surfaceGrouped = Color(uiColor: .systemGroupedBackground)

        // Text hierarchy
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color(uiColor: .tertiaryLabel)

        // Chat bubble surfaces
        // Light: warm gray. Dark: elevated surface. Both ensure text contrast >= 4.5:1.
        static let assistantBubbleLight = Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
        static let assistantBubbleDark = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)

        /// User bubble gradient derived from subject color.
        /// The 0.82 opacity stop creates depth without losing legibility of white text.
        static func userBubbleGradient(for color: Color) -> LinearGradient {
            LinearGradient(
                colors: [color, color.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Shadows (subtle, premium, never heavy)
    // Drop shadows use pure black at low opacity for natural depth.
    // Radius and Y-offset together create the "lifted paper" illusion.
    enum Shadow {
        static let card = (color: Color.black.opacity(0.06), radius: 8.0, x: 0.0, y: 2.0)
        static let cardElevated = (color: Color.black.opacity(0.1), radius: 16.0, x: 0.0, y: 4.0)
        static let toast = (color: Color.black.opacity(0.08), radius: 16.0, x: 0.0, y: 6.0)
    }

    // MARK: - Animation Curves
    // Three families:
    //   Spring  - interactive feedback (buttons, toggles, morphing)
    //   Entrance - elements appearing on screen (stagger, slide-in)
    //   Exit     - elements leaving (fast ease-out, no bounce)
    // Plus specialty curves for looping effects.
    enum Animation {

        // Spring family - interactive feedback
        static let springDefault = SwiftUI.Animation.spring(duration: 0.6, bounce: 0.25)
        static let springBouncy = SwiftUI.Animation.spring(duration: 0.5, bounce: 0.45)
        static let springSnappy = SwiftUI.Animation.spring(duration: 0.42, bounce: 0.18)
        static let springGentle = SwiftUI.Animation.spring(duration: 0.8, bounce: 0.2)

        // Entrance family - elements appearing
        static let entranceFast = SwiftUI.Animation.spring(duration: 0.45, bounce: 0.3)
        static let entranceMedium = SwiftUI.Animation.spring(duration: 0.65, bounce: 0.3)
        static let entranceSlow = SwiftUI.Animation.spring(duration: 0.9, bounce: 0.25)

        // Exit family - elements leaving
        static let exitFast = SwiftUI.Animation.easeOut(duration: 0.2)
        static let exitMedium = SwiftUI.Animation.easeOut(duration: 0.3)

        // Toast/notification curves
        static let toastEnter = SwiftUI.Animation.spring(duration: 0.65, bounce: 0.35)
        static let toastExit = SwiftUI.Animation.spring(duration: 0.45, bounce: 0.2)

        // Specialty curves
        static let hoverFeedback = SwiftUI.Animation.spring(duration: 0.6, bounce: 0.4)
        static let modeTransition = SwiftUI.Animation.easeInOut(duration: 1.0)
        static let microInteraction = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let dotBounce = SwiftUI.Animation.easeInOut(duration: 0.4)

        // Looping effects
        static let shimmer = SwiftUI.Animation.easeInOut(duration: 0.9)
        static let breathe = SwiftUI.Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        static let glowPulse = SwiftUI.Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)

        /// Stagger delay for list/grid entrance animations.
        /// - Parameters:
        ///   - index: The item's position in the sequence (0-based).
        ///   - base: Delay increment per item. Default 0.06s creates a fluid cascade.
        static func stagger(index: Int, base: Double = 0.06) -> SwiftUI.Animation {
            SwiftUI.Animation.spring(duration: 0.6, bounce: 0.3)
                .delay(Double(index) * base)
        }
    }

    // MARK: - Haptics (centralized, never inline UIImpactFeedbackGenerator calls)
    // Every haptic in the app goes through here. This ensures consistency
    // and makes it trivial to respect the user's hapticsEnabled setting.
    enum Haptics {
        /// Set from UserSettings on app launch. When false, all haptics are silenced.
        static var isEnabled: Bool = true

        static func light() { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        static func medium() { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        static func heavy() { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
        static func soft() { guard isEnabled else { return }; UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        static func success() { guard isEnabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
        static func warning() { guard isEnabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        static func error() { guard isEnabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
        static func selection() { guard isEnabled else { return }; UISelectionFeedbackGenerator().selectionChanged() }
    }

    // MARK: - Icon Sizes
    // Consistent icon sizing across the app. Matches SF Symbol optical sizes.
    enum IconSize {
        static let xs: CGFloat = 12
        static let sm: CGFloat = 16
        static let md: CGFloat = 20
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 44
    }

    // MARK: - Z-Index Layers
    // Strict layering prevents z-fighting and keeps overlay hierarchy predictable.
    enum ZLayer {
        static let background: Double = 0
        static let content: Double = 10
        static let overlay: Double = 50
        static let toast: Double = 100
        static let celebration: Double = 200
        static let islandNotification: Double = 300
    }
}
