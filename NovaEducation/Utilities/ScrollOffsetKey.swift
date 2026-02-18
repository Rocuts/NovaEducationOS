import SwiftUI

// MARK: - ScrollOffsetKey
// PreferenceKey for tracking scroll offset in ScrollView.
// Used to drive scroll-dependent UI effects such as parallax headers,
// collapsing navigation bars, and fade-on-scroll overlays.
//
// Usage:
//   ScrollView {
//       GeometryReader { geo in
//           Color.clear.preference(
//               key: ScrollOffsetKey.self,
//               value: geo.frame(in: .named("scroll")).minY
//           )
//       }
//       .frame(height: 0)
//       // ... content
//   }
//   .coordinateSpace(name: "scroll")
//   .onPreferenceChange(ScrollOffsetKey.self) { offset in
//       scrollOffset = offset
//   }

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
