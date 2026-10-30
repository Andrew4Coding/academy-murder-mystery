import SwiftUI

extension GameActivityState.Kind {
    var title: String {
        switch self {
        case .playing: "Game on"
        case .killed: "You were killed"
        case .expelled: "You were voted out"
        case .meeting: "Meeting"
        case .voting: "Voting"
        case .finalVote: "Final vote"
        case .reactor: "Sabotage: Reactor"
        case .oxygen: "Sabotage: Oxygen"
        case .villagersWon: "Villagers win!"
        case .werewolvesWon: "Werewolves win!"
        }
    }

    var symbol: String {
        switch self {
        case .playing: "moon.stars.fill"
        case .killed, .expelled: "person.fill.xmark"
        case .meeting: "bubble.left.and.bubble.right.fill"
        case .voting, .finalVote: "checkmark.seal.fill"
        case .reactor, .oxygen: "exclamationmark.triangle.fill"
        case .villagersWon: "house.fill"
        case .werewolvesWon: "moon.stars.fill"
        }
    }

    var tint: Color {
        switch self {
        case .playing, .villagersWon: .green
        case .killed, .expelled, .reactor, .oxygen: .red
        case .meeting, .voting, .finalVote: .orange
        case .werewolvesWon: .indigo
        }
    }
}
