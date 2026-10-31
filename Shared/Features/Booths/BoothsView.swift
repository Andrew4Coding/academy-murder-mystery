import SwiftUI

struct BoothActions {
    var save: (Booth) -> Void
    var delete: (UUID) -> Void
    var reorder: ([UUID]) -> Void
    var setImage: (UUID, Data) -> Void
    var removeImage: (UUID) -> Void
    var restoreDefaults: () -> Void
}

struct BoothsView: View {
    let booths: [Booth]
    let actions: BoothActions

    @State private var selection: UUID?
    @State private var confirmingRestore = false

    var body: some View {
        HStack(spacing: 0) {
            list
                .frame(width: 300)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .themedBackground()
        .navigationTitle("Booths")
        .toolbar {
            ToolbarItem {
                Button("Add Booth", systemImage: "plus", action: add)
                    .help("Add a booth")
            }
            ToolbarItem {
                Button("Restore Defaults", systemImage: "arrow.counterclockwise") { confirmingRestore = true }
                    .help("Replace every booth with the four from the carnival guide")
            }
        }
        .confirmationDialog("Restore the default booths?", isPresented: $confirmingRestore, titleVisibility: .visible) {
            Button("Restore Defaults", role: .destructive) {
                selection = nil
                actions.restoreDefaults()
            }
        } message: {
            Text("This replaces every booth and edit with the four from the carnival guide. Pictures of those booths are kept.")
        }
        .onChange(of: booths.map(\.id)) { _, ids in
            if let selection, !ids.contains(selection) {
                self.selection = nil
            }
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(Array(booths.enumerated()), id: \.element.id) { index, booth in
                VStack(alignment: .leading, spacing: 2) {
                    Text("Booth \(index + 1)").font(.footnote).foregroundStyle(Theme.textSecondary)
                    Text(booth.title.isEmpty ? "Untitled booth" : booth.title).font(.body.weight(.semibold))
                }
                .tag(booth.id)
                .listRowBackground(Theme.surface)
                .accessibilityElement(children: .combine)
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) { actions.delete(booth.id) }
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) { actions.delete(booth.id) }
                }
            }
            .onMove { source, destination in
                var ids = booths.map(\.id)
                ids.move(fromOffsets: source, toOffset: destination)
                actions.reorder(ids)
            }
        }
        .overlay {
            if booths.isEmpty {
                ContentUnavailableView(
                    "No booths",
                    systemImage: "square.grid.2x2",
                    description: Text("Add a booth or restore the defaults.")
                )
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let selection, let index = booths.firstIndex(where: { $0.id == selection }) {
            BoothEditorView(booth: booths[index], number: index + 1, actions: actions)
                .id(selection)
        } else {
            ContentUnavailableView(
                "Select a booth",
                systemImage: "square.and.pencil",
                description: Text("Players see everything except the staff notes.")
            )
        }
    }

    private func add() {
        let booth = Booth(title: "New booth")
        actions.save(booth)
        selection = booth.id
    }
}
