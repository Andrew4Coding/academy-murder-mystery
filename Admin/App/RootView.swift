import SwiftUI

enum AdminSection: String, CaseIterable, Identifiable {
    case setup
    case game
    case families
    case display
    case simulation
    case devices

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .setup: "Setup"
        case .game: "Game"
        case .families: "Families"
        case .display: "Display"
        case .simulation: "Simulation"
        case .devices: "Devices"
        }
    }

    var symbol: String {
        switch self {
        case .setup: "slider.horizontal.3"
        case .game: "gamecontroller"
        case .families: "person.3"
        case .display: "tv"
        case .simulation: "testtube.2"
        case .devices: "iphone.gen3.radiowaves.left.and.right"
        }
    }
}

struct RootView: View {
    let controller: HostController
    let simulation: SimulationController

    @State private var selection: AdminSection? = .setup
    @Environment(\.openWindow) private var openWindow
    @State private var bell = AdminSound("bell")

    var body: some View {
        NavigationSplitView {
            List(AdminSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .accessibilityLabel("Sections")
        } detail: {
            switch selection ?? .setup {
            case .setup:
                SetupView(controller: controller)
            case .game:
                GameControlView(controller: controller)
            case .families:
                FamiliesView(controller: controller)
            case .display:
                DisplaySettingsView(controller: controller)
            case .simulation:
                SimulationView(controller: simulation)
            case .devices:
                DevicesView(controller: controller)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Open Display", systemImage: "play.rectangle.fill") {
                    openWindow(id: PublicDisplayWindow.id)
                }
                .help("Open the Public Display: join QR and families for the lab screens")
                .accessibilityHint("Opens the Public Display window")
            }
        }
        .task { await controller.start() }
        .onChange(of: controller.host.bellRings) { _, _ in bell.play() }
    }
}

#Preview {
    RootView(controller: HostController(host: try! GameHost(repository: InMemoryGameRepository())), simulation: SimulationController())
}
