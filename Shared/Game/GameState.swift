import Foundation

struct GameState: Codable, Equatable, Sendable {
    var settings: GameSettings
    let startedAt: Date
    var families: [FamilyID: Family]
    var phase: Phase = .running
    var sabotage: ActiveSabotage?
    var sabotageReadyAt: Date
    var votes: [FamilyID: VoteChoice] = [:]
    var deadSinceLastMeeting: [FamilyID] = []
    var finalVoteStarted = false
    var finalVotePending = false

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
