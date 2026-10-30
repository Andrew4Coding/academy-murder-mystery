#if DEBUG
    import Foundation

    enum AdminStage: String, CaseIterable, Identifiable {
        case setupIssues
        case lobbyReady
        case running
        case discussion
        case voting
        case result
        case sabotage
        case ended

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .setupIssues: "Setup with issues"
            case .lobbyReady: "Lobby, ready to start"
            case .running: "Running"
            case .discussion: "Discussion"
            case .voting: "Voting"
            case .result: "Vote result"
            case .sabotage: "Sabotage"
            case .ended: "Game ended"
            }
        }
    }

    final class AdminPreviewTransport: ClientTransport {
        let events: AsyncStream<ClientTransportEvent>
        private let continuation: AsyncStream<ClientTransportEvent>.Continuation

        init() {
            (events, continuation) = AsyncStream.makeStream(of: ClientTransportEvent.self)
        }

        func push(_ event: ClientTransportEvent) {
            continuation.yield(event)
        }

        func start() {}
        func stop() {}
        func send(_: ClientMessage) {}
    }

    @MainActor
    enum AdminFixtures {
        static let familyNames = [
            "Hendersons", "Okafors", "Tanakas", "Riveras", "Nguyens", "Kowalskis",
            "Haddads", "Silvas", "Mullers", "Jensens", "Patels", "Costas"
        ]

        static func host(_ stage: AdminStage, now: Date = .now) -> GameHost {
            let clock = ManualHostClock(now)
            do {
                return try buildHost(stage, now: now, clock: clock)
            } catch {
                fatalError("admin fixture \(stage): \(error)")
            }
        }

        static func controller(_ stage: AdminStage, now: Date = .now) -> HostController {
            HostController(host: host(stage, now: now))
        }

        static func adminView(_ stage: AdminStage, now: Date = .now) -> AdminView {
            var view = host(stage, now: now).adminView()
            view.devices = devices(now: now)
            return view
        }

        static func emptyAdminView() -> AdminView {
            do {
                let host = try GameHost(repository: InMemoryGameRepository(), initialState: HostState(ocPin: "4821"))
                return host.adminView()
            } catch {
                fatalError("admin fixture empty: \(error)")
            }
        }

        static func client(status: ConnectionStatus = .connected, error: String? = nil) -> GameClient {
            let transport = AdminPreviewTransport()
            let client = GameClient(transport: transport, store: InMemoryIdentityStore())
            client.start()
            transport.push(.status(status))
            if let error {
                transport.push(.message(.rejected(error)))
            }
            return client
        }

        static func devices(now: Date = .now) -> [DeviceStatus] {
            [
                DeviceStatus(id: uuid(1), label: "Alex", detail: "Hendersons", connection: .online, lastSeen: now.addingTimeInterval(-3)),
                DeviceStatus(id: uuid(2), label: "Bola", detail: "Okafors", connection: .online, lastSeen: now.addingTimeInterval(-6)),
                DeviceStatus(
                    id: uuid(3),
                    label: "Chika",
                    detail: "Tanakas",
                    connection: .unreachable,
                    lastSeen: now.addingTimeInterval(-95)
                ),
                DeviceStatus(id: uuid(4), label: "Dev", detail: "Riveras", connection: .offline, lastSeen: nil),
                DeviceStatus(
                    id: uuid(5), label: "OC iPad", detail: "Admin station", connection: .online,
                    lastSeen: now.addingTimeInterval(-1), isOC: true
                )
            ]
        }

        static func simulation(_ stage: SimulationStage) -> SimulationController {
            let controller = SimulationController()
            controller.speed = .paused
            switch stage {
            case .idle:
                break
            case .running:
                controller.start(Simulation.Config(familyCount: 8, werewolfCount: 2, seed: 7))
                controller.simulation?.step(by: 420)
            case .finished:
                controller.start(Simulation.Config(familyCount: 8, werewolfCount: 2, seed: 7))
                controller.runToEnd()
            case .error:
                controller.start(Simulation.Config(familyCount: 4, werewolfCount: 4, seed: 7))
            }
            return controller
        }

        private static func uuid(_ index: Int) -> UUID {
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)) ?? UUID()
        }

        private static func buildHost(_ stage: AdminStage, now: Date, clock: ManualHostClock) throws -> GameHost {
            let issues = stage == .setupIssues
            let count = issues ? 4 : familyNames.count
            var state = HostState(ocPin: "4821")
            state.gameCode = "MOON42"
            state.werewolfCount = issues ? 2 : 3
            for index in 1 ... count {
                let id = FamilyID(index)
                state.families[id] = FamilyInfo(id: id, name: familyNames[index - 1], joinCode: "FAM\(String(format: "%03d", index))")
                if !issues || index <= 2 {
                    let playerID = uuid(index)
                    state.players[playerID] = Player(id: playerID, name: playerNames[index - 1], family: id, bleToken: "token\(index)")
                }
            }
            if !issues, stage != .lobbyReady {
                state.engine = try engine(for: stage, count: count, now: now)
            }
            return try GameHost(repository: InMemoryGameRepository(), clock: clock, initialState: state)
        }

        private static let playerNames = ["Alex", "Bola", "Chika", "Dev", "Eli", "Fumi", "Gus", "Hana", "Ivo", "Jun", "Kai", "Lena"]

        private static func engine(for stage: AdminStage, count: Int, now: Date) throws -> GameEngine {
            var generator = SeededGenerator(seed: 7)
            var (engine, _) = try GameEngine.start(
                familyIDs: (1 ... count).map { FamilyID($0) },
                werewolfCount: 3,
                at: now.addingTimeInterval(-600),
                using: &generator
            )
            func run(_ command: GameCommand, _ offset: TimeInterval) throws {
                _ = try engine.apply(command, at: now.addingTimeInterval(offset))
            }
            let villagers = engine.state.families.values.filter { $0.role == .villager }.map(\.id).sorted()
            let werewolves = engine.state.families.values.filter { $0.role == .werewolf }.map(\.id).sorted()
            if stage != .running {
                try run(.override(.forceKill(villagers[0])), -500)
            }
            switch stage {
            case .discussion:
                try run(.startMeeting, 0)
            case .voting:
                try run(.startMeeting, -130)
                _ = engine.advance(to: now)
                try castVotes(&engine, count: 7, target: villagers[1], at: now)
            case .result:
                try run(.startMeeting, -300)
                try castVotes(&engine, count: 11, target: villagers[1], at: now.addingTimeInterval(-150))
                _ = engine.advance(to: now)
            case .sabotage:
                try run(.requestSabotage(by: werewolves[0], kind: .reactor), -30)
            case .ended:
                try run(.override(.endGame(.villagers)), 0)
            case .setupIssues, .lobbyReady, .running:
                break
            }
            return engine
        }

        private static func castVotes(_ engine: inout GameEngine, count: Int, target: FamilyID, at time: Date) throws {
            let voters = engine.state.aliveFamilies().map(\.id).sorted().prefix(count)
            for voter in voters {
                let choice: VoteChoice = voter == target ? .skip : .family(target)
                _ = try engine.apply(.castVote(by: voter, choice: choice), at: time)
            }
        }
    }

    enum SimulationStage: String, CaseIterable, Identifiable {
        case idle
        case running
        case finished
        case error

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .idle: "Not started"
            case .running: "Running"
            case .finished: "Finished"
            case .error: "Can't start"
            }
        }
    }
#endif
