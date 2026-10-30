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
    var tint: Color = .accentColor

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(tint)
            Spacer(minLength: Spacing.sm)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(Spacing.md)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .opacity(isEnabled ? 1 : 0.45)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct BentoButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BentoTile(title: title, subtitle: subtitle, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
    }
}
