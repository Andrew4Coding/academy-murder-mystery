import Foundation

struct VoteCount: Codable, Equatable, Sendable {
    let choice: VoteChoice
    let count: Int
}

struct Reveal: Codable, Equatable, Sendable {
    let family: FamilyID
    let role: Role
}

struct GameEvent: Codable, Equatable, Sendable {
    enum Kind: Codable, Equatable, Sendable {
        case gameStarted(werewolves: [FamilyID])
        case familyKilled(FamilyID, by: FamilyID?)
        case sabotageStarted(kind: SabotageKind, by: FamilyID, endsAt: Date)
        case sabotageResolved
        case sabotageExpired
        case stampRecorded(FamilyID, Booth)
        case stampUndone(FamilyID, Booth)
        case meetingStarted(deadFamilies: [FamilyID])
        case votingOpened(isFinal: Bool)
        case voteCast(by: FamilyID)
        case voteClosed(tally: [VoteCount], expelled: [Reveal], isFinal: Bool)
        case ocOverride(OCOverride)
        case gameEnded(Outcome)
    }

    let at: Date
    let kind: Kind
}
