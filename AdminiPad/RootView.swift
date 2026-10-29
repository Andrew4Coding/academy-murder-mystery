import SwiftUI

struct RootView: View {
    let client: GameClient

    var body: some View {
        Group {
            if let admin = client.view?.admin {
                DashboardView(admin: admin, client: client)
            } else if client.isResuming {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Reconnecting to the host…").foregroundStyle(.secondary)
                    Button("Start Over", role: .destructive) { client.signOut() }
                        .buttonStyle(.bordered)
                }
            } else {
                PinView(client: client)
            }
        }
        .task { client.start() }
    }
}

private struct PinView: View {
    let client: GameClient

    @State private var pin = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("OC PIN", text: $pin)
                        .keyboardType(.numberPad)
                } footer: {
                    if let error = client.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    } else {
                        Text("The PIN is shown in Setup on the Mac host.")
                    }
                }
                Section {
                    Button("Connect") { client.signInAsOC(pin: pin, station: .admin) }
                        .frame(maxWidth: .infinity)
                        .disabled(pin.isEmpty || client.status != .connected)
                }
            }
            .navigationTitle("Murder Mystery Admin")
            .frame(maxWidth: 520)
        }
    }
}
