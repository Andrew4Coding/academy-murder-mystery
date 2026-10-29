import SwiftUI

@main
struct MoonfallAdminiPadApp: App {
    @State private var client = GameClient(transport: NetworkClientTransport(), store: UserDefaultsIdentityStore())

    var body: some Scene {
        WindowGroup {
            RootView(client: client)
        }
    }
}
