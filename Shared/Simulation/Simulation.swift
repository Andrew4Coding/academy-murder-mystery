import Foundation

@MainActor
final class Simulation {
    struct Config: Equatable, Sendable {
        var familyCount = 12
        var werewolfCount = 2
        var membersPerFamily = 3
        var seed: UInt64 = 1
        var resolveChance = 0.85
    }

    private struct Bot {
        let clientID: ClientID
        let playerID: PlayerID
    }

    nonisolated static let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    let config: Config
    let host: GameHost
    let repository = InMemoryGameRepository()
    private let clock = ManualHostClock(Simulation.epoch)
    private var rng: SeededGenerator
    private var bots: [FamilyID: [Bot]] = [:]
    private var resolveAt: Date?
    private var willResolve = true
    private var lastMeetingAt = Simulation.epoch

    private(set) var elapsed: TimeInterval = 0

    var isFinished: Bool {
        host.state.engine?.state.outcome != nil
    }

    var events: [GameEvent] {
        (try? repository.events(for: host.gameID)) ?? []
    }

    init(config: Config) throws {
        self.config = config
        rng = SeededGenerator(seed: config.seed)
        var state = HostState(ocPin: "0000")
        state.simulated = true
        host = try GameHost(repository: repository, clock: clock, initialState: state)
        try host.configure(familyCount: config.familyCount, werewolfCount: config.werewolfCount, settings: .standard)
        try seatBots()
        try host.startGame(using: &rng)
    }

    func step(by seconds: TimeInterval = 1) {
        guard !isFinished else { return }
        clock.advance(by: seconds)
        elapsed += seconds
        host.tick()
        guard let game = host.state.engine?.state, game.outcome == nil else { return }
        switch game.phase {
        case .running: playRunning(game, seconds: seconds)
        case .voting: castVotes(game)
        case .discussion, .ended: break
        }
    }

    func runToCompletion(maxSeconds: TimeInterval = 4000, step seconds: TimeInterval = 1) {
        while !isFinished, elapsed < maxSeconds {
            step(by: seconds)
        }
    }

    static func virtualSeconds(real: TimeInterval, speed: Double) -> TimeInterval {
        real * speed
    }
}

private extension Simulation {
    func seatBots() throws {
        for family in host.state.families.values.sorted(by: { $0.id < $1.id }) {
            var members: [Bot] = []
            for index in 1 ... config.membersPerFamily {
                let clientID = ClientID()
                host.handle(.connected(clientID))
                host.receive(
                    .hello(Hello(credential: .familyCode(family.joinCode), name: "Bot \(family.id.rawValue).\(index)")),
                    from: clientID
                )
                guard case let .player(playerID)? = host.sessions[clientID]?.identity else {
                    throw HostError.invalidCredential
                }
                members.append(Bot(clientID: clientID, playerID: playerID))
            }
            host.receive(.claimHead, from: members[0].clientID)
            bots[family.id] = members
        }
    }

    func roll(_ probability: Double) -> Bool {
        Double.random(in: 0 ..< 1, using: &rng) < probability
    }

    func pick<T>(_ items: [T]) -> T? {
        items.isEmpty ? nil : items[Int.random(in: 0 ..< items.count, using: &rng)]
    }

    func send(_ message: ClientMessage, as family: FamilyID) {
        guard let bot = bots[family]?.first else { return }
        host.receive(message, from: bot.clientID)
    }

    func playRunning(_ game: GameState, seconds: TimeInterval) {
        let families = game.families.values.sorted { $0.id < $1.id }
        stamp(families, seconds: seconds)
        kill(families, game: game, seconds: seconds)
        sabotage(families, game: game, seconds: seconds)
        meeting(game, seconds: seconds)
    }

    func stamp(_ families: [Family], seconds: TimeInterval) {
        for family in families where family.isAlive {
            let remaining = family.tasks.subtracting(family.stamps).sorted { $0.rawValue < $1.rawValue }
            guard !remaining.isEmpty, roll(seconds / 90), let booth = pick(remaining) else { continue }
            try? host.recordStamp(family: family.id, booth: booth, confirmOffList: false)
        }
    }

    func kill(_ families: [Family], game _: GameState, seconds: TimeInterval) {
        for wolf in families where wolf.role == .werewolf && wolf.isAlive && host.clock.now >= wolf.killReadyAt {
            guard roll(seconds / 60) else { continue }
            let victims = families.filter { $0.role == .villager && $0.isAlive }.map(\.id)
            guard let victim = pick(victims),
                  let token = host.state.players.values.first(where: { $0.family == victim })?.bleToken else { continue }
            send(.sightings([Sighting(token: token, rssi: -50)]), as: wolf.id)
            send(.kill(victim: victim), as: wolf.id)
        }
    }

    func sabotage(_ families: [Family], game: GameState, seconds: TimeInterval) {
        let now = host.clock.now
        if game.sabotage != nil {
            if resolveAt == nil {
                resolveAt = now.addingTimeInterval(Double.random(in: 20 ... 80, using: &rng))
                willResolve = roll(config.resolveChance)
            }
            if let due = resolveAt, now >= due, willResolve {
                try? host.applyAsOC(.resolveSabotage)
                resolveAt = nil
            }
            return
        }
        resolveAt = nil
        guard now >= game.sabotageReadyAt else { return }
        for wolf in families where wolf.role == .werewolf && roll(seconds / 150) {
            send(.requestSabotage(roll(0.5) ? .reactor : .oxygen), as: wolf.id)
            return
        }
    }

    func meeting(_ game: GameState, seconds: TimeInterval) {
        let now = host.clock.now
        let hasBodies = !game.deadSinceLastMeeting.isEmpty
        let wantsMeeting = hasBodies
            ? now.timeIntervalSince(lastMeetingAt) >= 20 && roll(seconds / 15)
            : roll(seconds / 900)
        guard wantsMeeting else { return }
        try? host.applyAsOC(.startMeeting)
        lastMeetingAt = now
    }

    func castVotes(_ game: GameState) {
        let alive = game.aliveFamilies()
        for voter in alive where game.votes[voter.id] == nil {
            let choice: VoteChoice = if roll(0.2) {
                .skip
            } else if voter.role == .villager, roll(0.35), let wolf = pick(alive.filter { $0.role == .werewolf }) {
                .family(wolf.id)
            } else if let target = pick(alive.filter { $0.id != voter.id }) {
                .family(target.id)
            } else {
                .skip
            }
            send(.vote(choice), as: voter.id)
        }
        lastMeetingAt = host.clock.now
    }
}
