import Foundation
import Testing
@testable import Moonfall

struct GameEngineDeterminismTests {
    private func playScript(seed: UInt64) throws -> (events: [GameEvent], engine: GameEngine) {
        var fixture = try Fixture(families: 8, werewolves: 2, seed: seed)
        var events: [GameEvent] = []
        let wolves = fixture.werewolves
        let villagers = fixture.villagers
        events += try fixture.apply(.kill(killer: wolves[0], victim: villagers[0]), at: 70)
        events += try fixture.apply(.requestSabotage(by: wolves[1], kind: .oxygen), at: 130)
        events += try fixture.apply(.resolveSabotage, at: 170)
        events += try fixture.apply(.startMeeting, at: 200)
        events += fixture.advance(to: 320)
        events += try fixture.apply(.castVote(by: villagers[1], choice: .family(wolves[0])), at: 330)
        events += fixture.advance(to: 450)
        events += fixture.advance(to: 3000)
        return (events, fixture.engine)
    }

    @Test func replayingTheSameScriptGivesIdenticalEventsAndState() throws {
        let first = try playScript(seed: 99)
        let second = try playScript(seed: 99)
        #expect(first.events == second.events)
        #expect(first.engine == second.engine)
    }

    @Test func aRestoredEngineContinuesExactlyLikeTheOriginal() throws {
        var fixture = try Fixture()
        try fixture.apply(.startMeeting, at: 100)
        let data = try JSONEncoder().encode(fixture.engine)
        var restored = try JSONDecoder().decode(GameEngine.self, from: data)
        let original = fixture.advance(to: 500)
        let resumed = restored.advance(to: at(500))
        #expect(original == resumed)
        #expect(fixture.engine == restored)
    }

    @Test func rejectedCommandsLeaveTheStateUntouched() throws {
        var fixture = try Fixture()
        let before = fixture.engine
        #expect(throws: RuleError.self) {
            try fixture.apply(.kill(killer: fixture.villagers[0], victim: fixture.villagers[1]), at: 5000)
        }
        #expect(fixture.engine == before)
    }
}
