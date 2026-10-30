import Foundation

struct GameActivityState: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case playing
        case killed
        case expelled
        case meeting
        case voting
        case finalVote
        case reactor
        case oxygen
        case villagersWon
        case werewolvesWon
    }

    let kind: Kind
    let countdownEnd: Date?
    let familyName: String
}

extension GameActivityState {
    var isEnded: Bool {
        kind == .villagersWon || kind == .werewolvesWon
    }
}
