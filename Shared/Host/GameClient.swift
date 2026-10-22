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
    private(set) var serverClock = ServerClock()

    @ObservationIgnored private let transport: any ClientTransport
    @ObservationIgnored private let store: any IdentityStore
    @ObservationIgnored private var pendingHello: Hello?
    @ObservationIgnored private var pump: Task<Void, Never>?

    init(transport: any ClientTransport, store: any IdentityStore) {
        self.transport = transport
        self.store = store
    }

    var serverNow: Date {
        serverClock.now()
    }

    func start() {
        pump?.cancel()
        pump = Task { [weak self, transport] in
            for await event in transport.events {
                guard let self else { return }
                handle(event)
            }
        }
        transport.start()
    }

    func stop() {
        pump?.cancel()
        transport.stop()
    }

    func join(code: String, name: String) {
        signIn(Hello(credential: .familyCode(code), name: name))
    }

    func signInAsOC(pin: String, station: OCStation) {
        signIn(Hello(credential: .ocPin(pin), station: station))
    }

    func send(_ message: ClientMessage) {
        transport.send(message)
    }

    func signOut() {
        store.resumeID = nil
        view = nil
        isSignedIn = false
        pendingHello = nil
    }

    private func signIn(_ hello: Hello) {
        lastError = nil
        pendingHello = hello
        if status == .connected {
            transport.send(.hello(hello))
        }
    }

    private func handle(_ event: ClientTransportEvent) {
        switch event {
        case let .status(newStatus):
            status = newStatus
            if newStatus == .connected {
                announce()
            }
        case let .message(message):
            handle(message)
        }
    }

    private func announce() {
        if let hello = pendingHello {
            transport.send(.hello(hello))
        } else if let resumeID = store.resumeID {
            transport.send(.hello(Hello(credential: .resume(resumeID))))
        }
    }

    private func handle(_ message: ServerMessage) {
        switch message {
        case let .welcome(welcome):
            store.resumeID = welcome.resumeID
            pendingHello = nil
            isSignedIn = true
            serverClock.sync(serverTime: welcome.serverTime, receivedAt: Date())
        case let .state(newView):
            view = newView
            serverClock.sync(serverTime: newView.serverTime, receivedAt: Date())
        case let .rejected(reason):
            lastError = reason
            pendingHello = nil
            if reason == HostError.unknownDevice.message {
                store.resumeID = nil
                isSignedIn = false
                view = nil
            }
        case let .probe(nonce):
            transport.send(.probeReply(nonce))
        }
    }
}
