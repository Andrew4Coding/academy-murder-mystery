import SwiftUI

enum AdminSection: String, CaseIterable, Identifiable {
    case devices

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .devices: "Devices"
        }
    }

    var symbol: String {
        switch self {
        case .devices: "iphone.gen3.radiowaves.left.and.right"
        }
    }
}

struct RootView: View {
    let controller: HostController

    @State private var selection: AdminSection? = .devices

    var body: some View {
        NavigationSplitView {
            List(AdminSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            switch selection ?? .devices {
            case .devices:
                DevicesView(controller: controller)
            }
        }
        .task { await controller.start() }
    }
}

#Preview {
    RootView(controller: HostController(host: try! GameHost(repository: InMemoryGameRepository())))
}
