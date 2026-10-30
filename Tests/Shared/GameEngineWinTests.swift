import Foundation
import Testing
@testable import Moonfall

struct GameEngineWinTests {
    @Test func villagersWinWhenEveryWerewolfFamilyIsExpelled() throws {
        var fixture = try Fixture()
        let wolf = fixture.werewolves[0]
        try fixture.apply(.startMeeting, at: 100)
        _ = fixture.advance(to: 220)
        for id in fixture.villagers {
            try fixture.apply(.castVote(by: id, choice: .family(wolf)), at: 230)
        }
        let events = try fixture.apply(.castVote(by: wolf, choice: .skip), at: 231)
        #expect(events.outcome == Outcome(winner: .villagers, reason: .allWerewolvesRemoved))
    }

    @Test func werewolvesWinOnParity() throws {
        var fixture = try Fixture(families: 4, werewolves: 1)
        let wolf = fixture.werewolves[0]
        try fixture.apply(.kill(killer: wolf, victim: fixture.villagers[0]), at: 0)
        #expect(fixture.engine.state.outcome == nil)
        let events = try fixture.apply(.kill(killer: wolf, victim: fixture.villagers[1]), at: 60)
        #expect(events.outcome == Outcome(winner: .werewolves, reason: .parity))
    }

    @Test func endedGamesRejectEveryCommand() throws {
        var fixture = try Fixture(families: 4, werewolves: 1)
        try fixture.apply(.override(.endGame(.villagers)), at: 5)
        #expect(throws: RuleError.gameEnded) {
            try fixture.apply(.startMeeting, at: 10)
        }
    }
}
