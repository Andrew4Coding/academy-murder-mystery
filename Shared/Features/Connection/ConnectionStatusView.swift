import SwiftUI

struct ConnectionStatusView: View {
    let status: ConnectionStatus
    var retry: () -> Void = {}

    var body: some View {
        switch status {
        case .idle, .searching:
            ContentUnavailableView {
                ProgressView().controlSize(.large)
                Text("Looking for game").font(.title2.bold())
            } description: {
                Text("Make sure you are on the event Wi-Fi.")
            }
            .accessibilityElement(children: .combine)
        case .connecting:
            ContentUnavailableView {
                ProgressView().controlSize(.large)
                Text("Connecting").font(.title2.bold())
            }
            .accessibilityElement(children: .combine)
        case .connected:
            ContentUnavailableView("Connected", systemImage: "checkmark.circle", description: Text("Waiting for the game host."))
        case let .failed(reason):
            ContentUnavailableView {
                Label("Can't reach the host", systemImage: "wifi.exclamationmark")
            } description: {
                Text(reason)
            } actions: {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("Searching") {
    ConnectionStatusView(status: .searching)
}

#Preview("Failed") {
    ConnectionStatusView(status: .failed("The network connection was lost."))
}
