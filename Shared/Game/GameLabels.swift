extension Role {
    var title: String {
        switch self {
        case .villager: "Villager"
        case .werewolf: "Werewolf"
        }
    }

    var symbol: String {
        switch self {
        case .villager: "house.fill"
        case .werewolf: "moon.stars.fill"
        }
    }
}

extension LifeState {
    var title: String {
        switch self {
        case .alive: "In the game"
        case .killed: "Eliminated"
        case .expelled: "Voted out"
        }
    }
}

extension Outcome.Reason {
    var explanation: String {
        switch self {
        case .allWerewolvesRemoved: "Every werewolf family is out of the game."
        case .parity: "There are as many werewolves as villagers left."
        case .sabotageExpired: "A sabotage wasn't stopped in time."
        case .finalVoteSucceeded: "The final vote caught every werewolf family."
        case .finalVoteFailed: "The final vote missed a werewolf family."
        case .ocEnded: "The organiser ended the game."
        }
    }
}
