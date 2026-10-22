import SwiftUI

struct RootView: View {
    let environment: AppEnvironment

    var body: some View {
        ContentUnavailableView(
            "Murder Mystery Admin",
            systemImage: "moon.stars",
            description: Text("Game setup is coming soon.")
        )
        .navigationTitle("Murder Mystery Admin")
    }
}

#Preview {
    RootView(environment: .preview())
}
