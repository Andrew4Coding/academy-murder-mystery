import SwiftUI

struct BentoGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: Spacing.md)], spacing: Spacing.md) {
            content
        }
    }
}

struct BentoTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = Theme.accent
    var isProminent = false

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(isProminent ? Theme.onAccentFill : tint)
                .accessibilityHidden(true)
            Spacer(minLength: Spacing.sm)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(isProminent ? Theme.onAccentFill : Theme.text)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(isProminent ? Theme.onAccentFill : Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(Spacing.md)
        .background(isProminent ? Theme.accentFill : Theme.surface, in: .rect(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(isProminent ? Color.clear : Theme.separator, lineWidth: 1))
        .opacity(isEnabled ? 1 : 0.45)
        .contentShape(.rect(cornerRadius: Radius.lg))
    }
}

struct BentoButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = Theme.accent
    var isProminent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BentoTile(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint, isProminent: isProminent)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func themedRows() -> some View {
        listRowBackground(Theme.surface)
    }
}
