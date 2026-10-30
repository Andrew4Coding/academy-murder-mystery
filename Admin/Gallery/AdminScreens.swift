#if DEBUG
    import SwiftUI

    private struct HostScreen<Content: View>: View {
        @State private var controller: HostController
        private let content: (HostController) -> Content

        init(_ stage: AdminStage, @ViewBuilder content: @escaping (HostController) -> Content) {
            _controller = State(initialValue: AdminFixtures.controller(stage))
            self.content = content
        }

        var body: some View {
            NavigationStack { content(controller) }
        }
    }

    private struct SimulationScreen: View {
        @State private var controller: SimulationController

        init(_ stage: SimulationStage) {
            _controller = State(initialValue: AdminFixtures.simulation(stage))
        }

        var body: some View {
            NavigationStack { SimulationView(controller: controller) }
        }
    }

    private struct DevicesScreen: View {
        let devices: [DeviceStatus]

        var body: some View {
            NavigationStack { DevicesContent(devices: devices) }
        }
    }

    struct AdminGalleryEntry: Identifiable {
        let id: String
        let title: String
        let screen: AnyView

        init(_ title: String, @ViewBuilder screen: () -> some View) {
            id = title
            self.title = title
            self.screen = AnyView(screen())
        }
    }

    @MainActor
    enum AdminScreens {
        static let setup: [AdminGalleryEntry] = [
            AdminGalleryEntry("Setup: issues to fix") { HostScreen(.setupIssues) { SetupView(controller: $0) } },
            AdminGalleryEntry("Setup: ready to start") { HostScreen(.lobbyReady) { SetupView(controller: $0) } }
        ]

        static let game: [AdminGalleryEntry] = [
            AdminGalleryEntry("Game: lobby") { HostScreen(.lobbyReady) { GameControlView(controller: $0) } },
            AdminGalleryEntry("Game: running") { HostScreen(.running) { GameControlView(controller: $0) } },
            AdminGalleryEntry("Game: discussion") { HostScreen(.discussion) { GameControlView(controller: $0) } },
            AdminGalleryEntry("Game: voting") { HostScreen(.voting) { GameControlView(controller: $0) } },
            AdminGalleryEntry("Game: vote result") { HostScreen(.result) { GameControlView(controller: $0) } },
            AdminGalleryEntry("Game: sabotage") { HostScreen(.sabotage) { GameControlView(controller: $0) } },
            AdminGalleryEntry("Game: ended") { HostScreen(.ended) { GameControlView(controller: $0) } }
        ]

        static let families: [AdminGalleryEntry] = [
            AdminGalleryEntry("Families: no game yet") { HostScreen(.lobbyReady) { FamiliesView(controller: $0) } },
            AdminGalleryEntry("Families: running") { HostScreen(.running) { FamiliesView(controller: $0) } },
            AdminGalleryEntry("Families: voting") { HostScreen(.voting) { FamiliesView(controller: $0) } }
        ]

        static let devices: [AdminGalleryEntry] = [
            AdminGalleryEntry("Devices: none connected") { DevicesScreen(devices: []) },
            AdminGalleryEntry("Devices: mixed status") { DevicesScreen(devices: AdminFixtures.devices()) }
        ]

        static let simulation: [AdminGalleryEntry] = SimulationStage.allCases.map { stage in
            AdminGalleryEntry("Simulation: \(stage.title.lowercased())") { SimulationScreen(stage) }
        }

        static let all = setup + game + families + devices + simulation
    }

    #Preview("Setup: issues to fix", traits: .fixedLayout(width: 960, height: 700)) { AdminScreens.setup[0].screen }
    #Preview("Setup: ready to start", traits: .fixedLayout(width: 960, height: 700)) { AdminScreens.setup[1].screen }
    #Preview("Game: lobby", traits: .fixedLayout(width: 960, height: 640)) { AdminScreens.game[0].screen }
    #Preview("Game: running", traits: .fixedLayout(width: 960, height: 640)) { AdminScreens.game[1].screen }
    #Preview("Game: discussion", traits: .fixedLayout(width: 960, height: 640)) { AdminScreens.game[2].screen }
    #Preview("Game: voting", traits: .fixedLayout(width: 960, height: 640)) { AdminScreens.game[3].screen }
    #Preview("Game: vote result", traits: .fixedLayout(width: 960, height: 640)) { AdminScreens.game[4].screen }
    #Preview("Game: sabotage", traits: .fixedLayout(width: 960, height: 640)) { AdminScreens.game[5].screen }
    #Preview("Game: ended", traits: .fixedLayout(width: 960, height: 640)) { AdminScreens.game[6].screen }
    #Preview("Families: no game yet", traits: .fixedLayout(width: 960, height: 560)) { AdminScreens.families[0].screen }
    #Preview("Families: running", traits: .fixedLayout(width: 960, height: 560)) { AdminScreens.families[1].screen }
    #Preview("Families: voting", traits: .fixedLayout(width: 960, height: 560)) { AdminScreens.families[2].screen }
    #Preview("Devices: none connected", traits: .fixedLayout(width: 960, height: 480)) { AdminScreens.devices[0].screen }
    #Preview("Devices: mixed status", traits: .fixedLayout(width: 960, height: 480)) { AdminScreens.devices[1].screen }
    #Preview("Simulation: not started", traits: .fixedLayout(width: 960, height: 640)) { AdminScreens.simulation[0].screen }
    #Preview("Simulation: running", traits: .fixedLayout(width: 960, height: 720)) { AdminScreens.simulation[1].screen }
    #Preview("Simulation: finished", traits: .fixedLayout(width: 960, height: 720)) { AdminScreens.simulation[2].screen }
    #Preview("Simulation: can't start", traits: .fixedLayout(width: 960, height: 640)) { AdminScreens.simulation[3].screen }
#endif
