import SwiftUI

struct OCSignInView: View {
    let client: GameClient

    @Environment(\.dismiss) private var dismiss
    @State private var pin = ""
    @State private var station: OCStation = .booth(.morseCode)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("OC PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                } footer: {
                    Text("The PIN is shown on the Town Hall Mac.")
                }

                Section("Your station") {
                    Picker("Station", selection: $station) {
                        Section("Task booths") {
                            ForEach(Booth.allCases, id: \.self) { booth in
                                Text(booth.title).tag(OCStation.booth(booth))
                            }
                        }
                        Section("Sabotage booths") {
                            ForEach(SabotageKind.allCases, id: \.self) { kind in
                                Text(kind.title).tag(OCStation.sabotage(kind))
                            }
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    Button("Sign In", action: signIn)
                        .frame(maxWidth: .infinity)
                        .disabled(pin.isEmpty || client.status != .connected)
                } footer: {
                    if let error = client.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
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
