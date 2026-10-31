import SwiftUI

@main
struct MoonfallAdminApp: App {
    @State private var environment: AppEnvironment
    @State private var controller: HostController
    @State private var mode: HostModeController
    @State private var simulation = SimulationController()

    init() {
        let environment = AppEnvironment.live()
        _environment = State(initialValue: environment)
        let host = environment.makeHost()
        let hostController = HostController(host: host)
        _controller = State(initialValue: hostController)
        _mode = State(initialValue: HostModeController(
            local: hostController,
            registry: HostRegistryClient.live { HostModeController.credential(host: host) }
        ))
    }

    var body: some Scene {
        WindowGroup {
            mainContent
                .frame(minWidth: 720, minHeight: 480)
                .tint(Theme.accent)
        }
        Window("Public Display", id: PublicDisplayWindow.id) {
            PublicDisplayView(controller: controller, mode: mode)
                .frame(minWidth: 960, minHeight: 540)
        }
        .windowResizability(.contentMinSize)
    }

    @ViewBuilder
    private var mainContent: some View {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-DisplayGallery") {
                PublicDisplayGalleryLaunch()
            } else if ProcessInfo.processInfo.arguments.contains("-AdminGallery") {
                AdminGalleryLaunch()
            } else {
                RootView(controller: controller, mode: mode, simulation: simulation)
                    .task { await PublicDisplayWindowCapture.captureIfRequested() }
            }
        #else
            RootView(controller: controller, mode: mode, simulation: simulation)
        #endif
    }
}
