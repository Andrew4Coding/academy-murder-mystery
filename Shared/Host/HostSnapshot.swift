import Foundation

struct HostSnapshot: Codable, Equatable, Sendable {
    var state: HostState
    var selfies: [Selfie]
    var boothMap: BoothMap?

    private enum CodingKeys: String, CodingKey {
        case state, selfies, map, mapJPEG
    }

    init(state: HostState, selfies: [Selfie], boothMap: BoothMap?) {
        self.state = state
        self.selfies = selfies
        self.boothMap = boothMap
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decode(HostState.self, forKey: .state)
        selfies = try container.decodeIfPresent([Selfie].self, forKey: .selfies) ?? []
        if let map = try container.decodeIfPresent(BoothMap.self, forKey: .map) {
            boothMap = BoothMap(jpeg: map.jpeg)
        } else if let jpeg = try container.decodeIfPresent(Data.self, forKey: .mapJPEG) {
            boothMap = BoothMap(jpeg: jpeg)
        } else {
            boothMap = nil
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state, forKey: .state)
        try container.encode(selfies, forKey: .selfies)
        try container.encodeIfPresent(boothMap, forKey: .map)
        try container.encodeIfPresent(boothMap?.jpeg, forKey: .mapJPEG)
    }
}

extension GameHost {
    func exportSnapshot() -> HostSnapshot {
        HostSnapshot(state: state, selfies: selfieList, boothMap: boothMap)
    }

    var hasSignedInClients: Bool {
        sessions.values.contains { $0.identity != nil }
    }
}
