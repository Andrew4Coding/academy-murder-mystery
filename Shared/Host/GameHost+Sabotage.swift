import Foundation

extension GameHost {
    func requestSabotage(identity: Identity, kind: SabotageKind) throws {
        guard case let .player(playerID) = identity, let player = state.players[playerID] else { throw HostError.notAPlayer }
        guard state.engine != nil else { throw HostError.notInGame }
        try applyAsOC(.requestSabotage(by: player.family, kind: kind))
    }

    func resolveSabotage(identity: Identity) throws {
        guard case let .oc(id) = identity, let device = state.ocDevices[id] else { throw HostError.notOC }
        guard let active = state.engine?.state.sabotage else { throw RuleError.noActiveSabotage }
        switch device.station {
        case .townHall: break
        case let .sabotage(kind) where kind == active.kind: break
        default: throw HostError.wrongStation
        }
        try applyAsOC(.resolveSabotage)
    }
}
