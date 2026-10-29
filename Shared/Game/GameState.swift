import Foundation

struct VoteResult: Codable, Equatable, Sendable {
    let tally: [VoteCount]
    let expelled: [Reveal]
    let isFinal: Bool
    let at: Date
}

struct GameState: Codable, Equatable, Sendable {
    var settings: GameSettings
    let startedAt: Date
    var families: [FamilyID: Family]
    var phase: Phase = .running
    var sabotage: ActiveSabotage?
    var sabotageReadyAt: Date
    var votes: [FamilyID: VoteChoice] = [:]
    var skipVotes: Set<FamilyID> = []
    var announcedDeaths: [FamilyID] = []
    var lastResult: VoteResult?
    var deadSinceLastMeeting: [FamilyID] = []
    var finalVoteStarted = false
    var finalVotePending = false

    /// Ballots are deliberately not encoded: stored games keep tallies, never who voted for whom.
    private enum CodingKeys: String, CodingKey {
        case settings, startedAt, families, phase, sabotage, sabotageReadyAt
        case announcedDeaths, lastResult, deadSinceLastMeeting, finalVoteStarted, finalVotePending
    }

    var finalVoteAt: Date {
        startedAt.addingTimeInterval(settings.gameDuration)
    }

    var outcome: Outcome? {
        if case let .ended(outcome) = phase {
            outcome
        } else {
            nil
        }
    }

    var skipRequested: Bool {
        skipVotes.count * 2 > aliveFamilies().count
    }

    func family(_ id: FamilyID) throws -> Family {
        guard let family = families[id] else { throw RuleError.unknownFamily(id) }
        return family
    }

    func aliveFamilies(role: Role? = nil) -> [Family] {
        families.values
            .filter { $0.isAlive && (role == nil || $0.role == role) }
            .sorted { $0.id < $1.id }
    }
}
