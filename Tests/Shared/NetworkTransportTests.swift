import Foundation
import Testing
@testable import MurderMystery

@MainActor
struct NetworkTransportTests {
    @Test func clientJoinsOverTheRealTransportOnLoopback() async throws {
        var state = HostState(ocPin: "4242")
        state.families[1] = FamilyInfo(id: 1, name: "Family 1", joinCode: "AAA111")
        let host = try GameHost(repository: InMemoryGameRepository(), initialState: state)
        let hostTransport = NetworkHostTransport(advertise: false)
        host.attach(hostTransport)
        try await hostTransport.start()
        let port = try #require(hostTransport.port)

        let client = GameClient(
            transport: NetworkClientTransport(target: .direct(host: "127.0.0.1", port: port)),
            store: InMemoryIdentityStore()
        )
        client.start()
        defer {
            client.stop()
            host.detach()
        }
        #expect(await eventually(timeout: 5) { client.status == .connected })
        client.join(code: "AAA111", name: "Dewi")
        #expect(await eventually(timeout: 5) { client.view != nil })
        #expect(host.state.players.count == 1)
    }
}
