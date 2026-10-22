import Foundation

typealias PlayerID = UUID
typealias ClientID = UUID

enum OCStation: Hashable, Codable, Sendable {
    case booth(Booth)
    case sabotage(SabotageKind)
    case townHall
}

struct Player: Codable, Equatable, Sendable {
    let id: PlayerID
    var name: String
    let family: FamilyID
    let bleToken: String
}

struct FamilyInfo: Codable, Equatable, Sendable, Identifiable {
    let id: FamilyID
    var name: String
    let joinCode: String
    var head: PlayerID?
}

struct OCDevice: Codable, Equatable, Sendable {
    let id: UUID
    var station: OCStation
}

enum Identity: Codable, Equatable, Hashable, Sendable {
    case player(PlayerID)
    case oc(UUID)
}

enum Credential: Codable, Equatable, Sendable {
    case familyCode(String)
    case ocPin(String)
    case resume(UUID)
}

struct Hello: Codable, Equatable, Sendable {
    var version: Int = WireVersion.current
    var credential: Credential
    var name: String?
    var station: OCStation?
}

enum WireVersion {
    static let current = 1
}

struct Sighting: Codable, Equatable, Sendable {
    let token: String
    let rssi: Int
}

struct ProximitySettings: Codable, Equatable, Sendable {
    let rssiThreshold: Int
    let sightingFreshness: TimeInterval
}
