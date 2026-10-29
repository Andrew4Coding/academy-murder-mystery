import Foundation
import Testing
@testable import Moonfall

@MainActor
struct SimulationTests {
    private func make(seed: UInt64 = 1, families: Int = 10, werewolves: Int = 2) throws -> Simulation {
        try Simulation(config: Simulation.Config(familyCount: families, werewolfCount: werewolves, seed: seed))
    }

    @Test func botsFillEveryFamilyAndTheGameStarts() throws {
        let sim = try make()
        let state = sim.host.state
        #expect(state.families.count == 10)
        #expect(state.players.count == 10)
        #expect(state.families.keys.allSatisfy { state.player(of: $0) != nil })
        #expect(state.engine?.state.families.values.filter { $0.role == .werewolf }.count == 2)
    }

    @Test func fastForwardingMovesTimersWithTheSimulatedClock() throws {
        #expect(Simulation.virtualSeconds(real: 0.1, speed: 20) == 2)
        let sim = try make()
        sim.step(by: 2700)
        let phase = sim.host.state.engine?.state.phase
        if case .voting(_, true)? = phase {} else if case .ended? = phase {} else {
            Issue.record("The final vote should be open or the game over after 45 simulated minutes, got \(String(describing: phase))")
        }
    }

    @Test func botsStampKillSabotageMeetAndVoteUntilTheGameEnds() throws {
        let sim = try make(seed: 7)
        sim.runToCompletion()
        #expect(sim.isFinished)
        let kinds = sim.events.map(\.kind)
        #expect(kinds.contains {
            if case .stampRecorded = $0 {
                true
            } else {
                false
            }
        })
        #expect(kinds.contains {
            if case .votingOpened = $0 {
                true
            } else {
                false
            }
        })
        #expect(kinds.contains {
            if case .gameEnded = $0 {
                true
            } else {
                false
            }
        })
    }

    @Test func someSeedsProduceKillsAndSabotages() throws {
        var sawKill = false
        var sawSabotage = false
        for seed in 1 ... 6 {
            let sim = try make(seed: UInt64(seed), families: 12, werewolves: 3)
            sim.runToCompletion()
            for case let .familyKilled(_, by: killer) in sim.events.map(\.kind) where killer != nil {
                sawKill = true
            }
            for case .sabotageStarted in sim.events.map(\.kind) {
                sawSabotage = true
            }
        }
        #expect(sawKill)
        #expect(sawSabotage)
    }

    @Test func simulatedGamesAreMarkedAndNeverRestoredAsRealGames() throws {
        let sim = try make()
        sim.step(by: 5)
        let stored = try #require(try sim.repository.latest())
        #expect(stored.state.simulated)
        #expect(sim.host.state.simulated)

        let container = try ModelContainerFactory.make(inMemory: true)
        let swiftData = SwiftDataGameRepository(context: container.mainContext)
        try swiftData.save(stored)
        #expect(try swiftData.latest() == nil)
    }

    @Test func aSimulationNeverTouchesARealHost() throws {
        let real = try HostHarness()
        let before = real.host.state
        let realGameID = real.host.gameID
        let sim = try make()
        sim.runToCompletion()
        #expect(real.host.state == before)
        #expect(real.host.gameID == realGameID)
        #expect(sim.host.gameID != realGameID)
    }

    @Test func theSameSeedReplaysTheSameEventsAndADifferentSeedDoesNot() throws {
        let first = try make(seed: 42)
        first.runToCompletion()
        let second = try make(seed: 42)
        second.runToCompletion()
        #expect(first.events == second.events)
        #expect(!first.events.isEmpty)

        let other = try make(seed: 43)
        other.runToCompletion()
        #expect(other.events != first.events)
    }
}
