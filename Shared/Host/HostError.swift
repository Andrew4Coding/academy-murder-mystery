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
    case notAPlayer
    case invalidName
    case photoTooLarge
    case notNearBody
    case setup(String)
    case notNearby
    case notOC
    case offList
    case undoExpired
    case wrongStation
    case notInGame
    case familyHasMembers

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
        case .notAPlayer: "Only players can do that."
        case .notNearBody: "Get closer to the body to report it."
        case .photoTooLarge: "That photo is too large."
        case .invalidName: "Family names need 1 to 24 characters."
        case let .setup(reason): reason
        case .notNearby: "That family isn't close enough."
        case .notOC: "Only organisers can do that."
        case .offList: "Not on this family's list."
        case .undoExpired: "Too late to undo this stamp."
        case .wrongStation: "This sabotage is handled at a different station."
        case .notInGame: "There's no game running."
        case .familyHasMembers: "That family already has members."
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
        case .skipNotRequested: "Most families haven't voted to skip yet."
        case .timerFinished: "That timer already finished."
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
