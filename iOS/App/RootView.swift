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
                        WaitingForStateView(client: client)
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

struct ReconnectingView: View {
    let client: GameClient

    var body: some View {
        NavigationStack {
            ConnectionStatusView(status: .connecting) { client.refresh() }
                .overlay(alignment: .bottom) {
                    Text("Reconnecting to your game. This usually takes a few seconds.")
                        .secondaryText()
                        .multilineTextAlignment(.center)
                        .padding(Spacing.md)
                }
                .themedBackground()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Start Over", role: .destructive) { client.signOut() }
                            .accessibilityHint("Forgets this game and returns to the join screen")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Retry", systemImage: "arrow.clockwise") { client.refresh() }
                    }
                }
        }
    }
}

struct WaitingForStateView: View {
    let client: GameClient

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                ProgressView().controlSize(.large)
                Text("Getting your game ready").font(.title2.bold())
            } description: {
                Text("Hang on, the host is sending your family details.")
            } actions: {
                Button("Refresh", systemImage: "arrow.clockwise") { client.refresh() }
                    .buttonStyle(.secondary)
                    .frame(maxWidth: 280)
            }
            .themedBackground()
        }
    }
}
