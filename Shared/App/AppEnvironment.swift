import SwiftData

@MainActor
final class AppEnvironment {
    let modelContainer: ModelContainer
    let gameRepository: any GameRepository
    let boothMapStore: any BoothMapStore
    let boothStore: any BoothStore

    init(modelContainer: ModelContainer, gameRepository: any GameRepository, boothMapStore: any BoothMapStore, boothStore: any BoothStore) {
        self.modelContainer = modelContainer
        self.gameRepository = gameRepository
        self.boothMapStore = boothMapStore
        self.boothStore = boothStore
    }

    static func live() -> AppEnvironment {
        make(inMemory: false)
    }

    static func preview() -> AppEnvironment {
        make(inMemory: true)
    }

    func makeHost() -> GameHost {
        do {
            return try GameHost(repository: gameRepository, boothMapStore: boothMapStore, boothStore: boothStore)
        } catch {
            fatalError("Failed to restore the game: \(error)")
        }
    }

    private static func make(inMemory: Bool) -> AppEnvironment {
        do {
            let container = try ModelContainerFactory.make(inMemory: inMemory)
            return AppEnvironment(
                modelContainer: container,
                gameRepository: SwiftDataGameRepository(context: container.mainContext),
                boothMapStore: inMemory ? InMemoryBoothMapStore() : FileBoothMapStore.appSupport(),
                boothStore: inMemory ? InMemoryBoothStore() : FileBoothStore.appSupport()
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
