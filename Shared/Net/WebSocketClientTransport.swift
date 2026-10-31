import Foundation

protocol WebSocketConnection: AnyObject, Sendable {
    func waitUntilOpen() async throws
    func send(_ data: Data) async throws
    func receive() async throws -> Data
    func close()
}

protocol WebSocketConnecting: Sendable {
    func open(_ url: URL) -> any WebSocketConnection
}

struct URLSessionWebSocketConnector: WebSocketConnecting {
    func open(_ url: URL) -> any WebSocketConnection {
        URLSessionWebSocketConnection(url: url)
    }
}

final class URLSessionWebSocketConnection: WebSocketConnection {
    private let session: URLSession
    private let task: URLSessionWebSocketTask

    init(url: URL) {
        session = URLSession(configuration: .default)
        task = session.webSocketTask(with: url)
        task.resume()
    }

    /// A ping only completes once the handshake is done, so it doubles as the "connected" signal without a delegate.
    func waitUntilOpen() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            task.sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func send(_ data: Data) async throws {
        try await task.send(.string(String(bytes: data, encoding: .utf8) ?? ""))
    }

    func receive() async throws -> Data {
        switch try await task.receive() {
        case let .string(text): Data(text.utf8)
        case let .data(data): data
        @unknown default: Data()
        }
    }

    func close() {
        task.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
    }
}

@MainActor
final class WebSocketClientTransport: ClientTransport {
    let events: AsyncStream<ClientTransportEvent>
    private let continuation: AsyncStream<ClientTransportEvent>.Continuation
    private let url: URL
    private let connector: any WebSocketConnecting
    private let retryDelay: Duration
    private var running = false
    private var connection: (any WebSocketConnection)?
    private var outbox: AsyncStream<Data>.Continuation?
    private var session: Task<Void, Never>?
    private var retry: Task<Void, Never>?
    private var generation = 0

    init(url: URL, connector: any WebSocketConnecting = URLSessionWebSocketConnector(), retryDelay: Duration = .milliseconds(500)) {
        self.url = url
        self.connector = connector
        self.retryDelay = retryDelay
        (events, continuation) = AsyncStream.makeStream(of: ClientTransportEvent.self)
    }

    func start() {
        guard !running else { return }
        running = true
        connect()
    }

    func stop() {
        running = false
        retry?.cancel()
        teardown()
        continuation.yield(.status(.idle))
    }

    func send(_ message: ClientMessage) {
        guard let data = try? WireCodec.encode(message) else { return }
        outbox?.yield(data)
    }

    func reconnect() {
        guard running else { return }
        retry?.cancel()
        teardown()
        connect()
    }

    private func teardown() {
        generation += 1
        session?.cancel()
        session = nil
        outbox?.finish()
        outbox = nil
        connection?.close()
        connection = nil
    }

    private func connect() {
        continuation.yield(.status(.connecting))
        generation += 1
        let mine = generation
        let connection = connector.open(url)
        self.connection = connection
        let (stream, outbox) = AsyncStream.makeStream(of: Data.self)
        self.outbox = outbox
        session = Task { [weak self] in
            do {
                try await connection.waitUntilOpen()
                guard let self, accept(mine) else { return }
                continuation.yield(.status(.connected))
                let writer = Task {
                    for await data in stream {
                        try? await connection.send(data)
                    }
                }
                defer { writer.cancel() }
                while !Task.isCancelled {
                    let data = try await connection.receive()
                    guard accept(mine) else { return }
                    if let message = try? WireCodec.decode(ServerMessage.self, from: data) {
                        continuation.yield(.message(message))
                    }
                }
            } catch {
                self?.lost(mine, reason: error.localizedDescription)
            }
        }
    }

    private func accept(_ mine: Int) -> Bool {
        running && mine == generation
    }

    private func lost(_ mine: Int, reason: String) {
        guard accept(mine) else { return }
        teardown()
        continuation.yield(.status(.failed(reason)))
        retry?.cancel()
        retry = Task { [weak self, retryDelay] in
            try? await Task.sleep(for: retryDelay)
            guard !Task.isCancelled, let self, running else { return }
            connect()
        }
    }
}
