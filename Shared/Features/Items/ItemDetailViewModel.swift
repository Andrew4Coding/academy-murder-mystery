import Foundation
import Observation

@Observable
@MainActor
final class ItemDetailViewModel {
    private(set) var item: Item?
    var errorMessage: String?

    private let repository: any ItemRepository
    private let itemID: UUID

    init(repository: any ItemRepository, itemID: UUID) {
        self.repository = repository
        self.itemID = itemID
    }

    func load() {
        do {
            item = try repository.fetch(id: itemID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
