import Testing
@testable import MurderMystery

struct ModelContainerTests {
    @Test @MainActor func inMemoryContainerBuildsWithCurrentSchema() throws {
        _ = try ModelContainerFactory.make(inMemory: true)
    }
}
