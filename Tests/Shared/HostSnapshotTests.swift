import Foundation
import Testing
@testable import Moonfall

@MainActor
struct HostSnapshotTests {
    // swiftlint:disable:next large_tuple
    private func lobbyWithPlayer() async throws -> (HostHarness, GameClient, InMemoryIdentityStore) {
        let harness = try HostHarness()
        let store = InMemoryIdentityStore()
        let client = harness.makeClient(store: store)
        client.join(code: "AAA111", name: "Dewi")
        #expect(await eventually { client.view?.lobby != nil })
        client.send(.selfie(Data([1, 2, 3])))
        #expect(await eventually { !harness.host.selfies.isEmpty })
        try harness.host.setBoothMap(imageData: Self.pngData())
        return (harness, client, store)
    }

    static func pngData() -> Data {
        let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        return Data(base64Encoded: png)!
    }

    @Test func roundTripsThroughJSONWithSelfiesAndMap() async throws {
        let (harness, client, _) = try await lobbyWithPlayer()
        client.stop()
        harness.host.detach()
        let snapshot = harness.host.exportSnapshot()
        #expect(snapshot.selfies.count == 1)
        #expect(snapshot.boothMap != nil)

        let decoded = try WireCodec.decode(HostSnapshot.self, from: WireCodec.encode(snapshot))
        #expect(decoded == snapshot)
    }

    @Test func importRestoresStateSelfiesAndMapOnAnotherHost() async throws {
        let (harness, client, _) = try await lobbyWithPlayer()
        client.stop()
        harness.host.detach()
        let snapshot = harness.host.exportSnapshot()

        let other = try GameHost(repository: InMemoryGameRepository())
        try other.importSnapshot(snapshot)
        #expect(other.state == harness.host.state)
        #expect(other.selfies == harness.host.selfies)
        #expect(other.boothMap == harness.host.boothMap)
        #expect(other.boothMapStore.load() == snapshot.boothMap)
    }

    @Test func phonesResumeWithTheSameIDAfterAnImport() async throws {
        let (harness, client, store) = try await lobbyWithPlayer()
        let resumeID = try #require(store.resumeID)
        let original = client.view?.identity
        client.stop()
        harness.host.detach()
        let snapshot = harness.host.exportSnapshot()

        let other = try GameHost(repository: InMemoryGameRepository())
        let hub = LoopbackHub()
        try other.importSnapshot(snapshot)
        other.attach(hub.host)
        let resumed = GameClient(transport: hub.makeClient(), store: store)
        resumed.start()
        #expect(await eventually { resumed.isSignedIn && resumed.view != nil })
        #expect(store.resumeID == resumeID)
        #expect(resumed.view?.identity == original)
        #expect(resumed.selfies.count == 1)
        other.detach()
    }

    @Test func importIsRefusedWhileClientsAreSignedIn() async throws {
        let (harness, client, _) = try await lobbyWithPlayer()
        defer { client.stop() }
        #expect(throws: HostError.snapshotBusy) {
            try harness.host.importSnapshot(harness.host.exportSnapshot())
        }
    }

    @Test func commitsNotifyTheHook() throws {
        let harness = try HostHarness()
        var count = 0
        harness.host.onCommit = { count += 1 }
        harness.host.commit()
        #expect(count == 1)
    }
}
