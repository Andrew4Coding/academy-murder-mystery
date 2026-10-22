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
            return ClientView(serverTime: clock.now, identity: .oc(id: id, station: device.station), familyName: nil)
        }
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
            phase: phase
        )
    }
}
