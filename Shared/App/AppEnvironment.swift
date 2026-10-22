import SwiftData

@MainActor
final class AppEnvironment {
    let modelContainer: ModelContainer
    let gameRepository: any GameRepository

    init(modelContainer: ModelContainer, gameRepository: any GameRepository) {
        self.modelContainer = modelContainer
        self.gameRepository = gameRepository
    }

    static func live() -> AppEnvironment {
        make(inMemory: false)
    }

    static func preview() -> AppEnvironment {
        make(inMemory: true)
    }

    func makeHost() -> GameHost {
        do {
            return try GameHost(repository: gameRepository)
        } catch {
            fatalError("Failed to restore the game: \(error)")
        }
    }

    private static func make(inMemory: Bool) -> AppEnvironment {
        do {
            let container = try ModelContainerFactory.make(inMemory: inMemory)
            return AppEnvironment(
                modelContainer: container,
                gameRepository: SwiftDataGameRepository(context: container.mainContext)
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
