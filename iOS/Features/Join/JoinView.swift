import SwiftUI

struct JoinView: View {
    let client: GameClient

    @State private var code = ""
    @State private var name = ""
    @State private var isScanning = false
    @State private var isSigningInAsOC = false
    @FocusState private var focus: Field?

    private enum Field {
        case code
        case name
    }

    private var canJoin: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && name.trimmingCharacters(in: .whitespaces).count <= 24
            && client.status == .connected
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Game code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focus, equals: .code)
                        .onSubmit { focus = .name }
                    Button("Scan QR Code", systemImage: "qrcode.viewfinder") {
                        isScanning = true
                    }
                } header: {
                    Text("Game")
                } footer: {
                    Text("Scan the QR on the big screen.")
                }

                Section {
                    TextField("Family name", text: $name)
                        .submitLabel(.join)
                        .focused($focus, equals: .name)
                        .onSubmit(join)
                } header: {
                    Text("Your family")
                } footer: {
                    Text("Pick a name for your family (up to 24 characters).")
                }

                Section {
                    Button("Join Game", action: join)
                        .frame(maxWidth: .infinity)
                        .disabled(!canJoin)
                } footer: {
                    if let error = client.lastError {
                        StatusLabel.error(error)
                    } else if client.status != .connected {
                        Text(statusText)
                    }
                }
            }
            .navigationTitle("Join the Game")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("I'm an Organiser", systemImage: "person.badge.key") { isSigningInAsOC = true }
                }
            }
            .sheet(isPresented: $isSigningInAsOC) { OCSignInView(client: client) }
            .sheet(isPresented: $isScanning) {
                ScannerSheet { scanned in
                    code = scanned
                    isScanning = false
                    focus = .name
                }
            }
        }
    }

    private var statusText: String {
        switch client.status {
        case let .failed(reason): reason
        default: "Looking for the game host…"
        }
    }

    private func join() {
        guard canJoin else { return }
        client.join(code: code, name: name)
    }
}

private struct ScannerSheet: View {
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if CodeScannerView.isAvailable {
                    CodeScannerView(onCode: onCode)
                        .ignoresSafeArea()
                } else {
                    ContentUnavailableView(
                        "Scanner unavailable",
                        systemImage: "camera.fill",
                        description: Text("Allow camera access in Settings, or type the family code instead.")
                    )
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
