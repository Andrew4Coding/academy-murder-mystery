import SwiftData
import Testing
@testable import MurderMystery

@MainActor
struct SwiftDataItemRepositoryTests {
    private func makeRepository() throws -> (repository: SwiftDataItemRepository, container: ModelContainer) {
        let container = try ModelContainerFactory.make(inMemory: true)
        return (SwiftDataItemRepository(context: container.mainContext), container)
    }

    @Test func insertThenFetchRoundTrips() throws {
        let (repository, container) = try makeRepository()
        let item = Item(title: "Persisted")

        try repository.insert(item)

        #expect(try repository.fetchAll().count == 1)
        #expect(try repository.fetch(id: item.id)?.title == "Persisted")
        withExtendedLifetime(container) {}
    }

    @Test func deleteRemovesItem() throws {
        let (repository, container) = try makeRepository()
        let item = Item(title: "Gone")
        try repository.insert(item)

        try repository.delete(item)

        #expect(try repository.fetchAll().isEmpty)
        withExtendedLifetime(container) {}
    }
}
