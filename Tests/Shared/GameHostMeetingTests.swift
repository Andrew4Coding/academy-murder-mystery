import Foundation
import Testing
@testable import MurderMystery

@MainActor
struct GameHostMeetingTests {
    private func startedGame() async throws -> (HostHarness, [FamilyID: GameClient]) {
        let (harness, heads) = try await HostHarness.seated(families: 5, werewolves: 1)
        try harness.host.startGame()
        harness.clock.advance(by: 61)
        let ready = await eventually { heads.values.allSatisfy { $0.view?.game != nil } }
        precondition(ready)
        return (harness, heads)
    }

    private func villagers(_ harness: HostHarness) -> [FamilyID] {
        harness.host.state.engine!.state.families.values.filter { $0.role == .villager }.map(\.id).sorted()
    }

    private func werewolf(_ harness: HostHarness) -> FamilyID {
        harness.host.state.engine!.state.families.values.first { $0.role == .werewolf }!.id
    }

    @Test func discussionStartsForEveryoneWithAnnouncedDeathsAndHostBasedTimers() async throws {
        let (harness, heads) = try await startedGame()
        let villagers = villagers(harness)
        try harness.host.applyAsOC(.kill(killer: werewolf(harness), victim: villagers[0]))
        try harness.host.applyAsOC(.startMeeting)
        let startedAt = harness.clock.now
        #expect(await eventually {
            heads.values.allSatisfy {
                if case let .discussion(until)? = $0.view?.game?.phase {
                    until == startedAt.addingTimeInterval(120)
                } else {
                    false
                }
            }
        })
        for client in heads.values {
            #expect(client.view?.game?.announcedDeaths.map(\.id) == [villagers[0]])
        }
    }

    @Test func votingOpensAutomaticallyAfterDiscussion() async throws {
        let (harness, heads) = try await startedGame()
        try harness.host.applyAsOC(.startMeeting)
        harness.clock.advance(by: 121)
        harness.host.tick()
        #expect(await eventually {
            heads.values.allSatisfy {
                if case .voting(_, false)? = $0.view?.game?.phase {
                    true
                } else {
                    false
                }
            }
        })
    }

    @Test func aFamilyMayChangeItsVoteUntilClose() async throws {
        let (harness, heads) = try await HostHarness.seated(families: 5, werewolves: 1)
        try harness.host.startGame()
        try harness.host.applyAsOC(.startMeeting)
        harness.clock.advance(by: 121)
        harness.host.tick()
        #expect(await eventually { heads[1]?.view?.game != nil })

        heads[1]?.send(.vote(.family(2)))
        #expect(await eventually { heads[1]!.view?.game?.myVote == .family(2) })
        heads[1]?.send(.vote(.skip))
        #expect(await eventually { heads[1]!.view?.game?.myVote == .skip })
        #expect(heads[1]?.view?.game?.votesCast == 1)
        #expect(heads[2]?.view?.game?.myVote == nil)
    }

    @Test func storedSnapshotsNeverContainWhoVotedForWhom() async throws {
        let repository = InMemoryGameRepository()
        let (harness, heads) = try await {
            let harness = try HostHarness(families: [], repository: repository)
            try harness.host.configure(familyCount: 4, werewolfCount: 1, settings: .standard)
            var heads: [FamilyID: GameClient] = [:]
            for family in harness.host.state.families.values.sorted(by: { $0.id < $1.id }) {
                let client = harness.makeClient()
                client.join(code: family.joinCode, name: "H\(family.id.rawValue)")
                _ = await eventually { client.isSignedIn }
                _ = await eventually { client.view?.lobby != nil }
                heads[family.id] = client
            }
            return (harness, heads)
        }()
        try harness.host.startGame()
        try harness.host.applyAsOC(.startMeeting)
        harness.clock.advance(by: 121)
        harness.host.tick()
        heads[1]?.send(.vote(.family(2)))
        #expect(await eventually { heads[1]!.view?.game?.myVote == .family(2) })
        let stored = try #require(try repository.latest())
        let restored = try WireCodec.decode(HostState.self, from: WireCodec.encode(stored.state))
        #expect(restored.engine?.state.votes.isEmpty == true)
        let events = try repository.events(for: harness.host.gameID)
        let json = try String(decoding: JSONEncoder().encode(events), as: UTF8.self)
        #expect(!json.contains("\"skip\"") && !json.contains("family\":{\"_0\""))
    }

    @Test func resultsAreSharedWithEveryoneAndExpelledFamiliesAreRevealed() async throws {
        let (harness, heads) = try await startedGame()
        let wolf = werewolf(harness)
        try harness.host.applyAsOC(.startMeeting)
        harness.clock.advance(by: 121)
        harness.host.tick()
        for id in villagers(harness) {
            heads[id]?.send(.vote(.family(wolf)))
        }
        heads[wolf]?.send(.vote(.skip))
        #expect(await eventually {
            heads.values.allSatisfy { $0.view?.game?.lastResult != nil }
        })
        let result = try #require(heads[1]?.view?.game?.lastResult)
        #expect(result.expelled.map(\.role) == [.werewolf])
        #expect(result.rows.first { !$0.isSkip }?.count == 4)
        #expect(result.rows.first { $0.isSkip }?.count == 1)
        #expect(heads[wolf]?.view?.game?.life == .expelled)
    }

    @Test func theFinalVoteAlertsEveryDeviceAtTheGameLimit() async throws {
        let (harness, heads) = try await startedGame()
        harness.clock.advance(by: 2700)
        harness.host.tick()
        #expect(await eventually {
            heads.values.allSatisfy {
                if case .voting(_, true)? = $0.view?.game?.phase {
                    true
                } else {
                    false
                }
            }
        })
    }
}
