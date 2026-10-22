import SwiftUI

@main
struct MurderMysteryAdminApp: App {
    @State private var environment: AppEnvironment
    @State private var controller: HostController

    init() {
        let environment = AppEnvironment.live()
        _environment = State(initialValue: environment)
        _controller = State(initialValue: HostController(host: environment.makeHost()))
    }

    var body: some Scene {
        WindowGroup {
            RootView(controller: controller)
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
