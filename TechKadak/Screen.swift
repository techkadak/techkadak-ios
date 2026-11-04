import SwiftUI

struct TKScreen: ViewModifier {
    @EnvironmentObject var theme: ThemeStore
    func body(content: Content) -> some View {
        content
            .background(ThemedBackground())
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 76) }
            .toolbarBackground(theme.p.isGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(theme.p.bg.opacity(0.92)), for: .navigationBar)
            .toolbarColorScheme(theme.p.scheme, for: .navigationBar)
    }
}

extension View {
    func tkScreen() -> some View { modifier(TKScreen()) }
}
