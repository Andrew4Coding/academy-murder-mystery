import Foundation
import Testing
@testable import MurderMystery

struct GameEngineWinTests {
    @Test func villagersWinWhenEveryVillagerFamilyHasAllStamps() throws {
        var fixture = try Fixture()
        var last: [GameEvent] = []
        for id in fixture.villagers {
            for booth in fixture.family(id).tasks.sorted(by: { $0.rawValue < $1.rawValue }) {
                last = try fixture.apply(.recordStamp(family: id, booth: booth), at: 10)
            }
        }
        #expect(last.outcome == Outcome(winner: .villagers, reason: .allTasksDone))
    }

    @Test func deadVillagerFamiliesKeepTheirStampsTowardTheWin() throws {
        var fixture = try Fixture()
        let dead = fixture.villagers[0]
        for booth in fixture.family(dead).tasks {
            try fixture.apply(.recordStamp(family: dead, booth: booth), at: 10)
        }
        try fixture.apply(.kill(killer: fixture.werewolves[0], victim: dead), at: 100)
        var last: [GameEvent] = []
        for id in fixture.villagers.dropFirst() {
            for booth in fixture.family(id).tasks {
                last = try fixture.apply(.recordStamp(family: id, booth: booth), at: 110)
            }
        }
        #expect(last.outcome?.reason == .allTasksDone)
    }

    @Test func deadFamiliesCanStampAndTheLastStampWinsTheGame() throws {
        var fixture = try Fixture()
        let (dead, expelled) = (fixture.villagers[0], fixture.villagers[1])
        try fixture.apply(.kill(killer: fixture.werewolves[0], victim: dead), at: 100)
        try fixture.apply(.override(.forceKill(expelled)), at: 110)
        var last: [GameEvent] = []
        for id in fixture.villagers {
            for booth in fixture.family(id).tasks.sorted(by: { $0.rawValue < $1.rawValue }) {
                last = try fixture.apply(.recordStamp(family: id, booth: booth), at: 120)
            }
        }
        #expect(fixture.family(dead).life == .killed)
        #expect(last.outcome == Outcome(winner: .villagers, reason: .allTasksDone))
    }

    @Test func deadFamiliesStayDeadWhenTheyStamp() throws {
        var fixture = try Fixture()
        let dead = fixture.villagers[0]
        try fixture.apply(.kill(killer: fixture.werewolves[0], victim: dead), at: 100)
        let booth = try #require(fixture.family(dead).tasks.first)
        try fixture.apply(.recordStamp(family: dead, booth: booth), at: 110)
        #expect(fixture.family(dead).life == .killed)
        #expect(fixture.family(dead).stamps == [booth])
    }

    @Test func werewolfStampsNeverCountTowardTheWin() throws {
        var fixture = try Fixture()
        let wolf = fixture.werewolves[0]
        for booth in fixture.family(wolf).tasks {
            try fixture.apply(.recordStamp(family: wolf, booth: booth), at: 10)
        }
        #expect(fixture.engine.state.outcome == nil)
    }

    @Test func stampsOutsideTheAssignedListDoNotCompleteTasks() throws {
        var fixture = try Fixture()
        let family = fixture.villagers[0]
        let extra = try #require(Booth.allCases.first { !fixture.family(family).tasks.contains($0) })
        try fixture.apply(.recordStamp(family: family, booth: extra), at: 10)
        #expect(!fixture.family(family).hasCompletedTasks)
    }

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
