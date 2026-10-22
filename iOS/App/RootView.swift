import SwiftUI

struct RootView: View {
    let environment: AppEnvironment

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: UUID?

    var body: some View {
        if horizontalSizeClass == .compact {
            TabView {
                Tab("Items", systemImage: "list.bullet") {
                    NavigationStack {
                        ItemListView(environment: environment)
                            .navigationDestination(for: UUID.self) { id in
                                ItemDetailView(environment: environment, itemID: id)
                            }
                    }
                }
            }
        } else {
            NavigationSplitView {
                ItemListView(environment: environment, selection: $selection)
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
}

#Preview {
    RootView(environment: .preview())
}
