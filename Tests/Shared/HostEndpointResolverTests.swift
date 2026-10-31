import Foundation
import Testing
@testable import Moonfall

@MainActor
struct HostEndpointResolverTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "resolver-\(UUID().uuidString)")!
    }

    @Test func cloudRegistryResolvesToCloudAndIsRemembered() async {
        let registry = FakeRegistry()
        registry.mode = .cloud
        let defaults = makeDefaults()
        let resolver = HostEndpointResolver(registry: registry, defaults: defaults)
        #expect(resolver.lastKnown == nil)
        #expect(await resolver.resolve() == .cloud)
        #expect(resolver.lastKnown == .cloud)
    }

    @Test func localRegistryResolvesToSelfHost() async {
        let registry = FakeRegistry()
        let resolver = HostEndpointResolver(registry: registry, defaults: makeDefaults())
        #expect(await resolver.resolve() == .selfHost)
    }

    @Test func unreachableRegistryFallsBackToBonjour() async {
        let registry = FakeRegistry()
        registry.mode = .cloud
        registry.reachable = false
        let resolver = HostEndpointResolver(registry: registry, defaults: makeDefaults())
        #expect(await resolver.resolve() == .selfHost)
    }

    @Test func adaptiveTransportPicksTheTransportTheRegistryNames() async {
        let registry = FakeRegistry()
        registry.mode = .cloud
        let hub = LoopbackHub()
        var madeCloud = 0
        var madeLocal = 0
        let transport = AdaptiveClientTransport(
            resolver: HostEndpointResolver(registry: registry, defaults: makeDefaults()),
            recheckInterval: .milliseconds(20),
            makeCloud: { madeCloud += 1; return hub.makeClient() },
            makeLocal: { madeLocal += 1; return hub.makeClient() }
        )
        transport.start()
        #expect(await eventually { transport.activeMode == .cloud })
        #expect(madeCloud == 1 && madeLocal == 0)
        transport.stop()
    }

    @Test func adaptiveTransportFollowsARegistryFlipWhileDisconnected() async {
        let registry = FakeRegistry()
        var transports: [HostMode] = []
        let transport = AdaptiveClientTransport(
            resolver: HostEndpointResolver(registry: registry, defaults: makeDefaults()),
            recheckInterval: .milliseconds(20),
            makeCloud: { transports.append(.cloud); return StalledTransport() },
            makeLocal: { transports.append(.selfHost); return StalledTransport() }
        )
        transport.start()
        #expect(await eventually { transport.activeMode == .selfHost })
        registry.mode = .cloud
        #expect(await eventually { transport.activeMode == .cloud })
        #expect(transports == [.selfHost, .cloud])
        transport.stop()
    }
}

@MainActor
final class StalledTransport: ClientTransport {
    let events: AsyncStream<ClientTransportEvent>
    private let continuation: AsyncStream<ClientTransportEvent>.Continuation

    init() {
        (events, continuation) = AsyncStream.makeStream(of: ClientTransportEvent.self)
    }

    func start() {
        continuation.yield(.status(.searching))
    }

    func stop() {
        continuation.finish()
    }

    func send(_: ClientMessage) {}
}
