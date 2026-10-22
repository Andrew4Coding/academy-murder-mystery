import SwiftUI

struct ItemListView: View {
    @State private var viewModel: ItemListViewModel
    @State private var isPresentingEditor = false

    private let environment: AppEnvironment
    private let selection: Binding<UUID?>?

    init(environment: AppEnvironment, selection: Binding<UUID?>? = nil) {
        self.environment = environment
        self.selection = selection
        _viewModel = State(initialValue: ItemListViewModel(repository: environment.itemRepository))
    }

    var body: some View {
        List(selection: selection) {
            ForEach(viewModel.items) { item in
                NavigationLink(value: item.id) {
                    ItemRow(item: item)
                }
            }
            .onDelete { viewModel.delete(at: $0) }
        }
        .overlay {
            if viewModel.items.isEmpty {
                ContentUnavailableView("No Items", systemImage: "tray", description: Text("Tap + to add one."))
            }
        }
        .navigationTitle("Items")
        .toolbar {
            ToolbarItem {
                Button("Add Item", systemImage: "plus") {
                    isPresentingEditor = true
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor, onDismiss: { viewModel.load() }) {
            ItemEditorView(repository: environment.itemRepository)
        }
        .task { viewModel.load() }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: {
                if !$0 {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

private struct ItemRow: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(item.title)
                .font(.headline)
            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ItemListView(environment: .preview())
    }
}
