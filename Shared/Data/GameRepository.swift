import Foundation
import SwiftData

struct StoredGame: Equatable, Sendable {
    let id: UUID
    var state: HostState
    var updatedAt: Date
}

@MainActor
protocol GameRepository {
    func latest() throws -> StoredGame?
    func save(_ game: StoredGame) throws
    func append(_ events: [GameEvent], to gameID: UUID) throws
    func events(for gameID: UUID) throws -> [GameEvent]
}

@MainActor
final class InMemoryGameRepository: GameRepository {
    private var games: [UUID: StoredGame] = [:]
    private var logs: [UUID: [GameEvent]] = [:]

    func latest() throws -> StoredGame? {
        games.values.max { $0.updatedAt < $1.updatedAt }
    }

    func save(_ game: StoredGame) throws {
        games[game.id] = game
    }

    func append(_ events: [GameEvent], to gameID: UUID) throws {
        logs[gameID, default: []] += events
    }

    func events(for gameID: UUID) throws -> [GameEvent] {
        logs[gameID] ?? []
    }
}

@MainActor
final class SwiftDataGameRepository: GameRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func latest() throws -> StoredGame? {
        var descriptor = FetchDescriptor<GameRecord>(
            predicate: #Predicate { !$0.simulated },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let record = try context.fetch(descriptor).first else { return nil }
        let state = try WireCodec.decode(HostState.self, from: record.snapshot)
        return StoredGame(id: record.id, state: state, updatedAt: record.updatedAt)
    }

    func save(_ game: StoredGame) throws {
        let id = game.id
        let snapshot = try WireCodec.encode(game.state)
        let existing = try context.fetch(FetchDescriptor<GameRecord>(predicate: #Predicate { $0.id == id })).first
        if let existing {
            existing.snapshot = snapshot
            existing.updatedAt = game.updatedAt
            existing.simulated = game.state.simulated
        } else {
            context.insert(GameRecord(
                id: id,
                createdAt: game.updatedAt,
                updatedAt: game.updatedAt,
                simulated: game.state.simulated,
                snapshot: snapshot
            ))
        }
        try context.save()
    }

    func append(_ events: [GameEvent], to gameID: UUID) throws {
        var descriptor = FetchDescriptor<GameEventRecord>(
            predicate: #Predicate { $0.gameID == gameID },
            sortBy: [SortDescriptor(\.seq, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        var seq = try context.fetch(descriptor).first?.seq ?? -1
        for event in events {
            seq += 1
            try context.insert(GameEventRecord(gameID: gameID, seq: seq, at: event.at, payload: WireCodec.encode(event)))
        }
        try context.save()
    }

    func events(for gameID: UUID) throws -> [GameEvent] {
        let descriptor = FetchDescriptor<GameEventRecord>(
            predicate: #Predicate { $0.gameID == gameID },
            sortBy: [SortDescriptor(\.seq)]
        )
        return try context.fetch(descriptor).map { try WireCodec.decode(GameEvent.self, from: $0.payload) }
    }
}
