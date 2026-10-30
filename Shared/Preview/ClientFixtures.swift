#if DEBUG
    import CoreGraphics
    import Foundation
    import ImageIO
    import UniformTypeIdentifiers

    @MainActor
    final class PreviewClientTransport: ClientTransport {
        let events: AsyncStream<ClientTransportEvent>
        private let continuation: AsyncStream<ClientTransportEvent>.Continuation

        init() {
            (events, continuation) = AsyncStream.makeStream(of: ClientTransportEvent.self)
        }

        func start() {}
        func stop() {}
        func send(_: ClientMessage) {}

        func push(_ event: ClientTransportEvent) {
            continuation.yield(event)
        }
    }

    @MainActor
    enum ClientFixtures {
        static let selfFamily: FamilyID = 1
        static let selfPlayer = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()

        static func family(
            _ id: FamilyID,
            _ name: String,
            life: LifeState = .alive,
            player: String? = nil
        ) -> FamilySummary {
            FamilySummary(id: id, name: name, life: life, revealedRole: nil, playerID: nil, playerName: player)
        }

        static var families: [FamilySummary] {
            [
                family(1, "The Hendersons", player: "Alex"),
                family(2, "Okafor Crew", player: "Ngozi"),
                family(3, "Tanaka Family", player: "Mika"),
                family(4, "Silva Squad", player: "Rafael"),
                family(5, "Novak Clan", player: "Petra")
            ]
        }

        static var nearby: [FamilySummary] {
            [family(2, "Okafor Crew"), family(4, "Silva Squad")]
        }

        static var fallenFamily: FamilySummary {
            family(5, "Novak Clan", life: .killed)
        }

        static func sabotage(_ kind: SabotageKind = .reactor, now: Date, remaining: TimeInterval = 70) -> SabotageView {
            SabotageView(kind: kind, startedAt: now.addingTimeInterval(remaining - 90), endsAt: now.addingTimeInterval(remaining))
        }

        static func voteResult(isFinal: Bool = false, expelled: Bool = true) -> VoteResultView {
            VoteResultView(
                rows: [
                    ResultRow(name: "Silva Squad", count: 3, isSkip: false),
                    ResultRow(name: "Okafor Crew", count: 1, isSkip: false),
                    ResultRow(name: "Skip", count: 1, isSkip: true)
                ],
                expelled: expelled ? [ExpelledView(name: "Silva Squad", role: nil)] : [],
                isFinal: isFinal
            )
        }

        static func game(
            now _: Date,
            role: Role = .villager,
            life: LifeState = .alive,
            phase: PhaseView = .running,
            nearby: [FamilySummary] = [],
            bodies: [FamilySummary] = [],
            killReadyAt: Date? = nil,
            sabotage: SabotageView? = nil,
            sabotageReadyAt: Date? = nil,
            myVote: VoteChoice? = nil,
            votesCast: Int = 0,
            skipVotes: Int = 0,
            mySkipVote: Bool = false,
            lastResult: VoteResultView? = nil,
            announcedDeaths: [FamilySummary] = [],
            startsAt: Date? = nil
        ) -> GameView {
            GameView(
                role: role,
                family: selfFamily,
                familyName: "The Hendersons",
                life: life,
                tasks: Booth.allCases,
                allies: role == .werewolf ? [family(3, "Tanaka Family")] : nil,
                families: families,
                phase: phase,
                announcedDeaths: announcedDeaths,
                myVote: myVote,
                votesCast: votesCast,
                votersTotal: 5,
                lastResult: lastResult,
                bleToken: "PREVIEW",
                proximity: ProximitySettings(rssiThreshold: -75, sightingFreshness: 10),
                nearby: nearby,
                killReadyAt: killReadyAt,
                sabotage: sabotage,
                sabotageReadyAt: sabotageReadyAt,
                sabotageTimings: SabotageKind.allCases.map { SabotageTiming(kind: $0, duration: 90) },
                nearbyBodies: bodies,
                bodyActive: false,
                skipVotes: skipVotes,
                mySkipVote: mySkipVote,
                skipRequested: false,
                startsAt: startsAt
            )
        }

        static func lobby() -> LobbyView {
            LobbyView(familyName: "The Hendersons", joinCode: "MOON42", playerID: selfPlayer, playerName: "Alex")
        }

        static func playerView(now: Date, game: GameView? = nil, lobby: LobbyView? = nil) -> ClientView {
            ClientView(
                serverTime: now,
                identity: .player(id: selfPlayer, name: "Alex", family: selfFamily),
                familyName: "The Hendersons",
                lobby: lobby,
                game: game
            )
        }

        static func ocView(now: Date, station: OCStation, sabotage: SabotageView?) -> ClientView {
            ClientView(
                serverTime: now,
                identity: .oc(id: UUID(), station: station),
                oc: OCView(sabotage: sabotage)
            )
        }

        static func boothMap() -> BoothMap {
            let size = 480
            let space = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil, width: size, height: size * 2 / 3, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return BoothMap(jpeg: Data()) }
            context.setFillColor(CGColor(red: 0.16, green: 0.11, blue: 0.15, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            context.setFillColor(CGColor(red: 0.78, green: 0.06, blue: 0.18, alpha: 1))
            for index in 0 ..< 7 {
                context.fill(CGRect(x: 30 + index * 62, y: 40 + (index % 2) * 120, width: 44, height: 44))
            }
            let data = NSMutableData()
            let type = UTType.jpeg.identifier as CFString
            if let image = context.makeImage(), let destination = CGImageDestinationCreateWithData(data, type, 1, nil) {
                CGImageDestinationAddImage(destination, image, nil)
                CGImageDestinationFinalize(destination)
            }
            return BoothMap(jpeg: data as Data)
        }

        static func client(
            status: ConnectionStatus = .connected,
            error: String? = nil,
            map: BoothMap? = nil,
            view: ClientView? = nil
        ) -> GameClient {
            let transport = PreviewClientTransport()
            let client = GameClient(transport: transport, store: InMemoryIdentityStore())
            client.start()
            transport.push(.status(status))
            if let map {
                transport.push(.message(.map(map)))
            }
            if let view {
                transport.push(.message(.state(view)))
            }
            if let error {
                transport.push(.message(.rejected(error)))
            }
            return client
        }
    }
#endif
