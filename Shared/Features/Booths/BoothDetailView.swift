import SwiftUI

struct BoothDetailView: View {
    let booth: Booth
    var showsStaffNotes = false
    var onClose: (() -> Void)?

    @State private var image: CGImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let boothImage = booth.image {
                        BoothMapThumbnail(image: image)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(imageAspectRatio, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: Radius.md))
                            .accessibilityLabel("Picture for \(booth.title)")
                            .task(id: boothImage.hash) {
                                image = BoothMapImporter.decode(boothImage.jpeg, maxPixelSize: 1600)
                            }
                    }

                    Text(booth.title)
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)

                    facts

                    if !booth.task.isEmpty {
                        section("Task") { Text(booth.task) }
                    }
                    if !booth.steps.isEmpty {
                        section("How to join") {
                            ForEach(Array(booth.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                                    Text("\(index + 1)").font(.body.weight(.semibold)).frame(minWidth: 24, alignment: .leading)
                                    Text(step)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Step \(index + 1): \(step)")
                            }
                        }
                    }
                    if !booth.stampRequirement.isEmpty {
                        section("Done when") { Text(booth.stampRequirement) }
                    }
                    if showsStaffNotes, !booth.staffNotes.isEmpty {
                        section("Staff notes") {
                            ForEach(Array(booth.staffNotes.enumerated()), id: \.offset) { _, note in
                                Text(note)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.lg)
            }
            .background(Theme.background)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: onClose)
                    }
                }
            }
        }
    }

    private var imageAspectRatio: CGFloat {
        guard let image else { return 4.0 / 3.0 }
        return CGFloat(image.width) / CGFloat(max(image.height, 1))
    }

    @ViewBuilder
    private var facts: some View {
        let rows = [
            ("mappin.and.ellipse", "Location", booth.location),
            ("person.2", "Capacity", booth.capacity),
            ("clock", "Duration", booth.duration)
        ].filter { !$0.2.isEmpty }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(rows, id: \.1) { icon, label, value in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label).font(.footnote).foregroundStyle(Theme.textSecondary)
                            Text(value)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
        }
    }
}
