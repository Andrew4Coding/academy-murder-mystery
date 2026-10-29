import Foundation
import SwiftData
import Testing
@testable import MurderMystery

@MainActor
struct GameHostSabotageTests {
    struct Setup {
        let harness: HostHarness
        let heads: [FamilyID: GameClient]
        let wolves: [FamilyID]
        let villagers: [FamilyID]
    }

    private func setup(repository: any GameRepository = InMemoryGameRepository()) async throws -> Setup {
        let harness = try HostHarness(families: [], repository: repository)
        try harness.host.configure(familyCount: 6, werewolfCount: 2, settings: .standard)
        var heads: [FamilyID: GameClient] = [:]
        for family in harness.host.state.families.values.sorted(by: { $0.id < $1.id }) {
            let client = harness.makeClient()
            client.join(code: family.joinCode, name: "H\(family.id.rawValue)")
            _ = await eventually { client.isSignedIn }
            _ = await eventually { client.view?.lobby != nil }
            heads[family.id] = client
        }
        try harness.host.startGame()
        harness.clock.advance(by: 121)
        _ = await eventually { heads.values.allSatisfy { $0.view?.game != nil } }
        let families = harness.host.state.engine!.state.families.values
        return Setup(
            harness: harness,
            heads: heads,
            wolves: families.filter { $0.role == .werewolf }.map(\.id).sorted(),
            villagers: families.filter { $0.role == .villager }.map(\.id).sorted()
        )
    }

    private func signInOC(_ harness: HostHarness, station: OCStation) async -> GameClient {
        let client = harness.makeClient()
        client.signInAsOC(pin: "4242", station: station)
        _ = await eventually { client.view != nil }
        return client
    }

    @Test func aWerewolfStartsASabotageEveryoneSeesWithAHostBasedCountdown() async throws {
        let s = try await setup()
        let now = s.harness.clock.now
        s.heads[s.wolves[0]]!.send(.requestSabotage(.reactor))
        #expect(await eventually {
            s.heads.values.allSatisfy { $0.view?.game?.sabotage?.endsAt == now.addingTimeInterval(90) }
        })
        for id in s.villagers {
            #expect(s.heads[id]!.view?.game?.sabotage?.kind == .reactor)
            #expect(s.heads[id]!.view?.game?.sabotageReadyAt == nil)
        }
        for id in s.wolves {
            #expect(s.heads[id]!.view?.game?.sabotageReadyAt == now.addingTimeInterval(120))
        }
    }

    @Test func villagersCannotSabotageAndCooldownsAreEnforced() async throws {
        let s = try await setup()
        let villager = s.heads[s.villagers[0]]!
        villager.send(.requestSabotage(.oxygen))
        #expect(await eventually { villager.lastError == RuleError.notWerewolf(1).message })

        let wolf = s.heads[s.wolves[0]]!
        wolf.send(.requestSabotage(.oxygen))
        #expect(await eventually { s.heads[s.villagers[0]]!.view?.game?.sabotage != nil })
        try s.harness.host.applyAsOC(.resolveSabotage)
        s.heads[s.wolves[1]]!.send(.requestSabotage(.reactor))
        #expect(await eventually { s.heads[s.wolves[1]]!.lastError == RuleError.cooldownActive(readyAt: .now).message })
    }

    @Test func aDeadWerewolfFamilyCanStillSabotage() async throws {
        let s = try await setup()
        try s.harness.host.applyAsOC(.override(.forceKill(s.wolves[0])))
        s.heads[s.wolves[0]]!.send(.requestSabotage(.reactor))
        #expect(await eventually { s.heads[s.wolves[0]]!.view?.game?.sabotage != nil })
    }

    @Test func sabotageIsBlockedWhileAMeetingRuns() async throws {
        let s = try await setup()
        try s.harness.host.applyAsOC(.startMeeting)
        s.heads[s.wolves[0]]!.send(.requestSabotage(.reactor))
        #expect(await eventually { s.heads[s.wolves[0]]!.lastError == RuleError.wrongPhase.message })
    }

    @Test func theRightStationOrTheTownHallCanResolveIt() async throws {
        let s = try await setup()
        let reactorOC = await signInOC(s.harness, station: .sabotage(.reactor))
        let oxygenOC = await signInOC(s.harness, station: .sabotage(.oxygen))
        let townHall = await signInOC(s.harness, station: .townHall)
        s.heads[s.wolves[0]]!.send(.requestSabotage(.reactor))
        #expect(await eventually { reactorOC.view?.oc?.sabotage?.kind == .reactor })

        oxygenOC.send(.resolveSabotage)
        #expect(await eventually { oxygenOC.lastError == HostError.wrongStation.message })
        s.heads[s.villagers[0]]!.send(.resolveSabotage)
        #expect(await eventually { s.heads[s.villagers[0]]!.lastError == HostError.notOC.message })

        reactorOC.send(.resolveSabotage)
        #expect(await eventually { s.heads.values.allSatisfy { $0.view?.game?.sabotage == nil } })

        s.harness.clock.advance(by: 121)
        s.heads[s.wolves[1]]!.send(.requestSabotage(.oxygen))
        #expect(await eventually { townHall.view?.oc?.sabotage?.kind == .oxygen })
        townHall.send(.resolveSabotage)
        #expect(await eventually { townHall.view?.oc?.sabotage == nil })
    }

    @Test func anUnresolvedSabotageEndsTheGameForTheWerewolves() async throws {
        let s = try await setup()
        s.heads[s.wolves[0]]!.send(.requestSabotage(.reactor))
        #expect(await eventually { s.heads[s.wolves[0]]!.view?.game?.sabotage != nil })
        s.harness.clock.advance(by: 91)
        s.harness.host.tick()
        #expect(await eventually {
            s.heads.values.allSatisfy { $0.view?.game?.phase == .ended(Outcome(winner: .werewolves, reason: .sabotageExpired)) }
        })
    }

    @Test func aRestartDuringASabotageKeepsTheRemainingTime() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = SwiftDataGameRepository(context: container.mainContext)
        let s = try await setup(repository: repository)
        let startedAt = s.harness.clock.now
        s.heads[s.wolves[0]]!.send(.requestSabotage(.reactor))
        #expect(await eventually { s.harness.host.state.engine?.state.sabotage != nil })
        s.harness.clock.advance(by: 30)

        let restored = try GameHost(repository: repository, clock: s.harness.clock)
        #expect(restored.state.engine?.state.sabotage?.endsAt == startedAt.addingTimeInterval(90))
        s.harness.clock.advance(by: 61)
        restored.tick()
        #expect(restored.state.engine?.state.outcome == Outcome(winner: .werewolves, reason: .sabotageExpired))
    }
}
