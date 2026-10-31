import SwiftUI

struct HostModeSection: View {
    let mode: HostModeController

    @State private var pending: HostMode?
    @State private var secret = ""

    private var current: HostMode {
        switch mode.phase {
        case .selfHost, .switchingToCloud: .selfHost
        case .cloud, .switchingToSelfHost: .cloud
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Host mode")
                .font(.headline)
            Picker("Active host", selection: Binding(get: { current }, set: request)) {
                ForEach(HostMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(mode.phase.isSwitching)
            .accessibilityLabel("Active host")
            .accessibilityHint("Moves the game between this Mac and the cloud host")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                hostStatus
                connectionStatus
                if let record = mode.registryRecord {
                    HStack {
                        Text("Registry says").foregroundStyle(Theme.textSecondary)
                        Text(record.mode.title)
                        if let at = record.snapshotAt {
                            Text("Cloud snapshot").foregroundStyle(Theme.textSecondary)
                            Text(at, style: .relative)
                        }
                    }
                }
                if let error = mode.lastError {
                    StatusLabel.error(error)
                }
            }

            Divider()
            HStack(spacing: Spacing.sm) {
                SecureField("Cloud pairing secret", text: $secret)
                    .onSubmit { mode.pairingSecret = secret }
                    .frame(maxWidth: 320)
                Button("Save Secret") { mode.pairingSecret = secret }
                    .disabled(secret == mode.pairingSecret)
            }
            Text("Registry writes use this secret, or the OC PIN when it is empty.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
        .padding(Spacing.md)
        .task {
            secret = mode.pairingSecret
            await mode.refresh()
        }
        .confirmationDialog(
            pending == .cloud ? "Move the game to the cloud?" : "Move the game back to this Mac?",
            isPresented: Binding(get: { pending != nil }, set: {
                if !$0 {
                    pending = nil
                }
            }),
            titleVisibility: .visible
        ) {
            if let target = pending {
                Button(target == .cloud ? "Move to Cloud" : "Move to This Mac") { perform(target) }
            }
        } message: {
            Text("A game is running. Phones reconnect to the new host in a few seconds. Votes already cast are not carried over.")
        }
    }

    private func request(_ target: HostMode) {
        guard target != current else { return }
        if mode.isGameRunning {
            pending = target
        } else {
            perform(target)
        }
    }

    private func perform(_ target: HostMode) {
        pending = nil
        Task {
            switch target {
            case .cloud: await mode.switchToCloud()
            case .selfHost: await mode.switchToSelfHost()
            }
        }
    }

    @ViewBuilder
    private var hostStatus: some View {
        switch mode.phase {
        case .selfHost:
            StatusLabel("Hosting on this Mac", systemImage: "desktopcomputer", tint: Theme.success)
        case .cloud:
            StatusLabel("Hosted in the cloud", systemImage: "cloud.fill", tint: Theme.success)
        case .switchingToCloud:
            StatusLabel("Moving the game to the cloud…", systemImage: "arrow.up.circle", tint: Theme.warning)
        case .switchingToSelfHost:
            StatusLabel("Moving the game back to this Mac…", systemImage: "arrow.down.circle", tint: Theme.warning)
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        switch mode.phase {
        case .cloud, .switchingToSelfHost:
            switch mode.adminClient?.status ?? .idle {
            case .connected where mode.adminClient?.isSignedIn == true:
                StatusLabel("Signed in to the cloud as admin", systemImage: "checkmark.circle.fill", tint: Theme.success)
            case .connected:
                StatusLabel(mode.adminClient?.lastError ?? "Signing in to the cloud…", systemImage: "key", tint: Theme.warning)
            case let .failed(reason):
                StatusLabel("Cloud connection lost: \(reason)", systemImage: "wifi.slash", tint: Theme.warning)
            default:
                StatusLabel("Connecting to the cloud…", systemImage: "wifi", tint: Theme.warning)
            }
        default:
            switch mode.uploader.status {
            case .idle:
                StatusLabel("Cloud backup waiting for the first save", systemImage: "icloud", tint: Theme.textSecondary)
            case .uploading:
                StatusLabel("Backing up to the cloud…", systemImage: "icloud.and.arrow.up", tint: Theme.warning)
            case let .uploaded(date):
                StatusLabel(
                    "Backed up \(date.formatted(.relative(presentation: .named)))",
                    systemImage: "checkmark.icloud",
                    tint: Theme.success
                )
            case let .failed(reason):
                StatusLabel("Backup failed: \(reason)", systemImage: "exclamationmark.icloud", tint: Theme.warning)
            }
        }
    }
}
