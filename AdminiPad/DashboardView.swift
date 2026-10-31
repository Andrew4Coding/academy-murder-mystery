import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case setup
    case game
    case families
    case booths
    case devices

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .setup: "Setup"
        case .game: "Game"
        case .families: "Families"
        case .booths: "Booths"
        case .devices: "Devices"
        }
    }

    var symbol: String {
        switch self {
        case .setup: "slider.horizontal.3"
        case .game: "gamecontroller"
        case .families: "person.3"
        case .booths: "square.grid.2x2"
        case .devices: "iphone.gen3.radiowaves.left.and.right"
        }
    }
}

struct DashboardView: View {
    let admin: AdminView
    let client: GameClient

    @State private var selection: DashboardSection? = .setup

    var body: some View {
        NavigationSplitView {
            List(DashboardSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("Moonfall OC")
            .themedBackground()
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            .toolbar {
                ToolbarItem {
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") { client.signOut() }
                }
            }
        } detail: {
            NavigationStack {
                switch selection ?? .setup {
                case .setup: SetupTab(admin: admin, client: client)
                case .game: GameTab(admin: admin, client: client)
                case .families: FamiliesTab(admin: admin, client: client)
                case .booths: BoothsTab(client: client)
                case .devices: DevicesTab(admin: admin, client: client)
                }
            }
        }
        .onChange(of: admin.isLobby) { _, isLobby in
            selection = isLobby ? .setup : .game
        }
    }
}
