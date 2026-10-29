import SwiftUI

@main
struct MurderMysteryiOSApp: App {
    @State private var client = GameClient(transport: NetworkClientTransport(), store: UserDefaultsIdentityStore())

    var body: some Scene {
        WindowGroup {
            RootView(client: client)
                .onAppear { GameClientRegistry.client = client }
        }
    }
}
