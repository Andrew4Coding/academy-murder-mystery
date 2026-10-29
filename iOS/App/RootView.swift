import SwiftUI

struct RootView: View {
    let client: GameClient

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
        .onChange(of: client.view) { _, view in LiveStatusController.shared.update(with: view) }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: LiveStatusController.shared.appDidEnterBackground()
            case .active: LiveStatusController.shared.appDidBecomeActive()
            default: break
            }
        }
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
