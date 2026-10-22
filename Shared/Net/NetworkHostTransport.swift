import Foundation
import Network

@MainActor
final class NetworkHostTransport: HostTransport {
    static let serviceType = "_murdermystery._tcp"

    let events: AsyncStream<HostTransportEvent>
    private let continuation: AsyncStream<HostTransportEvent>.Continuation
    private let advertise: Bool
    private var listener: NWListener?
    private var connections: [ClientID: NWConnection] = [:]
    private(set) var port: UInt16?

    init(advertise: Bool = true) {
        self.advertise = advertise
        (events, continuation) = AsyncStream.makeStream(of: HostTransportEvent.self)
    }

    func start() async throws {
        let listener = try NWListener(using: .murderMystery())
        if advertise {
            listener.service = NWListener.Service(type: Self.serviceType)
        }
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accept(connection) }
        }
        self.listener = listener
        let gate = ResumeGate()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            listener.stateUpdateHandler = { [weak self] state in
                MainActor.assumeIsolated {
                    switch state {
                    case .ready:
                        self?.port = listener.port?.rawValue
                        if gate.claim() {
                            continuation.resume()
                        }
                    case let .failed(error):
                        if gate.claim() {
                            continuation.resume(throwing: error)
                        }
                    default:
                        break
                    }
                }
            }
            listener.start(queue: .main)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for connection in connections.values {
            connection.cancel()
        }
    }

    func send(_ message: ServerMessage, to client: ClientID) {
        guard let connection = connections[client], let data = try? WireCodec.encode(message) else { return }
        connection.sendFramed(data)
    }

    func disconnect(_ client: ClientID) {
        connections[client]?.cancel()
    }

    private func accept(_ connection: NWConnection) {
        let id = ClientID()
        connections[id] = connection
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.stateChanged(id, state) }
        }
        connection.start(queue: .main)
    }

    private func stateChanged(_ id: ClientID, _ state: NWConnection.State) {
        switch state {
        case .ready:
            continuation.yield(.connected(id))
            if let connection = connections[id] {
                receive(id, on: connection)
            }
        case .failed, .cancelled:
            if connections.removeValue(forKey: id) != nil {
                continuation.yield(.disconnected(id))
            }
        default:
            break
        }
    }

    private func receive(_ id: ClientID, on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            MainActor.assumeIsolated { self?.received(id, on: connection, data: data, failed: error != nil) }
        }
    }

    private func received(_ id: ClientID, on connection: NWConnection, data: Data?, failed: Bool) {
        if let data, let message = try? WireCodec.decode(ClientMessage.self, from: data) {
            continuation.yield(.message(id, message))
        }
        if failed {
            connection.cancel()
        } else {
            receive(id, on: connection)
        }
    }
}

@MainActor
final class ResumeGate {
    private var claimed = false

    func claim() -> Bool {
        defer { claimed = true }
        return !claimed
    }
}
