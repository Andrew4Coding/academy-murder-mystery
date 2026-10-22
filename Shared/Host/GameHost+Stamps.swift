import Foundation

struct StampKey: Hashable {
    let family: FamilyID
    let booth: Booth
}

extension GameHost {
    static let undoWindow: TimeInterval = 60

    private func boothStation(_ identity: Identity) throws -> Booth {
        guard case let .oc(id) = identity, let device = state.ocDevices[id] else { throw HostError.notOC }
        guard case let .booth(booth) = device.station else { throw HostError.wrongStation }
        return booth
    }

    func stamp(identity: Identity, family: FamilyID, confirmOffList: Bool) throws {
        let booth = try boothStation(identity)
        try recordStamp(family: family, booth: booth, confirmOffList: confirmOffList)
    }

    func undoStamp(identity: Identity, family: FamilyID) throws {
        let booth = try boothStation(identity)
        let key = StampKey(family: family, booth: booth)
        guard let stampedAt = stampTimes[key], clock.now.timeIntervalSince(stampedAt) <= Self.undoWindow else {
            throw HostError.undoExpired
        }
        try applyAsOC(.undoStamp(family: family, booth: booth))
        stampTimes[key] = nil
    }

    func recordStamp(family: FamilyID, booth: Booth, confirmOffList: Bool) throws {
        guard let engine = state.engine else { throw HostError.notInGame }
        guard let record = engine.state.families[family] else { throw RuleError.unknownFamily(family) }
        if !record.tasks.contains(booth), !confirmOffList {
            throw HostError.offList
        }
        try applyAsOC(.recordStamp(family: family, booth: booth))
        stampTimes[StampKey(family: family, booth: booth)] = clock.now
    }

    func removeStamp(family: FamilyID, booth: Booth) throws {
        try applyAsOC(.undoStamp(family: family, booth: booth))
        stampTimes[StampKey(family: family, booth: booth)] = nil
    }
}
