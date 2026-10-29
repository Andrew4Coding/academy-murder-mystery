import Foundation

struct FamilyID: Hashable, Comparable, Codable, Sendable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    var rawValue: Int

    init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    init(integerLiteral value: Int) {
        rawValue = value
    }

    static func < (lhs: FamilyID, rhs: FamilyID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var description: String {
        "F\(rawValue)"
    }
}

enum Role: String, Codable, Sendable {
    case villager
    case werewolf
}

enum Side: String, Codable, Sendable {
    case villagers
    case werewolves
}

enum LifeState: String, Codable, Sendable {
    case alive
    case killed
    case expelled
}

enum Booth: Int, CaseIterable, Codable, Sendable {
    case morseCode = 1
    case painting
    case message
    case rightPlace
    case pattern
    case tower
    case locks
}

enum SabotageKind: String, CaseIterable, Codable, Sendable {
    case reactor
    case oxygen
}

enum VoteChoice: Hashable, Codable, Sendable {
    case family(FamilyID)
    case skip
}

struct GameSettings: Codable, Equatable, Sendable {
    var discussionDuration: TimeInterval = 120
    var votingDuration: TimeInterval = 120
    var killCooldown: TimeInterval = 60
    var sabotageCooldown: TimeInterval = 120
    var sabotageDuration: TimeInterval = 90
    var gameDuration: TimeInterval = 45 * 60
    var tasksPerFamily: Int = 5
    // Reactor keeps the original fields so stored games still decode; Oxygen overrides them when set.
    var oxygenDuration: TimeInterval?
    var oxygenCooldown: TimeInterval?

    static let standard = GameSettings()

    func sabotageDuration(for kind: SabotageKind) -> TimeInterval {
        kind == .oxygen ? oxygenDuration ?? sabotageDuration : sabotageDuration
    }

    func sabotageCooldown(for kind: SabotageKind) -> TimeInterval {
        kind == .oxygen ? oxygenCooldown ?? sabotageCooldown : sabotageCooldown
    }
}

struct Family: Codable, Equatable, Sendable, Identifiable {
    let id: FamilyID
    let role: Role
    var life: LifeState
    let tasks: Set<Booth>
    var stamps: Set<Booth>
    var killReadyAt: Date

    var isAlive: Bool {
        life == .alive
    }

    var hasCompletedTasks: Bool {
        tasks.isSubset(of: stamps)
    }
}

struct ActiveSabotage: Codable, Equatable, Sendable {
    let kind: SabotageKind
    let startedAt: Date
    var endsAt: Date
    let triggeredBy: FamilyID
}

enum Phase: Codable, Equatable, Sendable {
    case running
    case discussion(until: Date)
    case voting(until: Date, isFinal: Bool)
    case ended(Outcome)
}

struct Outcome: Codable, Equatable, Sendable {
    enum Reason: String, Codable, Sendable {
        case allTasksDone
        case allWerewolvesRemoved
        case parity
        case sabotageExpired
        case finalVoteSucceeded
        case finalVoteFailed
        case ocEnded
    }

    let winner: Side
    let reason: Reason
}
