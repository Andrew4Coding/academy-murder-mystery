import PhotosUI
import SwiftUI

struct BoothEditorView: View {
    let booth: Booth
    let actions: BoothActions

    @State private var draft: Booth
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var image: CGImage?
    @State private var imageError = false
    @State private var isPreviewing = false
    @State private var confirmingDelete = false

    init(booth: Booth, actions: BoothActions) {
        self.booth = booth
        self.actions = actions
        _draft = State(initialValue: booth)
    }

    private var hasChanges: Bool {
        var current = draft
        current.image = booth.image
        return current != booth
    }

    var body: some View {
        Form {
            Section("Picture") { pictureRow }

            Section("Details") {
                TextField("Title", text: $draft.title)
                TextField("Location", text: $draft.location, axis: .vertical)
                TextField("Capacity", text: $draft.capacity, axis: .vertical)
                TextField("Duration", text: $draft.duration, axis: .vertical)
                TextField("Done when", text: $draft.stampRequirement, axis: .vertical)
            }

            Section("Task") {
                TextField("What players have to do", text: $draft.task, axis: .vertical)
                    .lineLimit(2 ... 6)
            }

            lines("How to join", placeholder: "Step", add: "Add Step", items: $draft.steps)

            lines(
                "Staff notes",
                placeholder: "Note",
                add: "Add Note",
                items: $draft.staffNotes,
                footer: "Only visible here. These are never sent to player phones."
            )

            Section {
                Button("Delete Booth", systemImage: "trash", role: .destructive) { confirmingDelete = true }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle(booth.title.isEmpty ? "Untitled booth" : booth.title)
        .toolbar {
            ToolbarItem {
                Button("Preview", systemImage: "eye") { isPreviewing = true }
            }
            ToolbarItem {
                Button("Revert", systemImage: "arrow.uturn.backward") { draft = booth }
                    .disabled(!hasChanges)
            }
            ToolbarItem {
                Button("Save", systemImage: "checkmark") { actions.save(draft) }
                    .disabled(!hasChanges)
                    .keyboardShortcut("s")
            }
        }
        .sheet(isPresented: $isPreviewing) {
            BoothDetailView(booth: previewBooth, showsStaffNotes: true) { isPreviewing = false }
                .frame(minWidth: 380, minHeight: 520)
        }
        .confirmationDialog("Delete this booth?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Booth", role: .destructive) { actions.delete(booth.id) }
        } message: {
            Text("Players lose it from their phones straight away.")
        }
        .alert("That file isn't an image", isPresented: $imageError) {
            Button("OK", role: .cancel) {}
        }
        .task(id: booth.image?.hash) {
            image = booth.image.flatMap { BoothMapImporter.decode($0.jpeg, maxPixelSize: 1600) }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
    }

    private var previewBooth: Booth {
        var copy = draft
        copy.image = booth.image
        return copy
    }

    @ViewBuilder
    private var pictureRow: some View {
        if booth.image != nil {
            BoothMapThumbnail(image: image)
                .frame(maxWidth: .infinity)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(.rect(cornerRadius: Radius.md))
                .accessibilityLabel("Booth picture")
        }
        PhotosPicker(selection: $pickedPhoto, matching: .images) {
            Label(booth.image == nil ? "Choose Picture" : "Replace Picture", systemImage: "photo")
        }
        if let defaultImage = BoothDefaults.image(for: booth.id), booth.image?.hash != defaultImage.hash {
            Button("Use Default Picture", systemImage: "photo.badge.arrow.down") {
                actions.setImage(booth.id, defaultImage.jpeg)
            }
        }
        if booth.image != nil {
            Button("Remove Picture", systemImage: "trash", role: .destructive) { actions.removeImage(booth.id) }
        }
    }

    private var aspectRatio: CGFloat {
        guard let image else { return 16.0 / 9.0 }
        return CGFloat(image.width) / CGFloat(max(image.height, 1))
    }

    private func lines(
        _ title: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        add: LocalizedStringKey,
        items: Binding<[String]>,
        footer: LocalizedStringKey? = nil
    ) -> some View {
        Section {
            ForEach(items.wrappedValue.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1)").foregroundStyle(Theme.textSecondary).frame(minWidth: 20, alignment: .leading)
                    TextField(placeholder, text: items[index], axis: .vertical)
                    Button("Remove", systemImage: "minus.circle") { items.wrappedValue.remove(at: index) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(Theme.accent)
                }
            }
            .onMove { source, destination in items.wrappedValue.move(fromOffsets: source, toOffset: destination) }
            Button(add, systemImage: "plus.circle") { items.wrappedValue.append("") }
        } header: {
            Text(title)
        } footer: {
            if let footer {
                Text(footer)
            }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        defer { pickedPhoto = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let processed = try? BoothMapImporter.makeBoothImage(from: data)
        else {
            imageError = true
            return
        }
        actions.setImage(booth.id, processed.jpeg)
    }
}
