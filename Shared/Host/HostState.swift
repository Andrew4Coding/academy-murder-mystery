import Foundation

struct HostState: Codable, Equatable, Sendable {
    var settings = GameSettings.standard
    var werewolfCount = 1
    var maxFamilySize = 6
    var gameCode: String?
    var families: [FamilyID: FamilyInfo] = [:]
    var players: [PlayerID: Player] = [:]
    var ocDevices: [UUID: OCDevice] = [:]
    var ocPin: String
    var rssiThreshold = -65
    var sightingFreshness: TimeInterval = 5
    var engine: GameEngine?
    var simulated = false

    var isLobby: Bool {
        engine == nil
    }

    func members(of family: FamilyID) -> [Player] {
        players.values.filter { $0.family == family }.sorted { $0.name < $1.name }
    }
}
