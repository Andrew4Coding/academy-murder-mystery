import SwiftData

@MainActor
final class AppEnvironment {
    let modelContainer: ModelContainer
    let itemRepository: any ItemRepository

    init(modelContainer: ModelContainer, itemRepository: any ItemRepository) {
        self.modelContainer = modelContainer
        self.itemRepository = itemRepository
    }

    static func live() -> AppEnvironment {
        make(inMemory: false)
    }

    static func preview() -> AppEnvironment {
        make(inMemory: true)
    }

    private static func make(inMemory: Bool) -> AppEnvironment {
        do {
            let container = try ModelContainerFactory.make(inMemory: inMemory)
            return AppEnvironment(
                modelContainer: container,
                itemRepository: SwiftDataItemRepository(context: container.mainContext)
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
