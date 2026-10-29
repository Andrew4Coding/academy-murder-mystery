import Foundation
import Network

@MainActor
final class NetworkClientTransport: ClientTransport {
    enum Target: Sendable {
        case discover
        case direct(host: String, port: UInt16)
    }

    let events: AsyncStream<ClientTransportEvent>
    private let continuation: AsyncStream<ClientTransportEvent>.Continuation
    private let target: Target
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var running = false
    private var retry: Task<Void, Never>?

    init(target: Target = .discover) {
        self.target = target
        (events, continuation) = AsyncStream.makeStream(of: ClientTransportEvent.self)
    }

    func start() {
        guard !running else { return }
        running = true
        begin()
    }

    func stop() {
        running = false
        retry?.cancel()
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        continuation.yield(.status(.idle))
    }

    func send(_ message: ClientMessage) {
        guard let connection, let data = try? WireCodec.encode(message) else { return }
        connection.sendFramed(data)
    }

    private func begin() {
        switch target {
        case let .direct(host, port):
            guard let port = NWEndpoint.Port(rawValue: port) else { return }
            connect(to: .hostPort(host: NWEndpoint.Host(host), port: port))
        case .discover:
            continuation.yield(.status(.searching))
            let browser = NWBrowser(for: .bonjour(type: NetworkHostTransport.serviceType, domain: nil), using: .moonfall())
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                MainActor.assumeIsolated { self?.found(results.first?.endpoint) }
            }
            browser.stateUpdateHandler = { [weak self] state in
                MainActor.assumeIsolated { self?.browserChanged(state) }
            }
            self.browser = browser
            browser.start(queue: .main)
        }
    }

    private func connect(to endpoint: NWEndpoint) {
        continuation.yield(.status(.connecting))
        let connection = NWConnection(to: endpoint, using: .moonfall())
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.stateChanged(state, of: connection) }
        }
        connection.start(queue: .main)
    }

    private func stateChanged(_ state: NWConnection.State, of connection: NWConnection) {
        guard connection === self.connection else { return }
        switch state {
        case .ready:
            continuation.yield(.status(.connected))
            receive(on: connection)
        case let .failed(error):
            lost(reason: error.localizedDescription)
        case .cancelled:
            lost(reason: nil)
        default:
            break
        }
    }

    private func lost(reason: String?) {
        connection?.cancel()
        connection = nil
        guard running else { return }
        continuation.yield(.status(reason.map { .failed($0) } ?? .searching))
        retry?.cancel()
        retry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self, running else { return }
            if case .discover = target {
                browser?.cancel(); browser = nil
            }
            begin()
        }
    }

    private func found(_ endpoint: NWEndpoint?) {
        guard connection == nil, let endpoint else { return }
        connect(to: endpoint)
    }

    private func browserChanged(_ state: NWBrowser.State) {
        if case let .failed(error) = state {
            continuation.yield(.status(.failed(error.localizedDescription)))
        }
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            MainActor.assumeIsolated { self?.received(on: connection, data: data, failed: error != nil) }
        }
    }

    private func received(on connection: NWConnection, data: Data?, failed: Bool) {
        guard connection === self.connection else { return }
        if let data, let message = try? WireCodec.decode(ServerMessage.self, from: data) {
            continuation.yield(.message(message))
        }
        if failed {
            connection.cancel()
        } else {
            receive(on: connection)
        }
    }
}
