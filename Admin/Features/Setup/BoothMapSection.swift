import SwiftUI

struct BoothMapSection: View {
    let map: BoothMap?
    let onChoose: () -> Void
    let onRemove: () -> Void

    @State private var preview: CGImage?

    var body: some View {
        Section {
            if let map {
                HStack(alignment: .top, spacing: Spacing.md) {
                    BoothMapThumbnail(image: preview)
                        .frame(width: 240, height: 160)
                        .clipShape(.rect(cornerRadius: Radius.md))
                        .accessibilityLabel("Booth map preview")
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        if let preview {
                            Text("\(preview.width) × \(preview.height) px").foregroundStyle(Theme.textSecondary).monospacedDigit()
                        }
                        Text(ByteCountFormatter.string(fromByteCount: Int64(map.jpeg.count), countStyle: .file))
                            .foregroundStyle(Theme.textSecondary)
                        HStack {
                            Button("Replace…", action: onChoose)
                            Button("Remove", role: .destructive, action: onRemove)
                        }
                    }
                }
                .task(id: map.hash) { preview = BoothMapImporter.decode(map.jpeg, maxPixelSize: 4096) }
            } else {
                Button("Choose Image…", systemImage: "map", action: onChoose)
            }
        } header: {
            Text("Booth map")
        } footer: {
            Text("Optional. Players and the OC iPad can open it from their devices. Large images are shrunk to 3000 px. Changes reach connected devices straight away.")
        }
        .themedRows()
    }
}
