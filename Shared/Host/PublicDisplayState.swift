import Foundation

struct PublicDisplayState: Codable, Equatable, Sendable {
    enum Screen: Codable, Equatable, Sendable {
        case hostOffline
        case waiting
        case starting(at: Date)
        case playing(gameEndsAt: Date)
        case discussion(until: Date)
        case voting(until: Date, isFinal: Bool, cast: Int, total: Int)
        case result(VoteResultView)
        case ended(Outcome)
    }

    struct Alarm: Codable, Equatable, Sendable {
        let kind: SabotageKind
        let endsAt: Date
    }

    static let resultDuration: TimeInterval = 30

    var screen: Screen
    var familiesRemaining: Int?
    var alarm: Alarm?
    var announcedDeaths: [String]
    var joinCode: String?
    var lobbyFamilies: [LobbyFamily] = []
    var reveal: [RevealedFamily] = []
}

struct RevealedFamily: Codable, Equatable, Sendable, Identifiable {
    let id: FamilyID
    let name: String
    let player: String?
    let selfie: Data?
    let isWerewolf: Bool
}

struct LobbyFamily: Codable, Equatable, Sendable, Identifiable {
    let id: FamilyID
    let name: String
    let player: String?
    var selfie: Data?
}

extension GameHost {
    func publicDisplayState(hostRunning: Bool = true) -> PublicDisplayState {
        guard hostRunning else {
            return PublicDisplayState(screen: .hostOffline, familiesRemaining: nil, alarm: nil, announcedDeaths: [])
        }
        guard let engine = state.engine else {
            return PublicDisplayState(screen: .waiting, familiesRemaining: nil, alarm: nil, announcedDeaths: [], joinCode: state.gameCode, lobbyFamilies: lobbyFamilies())
        }
        let game = engine.state
        if game.startedAt > clock.now {
            return PublicDisplayState(screen: .starting(at: game.startedAt), familiesRemaining: nil, alarm: nil, announcedDeaths: [])
        }
        let names = game.announcedDeaths.compactMap { state.families[$0]?.name }
        let alarm = game.sabotage.map { PublicDisplayState.Alarm(kind: $0.kind, endsAt: $0.endsAt) }
        let screen: PublicDisplayState.Screen = switch game.phase {
        case let .ended(outcome):
            .ended(outcome)
        case let .discussion(until):
            .discussion(until: until)
        case let .voting(until, isFinal):
            .voting(until: until, isFinal: isFinal, cast: game.votes.count, total: game.aliveFamilies().count)
        case .running:
            if let result = game.lastResult, clock.now.timeIntervalSince(result.at) < PublicDisplayState.resultDuration {
                .result(publicResult(result))
            } else {
                .playing(gameEndsAt: game.finalVoteAt)
            }
        }
        return PublicDisplayState(
            screen: screen,
            familiesRemaining: game.aliveFamilies().count,
            alarm: alarm,
            announcedDeaths: names,
            reveal: game.outcome?.winner == .werewolves ? endReveal(game) : []
        )
    }

    func endReveal(_ game: GameState) -> [RevealedFamily] {
        game.families.values.sorted { $0.id < $1.id }.map { family in
            let player = state.player(of: family.id)
            return RevealedFamily(
                id: family.id,
                name: state.families[family.id]?.name ?? "Unknown",
                player: player?.name,
                selfie: player.flatMap { selfies[$0.id] },
                isWerewolf: family.role == .werewolf
            )
        }
    }

    func lobbyFamilies() -> [LobbyFamily] {
        state.families.values.sorted { $0.id < $1.id }.map { family in
            let player = state.player(of: family.id)
            return LobbyFamily(id: family.id, name: family.name, player: player?.name, selfie: player.flatMap { selfies[$0.id] })
        }
    }

    func publicResult(_ result: VoteResult) -> VoteResultView {
        let rows = result.tally.map { count -> ResultRow in
            switch count.choice {
            case let .family(id): ResultRow(name: state.families[id]?.name ?? "Unknown", count: count.count, isSkip: false)
            case .skip: ResultRow(name: "Skip", count: count.count, isSkip: true)
            }
        }
        let expelled = result.expelled.map { ExpelledView(name: state.families[$0.family]?.name ?? "Unknown", role: nil) }
        return VoteResultView(rows: rows, expelled: expelled, isFinal: result.isFinal)
    }
}
