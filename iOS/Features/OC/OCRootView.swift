import SwiftUI

struct OCRootView: View {
    let view: ClientView
    let client: GameClient

    var body: some View {
        if case let .oc(_, station) = view.identity {
            switch station {
            case let .sabotage(kind):
                SabotageStationView(kind: kind, oc: view.oc, client: client)
            case .admin:
                ContentUnavailableView {
                    Label("Use the iPad dashboard", systemImage: "ipad")
                } description: {
                    Text("This station belongs to the Moonfall OC app.")
                } actions: {
                    OCSignOutButton(client: client)
                }
                .foregroundStyle(Theme.text)
                .themedBackground()
            case .townHall:
                ContentUnavailableView {
                    Label("Station removed", systemImage: "xmark.circle")
                } description: {
                    Text("The Town Hall observer no longer exists. Sign out and pick a sabotage station.")
                } actions: {
                    OCSignOutButton(client: client)
                }
                .foregroundStyle(Theme.text)
                .themedBackground()
            }
        }
    }
}

struct OCSignOutButton: View {
    let client: GameClient

    var body: some View {
        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") { client.signOut() }
            .accessibilityHint("Returns to the join screen")
    }
}

struct WaitingForGameView: View {
    var body: some View {
        ContentUnavailableView(
            "No families yet",
            systemImage: "person.3",
            description: Text("Families appear here once the game has started.")
        )
        .foregroundStyle(Theme.text)
        .themedBackground()
    }
}
