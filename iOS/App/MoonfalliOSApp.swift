import SwiftUI

@main
struct MoonfalliOSApp: App {
    private let client = GameClientRegistry.shared

    var body: some Scene {
        WindowGroup {
            RootView(client: client)
        }
    }
}
