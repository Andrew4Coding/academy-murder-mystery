import Foundation
import SwiftData

@MainActor
protocol ItemRepository {
    func fetchAll() throws -> [Item]
    func fetch(id: UUID) throws -> Item?
    func insert(_ item: Item) throws
    func delete(_ item: Item) throws
    func save() throws
}

@MainActor
final class SwiftDataItemRepository: ItemRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Item] {
        let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> Item? {
        var descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func insert(_ item: Item) throws {
        context.insert(item)
        try context.save()
    }

    func delete(_ item: Item) throws {
        context.delete(item)
        try context.save()
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
