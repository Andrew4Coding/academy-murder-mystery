import Foundation

@MainActor
final class LoopbackHub {
    let host = LoopbackHostTransport()

    func makeClient() -> LoopbackClientTransport {
        LoopbackClientTransport(hub: self)
    }
}

@MainActor
final class LoopbackHostTransport: HostTransport {
    let events: AsyncStream<HostTransportEvent>
    fileprivate let continuation: AsyncStream<HostTransportEvent>.Continuation
    fileprivate var clients: [ClientID: LoopbackClientTransport] = [:]

    init() {
        (events, continuation) = AsyncStream.makeStream(of: HostTransportEvent.self)
    }

    func start() async throws {}

    func stop() {
        for (id, client) in clients {
            client.hostDropped()
            continuation.yield(.disconnected(id))
        }
        clients = [:]
    }

    func send(_ message: ServerMessage, to client: ClientID) {
        guard let data = try? WireCodec.encode(message), let decoded = try? WireCodec.decode(ServerMessage.self, from: data) else { return }
        clients[client]?.deliver(decoded)
    }

    func disconnect(_ client: ClientID) {
        clients[client]?.hostDropped()
        clients[client] = nil
        continuation.yield(.disconnected(client))
    }
}

@MainActor
final class LoopbackClientTransport: ClientTransport {
    let events: AsyncStream<ClientTransportEvent>
    private let continuation: AsyncStream<ClientTransportEvent>.Continuation
    private let hub: LoopbackHub
    private var id: ClientID?

    init(hub: LoopbackHub) {
        self.hub = hub
        (events, continuation) = AsyncStream.makeStream(of: ClientTransportEvent.self)
    }

    func start() {
        guard id == nil else { return }
        let id = ClientID()
        self.id = id
        hub.host.clients[id] = self
        hub.host.continuation.yield(.connected(id))
        continuation.yield(.status(.connected))
    }

    func stop() {
        guard let id else { return }
        hub.host.clients[id] = nil
        hub.host.continuation.yield(.disconnected(id))
        self.id = nil
        continuation.yield(.status(.idle))
    }

    func send(_ message: ClientMessage) {
        guard let id, let data = try? WireCodec.encode(message), let decoded = try? WireCodec.decode(ClientMessage.self, from: data) else { return }
        hub.host.continuation.yield(.message(id, decoded))
    }

    fileprivate func deliver(_ message: ServerMessage) {
        continuation.yield(.message(message))
    }

    fileprivate func hostDropped() {
        id = nil
        continuation.yield(.status(.idle))
    }
}
