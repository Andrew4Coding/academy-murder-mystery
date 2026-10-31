import SwiftUI

struct RootView: View {
    let client: GameClient

    var body: some View {
        Group {
            if let admin = client.view?.admin {
                DashboardView(admin: admin, client: client)
            } else if client.isResuming {
                ReconnectingView(onStartOver: { client.signOut() })
            } else {
                PinView(client: client)
            }
        }
        .task { client.start() }
    }
}

struct ReconnectingView: View {
    let onStartOver: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
            Text("Reconnecting to the host…").foregroundStyle(Theme.textSecondary)
            Button("Start Over", role: .destructive, action: onStartOver)
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
            TakeoverBar()
                .frame(maxWidth: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground()
        .accessibilityElement(children: .combine)
    }
}

struct PinView: View {
    let client: GameClient

    @State private var pin = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("OC PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .frame(minHeight: 44)
                        .onSubmit(connect)
                } footer: {
                    if let error = client.lastError {
                        StatusLabel.error(error)
                    } else if case let .failed(message) = client.status {
                        StatusLabel.error(message)
                    } else if client.status != .connected {
                        StatusLabel("Looking for the host on this network…", systemImage: "wifi", tint: Theme.warning)
                    } else {
                        Text("The PIN is shown in Setup on the Mac host.")
                    }
                }
                .listRowBackground(Theme.surface)
                Section {
                    TakeoverBar()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                Section {
                    Button("Connect", action: connect)
                        .buttonStyle(.accentFill)
                        .disabled(pin.isEmpty || client.status != .connected)
                }
                .listRowBackground(Color.clear)
            }
            .formStyle(.grouped)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .themedBackground()
            .navigationTitle("Moonfall OC")
        }
    }

    private func connect() {
        guard !pin.isEmpty, client.status == .connected else { return }
        client.signInAsOC(pin: pin, station: .admin)
    }
}
