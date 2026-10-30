import SwiftUI

struct OCSignInView: View {
    let client: GameClient

    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var station: OCStation = .sabotage(.reactor)

    var body: some View {
        NavigationStack {
            ThemedScreen {
                Text("Organisers run the booths. Enter the PIN, then pick the booth you are watching.")
                    .foregroundStyle(Theme.textSecondary)

                ScreenSection(title: "1. PIN", footer: "The PIN is shown on the Town Hall Mac.") {
                    SecureField("OC PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .themedField()
                }

                ScreenSection(title: "2. Your station") {
                    Picker("Station", selection: $station) {
                        ForEach(SabotageKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(OCStation.sabotage(kind))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(spacing: Spacing.sm) {
                    Button("Sign In", action: signIn)
                        .buttonStyle(.accentFill)
                        .disabled(pin.isEmpty || client.status != .connected)
                        .accessibilityHint(pin.isEmpty ? "Enter the PIN first" : "")
                    if let error = client.lastError {
                        ErrorRow(message: error)
                    } else if client.status != .connected {
                        Text("Waiting for the game host…").secondaryText()
                    }
                }
            }
            .navigationTitle("Organiser Sign-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: client.isSignedIn) { _, signedIn in
                if signedIn {
                    dismiss()
                }
            }
        }
    }

    private func signIn() {
        client.signInAsOC(pin: pin, station: station)
    }
}
