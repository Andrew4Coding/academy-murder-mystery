import Foundation

enum ClientMessage: Codable, Equatable, Sendable {
    case hello(Hello)
    case probeReply(UUID)
    case claimHead
    case handOverHead(to: PlayerID)
    case vote(VoteChoice)
    case sightings([Sighting])
    case kill(victim: FamilyID)
    case requestSabotage(SabotageKind)
    case resolveSabotage
}

enum ServerMessage: Codable, Equatable, Sendable {
    case welcome(Welcome)
    case state(ClientView)
    case rejected(String)
    case probe(UUID)
}

enum WireCodec {
    static func encode(_ value: some Encodable) throws -> Data {
        try JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
