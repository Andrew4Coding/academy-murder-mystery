import SwiftUI

struct GameTabsView: View {
    let game: GameView
    let client: GameClient

    private enum GameTab: Hashable {
        case family
        case meeting
    }

    @State private var selection: GameTab = .family

    var body: some View {
        TabView(selection: $selection) {
            Tab("Family", systemImage: "house", value: .family) {
                RoleView(game: game)
            }
            Tab("Meeting", systemImage: "person.3", value: .meeting) {
                MeetingView(game: game, client: client)
            }
        }
        .onChange(of: game.phase.isMeeting) { _, isMeeting in
            if isMeeting {
                selection = .meeting
            }
        }
        .sensoryFeedback(.warning, trigger: game.phase.isMeeting)
    }
}
