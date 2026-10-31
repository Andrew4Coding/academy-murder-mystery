import SwiftUI

extension EnvironmentValues {
    @Entry var cloudTakeover: CloudTakeoverController?
}

struct TakeoverBar: View {
    @Environment(\.cloudTakeover) private var takeover

    @State private var asking = false
    @State private var pin = ""

    var body: some View {
        if let takeover {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                registryLine(takeover)
                if takeover.record?.mode != .cloud {
                    Button("Take Over in Cloud", systemImage: "cloud") { asking = true }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                        .disabled(takeover.state == .working)
                        .accessibilityHint("Use when the Mac host can't be reached")
                }
                stateLine(takeover)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(Theme.surface)
            .task { await takeover.refresh() }
            .alert("Take over in the cloud?", isPresented: $asking) {
                SecureField("OC PIN", text: $pin)
                    .keyboardType(.numberPad)
                Button("Take Over", role: .destructive) {
                    let entered = pin
                    pin = ""
                    Task { await takeover.takeOver(pin: entered) }
                }
                Button("Cancel", role: .cancel) { pin = "" }
            } message: {
                Text("The cloud host starts from the Mac's latest backup. Do this only when the Mac is down.")
            }
        }
    }

    @ViewBuilder
    private func registryLine(_ takeover: CloudTakeoverController) -> some View {
        if let record = takeover.record {
            switch record.mode {
            case .cloud:
                StatusLabel("The cloud is the active host", systemImage: "cloud.fill", tint: Theme.success)
            case .selfHost:
                if record.hasSnapshot, let at = record.snapshotAt {
                    StatusLabel(
                        "The Mac is the active host. Last backup \(at.formatted(.relative(presentation: .named)))",
                        systemImage: "desktopcomputer",
                        tint: Theme.success
                    )
                } else {
                    StatusLabel("The Mac is the active host. No cloud backup yet", systemImage: "desktopcomputer", tint: Theme.warning)
                }
            }
        } else if let error = takeover.registryError {
            StatusLabel(error, systemImage: "wifi.slash", tint: Theme.warning)
        } else {
            StatusLabel("Checking the cloud registry…", systemImage: "hourglass", tint: Theme.textSecondary)
        }
    }

    @ViewBuilder
    private func stateLine(_ takeover: CloudTakeoverController) -> some View {
        switch takeover.state {
        case .idle:
            EmptyView()
        case .working:
            StatusLabel("Starting the cloud host…", systemImage: "hourglass", tint: Theme.warning)
        case .done:
            StatusLabel("The cloud took over. Sign in again with the OC PIN.", systemImage: "checkmark.circle.fill", tint: Theme.success)
        case let .failed(message):
            StatusLabel.error(message)
        }
    }
}
