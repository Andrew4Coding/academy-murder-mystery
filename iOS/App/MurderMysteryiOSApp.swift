import SwiftUI

@main
struct MurderMysteryiOSApp: App {
    private let client = GameClientRegistry.shared

    var body: some Scene {
        WindowGroup {
            RootView(client: client)
        }
    }
}
