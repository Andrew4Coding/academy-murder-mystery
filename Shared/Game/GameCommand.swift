import Foundation

enum OCOverride: Codable, Equatable, Sendable {
    case forceKill(FamilyID)
    case revive(FamilyID)
    case endGame(Side)
    case proxyVote(FamilyID)
}

enum GameCommand: Codable, Equatable, Sendable {
    case kill(killer: FamilyID, victim: FamilyID)
    case requestSabotage(by: FamilyID, kind: SabotageKind)
    case resolveSabotage
    case recordStamp(family: FamilyID, booth: Booth)
    case undoStamp(family: FamilyID, booth: Booth)
    case startMeeting
    case reportBody(by: FamilyID, body: FamilyID)
    case castVote(by: FamilyID, choice: VoteChoice)
    case proxyVote(for: FamilyID, choice: VoteChoice)
    case extendMeeting(seconds: TimeInterval)
    case voteSkipDiscussion(by: FamilyID)
    case approveSkipDiscussion
    case override(OCOverride)
}

enum RuleError: Error, Equatable, Sendable {
    case invalidSetup(String)
    case gameEnded
    case unknownFamily(FamilyID)
    case familyNotAlive(FamilyID)
    case notWerewolf(FamilyID)
    case notVillager(FamilyID)
    case wrongPhase
    case cooldownActive(readyAt: Date)
    case sabotageAlreadyActive
    case noActiveSabotage
    case alreadyStamped
    case notStamped
    case invalidVoteTarget
    case notDead(FamilyID)
    case skipNotRequested
}
