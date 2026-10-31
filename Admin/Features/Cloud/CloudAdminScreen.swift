import SwiftUI

struct CloudAdminScreen: View {
    let mode: HostModeController
    let section: AdminSection

    var body: some View {
        if let client = mode.adminClient, let admin = client.view?.admin {
            NavigationStack {
                switch section {
                case .game: GameTab(admin: admin, client: client)
                case .families: FamiliesTab(admin: admin, client: client)
                case .booths: BoothsTab(client: client)
                default: SetupTab(admin: admin, client: client)
                }
            }
        } else {
            ContentUnavailableView(
                "Connecting to the cloud host",
                systemImage: "cloud",
                description: Text(mode.adminClient?.lastError ?? "Waiting for the cloud host\u{2026}")
            )
            .themedBackground()
            .navigationTitle(section.title)
        }
    }
}
