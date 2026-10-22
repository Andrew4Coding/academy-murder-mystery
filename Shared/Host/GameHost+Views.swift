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
                    joinCode: family.joinCode,
                    members: memberViews(of: family),
                    isHead: family.head == id,
                    hasHead: family.head != nil
                )
            }
            return view
        case let .oc(id):
            guard let device = state.ocDevices[id] else { return nil }
            var view = ClientView(serverTime: clock.now, identity: .oc(id: id, station: device.station), familyName: nil)
            if let engine = state.engine {
                view.oc = OCView(sabotage: sabotageView(engine), families: ocRows(engine, station: device.station))
            }
            return view
        }
    }

    func ocRows(_ engine: GameEngine, station: OCStation) -> [OCFamilyRow] {
        let booth: Booth? = if case let .booth(booth) = station {
            booth
        } else {
            nil
        }
        return engine.state.families.values.sorted { $0.id < $1.id }.map { family in
            OCFamilyRow(
                id: family.id,
                name: state.families[family.id]?.name ?? "Unknown",
                life: family.life,
                stampsDone: family.stamps.intersection(family.tasks).count,
                stampsTotal: family.tasks.count,
                onList: booth.map { family.tasks.contains($0) },
                stamped: booth.map { family.stamps.contains($0) }
            )
        }
    }

    func sabotageView(_ engine: GameEngine) -> SabotageView? {
        engine.state.sabotage.map { SabotageView(kind: $0.kind, startedAt: $0.startedAt, endsAt: $0.endsAt) }
    }

    func memberViews(of family: FamilyInfo) -> [MemberView] {
        state.members(of: family.id).map { MemberView(id: $0.id, name: $0.name, isHead: family.head == $0.id) }
    }

    func summary(of id: FamilyID, in engine: GameEngine) -> FamilySummary? {
        guard let info = state.families[id], let family = engine.state.families[id] else { return nil }
        return FamilySummary(
            id: id,
            name: info.name,
            life: family.life,
            revealedRole: family.life == .expelled ? family.role : nil
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
            isHead: info.head == viewer,
            members: memberViews(of: info),
            tasks: engineFamily.tasks.sorted { $0.rawValue < $1.rawValue }
                .map { TaskProgress(booth: $0, done: engineFamily.stamps.contains($0)) },
            allies: allies,
            families: state.families.keys.sorted().compactMap { summary(of: $0, in: engine) },
            phase: phase,
            announcedDeaths: engine.state.announcedDeaths.compactMap { summary(of: $0, in: engine) },
            myVote: info.head == viewer ? engine.state.votes[info.id] : nil,
            votesCast: engine.state.votes.count,
            votersTotal: engine.state.aliveFamilies().count,
            lastResult: engine.state.lastResult.map(resultView),
            bleToken: state.players[viewer]?.bleToken ?? "",
            proximity: ProximitySettings(rssiThreshold: state.rssiThreshold, sightingFreshness: state.sightingFreshness),
            nearby: engineFamily.role == .werewolf && engineFamily.isAlive
                ? nearbyFamilies(of: info.id).compactMap { summary(of: $0, in: engine) }
                : [],
            killReadyAt: engineFamily.role == .werewolf && engineFamily.isAlive ? engineFamily.killReadyAt : nil,
            sabotage: sabotageView(engine),
            sabotageReadyAt: engineFamily.role == .werewolf ? engine.state.sabotageReadyAt : nil
        )
    }

    private func resultView(_ result: VoteResult) -> VoteResultView {
        let rows = result.tally.map { count -> ResultRow in
            switch count.choice {
            case let .family(id): ResultRow(name: state.families[id]?.name ?? "Unknown", count: count.count, isSkip: false)
            case .skip: ResultRow(name: "Skip", count: count.count, isSkip: true)
            }
        }
        let expelled = result.expelled.map { ExpelledView(name: state.families[$0.family]?.name ?? "Unknown", role: $0.role) }
        return VoteResultView(rows: rows, expelled: expelled, isFinal: result.isFinal)
    }
}
