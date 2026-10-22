import Foundation
import Testing
@testable import MurderMystery

struct GameEngineOverrideTests {
    @Test func forceKillAndReviveRecordOverridesAndRecheckWinConditions() throws {
        var fixture = try Fixture(families: 4, werewolves: 1)
        let (a, b) = (fixture.villagers[0], fixture.villagers[1])
        let killed = try fixture.apply(.override(.forceKill(a)), at: 10)
        #expect(killed.kinds.first == .ocOverride(.forceKill(a)))
        #expect(fixture.family(a).life == .killed)
        let ended = try fixture.apply(.override(.forceKill(b)), at: 20)
        #expect(ended.outcome == Outcome(winner: .werewolves, reason: .parity))
    }

    @Test func reviveBringsAFamilyBack() throws {
        var fixture = try Fixture()
        let family = fixture.villagers[0]
        try fixture.apply(.override(.forceKill(family)), at: 10)
        try fixture.apply(.override(.revive(family)), at: 20)
        #expect(fixture.family(family).life == .alive)
        #expect(throws: RuleError.notDead(family)) {
            try fixture.apply(.override(.revive(family)), at: 30)
        }
    }

    @Test func forceKillDuringVotingCanCompleteTheVote() throws {
        var fixture = try Fixture(families: 4, werewolves: 1)
        try fixture.apply(.startMeeting, at: 100)
        _ = fixture.advance(to: 220)
        let ids = (1 ... 4).map { FamilyID($0) }
        for id in ids.prefix(3) {
            try fixture.apply(.castVote(by: id, choice: .skip), at: 230)
        }
        let events = try fixture.apply(.override(.forceKill(ids[3])), at: 240)
        #expect(events.kinds.contains {
            if case .voteClosed = $0 {
                true
            } else {
                false
            }
        })
    }

    @Test func ocCanEndTheGame() throws {
        var fixture = try Fixture()
        let events = try fixture.apply(.override(.endGame(.villagers)), at: 5)
        #expect(events.outcome == Outcome(winner: .villagers, reason: .ocEnded))
    }
}
