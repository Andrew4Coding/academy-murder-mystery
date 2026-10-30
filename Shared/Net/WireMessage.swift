import Foundation

enum ClientMessage: Codable, Equatable, Sendable {
    case hello(Hello)
    case probeReply(UUID)
    case renameFamily(String)
    case voteSkipDiscussion
    case reportBody(FamilyID)
    case admin(AdminCommand)
    case selfie(Data)
    case vote(VoteChoice)
    case sightings([Sighting])
    case kill(victim: FamilyID)
    case requestSabotage(SabotageKind)
    case resolveSabotage
    case leave
    case sync
}

enum ServerMessage: Codable, Equatable, Sendable {
    case welcome(Welcome)
    case state(ClientView)
    case rejected(String)
    case probe(UUID)
    case reset
    case selfies([Selfie])
    case map(BoothMap?)
}

enum AdminCommand: Codable, Equatable, Sendable {
    case ringBell
    case startMeeting
    case extendMeeting(seconds: TimeInterval)
    case adjustTimer(TimerTarget, seconds: TimeInterval)
    case approveSkipDiscussion
    case resolveSabotage
    case removeFamily(FamilyID)
    case removeDevice(UUID)
    case updateSettings(werewolfCount: Int, settings: GameSettings)
    case setProximity(rssiThreshold: Int, sightingFreshness: TimeInterval)
    case startGame
    case newGame
    case renameFamily(FamilyID, String)
    case regenerateOCPIN
    case setBoothMap(Data)
    case removeBoothMap
    case eliminate([FamilyID])
    case revive([FamilyID])
    case proxyVote(family: FamilyID, choice: VoteChoice)
    case endGame(Side)
    case checkConnectivity
}

struct Selfie: Codable, Equatable, Sendable {
    let player: PlayerID
    let jpeg: Data
}

enum WireCodec {
    static func encode(_ value: some Encodable) throws -> Data {
        try JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
