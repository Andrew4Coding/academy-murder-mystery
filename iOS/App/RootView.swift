import SwiftUI

struct RootView: View {
    let client: GameClient

    var body: some View {
        Group {
            if let view = client.view {
                switch view.identity {
                case .player:
                    if let game = view.game {
                        RoleView(game: game)
                    } else if let lobby = view.lobby {
                        FamilyLobbyView(lobby: lobby, client: client)
                    } else {
                        ProgressView()
                    }
                case .oc:
                    ContentUnavailableView("OC mode", systemImage: "person.badge.key", description: Text("Coming soon."))
                }
            } else {
                JoinView(client: client)
            }
        }
        .task { client.start() }
    }
}

#Preview {
    RootView(client: GameClient(transport: LoopbackHub().makeClient(), store: InMemoryIdentityStore()))
}
