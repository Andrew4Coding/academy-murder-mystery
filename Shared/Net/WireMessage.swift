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
    case stamp(family: FamilyID, confirmOffList: Bool)
    case undoStamp(family: FamilyID)
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
}

enum AdminCommand: Codable, Equatable, Sendable {
    case startMeeting
    case extendMeeting(seconds: TimeInterval)
    case adjustTimer(TimerTarget, seconds: TimeInterval)
    case approveSkipDiscussion
    case resolveSabotage
    case removeFamily(FamilyID)
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
