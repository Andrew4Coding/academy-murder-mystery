import Foundation
import Testing
@testable import Moonfall

@MainActor
struct GameHostKillTests {
    struct Setup {
        let harness: HostHarness
        let heads: [FamilyID: GameClient]
        let wolf: FamilyID
        let victim: FamilyID
        let victimToken: String
    }

    private func setup() async throws -> Setup {
        let (harness, heads) = try await HostHarness.seated(families: 5, werewolves: 1)
        try harness.host.startGame()
        harness.clock.advance(by: 61)
        let ready = await eventually { heads.values.allSatisfy { $0.view?.game != nil } }
        precondition(ready)
        let families = harness.host.state.engine!.state.families.values
        let wolf = families.first { $0.role == .werewolf }!.id
        let victim = families.filter { $0.role == .villager }.map(\.id).sorted()[0]
        let token = harness.host.state.players.values.first { $0.family == victim }!.bleToken
        return Setup(harness: harness, heads: heads, wolf: wolf, victim: victim, victimToken: token)
    }

    @Test func aFreshStrongSightingMakesAVillagerFamilyKillable() async throws {
        let s = try await setup()
        s.heads[s.wolf]?.send(.sightings([Sighting(token: s.victimToken, rssi: -50)]))
        #expect(await eventually { s.heads[s.wolf]!.view?.game?.nearby.map(\.id) == [s.victim] })
        #expect(s.heads[s.wolf]?.view?.game?.killReadyAt != nil)
        #expect(s.heads[s.victim]?.view?.game?.nearby.isEmpty == true)
    }

    @Test func weakSightingsAndStaleSightingsAreIgnored() async throws {
        let s = try await setup()
        s.heads[s.wolf]?.send(.sightings([Sighting(token: s.victimToken, rssi: -90)]))
        _ = await eventually { s.harness.host.sightings[s.wolf] != nil }
        #expect(s.heads[s.wolf]?.view?.game?.nearby.isEmpty == true)

        s.heads[s.wolf]?.send(.sightings([Sighting(token: s.victimToken, rssi: -50)]))
        #expect(await eventually { s.heads[s.wolf]!.view?.game?.nearby.count == 1 })
        s.harness.clock.advance(by: s.harness.host.state.sightingFreshness + 1)
        s.harness.host.tick()
        #expect(await eventually { s.heads[s.wolf]!.view?.game?.nearby.isEmpty == true })
    }

    @Test func killEliminatesTheWholeVictimFamilyAndStartsTheCooldown() async throws {
        let s = try await setup()
        let wolfClient = try #require(s.heads[s.wolf])
        wolfClient.send(.sightings([Sighting(token: s.victimToken, rssi: -50)]))
        #expect(await eventually { wolfClient.view?.game?.nearby.count == 1 })
        let before = s.harness.clock.now
        wolfClient.send(.kill(victim: s.victim))
        #expect(await eventually { s.heads[s.victim]!.view?.game?.life == .killed })
        #expect(wolfClient.view?.game?.killReadyAt == before.addingTimeInterval(60))
        #expect(wolfClient.view?.game?.nearby.isEmpty == true)
    }

    @Test func killWithoutAFreshSightingIsRejected() async throws {
        let s = try await setup()
        let wolfClient = try #require(s.heads[s.wolf])
        wolfClient.send(.kill(victim: s.victim))
        #expect(await eventually { wolfClient.lastError == HostError.notNearby.message })
        #expect(s.harness.host.state.engine?.state.families[s.victim]?.life == .alive)
    }

    @Test func killOnCooldownIsRejectedByTheEngine() async throws {
        let s = try await setup()
        let wolfClient = try #require(s.heads[s.wolf])
        let others = try #require(s.harness.host.state.engine?.state.families.values.filter { $0.role == .villager }.map(\.id).sorted())
        let second = others[1]
        let secondToken = try #require(s.harness.host.state.players.values.first { $0.family == second }?.bleToken)
        wolfClient.send(.sightings([Sighting(token: s.victimToken, rssi: -50), Sighting(token: secondToken, rssi: -50)]))
        #expect(await eventually { wolfClient.view?.game?.nearby.count == 2 })
        wolfClient.send(.kill(victim: s.victim))
        #expect(await eventually { s.heads[s.victim]!.view?.game?.life == .killed })
        wolfClient.send(.sightings([Sighting(token: secondToken, rssi: -50)]))
        wolfClient.send(.kill(victim: second))
        #expect(await eventually { wolfClient.lastError == RuleError.cooldownActive(readyAt: .now).message })
    }

    @Test func changedProximitySettingsReachClients() async throws {
        let s = try await setup()
        s.harness.host.setProximity(rssiThreshold: -55, sightingFreshness: 3)
        #expect(await eventually {
            s.heads.values.allSatisfy { $0.view?.game?.proximity == ProximitySettings(rssiThreshold: -55, sightingFreshness: 3) }
        })
        s.heads[s.wolf]?.send(.sightings([Sighting(token: s.victimToken, rssi: -60)]))
        _ = await eventually { s.harness.host.sightings[s.wolf] != nil }
        #expect(s.heads[s.wolf]?.view?.game?.nearby.isEmpty == true)
    }

    @Test func ocCanForceKillAndReviveAFamily() async throws {
        let s = try await setup()
        try s.harness.host.applyAsOC(.override(.forceKill(s.victim)))
        #expect(await eventually { s.heads[s.victim]!.view?.game?.life == .killed })
        try s.harness.host.applyAsOC(.override(.revive(s.victim)))
        #expect(await eventually { s.heads[s.victim]!.view?.game?.life == .alive })
    }

    @Test func tokensAreRandomShortAndCarryNoIdentity() async throws {
        let s = try await setup()
        let players = s.harness.host.state.players.values
        let tokens = players.map(\.bleToken)
        #expect(Set(tokens).count == tokens.count)
        for player in players {
            #expect(player.bleToken.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil)
            #expect(!player.id.uuidString.contains(player.bleToken))
        }
        for client in s.heads.values {
            let json = try String(decoding: JSONEncoder().encode(client.view), as: UTF8.self)
            let own = client.view?.game?.bleToken ?? ""
            for token in tokens where token != own {
                #expect(!json.contains(token))
            }
        }
    }
}
