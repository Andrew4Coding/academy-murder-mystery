import SwiftUI

struct ItemEditorView: View {
    @State private var viewModel: ItemEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(repository: any ItemRepository, item: Item? = nil) {
        _viewModel = State(initialValue: ItemEditorViewModel(repository: repository, item: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $viewModel.title)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3 ... 8)
            }
            .formStyle(.grouped)
            .navigationTitle(viewModel.isEditing ? "Edit Item" : "New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.save() {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .alert("Could not save", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .presentationSizing(.form)
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
