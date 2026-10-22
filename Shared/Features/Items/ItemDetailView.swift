import SwiftUI

struct ItemDetailView: View {
    @State private var viewModel: ItemDetailViewModel
    @State private var isPresentingEditor = false

    private let environment: AppEnvironment

    init(environment: AppEnvironment, itemID: UUID) {
        self.environment = environment
        _viewModel = State(initialValue: ItemDetailViewModel(repository: environment.itemRepository, itemID: itemID))
    }

    var body: some View {
        Group {
            if let item = viewModel.item {
                Form {
                    Section("Title") {
                        Text(item.title)
                    }
                    if !item.notes.isEmpty {
                        Section("Notes") {
                            Text(item.notes)
                        }
                    }
                    Section("Created") {
                        Text(item.createdAt, format: .dateTime)
                    }
                }
                .navigationTitle(item.title)
                .toolbar {
                    ToolbarItem {
                        Button("Edit", systemImage: "pencil") {
                            isPresentingEditor = true
                        }
                    }
                }
                .sheet(isPresented: $isPresentingEditor, onDismiss: { viewModel.load() }) {
                    ItemEditorView(repository: environment.itemRepository, item: item)
                }
            } else {
                ContentUnavailableView("Item Not Found", systemImage: "questionmark.folder")
            }
        }
        .task { viewModel.load() }
    }
}
