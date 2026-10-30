import Foundation

extension GameActivityState {
    init(game: GameView, clockOffset: TimeInterval) {
        let done = game.tasks.filter(\.done).count
        let local: (Date) -> Date = { $0.addingTimeInterval(-clockOffset) }

        var kind = Kind.playing
        var end: Date?

        switch game.phase {
        case let .ended(outcome):
            kind = outcome.winner == .villagers ? .villagersWon : .werewolvesWon
        case let .discussion(until):
            kind = .meeting
            end = until
        case let .voting(until, isFinal):
            kind = isFinal ? .finalVote : .voting
            end = until
        case .running:
            if let sabotage = game.sabotage {
                kind = sabotage.kind == .reactor ? .reactor : .oxygen
                end = sabotage.endsAt
            }
        }

        if case .ended = game.phase {
            end = nil
        } else if game.life != .alive {
            kind = game.life == .killed ? .killed : .expelled
            end = nil
        }

        self.init(
            kind: kind,
            tasksDone: done,
            tasksTotal: game.tasks.count,
            countdownEnd: end.map(local),
            familyName: game.familyName
        )
    }

    static func nextChange(of game: GameView, clockOffset: TimeInterval) -> Date? {
        let phaseEnd: Date? = switch game.phase {
        case let .discussion(until), let .voting(until, _): until
        case .running, .ended: nil
        }
        return [phaseEnd, game.sabotage?.endsAt]
            .compactMap(\.self)
            .min()
            .map { $0.addingTimeInterval(-clockOffset) }
    }
}
