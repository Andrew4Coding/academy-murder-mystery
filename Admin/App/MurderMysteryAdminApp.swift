import SwiftUI

@main
struct MurderMysteryAdminApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
