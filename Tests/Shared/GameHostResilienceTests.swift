import Foundation
import SwiftData
import Testing
@testable import Moonfall

@MainActor
struct GameHostResilienceTests {
    private func startEngine(_ harness: HostHarness) throws {
        var generator = SeededGenerator(seed: 5)
        let (engine, _) = try GameEngine.start(
            familyIDs: [1, 2, 3, 4], werewolfCount: 1, at: harness.clock.now, using: &generator
        )
        harness.host.replaceState { $0.engine = engine }
    }

    @Test func resumesFromPersistedStateAfterARestart() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let repository = SwiftDataGameRepository(context: container.mainContext)
        let harness = try HostHarness(repository: repository)
        let client = harness.makeClient()
        client.join(code: "AAA111", name: "Dewi")
        #expect(await eventually { client.isSignedIn })
        try startEngine(harness)
        harness.clock.advance(by: 2701)
        harness.host.tick()
        let before = harness.host.state

        let restored = try GameHost(repository: repository, clock: harness.clock)
        #expect(restored.state == before)
        #expect(restored.gameID == harness.host.gameID)
        #expect(restored.state.engine?.state.phase == before.engine?.state.phase)
        #expect(!restored.recentEvents.isEmpty)
    }

    @Test func tickPersistsEventsFromTheEngine() throws {
        let repository = InMemoryGameRepository()
        let harness = try HostHarness(repository: repository)
        try startEngine(harness)
        harness.clock.advance(by: 2701)
        harness.host.tick()
        let stored = try repository.events(for: harness.host.gameID)
        #expect(stored.contains {
            if case .votingOpened(isFinal: true) = $0.kind {
                true
            } else {
                false
            }
        })
    }

    @Test func clientsRejoinTheirFamilyAfterReconnecting() async throws {
        let harness = try HostHarness()
        let store = InMemoryIdentityStore()
        let transport = harness.hub.makeClient()
        let client = GameClient(transport: transport, store: store)
        client.start()
        client.join(code: "AAA111", name: "Dewi")
        #expect(await eventually { client.view != nil })
        let original = client.view?.identity

        transport.stop()
        #expect(await eventually { harness.host.sessions.isEmpty })
        transport.start()
        #expect(await eventually { harness.host.sessions.values.contains { $0.identity != nil } })
        #expect(await eventually { client.status == .connected && client.view?.identity == original })
        #expect(harness.host.state.players.count == 1)
    }

    @Test func unknownResumeIdentitiesAreClearedOnTheClient() async throws {
        let harness = try HostHarness()
        let store = InMemoryIdentityStore()
        store.resumeID = UUID()
        let client = harness.makeClient(store: store)
        #expect(await eventually { client.lastError == HostError.unknownDevice.message })
        #expect(store.resumeID == nil)
    }

    @Test func connectivityCheckFlagsUnreachableAndOfflineDevices() async throws {
        let harness = try HostHarness()
        let responsive = harness.makeClient()
        responsive.join(code: "AAA111", name: "Dewi")
        #expect(await eventually { responsive.isSignedIn })

        let silent = harness.hub.makeClient()
        silent.start()
        silent.send(.hello(Hello(credential: .familyCode("BBB222"), name: "Budi")))
        #expect(await eventually { harness.host.state.players.count == 2 })

        let leaver = harness.makeClient()
        leaver.join(code: "BBB222", name: "Citra")
        #expect(await eventually { harness.host.state.players.count == 3 })
        leaver.stop()
        #expect(await eventually { harness.host.sessions.count == 2 })

        harness.host.checkConnectivity()
        _ = await eventually { harness.host.sessions.values.contains { $0.lastReplyAt != nil } }
        harness.clock.advance(by: GameHost.probeTimeout + 1)
        let byName = Dictionary(uniqueKeysWithValues: harness.host.deviceStatuses().map { ($0.label, $0.connection) })
        #expect(byName["Dewi"] == .online)
        #expect(byName["Budi"] == .unreachable)
        #expect(byName["Citra"] == .offline)
    }

    @Test func clientCountdownsFollowTheHostClockNotTheLocalOne() async throws {
        let ahead = ManualHostClock(Date().addingTimeInterval(100))
        let harness = try HostHarness(clock: ahead)
        let client = harness.makeClient()
        client.join(code: "AAA111", name: "Dewi")
        #expect(await eventually { client.view != nil })
        let drift = client.serverNow.timeIntervalSince(ahead.now)
        #expect(abs(drift) < 1)
    }

    @Test func serverClockAppliesTheOffsetToAnyLocalTime() {
        var clock = ServerClock()
        let local = Date(timeIntervalSinceReferenceDate: 1000)
        clock.sync(serverTime: local.addingTimeInterval(30), receivedAt: local)
        #expect(clock.now(local: local.addingTimeInterval(5)) == local.addingTimeInterval(35))
    }
}
