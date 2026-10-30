import Foundation
import Observation

protocol IdentityStore: AnyObject {
    var resumeID: UUID? { get set }
}

final class UserDefaultsIdentityStore: IdentityStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "resumeID") {
        self.defaults = defaults
        self.key = key
    }

    var resumeID: UUID? {
        get { defaults.string(forKey: key).flatMap(UUID.init(uuidString:)) }
        set { defaults.set(newValue?.uuidString, forKey: key) }
    }
}

final class InMemoryIdentityStore: IdentityStore {
    var resumeID: UUID?
}

@MainActor @Observable
final class GameClient {
    private(set) var status: ConnectionStatus = .idle
    private(set) var view: ClientView?
    private(set) var lastError: String?
    private(set) var isSignedIn = false
    private(set) var isResuming = false
    private(set) var serverClock = ServerClock()
    private(set) var selfies: [PlayerID: Data] = [:]
    private(set) var boothMap: BoothMap?

    @ObservationIgnored private let transport: any ClientTransport
    @ObservationIgnored private let store: any IdentityStore
    @ObservationIgnored private var pendingHello: Hello?
    @ObservationIgnored private var pump: Task<Void, Never>?
    @ObservationIgnored private var heartbeat: Task<Void, Never>?
    @ObservationIgnored private var lastHeard = Date()
    @ObservationIgnored private var queuedKill: (message: ClientMessage, at: Date)?

    init(transport: any ClientTransport, store: any IdentityStore) {
        self.transport = transport
        self.store = store
        isResuming = store.resumeID != nil
    }

    var serverNow: Date {
        serverClock.now()
    }

    func start() {
        guard pump == nil else { return }
        pump?.cancel()
        pump = Task { [weak self, transport] in
            for await event in transport.events {
                guard let self else { return }
                handle(event)
            }
        }
        transport.start()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.heartbeatInterval))
                self?.beat()
            }
        }
    }

    private static let heartbeatInterval: TimeInterval = 4
    private static let silenceLimit: TimeInterval = 12

    private func beat() {
        guard isSignedIn else { return }
        if Date().timeIntervalSince(lastHeard) > Self.silenceLimit {
            transport.reconnect()
        } else {
            transport.send(.sync)
        }
    }

    func refresh() {
        lastError = nil
        if isSignedIn {
            transport.send(.sync)
        } else {
            transport.reconnect()
        }
    }

    func clearError() {
        lastError = nil
    }

    func stop() {
        pump?.cancel()
        pump = nil
        heartbeat?.cancel()
        heartbeat = nil
        transport.stop()
    }

    func join(code: String, name: String) {
        signIn(Hello(credential: .familyCode(code), name: name))
    }

    func signInAsOC(pin: String, station: OCStation) {
        signIn(Hello(credential: .ocPin(pin), station: station))
    }

    func send(_ message: ClientMessage) {
        guard isSignedIn else {
            if case .kill = message {
                queuedKill = (message, Date())
            }
            return
        }
        transport.send(message)
    }

    func leave() {
        send(.leave)
        signOut()
    }

    func signOut() {
        store.resumeID = nil
        view = nil
        isSignedIn = false
        isResuming = false
        pendingHello = nil
        lastError = nil
        selfies = [:]
        boothMap = nil
    }

    private func signIn(_ hello: Hello) {
        lastError = nil
        pendingHello = hello
        if status == .connected {
            transport.send(.hello(withMapHash(hello)))
        }
    }

    private func handle(_ event: ClientTransportEvent) {
        switch event {
        case let .status(newStatus):
            status = newStatus
            if newStatus == .connected {
                lastHeard = Date()
                announce()
            } else {
                isSignedIn = false
            }
        case let .message(message):
            handle(message)
        }
    }

    private func flushQueuedKill() {
        guard let queued = queuedKill else { return }
        queuedKill = nil
        if Date().timeIntervalSince(queued.at) < 10 {
            transport.send(queued.message)
        }
    }

    private func withMapHash(_ hello: Hello) -> Hello {
        var hello = hello
        hello.mapHash = boothMap?.hash
        return hello
    }

    private func announce() {
        if let resumeID = store.resumeID {
            transport.send(.hello(withMapHash(Hello(credential: .resume(resumeID)))))
        } else if let hello = pendingHello {
            transport.send(.hello(withMapHash(hello)))
        }
    }

    private func handle(_ message: ServerMessage) {
        lastHeard = Date()
        switch message {
        case let .welcome(welcome):
            store.resumeID = welcome.resumeID
            pendingHello = nil
            isSignedIn = true
            isResuming = true
            lastError = nil
            flushQueuedKill()
            serverClock.sync(serverTime: welcome.serverTime, receivedAt: Date())
        case let .state(newView):
            view = newView
            serverClock.sync(serverTime: newView.serverTime, receivedAt: Date())
        case let .rejected(reason):
            lastError = reason
            if reason != HostError.unknownDevice.message {
                pendingHello = nil
            }
        case let .probe(nonce):
            transport.send(.probeReply(nonce))
        case .reset:
            signOut()
        case let .selfies(list):
            selfies = Dictionary(list.map { ($0.player, $0.jpeg) }, uniquingKeysWith: { _, last in last })
        case let .map(map):
            boothMap = map
        }
    }
}
