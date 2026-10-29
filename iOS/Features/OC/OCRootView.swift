import SwiftUI

struct OCRootView: View {
    let view: ClientView
    let client: GameClient

    var body: some View {
        if case let .oc(_, station) = view.identity {
            switch station {
            case let .booth(booth):
                BoothStampView(booth: booth, oc: view.oc, client: client)
            case let .sabotage(kind):
                SabotageStationView(kind: kind, oc: view.oc, client: client)
            case .townHall:
                ContentUnavailableView {
                    Label("Station removed", systemImage: "xmark.circle")
                } description: {
                    Text("The Town Hall observer no longer exists. Sign out and pick a booth.")
                } actions: {
                    OCSignOutButton(client: client)
                }
            }
        }
    }
}

struct OCSignOutButton: View {
    let client: GameClient

    var body: some View {
        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") { client.signOut() }
    }
}

struct WaitingForGameView: View {
    var body: some View {
        ContentUnavailableView(
            "No families yet",
            systemImage: "person.3",
            description: Text("Families appear here once the game has started.")
        )
    }
}
