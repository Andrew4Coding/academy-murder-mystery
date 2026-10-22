import SwiftUI

struct RootView: View {
    let client: GameClient

    var body: some View {
        NavigationStack {
            ConnectionStatusView(status: client.status, retry: client.start)
                .navigationTitle("Murder Mystery")
                .navigationBarTitleDisplayMode(.inline)
        }
        .task { client.start() }
    }
}

#Preview {
    RootView(client: GameClient(transport: LoopbackHub().makeClient(), store: InMemoryIdentityStore()))
}
