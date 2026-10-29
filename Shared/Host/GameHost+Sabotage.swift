import Foundation

extension GameHost {
    func requestSabotage(identity: Identity, kind: SabotageKind) throws {
        guard case let .player(playerID) = identity, let player = state.players[playerID] else { throw HostError.notAPlayer }
        guard state.engine != nil else { throw HostError.notInGame }
        try applyAsOC(.requestSabotage(by: player.family, kind: kind))
    }

    func adminCommand(_ command: AdminCommand, identity: Identity) throws {
        guard case let .oc(id) = identity, state.ocDevices[id]?.station == .admin else { throw HostError.notOC }
        switch command {
        case .startMeeting: try applyAsOC(.startMeeting)
        case let .extendMeeting(seconds): try extendMeeting(seconds: seconds)
        case .approveSkipDiscussion: try approveSkipDiscussion()
        case .resolveSabotage: try applyAsOC(.resolveSabotage)
        case let .removeFamily(family): try removeFamily(family)
        }
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
