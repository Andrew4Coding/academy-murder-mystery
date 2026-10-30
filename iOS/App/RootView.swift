import SwiftUI

struct RootView: View {
    let client: GameClient
    @State private var liveActivity = LiveActivityController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let view = client.view {
                switch view.identity {
                case .player:
                    if let game = view.game {
                        GameTabsView(game: game, client: client)
                    } else if let lobby = view.lobby {
                        FamilyLobbyView(lobby: lobby, client: client)
                    } else {
                        ProgressView()
                    }
                case .oc:
                    OCRootView(view: view, client: client)
                }
            } else if client.isResuming {
                ReconnectingView(client: client)
            } else {
                JoinView(client: client)
            }
        }
        .task { client.start() }
        .onChange(of: client.view) { syncLiveActivity() }
        .onChange(of: scenePhase) { syncLiveActivity() }
    }

    private func syncLiveActivity() {
        guard scenePhase == .active else { return }
        liveActivity.sync(view: client.view, clock: client.serverClock)
    }
}

private struct ReconnectingView: View {
    let client: GameClient

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Reconnecting to the game…")
                .foregroundStyle(.secondary)
            Button("Start Over", role: .destructive) { client.signOut() }
                .buttonStyle(.bordered)
        }
    }
}

#Preview {
    RootView(client: GameClient(transport: LoopbackHub().makeClient(), store: InMemoryIdentityStore()))
}
