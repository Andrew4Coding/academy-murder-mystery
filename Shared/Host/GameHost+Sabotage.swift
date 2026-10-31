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
        case .ringBell: ringBell()
        case .startMeeting: try applyAsOC(.startMeeting)
        case let .extendMeeting(seconds): try extendMeeting(seconds: seconds)
        case let .adjustTimer(target, seconds): try applyAsOC(.adjustTimer(target, seconds: seconds))
        case let .pauseTimer(target): try applyAsOC(.pauseTimer(target))
        case let .resumeTimer(target): try applyAsOC(.resumeTimer(target))
        case .approveSkipDiscussion: try approveSkipDiscussion()
        case .resolveSabotage: try applyAsOC(.resolveSabotage)
        case let .removeFamily(family): try removeFamily(family)
        case let .removeDevice(device): try removeDevice(device)
        case let .updateSettings(werewolfCount, settings): try updateSettings(werewolfCount: werewolfCount, settings: settings)
        case let .setProximity(rssi, freshness): setProximity(rssiThreshold: rssi, sightingFreshness: freshness)
        case .startGame: try startGame()
        case .newGame: try newGame()
        case let .renameFamily(family, name): try renameFamily(family, to: name)
        case .regenerateOCPIN: regenerateOCPIN()
        case let .setBoothMap(data): try setBoothMap(imageData: data)
        case .removeBoothMap: try removeBoothMap()
        case let .eliminate(families):
            for family in families { try applyAsOC(.override(.forceKill(family))) }
        case let .revive(families):
            for family in families { try applyAsOC(.override(.revive(family))) }
        case let .proxyVote(family, choice): try applyAsOC(.proxyVote(for: family, choice: choice))
        case let .endGame(side): try applyAsOC(.override(.endGame(side)))
        case .checkConnectivity: checkConnectivity()
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
