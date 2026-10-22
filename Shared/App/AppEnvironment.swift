import SwiftData

@MainActor
final class AppEnvironment {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    static func live() -> AppEnvironment {
        make(inMemory: false)
    }

    static func preview() -> AppEnvironment {
        make(inMemory: true)
    }

    private static func make(inMemory: Bool) -> AppEnvironment {
        do {
            return AppEnvironment(modelContainer: try ModelContainerFactory.make(inMemory: inMemory))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
