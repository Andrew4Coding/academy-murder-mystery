import SwiftUI

@main
struct MoonfallAdminiPadApp: App {
    @State private var client = GameClient(transport: AdaptiveClientTransport.live(), store: UserDefaultsIdentityStore())

    var body: some Scene {
        WindowGroup {
            RootView(client: client)
                .tint(Theme.accent)
        }
    }
}
