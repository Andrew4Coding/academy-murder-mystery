import SwiftUI

enum AdminSection: String, CaseIterable, Identifiable {
    case setup
    case game
    case families
    case booths
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
        case .booths: "Booths"
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
        case .booths: "square.grid.2x2"
        case .display: "tv"
        case .simulation: "testtube.2"
        case .devices: "iphone.gen3.radiowaves.left.and.right"
        }
    }
}

struct RootView: View {
    let controller: HostController
    let mode: HostModeController
    let simulation: SimulationController

    @State private var selection: AdminSection? = RootView.initialSection
    @Environment(\.openWindow) private var openWindow
    @State private var bell = AdminSound("bell")

    private static var initialSection: AdminSection {
        #if DEBUG
            AdminSection(rawValue: UserDefaults.standard.string(forKey: "AdminSection") ?? "") ?? .setup
        #else
            .setup
        #endif
    }

    var body: some View {
        NavigationSplitView {
            List(AdminSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .accessibilityLabel("Sections")
        } detail: {
            switch selection ?? .setup {
            case .setup where mode.phase == .cloud, .game where mode.phase == .cloud, .families where mode.phase == .cloud,
                 .booths where mode.phase == .cloud:
                CloudControlView(mode: mode, title: (selection ?? .setup).title)
            case .setup:
                SetupView(controller: controller)
            case .game:
                GameControlView(controller: controller)
            case .families:
                FamiliesView(controller: controller)
            case .booths:
                BoothsAdminView(controller: controller)
            case .display:
                DisplaySettingsView(controller: controller, mode: mode)
            case .simulation:
                SimulationView(controller: simulation)
            case .devices:
                DevicesView(controller: controller, mode: mode)
            }
        }
        .toolbarBackground(Theme.background, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Open Display", systemImage: "play.rectangle.fill") {
                    openWindow(id: PublicDisplayWindow.id)
                }
                .help("Open the Public Display: join QR and families for the lab screens")
                .accessibilityHint("Opens the Public Display window")
            }
        }
        .task { await mode.bootstrap() }
        .onChange(of: controller.host.bellRings) { _, _ in bell.play() }
    }
}

#Preview {
    // swiftlint:disable:next force_try
    let controller = HostController(host: try! GameHost(repository: InMemoryGameRepository()))
    return RootView(
        controller: controller,
        mode: HostModeController(local: controller, registry: HostRegistryClient.live()),
        simulation: SimulationController()
    )
}
