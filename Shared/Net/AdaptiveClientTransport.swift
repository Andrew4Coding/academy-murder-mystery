import Foundation

@MainActor
final class AdaptiveClientTransport: ClientTransport {
    let events: AsyncStream<ClientTransportEvent>
    private let continuation: AsyncStream<ClientTransportEvent>.Continuation
    private let resolver: HostEndpointResolver
    private let makeCloud: @MainActor () -> any ClientTransport
    private let makeLocal: @MainActor () -> any ClientTransport
    private let recheckInterval: Duration
    private var running = false
    private var inner: (transport: any ClientTransport, mode: HostMode)?
    private var forward: Task<Void, Never>?
    private var watcher: Task<Void, Never>?
    private var innerStatus: ConnectionStatus = .idle
    private var resolving = false

    init(
        resolver: HostEndpointResolver,
        recheckInterval: Duration = .seconds(5),
        makeCloud: @escaping @MainActor () -> any ClientTransport = { WebSocketClientTransport(url: CloudConfig.socketURL) },
        makeLocal: @escaping @MainActor () -> any ClientTransport = { NetworkClientTransport() }
    ) {
        self.resolver = resolver
        self.recheckInterval = recheckInterval
        self.makeCloud = makeCloud
        self.makeLocal = makeLocal
        (events, continuation) = AsyncStream.makeStream(of: ClientTransportEvent.self)
    }

    static func live() -> AdaptiveClientTransport {
        AdaptiveClientTransport(resolver: HostEndpointResolver(registry: HostRegistryClient.live()))
    }

    var activeMode: HostMode? {
        inner?.mode
    }

    func start() {
        guard !running else { return }
        running = true
        continuation.yield(.status(.searching))
        Task { await refresh() }
        watcher = Task { [weak self, recheckInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: recheckInterval)
                guard let self, running, innerStatus != .connected else { continue }
                await refresh()
            }
        }
    }

    func stop() {
        running = false
        watcher?.cancel()
        watcher = nil
        dropInner()
        continuation.yield(.status(.idle))
    }

    func send(_ message: ClientMessage) {
        inner?.transport.send(message)
    }

    func reconnect() {
        guard running else { return }
        if let transport = inner?.transport {
            transport.reconnect()
        }
        Task { await refresh() }
    }

    private func refresh() async {
        guard running, !resolving else { return }
        resolving = true
        let mode = await resolver.resolve()
        resolving = false
        guard running, inner?.mode != mode else { return }
        adopt(mode)
    }

    private func adopt(_ mode: HostMode) {
        dropInner()
        let transport = switch mode {
        case .cloud: makeCloud()
        case .selfHost: makeLocal()
        }
        inner = (transport, mode)
        innerStatus = .idle
        forward = Task { [weak self] in
            for await event in transport.events {
                guard let self else { return }
                if case let .status(status) = event {
                    innerStatus = status
                }
                continuation.yield(event)
            }
        }
        transport.start()
    }

    private func dropInner() {
        forward?.cancel()
        forward = nil
        inner?.transport.stop()
        inner = nil
        innerStatus = .idle
    }
}
