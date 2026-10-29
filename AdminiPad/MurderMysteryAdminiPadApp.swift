import SwiftUI

@main
struct MurderMysteryAdminiPadApp: App {
    @State private var client = GameClient(transport: NetworkClientTransport(), store: UserDefaultsIdentityStore())

    var body: some Scene {
        WindowGroup {
            RootView(client: client)
        }
    }
}
