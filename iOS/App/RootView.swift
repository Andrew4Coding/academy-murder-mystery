import SwiftUI

struct RootView: View {
    let environment: AppEnvironment

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Murder Mystery",
                systemImage: "moon.stars",
                description: Text("Joining a game is coming soon.")
            )
            .navigationTitle("Murder Mystery")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    RootView(environment: .preview())
}
