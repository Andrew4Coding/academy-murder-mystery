import Foundation

extension GameHost {
    func view(for identity: Identity) -> ClientView? {
        switch identity {
        case let .player(id):
            guard let player = state.players[id], let family = state.families[player.family] else { return nil }
            var view = ClientView(
                serverTime: clock.now,
                identity: .player(id: id, name: player.name, family: player.family),
                familyName: family.name
            )
            if let engine = state.engine, let engineFamily = engine.state.families[family.id] {
                view.game = gameView(for: family, engineFamily: engineFamily, engine: engine, viewer: id)
            } else {
                view.lobby = LobbyView(
                    familyName: family.name,
                    joinCode: state.gameCode ?? family.joinCode,
                    playerID: id,
                    playerName: player.name
                )
            }
            return view
        case let .oc(id):
            guard let device = state.ocDevices[id] else { return nil }
            var view = ClientView(serverTime: clock.now, identity: .oc(id: id, station: device.station), familyName: nil)
            if device.station == .admin {
                view.admin = adminView()
            } else if let engine = state.engine {
                view.oc = OCView(sabotage: sabotageView(engine))
            }
            return view
        }
    }

    func adminView() -> AdminView {
        let engine = state.engine
        let phase: PhaseView = switch engine?.state.phase {
        case .none, .running?: .running
        case let .discussion(until)?: .discussion(until: until)
        case let .voting(until, isFinal)?: .voting(until: until, isFinal: isFinal)
        case let .ended(outcome)?: .ended(outcome)
        }
        let rows = state.families.values.sorted { $0.id < $1.id }.map { info -> AdminFamilyRow in
            let game = engine?.state.families[info.id]
            return AdminFamilyRow(
                id: info.id,
                name: info.name,
                playerName: state.player(of: info.id)?.name,
                life: game?.life ?? .alive,
                role: game?.role,
                voted: engine?.state.votes[info.id] != nil
            )
        }
        return AdminView(
            joinCode: state.gameCode,
            playersJoined: state.players.count,
            isLobby: engine == nil,
            phase: phase,
            gameEndsAt: engine?.state.finalVoteAt,
            families: rows,
            sabotage: engine.flatMap { sabotageView($0) },
            skipVotes: engine?.state.skipVotes.count ?? 0,
            votersTotal: engine?.state.aliveFamilies().count ?? 0,
            skipRequested: engine?.state.skipRequested ?? false,
            settings: state.settings,
            werewolfCount: state.werewolfCount,
            rssiThreshold: state.rssiThreshold,
            sightingFreshness: state.sightingFreshness,
            ocPin: state.ocPin,
            setupIssues: engine == nil ? state.setupIssues() : [],
            lastResult: engine?.state.lastResult.map(publicResult),
            votesCast: engine?.state.votes.count ?? 0,
            devices: deviceStatuses(),
            timerPausedAt: engine?.state.timerPausedAt ?? [:]
        )
    }

    func sabotageView(_ engine: GameEngine) -> SabotageView? {
        engine.state.sabotage.map { SabotageView(kind: $0.kind, startedAt: $0.startedAt, endsAt: $0.endsAt) }
    }

    func summary(of id: FamilyID, in engine: GameEngine) -> FamilySummary? {
        guard let info = state.families[id], let family = engine.state.families[id] else { return nil }
        return FamilySummary(
            id: id,
            name: info.name,
            life: family.life,
            revealedRole: engine.state.outcome != nil && family.life == .expelled ? family.role : nil,
            playerID: state.player(of: id)?.id,
            playerName: state.player(of: id)?.name
        )
    }

    private func gameView(for info: FamilyInfo, engineFamily: Family, engine: GameEngine, viewer: PlayerID) -> GameView {
        let allies: [FamilySummary]? = engineFamily.role == .werewolf
            ? engine.state.families.values
            .filter { $0.role == .werewolf && $0.id != engineFamily.id }
            .sorted { $0.id < $1.id }
            .compactMap { summary(of: $0.id, in: engine) }
            : nil
        let phase: PhaseView = switch engine.state.phase {
        case .running: .running
        case let .discussion(until): .discussion(until: until)
        case let .voting(until, isFinal): .voting(until: until, isFinal: isFinal)
        case let .ended(outcome): .ended(outcome)
        }
        return GameView(
            role: engineFamily.role,
            family: info.id,
            familyName: info.name,
            life: engineFamily.life,
            allies: allies,
            families: state.families.keys.sorted().compactMap { summary(of: $0, in: engine) },
            phase: phase,
            announcedDeaths: engine.state.announcedDeaths.compactMap { summary(of: $0, in: engine) },
            myVote: engine.state.votes[info.id],
            votesCast: engine.state.votes.count,
            votersTotal: engine.state.aliveFamilies().count,
            lastResult: engine.state.lastResult.map(publicResult),
            bleToken: state.players[viewer]?.bleToken ?? "",
            proximity: ProximitySettings(rssiThreshold: state.rssiThreshold, sightingFreshness: state.sightingFreshness),
            nearby: engineFamily.role == .werewolf && engineFamily.isAlive
                ? nearbyFamilies(of: info.id).compactMap { summary(of: $0, in: engine) }
                : [],
            killReadyAt: engineFamily.role == .werewolf && engineFamily.isAlive ? engineFamily.killReadyAt : nil,
            sabotage: sabotageView(engine),
            sabotageReadyAt: engineFamily.role == .werewolf ? engine.state.sabotageReadyAt : nil,
            sabotageTimings: SabotageKind.allCases.map { SabotageTiming(kind: $0, duration: engine.state.settings.sabotageDuration(for: $0)) },
            nearbyBodies: engineFamily.isAlive ? nearbyBodies(of: info.id).compactMap { summary(of: $0, in: engine) } : [],
            bodyActive: engineFamily.life == .killed && engine.state.deadSinceLastMeeting.contains(info.id),
            skipVotes: engine.state.skipVotes.count,
            mySkipVote: engine.state.skipVotes.contains(info.id),
            skipRequested: engine.state.skipRequested,
            startsAt: engine.state.startedAt
        )
    }
}
