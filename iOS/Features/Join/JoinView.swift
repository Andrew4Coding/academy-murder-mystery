import SwiftUI

struct JoinView: View {
    let client: GameClient

    @State private var code = ""
    @State private var name = ""
    @State private var isScanning = false
    @FocusState private var focus: Field?

    private enum Field {
        case code
        case name
    }

    private var canJoin: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && client.status == .connected
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Family code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focus, equals: .code)
                        .onSubmit { focus = .name }
                    Button("Scan QR Code", systemImage: "qrcode.viewfinder") {
                        isScanning = true
                    }
                } header: {
                    Text("Your family")
                } footer: {
                    Text("Ask your family's organiser for the code or QR on their screen.")
                }

                Section("You") {
                    TextField("Your name", text: $name)
                        .textContentType(.givenName)
                        .submitLabel(.join)
                        .focused($focus, equals: .name)
                        .onSubmit(join)
                }

                Section {
                    Button("Join Family", action: join)
                        .frame(maxWidth: .infinity)
                        .disabled(!canJoin)
                } footer: {
                    if let error = client.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    } else if client.status != .connected {
                        Text(statusText)
                    }
                }
            }
            .navigationTitle("Join the Game")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ConnectionBadge(status: client.status)
                }
            }
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
        case .failed: "Can't reach the host. Check the event Wi-Fi."
        default: "Looking for the game host…"
        }
    }

    private func join() {
        guard canJoin else { return }
        client.join(code: code, name: name)
    }
}

struct ConnectionBadge: View {
    let status: ConnectionStatus

    var body: some View {
        switch status {
        case .connected:
            Label("Connected", systemImage: "wifi")
        case .failed:
            Label("Offline", systemImage: "wifi.exclamationmark")
        default:
            Label("Searching", systemImage: "wifi")
                .symbolEffect(.variableColor.iterative, isActive: true)
        }
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
