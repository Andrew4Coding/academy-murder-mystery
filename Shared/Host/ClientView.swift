import Foundation

enum IdentityView: Codable, Equatable, Sendable {
    case player(id: PlayerID, name: String, family: FamilyID)
    case oc(id: UUID, station: OCStation)
}

struct ClientView: Codable, Equatable, Sendable {
    var serverTime: Date
    var identity: IdentityView
    var familyName: String?
}

struct Welcome: Codable, Equatable, Sendable {
    let resumeID: UUID
    let serverTime: Date
}

struct ServerClock: Equatable, Sendable {
    private(set) var offset: TimeInterval = 0

    mutating func sync(serverTime: Date, receivedAt local: Date) {
        offset = serverTime.timeIntervalSince(local)
    }

    func now(local: Date = Date()) -> Date {
        local.addingTimeInterval(offset)
    }
}
