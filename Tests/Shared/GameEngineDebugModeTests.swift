import Foundation
import Testing
@testable import Moonfall

struct GameEngineDebugModeTests {
    private var debug: GameSettings {
        var settings = GameSettings.standard
        settings.debugMode = true
        return settings
    }

    @Test func twoFamiliesCanStartOnlyInDebugMode() throws {
        var generator = SeededGenerator(seed: 1)
        #expect(throws: RuleError.self) {
            _ = try GameEngine.start(familyIDs: [1, 2], werewolfCount: 1, at: t0, using: &generator)
        }
        let started = try GameEngine.start(familyIDs: [1, 2], werewolfCount: 1, settings: debug, at: t0, using: &generator)
        #expect(started.engine.state.families.count == 2)
    }

    @Test func killAndSabotageHaveNoCooldown() throws {
        var fixture = try Fixture(families: 6, settings: debug)
        let wolf = fixture.werewolves[0]
        try fixture.apply(.kill(killer: wolf, victim: fixture.villagers[0]), at: 10)
        try fixture.apply(.kill(killer: wolf, victim: fixture.villagers[1]), at: 10)
        try fixture.apply(.requestSabotage(by: wolf, kind: .reactor), at: 10)
        try fixture.apply(.resolveSabotage, at: 11)
        try fixture.apply(.requestSabotage(by: wolf, kind: .oxygen), at: 11)
    }

    @Test func killingToParityDoesNotEndTheGame() throws {
        var fixture = try Fixture(families: 2, settings: debug)
        let events = try fixture.apply(.kill(killer: fixture.werewolves[0], victim: fixture.villagers[0]), at: 10)
        #expect(events.outcome == nil)
        #expect(fixture.engine.state.outcome == nil)
    }

    @Test func storedSettingsWithoutTheFlagDecodeAsOff() throws {
        let data = try JSONEncoder().encode(GameSettings.standard)
        #expect(try JSONDecoder().decode(GameSettings.self, from: data).isDebug == false)
    }
}
