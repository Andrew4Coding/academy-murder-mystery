import Foundation
import Observation

struct DeviceStatus: Identifiable, Equatable, Sendable {
    enum Connection: String, Sendable {
        case online
        case unreachable
        case offline
    }

    let id: UUID
    let label: String
    let detail: String
    let connection: Connection
    let lastSeen: Date?
}

@MainActor @Observable
final class GameHost {
    struct Session {
        var identity: Identity?
        var failures = 0
        var lockedUntil: Date?
        var lastSeen: Date
        var probe: (nonce: UUID, sentAt: Date)?
        var lastReplyAt: Date?
    }

    static let maxFailures = 5
    static let lockDuration: TimeInterval = 30
    static let probeTimeout: TimeInterval = 3

    var state: HostState
    var gameID: UUID
    var sessions: [ClientID: Session] = [:]
    private(set) var recentEvents: [GameEvent] = []
    private(set) var revision = 0
    private(set) var bellRings = 0

    @ObservationIgnored var selfies: [PlayerID: Data] = [:]
    @ObservationIgnored var testingToolsEnabled = TestingTools.isEnabled
    @ObservationIgnored var sightings: [FamilyID: [FamilyID: SightingRecord]] = [:]
    @ObservationIgnored var stampTimes: [StampKey: Date] = [:]
    @ObservationIgnored var lastNearby: [FamilyID: Set<FamilyID>] = [:]
    @ObservationIgnored var lastBodies: [FamilyID: Set<FamilyID>] = [:]
    @ObservationIgnored let clock: any HostClock
    @ObservationIgnored private let repository: any GameRepository
    @ObservationIgnored private var transport: (any HostTransport)?
    @ObservationIgnored private var pump: Task<Void, Never>?

    init(repository: any GameRepository, clock: any HostClock = SystemHostClock(), initialState: HostState? = nil) throws {
        self.repository = repository
        self.clock = clock
        if let stored = try repository.latest() {
            gameID = stored.id
            state = stored.state
            if state.gameCode == nil {
                state.gameCode = Self.makeJoinCode(excluding: [])
            }
            recentEvents = try Array(repository.events(for: stored.id).suffix(200))
        } else {
            gameID = UUID()
            var initial = initialState ?? HostState(ocPin: Self.makePIN())
            if initial.gameCode == nil {
                initial.gameCode = Self.makeJoinCode(excluding: [])
            }
            state = initial
            try repository.save(StoredGame(id: gameID, state: state, updatedAt: clock.now))
        }
    }

    func ringBell() {
        bellRings += 1
    }

    func regenerateOCPIN() {
        state.ocPin = Self.makePIN()
        commit()
    }

    static func makePIN() -> String {
        String(format: "%04d", Int.random(in: 0 ... 9999))
    }

    func attach(_ transport: any HostTransport) {
        self.transport = transport
        pump?.cancel()
        pump = Task { [weak self] in
            for await event in transport.events {
                guard let self else { return }
                handle(event)
            }
        }
    }

    func detach() {
        pump?.cancel()
        pump = nil
        transport?.stop()
        transport = nil
        sessions = [:]
    }

    func handle(_ event: HostTransportEvent) {
        switch event {
        case let .connected(id):
            sessions[id] = Session(lastSeen: clock.now)
        case let .disconnected(id):
            sessions[id] = nil
            revision += 1
        case let .message(id, message):
            receive(message, from: id)
        }
    }

    func receive(_ message: ClientMessage, from id: ClientID) {
        guard sessions[id] != nil else { return }
        sessions[id]?.lastSeen = clock.now
        do {
            switch message {
            case let .hello(hello):
                try authenticate(hello, clientID: id)
            case let .probeReply(nonce):
                if sessions[id]?.probe?.nonce == nonce {
                    sessions[id]?.lastReplyAt = clock.now
                }
            case let .renameFamily(name):
                try renameFamily(identity: signedIn(id), to: name)
            case let .admin(command):
                try adminCommand(command, identity: signedIn(id))
            case let .reportBody(body):
                try reportBody(identity: signedIn(id), body: body)
            case .voteSkipDiscussion:
                try voteSkipDiscussion(identity: signedIn(id))
            case let .selfie(data):
                try storeSelfie(data, identity: signedIn(id))
            case let .vote(choice):
                try vote(identity: signedIn(id), choice: choice)
            case let .sightings(list):
                try receiveSightings(list, identity: signedIn(id))
            case let .kill(victim):
                try kill(identity: signedIn(id), victim: victim)
            case let .requestSabotage(kind):
                try requestSabotage(identity: signedIn(id), kind: kind)
            case .resolveSabotage:
                try resolveSabotage(identity: signedIn(id))
            case let .stamp(family, confirmOffList):
                try stamp(identity: signedIn(id), family: family, confirmOffList: confirmOffList)
            case let .undoStamp(family):
                try undoStamp(identity: signedIn(id), family: family)
            case .leave:
                try leave(identity: signedIn(id), clientID: id)
            case .sync:
                try sync(clientID: id)
            }
        } catch let error as HostError {
            send(.rejected(error.message), to: id)
        } catch let error as RuleError {
            send(.rejected(error.message), to: id)
        } catch {
            send(.rejected("Something went wrong."), to: id)
        }
    }

    func tick() {
        guard var engine = state.engine else { return }
        let events = engine.advance(to: clock.now)
        if !events.isEmpty {
            state.engine = engine
            commit(events: events)
        }
        refreshNearby()
    }

    func checkConnectivity() {
        let nonce = UUID()
        let now = clock.now
        for id in sessions.keys where sessions[id]?.identity != nil {
            sessions[id]?.probe = (nonce, now)
            sessions[id]?.lastReplyAt = nil
            send(.probe(nonce), to: id)
        }
        revision += 1
    }

    func deviceStatuses() -> [DeviceStatus] {
        let now = clock.now
        var online: [Identity: (Session, ClientID)] = [:]
        for (clientID, session) in sessions {
            if let identity = session.identity {
                online[identity] = (session, clientID)
            }
        }

        func connection(_ identity: Identity) -> (DeviceStatus.Connection, Date?) {
            guard let (session, _) = online[identity] else { return (.offline, nil) }
            if let probe = session.probe, session.lastReplyAt == nil, now.timeIntervalSince(probe.sentAt) > Self.probeTimeout {
                return (.unreachable, session.lastSeen)
            }
            return (.online, session.lastSeen)
        }

        let players = state.players.values.map { player -> DeviceStatus in
            let (status, seen) = connection(.player(player.id))
            let family = state.families[player.family]?.name ?? "Unknown family"
            return DeviceStatus(id: player.id, label: player.name, detail: family, connection: status, lastSeen: seen)
        }
        let ocs = state.ocDevices.values.map { device -> DeviceStatus in
            let (status, seen) = connection(.oc(device.id))
            return DeviceStatus(id: device.id, label: "OC", detail: device.station.title, connection: status, lastSeen: seen)
        }
        return (players + ocs).sorted { ($0.detail, $0.label) < ($1.detail, $1.label) }
    }

    var selfieList: [Selfie] {
        selfies.map { Selfie(player: $0.key, jpeg: $0.value) }
    }

    func replaceState(_ change: (inout HostState) -> Void) {
        change(&state)
        commit()
    }

    func broadcast() {
        for (id, session) in sessions {
            guard let identity = session.identity, let view = view(for: identity) else { continue }
            send(.state(view), to: id)
        }
    }

    func commit(events: [GameEvent] = []) {
        revision += 1
        recentEvents = Array((recentEvents + events).suffix(200))
        do {
            try repository.save(StoredGame(id: gameID, state: state, updatedAt: clock.now))
            if !events.isEmpty {
                try repository.append(events, to: gameID)
            }
        } catch {
            assertionFailure("Failed to persist game: \(error)")
        }
        broadcast()
    }

    func send(_ message: ServerMessage, to id: ClientID) {
        transport?.send(message, to: id)
    }

    func signedIn(_ id: ClientID) throws -> Identity {
        guard let identity = sessions[id]?.identity else { throw HostError.notSignedIn }
        return identity
    }

    private func authenticate(_ hello: Hello, clientID id: ClientID) throws {
        let now = clock.now
        if let until = sessions[id]?.lockedUntil, now < until {
            throw HostError.tooManyAttempts
        }
        guard hello.version == WireVersion.current else { throw HostError.unsupportedVersion }

        let identity: Identity
        do {
            identity = try resolve(hello)
        } catch let error as HostError where error == .invalidCredential || error == .unknownDevice {
            registerFailure(for: id)
            throw error
        }

        sessions[id]?.failures = 0
        sessions[id]?.identity = identity
        let resumeID: UUID = switch identity {
        case let .player(playerID): playerID
        case let .oc(ocID): ocID
        }
        send(.welcome(Welcome(resumeID: resumeID, serverTime: now)), to: id)
        send(.selfies(selfieList), to: id)
        commit()
    }

    private func resolve(_ hello: Hello) throws -> Identity {
        switch hello.credential {
        case let .familyCode(code):
            let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let legacyFamily = state.families.values.first(where: { $0.joinCode == normalized })
            guard normalized == state.gameCode || legacyFamily != nil else { throw HostError.invalidCredential }
            guard state.isLobby else { throw HostError.gameAlreadyStarted }
            guard let name = hello.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                throw HostError.nameRequired
            }
            let family: FamilyID
            if let legacyFamily {
                guard state.player(of: legacyFamily.id) == nil else { throw HostError.familyFull }
                family = legacyFamily.id
            } else {
                family = try assignFamily()
            }
            let player = Player(id: UUID(), name: name, family: family, bleToken: Self.makeToken())
            state.players[player.id] = player
            return .player(player.id)
        case let .ocPin(pin):
            guard pin == state.ocPin, let station = hello.station else { throw HostError.invalidCredential }
            let device = OCDevice(id: UUID(), station: station)
            state.ocDevices[device.id] = device
            return .oc(device.id)
        case let .resume(id):
            if state.players[id] != nil {
                return .player(id)
            }
            if state.ocDevices[id] != nil {
                return .oc(id)
            }
            throw HostError.unknownDevice
        }
    }

    private func registerFailure(for id: ClientID) {
        guard var session = sessions[id] else { return }
        session.failures += 1
        if session.failures >= Self.maxFailures {
            session.lockedUntil = clock.now.addingTimeInterval(Self.lockDuration)
            session.failures = 0
        }
        sessions[id] = session
    }

    private static func makeToken() -> String {
        String((0 ..< 6).map { _ in "0123456789ABCDEF".randomElement()! })
    }
}

extension OCStation {
    var title: String {
        switch self {
        case let .booth(booth): booth.title
        case let .sabotage(kind): kind.title
        case .townHall: "Town Hall"
        case .admin: "iPad dashboard"
        }
    }
}

extension Booth {
    var title: String {
        switch self {
        case .morseCode: "Booth 1: Decipher Morse Code"
        case .painting: "Booth 2: Recreate the Painting"
        case .message: "Booth 3: Message Passenger"
        case .rightPlace: "Booth 4: The Right Place"
        case .pattern: "Booth 5: Follow the Pattern"
        case .tower: "Booth 6: Tower Danger"
        case .locks: "Booth 7: Separate Metal Locks"
        }
    }
}

extension SabotageKind {
    var title: String {
        switch self {
        case .reactor: "Reactor (Collab 7A)"
        case .oxygen: "Oxygen (Collab 6)"
        }
    }
}
