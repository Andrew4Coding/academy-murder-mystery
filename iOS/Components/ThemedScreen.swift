import SwiftUI

struct ThemedScreen<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
        }
        .foregroundStyle(Theme.text)
        .themedBackground()
    }
}

struct ScreenSection<Content: View>: View {
    var title: LocalizedStringKey?
    var footer: LocalizedStringKey?

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let title {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: Spacing.md) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

struct ErrorRow: View {
    let message: String

    var body: some View {
        StatusLabel(message, systemImage: "exclamationmark.triangle.fill", tint: Theme.warning)
            .accessibilityLabel("Error: \(message)")
    }
}

struct SecondaryText: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.subheadline).foregroundStyle(Theme.textSecondary)
    }
}

struct ThemedField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 44)
            .background(Theme.surfaceRaised, in: .rect(cornerRadius: Radius.md))
    }
}

extension View {
    func secondaryText() -> some View {
        modifier(SecondaryText())
    }

    func themedField() -> some View {
        modifier(ThemedField())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Spacing.md)
            .background(Theme.surfaceRaised, in: .rect(cornerRadius: Radius.md))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
            .contentShape(.rect(cornerRadius: Radius.md))
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle {
        SecondaryButtonStyle()
    }
}
