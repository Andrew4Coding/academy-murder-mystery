import SwiftUI

struct ConnectionStatusView: View {
    let status: ConnectionStatus
    var retry: () -> Void = {}

    var body: some View {
        content
            .foregroundStyle(Theme.text)
            .themedBackground()
    }

    @ViewBuilder
    private var content: some View {
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
            } description: {
                Text("Hang on, this only takes a moment.")
            }
            .accessibilityElement(children: .combine)
        case .connected:
            ContentUnavailableView {
                Label("Connected", systemImage: "checkmark.circle.fill")
            } description: {
                Text("Waiting for the game host.")
            }
        case let .failed(reason):
            ContentUnavailableView {
                Label("Can't reach the host", systemImage: "wifi.exclamationmark")
            } description: {
                Text(reason)
                Text("Check that you are on the event Wi-Fi, then try again.")
            } actions: {
                Button("Try Again", systemImage: "arrow.clockwise", action: retry)
                    .buttonStyle(.accentFill)
                    .frame(maxWidth: 280)
            }
        }
    }
}
