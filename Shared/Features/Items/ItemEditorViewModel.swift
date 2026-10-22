import Foundation
import Observation

@Observable
@MainActor
final class ItemEditorViewModel {
    var title: String
    var notes: String
    var errorMessage: String?

    private let repository: any ItemRepository
    private let item: Item?

    init(repository: any ItemRepository, item: Item? = nil) {
        self.repository = repository
        self.item = item
        title = item?.title ?? ""
        notes = item?.notes ?? ""
    }

    var isEditing: Bool {
        item != nil
    }

    var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func save() -> Bool {
        do {
            if let item {
                item.title = trimmedTitle
                item.notes = notes
                try repository.save()
            } else {
                try repository.insert(Item(title: trimmedTitle, notes: notes))
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
