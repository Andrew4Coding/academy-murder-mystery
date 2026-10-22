import Foundation
@testable import MurderMystery

@MainActor
final class MockItemRepository: ItemRepository {
    var items: [Item]
    var error: (any Error)?
    private(set) var saveCount = 0

    init(items: [Item] = []) {
        self.items = items
    }

    func fetchAll() throws -> [Item] {
        if let error {
            throw error
        }
        return items
    }

    func fetch(id: UUID) throws -> Item? {
        if let error {
            throw error
        }
        return items.first { $0.id == id }
    }

    func insert(_ item: Item) throws {
        if let error {
            throw error
        }
        items.append(item)
    }

    func delete(_ item: Item) throws {
        if let error {
            throw error
        }
        items.removeAll { $0.id == item.id }
    }

    func save() throws {
        if let error {
            throw error
        }
        saveCount += 1
    }
}

struct TestError: Error {}
