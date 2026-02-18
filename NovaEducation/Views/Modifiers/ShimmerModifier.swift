import SwiftUI

// MARK: - ShimmerModifier
// Premium skeleton/loading shimmer effect.
// A translucent highlight sweeps across the view in an infinite loop,
// giving the user a clear signal that content is loading.
// Usage: anyView.shimmer()

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.12),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: -geo.size.width * 0.3 + (geo.size.width * 1.6) * phase)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Nova.Radius.md))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a premium shimmer/skeleton loading effect.
    /// The highlight sweeps left-to-right in a continuous loop.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
