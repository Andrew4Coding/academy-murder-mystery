import Foundation
import Testing
@testable import MurderMystery

struct GameEngineActionTests {
    @Test func killMarksWholeFamilyDeadAndStartsCooldown() throws {
        var fixture = try Fixture()
        let (wolf, victim) = (fixture.werewolves[0], fixture.villagers[0])
        let events = try fixture.apply(.kill(killer: wolf, victim: victim), at: 61)
        #expect(events.kinds.contains(.familyKilled(victim, by: wolf)))
        #expect(fixture.family(victim).life == .killed)
        #expect(fixture.family(wolf).killReadyAt == at(121))
    }

    @Test func killRespectsCooldown() throws {
        var fixture = try Fixture()
        let (wolf, victims) = (fixture.werewolves[0], fixture.villagers)
        try fixture.apply(.kill(killer: wolf, victim: victims[0]), at: 0)
        #expect(throws: RuleError.cooldownActive(readyAt: at(60))) {
            try fixture.apply(.kill(killer: wolf, victim: victims[1]), at: 59)
        }
        try fixture.apply(.kill(killer: wolf, victim: victims[1]), at: 60)
    }

    @Test func killAndSabotageAreReadyAtStart() throws {
        let fixture = try Fixture()
        #expect(fixture.family(fixture.werewolves[0]).killReadyAt == at(0))
        #expect(fixture.engine.state.sabotageReadyAt == at(0))
    }

    @Test func killIsRejectedForInvalidActorsAndTargets() throws {
        var fixture = try Fixture()
        let (wolf, villager, other) = (fixture.werewolves[0], fixture.villagers[0], fixture.villagers[1])
        #expect(throws: RuleError.notWerewolf(villager)) {
            try fixture.apply(.kill(killer: villager, victim: other), at: 100)
        }
        #expect(throws: RuleError.notVillager(wolf)) {
            try fixture.apply(.kill(killer: wolf, victim: wolf), at: 100)
        }
        try fixture.apply(.kill(killer: wolf, victim: villager), at: 100)
        #expect(throws: RuleError.familyNotAlive(villager)) {
            try fixture.apply(.kill(killer: wolf, victim: villager), at: 200)
        }
    }

    @Test func killIsBlockedDuringMeetings() throws {
        var fixture = try Fixture()
        let (wolf, victim) = (fixture.werewolves[0], fixture.villagers[0])
        try fixture.apply(.startMeeting, at: 100)
        #expect(throws: RuleError.wrongPhase) {
            try fixture.apply(.kill(killer: wolf, victim: victim), at: 110)
        }
        _ = fixture.advance(to: 230)
        #expect(throws: RuleError.wrongPhase) {
            try fixture.apply(.kill(killer: wolf, victim: victim), at: 231)
        }
        _ = fixture.advance(to: 350)
        try fixture.apply(.kill(killer: wolf, victim: victim), at: 351)
    }

    @Test func sabotageStartsCountdownAndSharedCooldown() throws {
        var fixture = try Fixture(families: 6, werewolves: 2)
        let (first, second) = (fixture.werewolves[0], fixture.werewolves[1])
        let events = try fixture.apply(.requestSabotage(by: first, kind: .reactor), at: 0)
        #expect(events.kinds == [.sabotageStarted(kind: .reactor, by: first, endsAt: at(90))])
        #expect(fixture.engine.state.sabotageReadyAt == at(120))
        try fixture.apply(.resolveSabotage, at: 10)
        #expect(throws: RuleError.cooldownActive(readyAt: at(120))) {
            try fixture.apply(.requestSabotage(by: second, kind: .oxygen), at: 119)
        }
        try fixture.apply(.requestSabotage(by: second, kind: .oxygen), at: 120)
    }

    @Test func onlyOneSabotageAtATimeAndNotDuringMeetings() throws {
        var fixture = try Fixture(settings: GameSettings(sabotageCooldown: 0))
        let wolf = fixture.werewolves[0]
        try fixture.apply(.requestSabotage(by: wolf, kind: .reactor), at: 10)
        #expect(throws: RuleError.sabotageAlreadyActive) {
            try fixture.apply(.requestSabotage(by: wolf, kind: .oxygen), at: 20)
        }
        try fixture.apply(.resolveSabotage, at: 30)
        try fixture.apply(.startMeeting, at: 40)
        #expect(throws: RuleError.wrongPhase) {
            try fixture.apply(.requestSabotage(by: wolf, kind: .oxygen), at: 50)
        }
    }

    @Test func villagersCannotSabotage() throws {
        var fixture = try Fixture()
        let villager = fixture.villagers[0]
        #expect(throws: RuleError.notWerewolf(villager)) {
            try fixture.apply(.requestSabotage(by: villager, kind: .reactor), at: 500)
        }
    }

    @Test func resolvedSabotageClearsAndExpiredSabotageEndsTheGame() throws {
        var fixture = try Fixture()
        let wolf = fixture.werewolves[0]
        try fixture.apply(.requestSabotage(by: wolf, kind: .oxygen), at: 120)
        let resolved = try fixture.apply(.resolveSabotage, at: 209)
        #expect(resolved.kinds == [.sabotageResolved])
        #expect(fixture.advance(to: 400).outcome == nil)

        try fixture.apply(.requestSabotage(by: wolf, kind: .oxygen), at: 400)
        let expired = fixture.advance(to: 490)
        #expect(expired.outcome == Outcome(winner: .werewolves, reason: .sabotageExpired))
        #expect(fixture.engine.state.outcome != nil)
    }

    @Test func deadOrExpelledWerewolvesCanStillSabotageButNotKill() throws {
        var fixture = try Fixture(families: 6, werewolves: 2)
        let wolf = fixture.werewolves[0]
        try fixture.apply(.override(.forceKill(wolf)), at: 10)
        #expect(throws: RuleError.familyNotAlive(wolf)) {
            try fixture.apply(.kill(killer: wolf, victim: fixture.villagers[0]), at: 100)
        }
        try fixture.apply(.requestSabotage(by: wolf, kind: .reactor), at: 120)
    }

    @Test func stampsAreIdempotentAndUndoable() throws {
        var fixture = try Fixture()
        let family = fixture.villagers[0]
        try fixture.apply(.recordStamp(family: family, booth: .morseCode), at: 10)
        #expect(throws: RuleError.alreadyStamped) {
            try fixture.apply(.recordStamp(family: family, booth: .morseCode), at: 11)
        }
        try fixture.apply(.undoStamp(family: family, booth: .morseCode), at: 12)
        #expect(throws: RuleError.notStamped) {
            try fixture.apply(.undoStamp(family: family, booth: .morseCode), at: 13)
        }
    }
}
