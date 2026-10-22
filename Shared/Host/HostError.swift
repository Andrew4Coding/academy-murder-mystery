import Foundation

enum HostError: Error, Equatable, Sendable {
    case notSignedIn
    case unsupportedVersion
    case invalidCredential
    case tooManyAttempts
    case nameRequired
    case familyFull
    case gameAlreadyStarted
    case unknownDevice

    var message: String {
        switch self {
        case .notSignedIn: "Join a family or enter the OC PIN first."
        case .unsupportedVersion: "This app version is too old or too new for the host. Update the app."
        case .invalidCredential: "That code isn't valid. Check it and try again."
        case .tooManyAttempts: "Too many attempts. Wait a moment and try again."
        case .nameRequired: "Enter your name to join."
        case .familyFull: "That family is already full."
        case .gameAlreadyStarted: "The game has already started."
        case .unknownDevice: "This device isn't registered with the host any more."
        }
    }
}

extension RuleError {
    var message: String {
        switch self {
        case let .invalidSetup(reason): reason
        case .gameEnded: "The game has ended."
        case .unknownFamily: "Unknown family."
        case .familyNotAlive: "That family is no longer in the game."
        case .notWerewolf: "Only werewolf families can do that."
        case .notVillager: "That family can't be targeted."
        case .wrongPhase: "That isn't allowed right now."
        case .cooldownActive: "Still on cooldown."
        case .sabotageAlreadyActive: "A sabotage is already running."
        case .noActiveSabotage: "There's no sabotage to resolve."
        case .alreadyStamped: "Already stamped."
        case .notStamped: "There's no stamp to undo."
        case .invalidVoteTarget: "That family can't receive votes."
        case .notDead: "That family is still in the game."
        }
    }
}
