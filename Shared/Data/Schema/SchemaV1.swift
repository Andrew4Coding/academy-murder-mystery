import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Item.self]
    }

    @Model
    final class Item {
        @Attribute(.unique) var id: UUID
        var title: String
        var notes: String
        var createdAt: Date

        init(id: UUID = UUID(), title: String, notes: String = "", createdAt: Date = .now) {
            self.id = id
            self.title = title
            self.notes = notes
            self.createdAt = createdAt
        }
    }
}
