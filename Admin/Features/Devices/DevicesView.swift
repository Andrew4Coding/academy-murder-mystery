import SwiftUI

struct DevicesView: View {
    let controller: HostController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let devices = controller.host.deviceStatuses()
            Group {
                if devices.isEmpty {
                    ContentUnavailableView(
                        "No devices connected",
                        systemImage: "iphone.slash",
                        description: Text("Players and OC appear here once they join the game.")
                    )
                } else {
                    Table(devices) {
                        TableColumn("Name", value: \.label)
                        TableColumn("Family or station", value: \.detail)
                        TableColumn("Status") { device in
                            Label(device.connection.title, systemImage: device.connection.symbol)
                                .foregroundStyle(device.connection.tint)
                        }
                        TableColumn("Last seen") { device in
                            if let lastSeen = device.lastSeen {
                                Text(lastSeen, style: .relative)
                            } else {
                                Text("Not connected").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
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
        case .online: .green
        case .unreachable: .orange
        case .offline: .secondary
        }
    }
}
