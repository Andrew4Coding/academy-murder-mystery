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
    private var watchdog: Task<Void, Never>?
    private var cachedEndpoint: NWEndpoint?
    private var triedCache = false

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
        watchdog?.cancel()
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
            if let cachedEndpoint, !triedCache {
                triedCache = true
                connect(to: cachedEndpoint)
                return
            }
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
            watch(after: Self.searchTimeout)
        }
    }

    private static let searchTimeout: Duration = .seconds(6)
    private static let connectTimeout: Duration = .seconds(8)

    // A browser can sit "ready" with no results, and a connection can sit in .waiting, on some phones; restart both instead of staying stuck.
    private func watch(after delay: Duration) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, running else { return }
            if let connection {
                guard connection.state != .ready else { return }
                connection.cancel()
            } else {
                browser?.cancel()
                browser = nil
                begin()
            }
        }
    }

    private func connect(to endpoint: NWEndpoint) {
        continuation.yield(.status(.connecting))
        let connection = NWConnection(to: endpoint, using: .moonfall())
        self.connection = connection
        watch(after: Self.connectTimeout)
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.stateChanged(state, of: connection) }
        }
        connection.start(queue: .main)
    }

    private func stateChanged(_ state: NWConnection.State, of connection: NWConnection) {
        guard connection === self.connection else { return }
        switch state {
        case .ready:
            triedCache = false
            cachedEndpoint = connection.endpoint
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

    func reconnect() {
        guard running, connection != nil else { return }
        connection?.cancel()
    }

    private func lost(reason: String?) {
        connection?.cancel()
        connection = nil
        if triedCache {
            cachedEndpoint = nil
            triedCache = false
        }
        guard running else { return }
        continuation.yield(.status(reason.map { .failed($0) } ?? .searching))
        retry?.cancel()
        retry = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
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
        switch state {
        case let .failed(error):
            continuation.yield(.status(.failed(error.localizedDescription)))
        case .waiting:
            continuation.yield(.status(.failed("Can't search the network. Allow Local Network access for Moonfall in Settings and join the event Wi-Fi.")))
        case .ready:
            if connection == nil { continuation.yield(.status(.searching)) }
        default:
            break
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
