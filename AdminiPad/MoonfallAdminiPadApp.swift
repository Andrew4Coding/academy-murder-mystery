import SwiftUI

@main
struct MoonfallAdminiPadApp: App {
    @State private var client = GameClient(transport: AdaptiveClientTransport.live(), store: UserDefaultsIdentityStore())
    @State private var takeover = CloudTakeoverController.live()

    var body: some Scene {
        WindowGroup {
            RootView(client: client)
                .tint(Theme.accent)
                .environment(\.cloudTakeover, takeover)
        }
    }
}
