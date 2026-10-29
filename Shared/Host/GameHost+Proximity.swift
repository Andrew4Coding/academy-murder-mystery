import Foundation

struct SightingRecord: Equatable {
    var rssi: Int
    var at: Date
}

extension GameHost {
    func receiveSightings(_ list: [Sighting], identity: Identity) throws {
        guard case let .player(playerID) = identity, let observer = state.players[playerID] else { throw HostError.notAPlayer }
        let owners = Dictionary(state.players.values.map { ($0.bleToken, $0.family) }, uniquingKeysWith: { first, _ in first })
        let now = clock.now
        for sighting in list {
            guard let target = owners[sighting.token], target != observer.family else { continue }
            let current = sightings[observer.family]?[target]
            let isFresh = current.map { now.timeIntervalSince($0.at) <= state.sightingFreshness } ?? false
            if let current, isFresh, current.rssi > sighting.rssi, now.timeIntervalSince(current.at) < 1 {
                continue
            }
            sightings[observer.family, default: [:]][target] = SightingRecord(rssi: sighting.rssi, at: now)
        }
        refreshNearby()
    }

    func nearbyFamilies(of killer: FamilyID) -> [FamilyID] {
        guard let engine = state.engine else { return [] }
        let now = clock.now
        let records = sightings[killer] ?? [:]
        return records
            .filter { target, record in
                engine.state.families[target].map { $0.role == .villager && $0.isAlive } ?? false
                    && record.rssi >= state.rssiThreshold
                    && now.timeIntervalSince(record.at) <= state.sightingFreshness
            }
            .keys
            .sorted()
    }

    func nearbyBodies(of viewer: FamilyID) -> [FamilyID] {
        guard let engine = state.engine, engine.state.families[viewer]?.isAlive == true else { return [] }
        let now = clock.now
        return (sightings[viewer] ?? [:])
            .filter { target, record in
                engine.state.families[target]?.life == .killed
                    && engine.state.deadSinceLastMeeting.contains(target)
                    && record.rssi >= state.rssiThreshold
                    && now.timeIntervalSince(record.at) <= state.sightingFreshness
            }
            .keys
            .sorted()
    }

    func reportBody(identity: Identity, body: FamilyID) throws {
        guard case let .player(playerID) = identity, let player = state.players[playerID] else { throw HostError.notAPlayer }
        guard state.engine != nil else { throw HostError.notInGame }
        guard nearbyBodies(of: player.family).contains(body) else { throw HostError.notNearBody }
        try applyAsOC(.reportBody(by: player.family, body: body))
        refreshNearby()
    }

    func refreshNearby() {
        guard let engine = state.engine else { return }
        var changed = false
        for family in engine.state.families.values where family.role == .werewolf {
            let current = Set(nearbyFamilies(of: family.id))
            if lastNearby[family.id] != current {
                lastNearby[family.id] = current
                changed = true
            }
        }
        for family in engine.state.families.values where family.isAlive {
            let current = Set(nearbyBodies(of: family.id))
            if lastBodies[family.id] ?? [] != current {
                lastBodies[family.id] = current
                changed = true
            }
        }
        if changed {
            broadcast()
        }
    }

    func kill(identity: Identity, victim: FamilyID) throws {
        guard case let .player(playerID) = identity, let player = state.players[playerID] else { throw HostError.notAPlayer }
        guard state.engine != nil else { throw HostError.notInGame }
        guard nearbyFamilies(of: player.family).contains(victim) else { throw HostError.notNearby }
        try applyAsOC(.kill(killer: player.family, victim: victim))
        sightings[player.family]?[victim] = nil
        refreshNearby()
    }

    func setProximity(rssiThreshold: Int, sightingFreshness: TimeInterval) {
        replaceState {
            $0.rssiThreshold = rssiThreshold
            $0.sightingFreshness = sightingFreshness
        }
    }
}
