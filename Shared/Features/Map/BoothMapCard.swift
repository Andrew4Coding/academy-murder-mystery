import SwiftUI

struct BoothMapCard: View {
    let map: BoothMap
    let onOpen: () -> Void

    @State private var thumbnail: CGImage?

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Spacing.md) {
                BoothMapThumbnail(image: thumbnail)
                    .frame(width: 96, height: 72)
                    .clipShape(.rect(cornerRadius: Radius.sm))
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Booth map").font(.headline)
                    Text("Tap to open and zoom").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right").foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Booth map")
        .accessibilityHint("Opens full screen")
        .accessibilityAddTraits(.isButton)
        .task(id: map.hash) { thumbnail = BoothMapImporter.decode(map.jpeg, maxPixelSize: 400) }
    }
}

struct BoothMapThumbnail: View {
    let image: CGImage?

    var body: some View {
        ZStack {
            Color.secondary.opacity(0.15)
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
    }
}
