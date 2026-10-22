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
        .sensoryFeedback(.warning, trigger: game.phase.isMeeting)
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

private extension PhaseView {
    var isEnded: Bool {
        if case .ended = self {
            true
        } else {
            false
        }
    }
}
