import SwiftUI

struct RootView: View {
    let environment: AppEnvironment

    @State private var selection: UUID?

    var body: some View {
        NavigationSplitView {
            ItemListView(environment: environment, selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let selection {
                ItemDetailView(environment: environment, itemID: selection)
                    .id(selection)
            } else {
                ContentUnavailableView("Select an Item", systemImage: "square.and.pencil")
            }
        }
    }
}

#Preview {
    RootView(environment: .preview())
}
