import Testing
@testable import Moonfall

struct ModelContainerTests {
    @Test @MainActor func inMemoryContainerBuildsWithCurrentSchema() throws {
        _ = try ModelContainerFactory.make(inMemory: true)
    }
}
