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
            ThemedScreen {
                Text("Scan the QR code on the big screen, then pick a name for your family.")
                    .foregroundStyle(Theme.textSecondary)

                ScreenSection(title: "1. Find the game", footer: "The code is shown under the QR code on the big screen.") {
                    TextField("Game code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focus, equals: .code)
                        .onSubmit { focus = .name }
                        .themedField()
                    Button("Scan QR Code", systemImage: "qrcode.viewfinder") {
                        isScanning = true
                    }
                    .buttonStyle(.secondary)
                }

                ScreenSection(title: "2. Name your family", footer: "Up to 24 characters.") {
                    TextField("Family name", text: $name)
                        .submitLabel(.join)
                        .focused($focus, equals: .name)
                        .onSubmit(join)
                        .themedField()
                }

                VStack(spacing: Spacing.sm) {
                    Button("Join Game", action: join)
                        .buttonStyle(.accentFill)
                        .disabled(!canJoin)
                        .accessibilityHint(canJoin ? "" : "Enter the game code and a family name first")
                    connectionRow
                }
            }
            .navigationTitle("Join the Game")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Organiser", systemImage: "person.badge.key") { isSigningInAsOC = true }
                        .accessibilityHint("Sign in with the organiser PIN")
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

    @ViewBuilder
    private var connectionRow: some View {
        if let error = client.lastError {
            ErrorRow(message: error)
        } else {
            switch client.status {
            case .connected:
                StatusLabel("Connected to the game host", systemImage: "checkmark.circle.fill", tint: Theme.success)
                    .secondaryText()
            case let .failed(reason):
                VStack(spacing: Spacing.sm) {
                    StatusLabel(reason, systemImage: "wifi.exclamationmark", tint: Theme.warning)
                    Button("Try Again", systemImage: "arrow.clockwise") { client.refresh() }
                        .buttonStyle(.secondary)
                }
            case .idle, .searching, .connecting:
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text(statusText).secondaryText()
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var statusText: String {
        client.status == .connecting ? "Connecting to the game host…" : "Looking for the game host. Join the event Wi-Fi."
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
                        description: Text("Allow camera access in Settings, or type the game code instead.")
                    )
                    .themedBackground()
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
