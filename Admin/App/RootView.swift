import SwiftUI

enum AdminSection: String, CaseIterable, Identifiable {
    case setup
    case game
    case display
    case devices

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .setup: "Setup"
        case .game: "Game"
        case .display: "Display"
        case .devices: "Devices"
        }
    }

    var symbol: String {
        switch self {
        case .setup: "slider.horizontal.3"
        case .game: "gamecontroller"
        case .display: "tv"
        case .devices: "iphone.gen3.radiowaves.left.and.right"
        }
    }
}

struct RootView: View {
    let controller: HostController

    @State private var selection: AdminSection? = .setup

    var body: some View {
        NavigationSplitView {
            List(AdminSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            switch selection ?? .setup {
            case .setup:
                SetupView(controller: controller)
            case .game:
                GameControlView(controller: controller)
            case .display:
                DisplaySettingsView()
            case .devices:
                DevicesView(controller: controller)
            }
        }
        .task { await controller.start() }
    }
}

#Preview {
    RootView(controller: HostController(host: try! GameHost(repository: InMemoryGameRepository())))
}
