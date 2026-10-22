import Foundation
import Observation

@Observable
@MainActor
final class ItemListViewModel {
    private(set) var items: [Item] = []
    var errorMessage: String?

    private let repository: any ItemRepository

    init(repository: any ItemRepository) {
        self.repository = repository
    }

    func load() {
        do {
            items = try repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(at offsets: IndexSet) {
        do {
            for index in offsets {
                try repository.delete(items[index])
            }
            items = try repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
