import Foundation
import Synchronization
import Testing
@testable import Moonfall

final class FakeSocket: WebSocketConnection {
    private let sentFrames = Mutex<[Data]>([])
    private let incoming: AsyncStream<Data>
    private let incomingContinuation: AsyncStream<Data>.Continuation
    private let failOpen: Bool
    private let closed = Mutex(false)

    init(failOpen: Bool = false) {
        self.failOpen = failOpen
        (incoming, incomingContinuation) = AsyncStream.makeStream(of: Data.self)
    }

    var sent: [Data] {
        sentFrames.withLock { $0 }
    }

    var isClosed: Bool {
        closed.withLock { $0 }
    }

    func waitUntilOpen() async throws {
        if failOpen {
            throw URLError(.cannotConnectToHost)
        }
    }

    func send(_ data: Data) async throws {
        sentFrames.withLock { $0.append(data) }
    }

    func receive() async throws -> Data {
        for await data in incoming {
            return data
        }
        throw URLError(.networkConnectionLost)
    }

    func close() {
        closed.withLock { $0 = true }
        incomingContinuation.finish()
    }

    func deliver(_ message: ServerMessage) {
        if let data = try? WireCodec.encode(message) {
            incomingContinuation.yield(data)
        }
    }

    func drop() {
        incomingContinuation.finish()
    }
}

final class FakeConnector: WebSocketConnecting {
    private let queue = Mutex<[FakeSocket]>([])
    private let opened = Mutex<[FakeSocket]>([])

    init(_ sockets: [FakeSocket]) {
        queue.withLock { $0 = sockets }
    }

    var sockets: [FakeSocket] {
        opened.withLock { $0 }
    }

    func open(_: URL) -> any WebSocketConnection {
        let socket = queue.withLock { $0.isEmpty ? FakeSocket() : $0.removeFirst() }
        opened.withLock { $0.append(socket) }
        return socket
    }
}

@MainActor
struct WebSocketClientTransportTests {
    private let url = URL(string: "wss://example.test/ws")!

    @Test func sendsOneJSONMessagePerFrameAndDecodesIncoming() async throws {
        let socket = FakeSocket()
        let transport = WebSocketClientTransport(url: url, connector: FakeConnector([socket]))
        var received: [ClientTransportEvent] = []
        let reader = Task {
            for await event in transport.events {
                received.append(event)
            }
        }
        defer { reader.cancel() }
        transport.start()
        #expect(await eventually { received.contains {
            if case .status(.connected) = $0 {
                true
            } else {
                false
            }
        } })

        transport.send(.sync)
        #expect(await eventually { socket.sent.count == 1 })
        #expect(try WireCodec.decode(ClientMessage.self, from: socket.sent[0]) == .sync)

        socket.deliver(.rejected("nope"))
        #expect(await eventually { received.contains {
            if case .message(.rejected("nope")) = $0 {
                true
            } else {
                false
            }
        } })
        transport.stop()
    }

    @Test func reconnectsAfterTheConnectionIsLost() async {
        let first = FakeSocket()
        let second = FakeSocket()
        let connector = FakeConnector([first, second])
        let transport = WebSocketClientTransport(url: url, connector: connector, retryDelay: .milliseconds(10))
        var statuses: [ConnectionStatus] = []
        let reader = Task {
            for await event in transport.events {
                if case let .status(status) = event {
                    statuses.append(status)
                }
            }
        }
        defer { reader.cancel() }
        transport.start()
        #expect(await eventually { statuses.last == .connected })
        first.drop()
        #expect(await eventually { connector.sockets.count == 2 && statuses.last == .connected })
        #expect(statuses.contains {
            if case .failed = $0 {
                true
            } else {
                false
            }
        })
        #expect(first.isClosed)
        transport.stop()
    }

    @Test func reportsFailureWhenTheHandshakeFails() async {
        let transport = WebSocketClientTransport(url: url, connector: FakeConnector([FakeSocket(failOpen: true)]), retryDelay: .seconds(60))
        var statuses: [ConnectionStatus] = []
        let reader = Task {
            for await event in transport.events {
                if case let .status(status) = event {
                    statuses.append(status)
                }
            }
        }
        defer { reader.cancel() }
        transport.start()
        #expect(await eventually { statuses.contains {
            if case .failed = $0 {
                true
            } else {
                false
            }
        } })
        transport.stop()
    }
}
