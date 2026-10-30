import Foundation

enum HostTransportEvent: Sendable {
    case connected(ClientID)
    case message(ClientID, ClientMessage)
    case disconnected(ClientID)
}

enum ConnectionStatus: Equatable, Sendable {
    case idle
    case searching
    case connecting
    case connected
    case failed(String)
}

enum ClientTransportEvent: Sendable {
    case status(ConnectionStatus)
    case message(ServerMessage)
}

@MainActor
protocol HostTransport: AnyObject {
    var events: AsyncStream<HostTransportEvent> { get }
    func start() async throws
    func stop()
    func send(_ message: ServerMessage, to client: ClientID)
    func disconnect(_ client: ClientID)
}

@MainActor
protocol ClientTransport: AnyObject {
    var events: AsyncStream<ClientTransportEvent> { get }
    func start()
    func stop()
    func send(_ message: ClientMessage)
    func reconnect()
}

extension ClientTransport {
    func reconnect() {}
}
