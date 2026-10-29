import SwiftUI

struct GameTabsView: View {
    let game: GameView
    let client: GameClient

    private enum GameTab: Hashable {
        case family
        case meeting
        case actions
    }

    @State private var selection: GameTab = .family
    @State private var proximity = ProximityService()
    @State private var notice: GameNotice?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selection) {
            Tab("Family", systemImage: "house", value: .family) {
                RoleView(game: game)
            }
            Tab("Meeting", systemImage: "person.3", value: .meeting) {
                MeetingView(game: game, client: client)
            }
            if game.role == .werewolf {
                Tab("Actions", systemImage: "scope", value: .actions) {
                    ActionsView(game: game, client: client, proximity: proximity)
                }
            }
        }
        .onChange(of: game.phase.isMeeting) { _, isMeeting in
            if isMeeting {
                selection = .meeting
            }
        }
        .safeAreaInset(edge: .top) {
            if let sabotage = game.sabotage {
                SabotageBanner(sabotage: sabotage, client: client)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.default, value: game.sabotage)
        .onChange(of: game.life) { old, new in
            if old == .alive, new == .killed, notice == nil {
                notice = .killed
            }
        }
        .onChange(of: game.phase) { _, phase in
            if case let .ended(outcome) = phase {
                notice = .over(outcome)
            }
        }
        .fullScreenCover(item: $notice) { notice in
            switch notice {
            case .killed: KilledNoticeView { self.notice = nil }
            case let .over(outcome): GameOverView(outcome: outcome) { self.notice = nil }
            }
        }
        .sensoryFeedback(.error, trigger: notice)
        .sensoryFeedback(.warning, trigger: game.phase.isMeeting)
        .sensoryFeedback(.error, trigger: game.sabotage?.startedAt)
        .task(id: game.deadline) { await syncAfterDeadline() }
        .task(id: ProximityPlan(game: game, isActive: scenePhase == .active)) { configureProximity() }
        .onDisappear { proximity.stop() }
    }

    private struct ProximityPlan: Hashable {
        let token: String
        let advertise: Bool
        let scan: Bool

        init(game: GameView, isActive: Bool) {
            token = game.bleToken
            let inPlay = isActive && game.life == .alive && !game.phase.isEnded
            advertise = inPlay
            scan = inPlay && game.role == .werewolf
        }
    }

    private func syncAfterDeadline() async {
        guard let deadline = game.deadline else { return }
        while !Task.isCancelled {
            let wait = deadline.timeIntervalSince(client.serverNow) + 1
            try? await Task.sleep(for: .seconds(max(wait, 2)))
            guard !Task.isCancelled else { return }
            client.send(.sync)
        }
    }

    private func configureProximity() {
        let plan = ProximityPlan(game: game, isActive: scenePhase == .active)
        guard plan.advertise else {
            proximity.stop()
            return
        }
        proximity.configure(token: plan.token, advertise: true, scan: plan.scan) { [client] sightings in
            client.send(.sightings(sightings))
        }
    }
}

private extension GameView {
    var deadline: Date? {
        let phaseEnd: Date? = switch phase {
        case let .discussion(until), let .voting(until, _): until
        case .running, .ended: nil
        }
        return [phaseEnd, sabotage?.endsAt].compactMap(\.self).min()
    }
}

private extension PhaseView {
    var isEnded: Bool {
        if case .ended = self {
            true
        } else {
            false
        }
    }
}
