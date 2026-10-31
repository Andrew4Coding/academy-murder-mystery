import Foundation
import Testing
@testable import Moonfall

@MainActor
struct SnapshotUploaderTests {
    @Test func uploadsASnapshotAfterACommitWhenEnabled() async throws {
        let harness = try HostHarness()
        let registry = FakeRegistry()
        let uploader = SnapshotUploader(host: harness.host, registry: registry)
        uploader.isEnabled = true
        await uploader.waitUntilIdle()
        harness.host.replaceState { $0.families[1]?.name = "Changed" }
        await uploader.waitUntilIdle()
        #expect(registry.stored?.state.families[1]?.name == "Changed")
        #expect(uploader.lastUploadedAt != nil)
        #expect(registry.mode == .selfHost)
    }

    @Test func doesNothingWhileDisabled() async throws {
        let harness = try HostHarness()
        let registry = FakeRegistry()
        let uploader = SnapshotUploader(host: harness.host, registry: registry)
        harness.host.commit()
        await uploader.waitUntilIdle()
        #expect(registry.stored == nil)
        #expect(uploader.status == .idle)
    }

    @Test func coalescesBurstsWithAtMostOneUploadInFlight() async throws {
        let harness = try HostHarness()
        let registry = FakeRegistry()
        registry.putDelay = .milliseconds(40)
        let uploader = SnapshotUploader(host: harness.host, registry: registry)
        uploader.isEnabled = true
        await uploader.waitUntilIdle()
        let before = registry.calls.filter { $0 == "putSnapshot" }.count
        for index in 0 ..< 10 {
            harness.host.replaceState { $0.families[1]?.name = "Name \(index)" }
        }
        await uploader.waitUntilIdle()
        let puts = registry.calls.filter { $0 == "putSnapshot" }.count - before
        #expect(puts >= 1 && puts <= 2)
        #expect(registry.stored?.state.families[1]?.name == "Name 9")
    }

    @Test func failuresAreSilentButSurfacedAsStatus() async throws {
        let harness = try HostHarness()
        let registry = FakeRegistry()
        registry.reachable = false
        let uploader = SnapshotUploader(host: harness.host, registry: registry)
        uploader.isEnabled = true
        harness.host.commit()
        await uploader.waitUntilIdle()
        if case .failed = uploader.status {} else {
            Issue.record("expected failed, got \(uploader.status)")
        }

        registry.reachable = true
        harness.host.commit()
        await uploader.waitUntilIdle()
        #expect(uploader.lastUploadedAt != nil)
    }

    @Test func stopsRetryingAfterARefusedCredentialUntilResumed() async throws {
        let harness = try HostHarness()
        let registry = FakeRegistry()
        registry.rejection = .unauthorized
        let uploader = SnapshotUploader(host: harness.host, registry: registry)
        uploader.isEnabled = true
        await uploader.waitUntilIdle()
        let attempts = registry.calls.filter { $0 == "putSnapshot" }.count
        for _ in 0 ..< 3 {
            harness.host.commit()
            await uploader.waitUntilIdle()
        }
        #expect(registry.calls.filter { $0 == "putSnapshot" }.count == attempts)

        registry.rejection = nil
        uploader.resume()
        await uploader.waitUntilIdle()
        #expect(uploader.lastUploadedAt != nil)
    }

    @Test func neverUploadsSimulatedGames() async throws {
        let harness = try HostHarness()
        let registry = FakeRegistry()
        let uploader = SnapshotUploader(host: harness.host, registry: registry)
        harness.host.replaceState { $0.simulated = true }
        uploader.isEnabled = true
        harness.host.commit()
        await uploader.waitUntilIdle()
        #expect(registry.stored == nil)
    }

    @Test func clientKeepsTheLatestDisplayStateFromTheServer() async {
        let transport = ScriptedTransport()
        let client = GameClient(transport: transport, store: InMemoryIdentityStore())
        client.start()
        let display = PublicDisplayState(screen: .waiting, familiesRemaining: nil, alarm: nil, announcedDeaths: [], joinCode: "ABC123")
        transport.deliver(.display(display))
        #expect(await eventually { client.display == display })
        client.stop()
    }
}

@MainActor
final class ScriptedTransport: ClientTransport {
    let events: AsyncStream<ClientTransportEvent>
    private let continuation: AsyncStream<ClientTransportEvent>.Continuation

    init() {
        (events, continuation) = AsyncStream.makeStream(of: ClientTransportEvent.self)
    }

    func start() {
        continuation.yield(.status(.connected))
    }

    func stop() {}

    func send(_: ClientMessage) {}

    func deliver(_ message: ServerMessage) {
        continuation.yield(.message(message))
    }
}
