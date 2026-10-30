import SwiftUI

@main
struct MoonfallAdminApp: App {
    @State private var environment: AppEnvironment
    @State private var controller: HostController
    @State private var simulation = SimulationController()

    init() {
        let environment = AppEnvironment.live()
        _environment = State(initialValue: environment)
        _controller = State(initialValue: HostController(host: environment.makeHost()))
    }

    var body: some Scene {
        WindowGroup {
            mainContent
                .frame(minWidth: 720, minHeight: 480)
                .tint(Theme.accent)
        }
        Window("Public Display", id: PublicDisplayWindow.id) {
            PublicDisplayView(controller: controller)
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
                RootView(controller: controller, simulation: simulation)
            }
        #else
            RootView(controller: controller, simulation: simulation)
        #endif
    }
}
