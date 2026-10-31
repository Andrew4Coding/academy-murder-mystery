import SwiftUI

enum Theme {
    static let background = Color("ThemeBackground")
    static let surface = Color("ThemeSurface")
    static let surfaceRaised = Color("ThemeSurfaceRaised")
    static let separator = Color("ThemeSeparator")
    static let text = Color("ThemeText")
    static let textSecondary = Color("ThemeTextSecondary")
    static let accent = Color("ThemeAccent")
    static let accentFill = Color("ThemeAccentFill")
    static let success = Color("ThemeSuccess")
    static let warning = Color("ThemeWarning")
    static let onAccentFill = Color.white
}

struct ThemedBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }
}

struct ThemedCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
    }
}

struct AccentFillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.onAccentFill)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Spacing.md)
            .background(Theme.accentFill, in: .rect(cornerRadius: Radius.md))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .contentShape(.rect(cornerRadius: Radius.md))
    }
}

extension ButtonStyle where Self == AccentFillButtonStyle {
    static var accentFill: AccentFillButtonStyle { AccentFillButtonStyle() }
}

extension View {
    func themedBackground() -> some View { modifier(ThemedBackground()) }
    func themedCard() -> some View { modifier(ThemedCard()) }
}
