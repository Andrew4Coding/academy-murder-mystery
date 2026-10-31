import SwiftUI

struct DevicesTab: View {
    let admin: AdminView
    let client: GameClient

    @State private var deleting: DeviceStatus?

    var body: some View {
        Group {
            if admin.devices.isEmpty {
                ContentUnavailableView(
                    "No devices connected",
                    systemImage: "iphone.slash",
                    description: Text("Players and OC appear here once they join the game with the code from Setup.")
                )
            } else {
                List(admin.devices) { device in
                    HStack(spacing: Spacing.md) {
                        VStack(alignment: .leading) {
                            Text(device.label).font(.headline)
                            Text(device.detail).font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if let lastSeen = device.lastSeen {
                            Text(lastSeen, style: .relative).foregroundStyle(Theme.textSecondary)
                        } else {
                            Text("Not connected").foregroundStyle(Theme.textSecondary)
                        }
                        StatusLabel(device.connection.title, systemImage: device.connection.symbol, tint: device.connection.tint)
                    }
                    .listRowBackground(Theme.surface)
                    .swipeActions(edge: .trailing) {
                        if device.isOC || admin.isLobby {
                            Button("Delete", systemImage: "trash", role: .destructive) { deleting = device }
                        }
                    }
                }
            }
        }
        .themedBackground()
        .safeAreaInset(edge: .top, spacing: 0) { TakeoverBar() }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem {
                Button("Check Connections", systemImage: "antenna.radiowaves.left.and.right") {
                    client.send(.admin(.checkConnectivity))
                }
            }
        }
        .confirmationDialog(
            deleting.map { "Delete \($0.label), \($0.detail)?" } ?? "",
            isPresented: Binding(get: { deleting != nil }, set: {
                if !$0 {
                    deleting = nil
                }
            }),
            titleVisibility: .visible
        ) {
            if let device = deleting {
                Button("Delete Device", role: .destructive) {
                    client.send(.admin(.removeDevice(device.id)))
                    deleting = nil
                }
            }
        } message: {
            Text("The device is signed out and has to join again.")
        }
    }
}

private extension DeviceStatus.Connection {
    var title: String {
        switch self {
        case .online: "Online"
        case .unreachable: "Unreachable"
        case .offline: "Offline"
        }
    }

    var symbol: String {
        switch self {
        case .online: "checkmark.circle.fill"
        case .unreachable: "exclamationmark.triangle.fill"
        case .offline: "circle.slash"
        }
    }

    var tint: Color {
        switch self {
        case .online: Theme.success
        case .unreachable: Theme.warning
        case .offline: Theme.textSecondary
        }
    }
}
