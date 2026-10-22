import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [GameRecord.self, GameEventRecord.self]
    }

    @Model
    final class GameRecord {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var simulated: Bool
        var snapshot: Data

        init(id: UUID, createdAt: Date, updatedAt: Date, simulated: Bool, snapshot: Data) {
            self.id = id
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.simulated = simulated
            self.snapshot = snapshot
        }
    }

    @Model
    final class GameEventRecord {
        var gameID: UUID
        var seq: Int
        var at: Date
        var payload: Data

        init(gameID: UUID, seq: Int, at: Date, payload: Data) {
            self.gameID = gameID
            self.seq = seq
            self.at = at
            self.payload = payload
        }
    }
}
