import SwiftUI

struct DevicesView: View {
    let controller: HostController
    let mode: HostModeController

    var body: some View {
        VStack(spacing: 0) {
            HostModeSection(mode: mode)
            if mode.phase == .cloud {
                DevicesContent(devices: mode.adminClient?.view?.admin?.devices ?? [])
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    DevicesContent(devices: controller.host.deviceStatuses())
                }
            }
        }
        .themedBackground()
    }
}

struct DevicesContent: View {
    let devices: [DeviceStatus]

    var body: some View {
        Group {
            if devices.isEmpty {
                ContentUnavailableView(
                    "No devices connected",
                    systemImage: "iphone.slash",
                    description: Text("Players and OC appear here once they join the game with the code from Setup.")
                )
            } else {
                Table(devices) {
                    TableColumn("Name", value: \.label)
                    TableColumn("Family or station", value: \.detail)
                    TableColumn("Status") { device in
                        StatusLabel(device.connection.title, systemImage: device.connection.symbol, tint: device.connection.tint)
                    }
                    TableColumn("Last seen") { device in
                        if let lastSeen = device.lastSeen {
                            Text(lastSeen, style: .relative)
                        } else {
                            Text("Not connected").foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .themedBackground()
        .navigationTitle("Devices")
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
