import Foundation

struct HostSnapshot: Codable, Equatable, Sendable {
    var state: HostState
    var selfies: [Selfie]
    var boothMap: BoothMap?
    var booths: BoothCatalog?

    private enum CodingKeys: String, CodingKey {
        case state, selfies, map, mapJPEG, booths
    }

    init(state: HostState, selfies: [Selfie], boothMap: BoothMap?, booths: BoothCatalog? = nil) {
        self.state = state
        self.selfies = selfies
        self.boothMap = boothMap
        self.booths = booths
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
        booths = try container.decodeIfPresent(BoothCatalog.self, forKey: .booths)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state, forKey: .state)
        try container.encode(selfies, forKey: .selfies)
        try container.encodeIfPresent(boothMap, forKey: .map)
        try container.encodeIfPresent(boothMap?.jpeg, forKey: .mapJPEG)
        try container.encodeIfPresent(booths, forKey: .booths)
    }
}

extension GameHost {
    func exportSnapshot() -> HostSnapshot {
        HostSnapshot(state: state, selfies: selfieList, boothMap: boothMap, booths: boothCatalog)
    }

    var hasSignedInClients: Bool {
        sessions.values.contains { $0.identity != nil }
    }
}
