import SwiftUI

extension View {
    func refreshToolbar(_ client: GameClient) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { client.refresh() }
            }
        }
    }
}
