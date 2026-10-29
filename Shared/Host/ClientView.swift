import Foundation

enum IdentityView: Codable, Equatable, Sendable {
    case player(id: PlayerID, name: String, family: FamilyID)
    case oc(id: UUID, station: OCStation)
}

struct MemberView: Codable, Equatable, Sendable, Identifiable {
    let id: PlayerID
    let name: String
    let isHead: Bool
}

struct FamilySummary: Codable, Equatable, Sendable, Identifiable {
    let id: FamilyID
    let name: String
    let life: LifeState
    let revealedRole: Role?
    var headID: PlayerID?
    var headName: String?
}

struct TaskProgress: Codable, Equatable, Sendable, Identifiable {
    let booth: Booth
    let done: Bool

    var id: Int {
        booth.rawValue
    }
}

enum PhaseView: Codable, Equatable, Sendable {
    case running
    case discussion(until: Date)
    case voting(until: Date, isFinal: Bool)
    case ended(Outcome)
}

struct LobbyView: Codable, Equatable, Sendable {
    let familyName: String
    let joinCode: String
    let members: [MemberView]
    let isHead: Bool
    let hasHead: Bool
}

struct ResultRow: Codable, Equatable, Sendable, Identifiable {
    let name: String
    let count: Int
    let isSkip: Bool

    var id: String {
        isSkip ? "skip" : name
    }
}

struct ExpelledView: Codable, Equatable, Sendable, Identifiable {
    let name: String
    let role: Role

    var id: String {
        name
    }
}

struct VoteResultView: Codable, Equatable, Sendable {
    let rows: [ResultRow]
    let expelled: [ExpelledView]
    let isFinal: Bool
}

struct SabotageView: Codable, Equatable, Sendable {
    let kind: SabotageKind
    let startedAt: Date
    let endsAt: Date
}

struct OCFamilyRow: Codable, Equatable, Sendable, Identifiable {
    let id: FamilyID
    let name: String
    let life: LifeState
    let stampsDone: Int
    let stampsTotal: Int
    let onList: Bool?
    let stamped: Bool?
}

struct OCView: Codable, Equatable, Sendable {
    let sabotage: SabotageView?
    let families: [OCFamilyRow]
}

struct SabotageTiming: Codable, Equatable, Sendable, Identifiable {
    let kind: SabotageKind
    let duration: TimeInterval

    var id: SabotageKind {
        kind
    }
}

struct GameView: Codable, Equatable, Sendable {
    let role: Role
    let family: FamilyID
    let familyName: String
    let life: LifeState
    let isHead: Bool
    let members: [MemberView]
    let tasks: [TaskProgress]
    let allies: [FamilySummary]?
    let families: [FamilySummary]
    let phase: PhaseView
    let announcedDeaths: [FamilySummary]
    let myVote: VoteChoice?
    let votesCast: Int
    let votersTotal: Int
    let lastResult: VoteResultView?
    let bleToken: String
    let proximity: ProximitySettings
    let nearby: [FamilySummary]
    let killReadyAt: Date?
    let sabotage: SabotageView?
    let sabotageReadyAt: Date?
    var sabotageTimings: [SabotageTiming] = []
    var skipVotes = 0
    var mySkipVote = false
    var skipRequested = false
}

struct ClientView: Codable, Equatable, Sendable {
    var serverTime: Date
    var identity: IdentityView
    var familyName: String?
    var lobby: LobbyView?
    var game: GameView?
    var oc: OCView?
}

struct Welcome: Codable, Equatable, Sendable {
    let resumeID: UUID
    let serverTime: Date
}

struct ServerClock: Equatable, Sendable {
    private(set) var offset: TimeInterval = 0

    mutating func sync(serverTime: Date, receivedAt local: Date) {
        offset = serverTime.timeIntervalSince(local)
    }

    func now(local: Date = Date()) -> Date {
        local.addingTimeInterval(offset)
    }
}
