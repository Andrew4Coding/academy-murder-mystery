import SwiftUI

struct SetupView: View {
    let controller: HostController

    @State private var familyCount = 12
    @State private var werewolfCount = 2
    @State private var discussionMinutes = 2
    @State private var votingMinutes = 2
    @State private var rssiThreshold = -65.0
    @State private var sightingFreshness = 5
    @State private var qrFamily: FamilyInfo?
    @State private var errorMessage: String?
    @State private var confirmingNewGame = false

    private var host: GameHost {
        controller.host
    }

    private var isLobby: Bool {
        host.state.isLobby
    }

    var body: some View {
        let issues = host.state.setupIssues()
        Form {
            Section("Game") {
                Stepper("Families: \(familyCount)", value: $familyCount, in: 3 ... 40)
                Stepper("Werewolf families: \(werewolfCount)", value: $werewolfCount, in: 1 ... max(1, (familyCount - 1) / 2))
                Stepper("Discussion: \(discussionMinutes) min", value: $discussionMinutes, in: 1 ... 5)
                Stepper("Voting: \(votingMinutes) min", value: $votingMinutes, in: 1 ... 5)
            }
            .disabled(!isLobby)

            Section {
                LabeledContent("Kill range") {
                    Slider(value: $rssiThreshold, in: -90 ... -40, step: 1) {
                        Text("Signal threshold")
                    } minimumValueLabel: {
                        Text("Far")
                    } maximumValueLabel: {
                        Text("Close")
                    }
                    .frame(maxWidth: 280)
                    Text("\(Int(rssiThreshold)) dBm").monospacedDigit().frame(width: 70, alignment: .trailing)
                }
                Stepper("Sighting stays valid for \(sightingFreshness) s", value: $sightingFreshness, in: 1 ... 10)
            } header: {
                Text("Bluetooth")
            } footer: {
                Text("Higher (closer to zero) means players must stand closer for a kill. Calibrate with real phones at the venue.")
            }

            Section("OC PIN") {
                LabeledContent("PIN for booth organisers") {
                    Text(host.state.ocPin)
                        .font(.title3.monospaced())
                        .textSelection(.enabled)
                }
            }

            Section("Families") {
                FamiliesTable(host: host, onShowQR: { qrFamily = $0 })
                    .frame(minHeight: 220)
            }

            if isLobby, !issues.isEmpty {
                Section("Before you can start") {
                    ForEach(issues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.circle")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Setup")
        .onAppear(perform: loadDraft)
        .onChange(of: familyCount) { _, _ in apply() }
        .onChange(of: werewolfCount) { _, _ in apply() }
        .onChange(of: discussionMinutes) { _, _ in apply() }
        .onChange(of: votingMinutes) { _, _ in apply() }
        .onChange(of: rssiThreshold) { _, _ in applyProximity() }
        .onChange(of: sightingFreshness) { _, _ in applyProximity() }
        .toolbar {
            ToolbarItem {
                Button("New Game", systemImage: "arrow.counterclockwise") { confirmingNewGame = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Start Game", systemImage: "play.fill") {
                    do { try host.startGame() } catch let error as HostError { errorMessage = error.message } catch {
                        errorMessage = "\(error)"
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!isLobby || !issues.isEmpty)
                .help(issues.first ?? "Assign roles and start the game")
            }
        }
        .popover(item: $qrFamily) { family in
            VStack(spacing: 12) {
                Text(family.name).font(.headline)
                QRCodeView(text: family.joinCode).frame(width: 260, height: 260)
                Text(family.joinCode).font(.title2.monospaced()).textSelection(.enabled)
            }
            .padding()
        }
        .alert("Can't change setup", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil; loadDraft() }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("Start a new game?", isPresented: $confirmingNewGame) {
            Button("New Game", role: .destructive) {
                do { try host.newGame(); loadDraft() } catch { errorMessage = "\(error)" }
            }
        } message: {
            Text("This removes every family, player and result from the current game.")
        }
    }

    private func loadDraft() {
        let state = host.state
        if !state.families.isEmpty {
            familyCount = state.families.count
        }
        werewolfCount = max(1, state.werewolfCount)
        discussionMinutes = max(1, Int(state.settings.discussionDuration / 60))
        votingMinutes = max(1, Int(state.settings.votingDuration / 60))
        rssiThreshold = Double(state.rssiThreshold)
        sightingFreshness = Int(state.sightingFreshness)
        if state.families.isEmpty {
            apply()
        }
    }

    private func applyProximity() {
        host.setProximity(rssiThreshold: Int(rssiThreshold), sightingFreshness: TimeInterval(sightingFreshness))
    }

    private func apply() {
        guard isLobby else { return }
        var settings = host.state.settings
        settings.discussionDuration = TimeInterval(discussionMinutes * 60)
        settings.votingDuration = TimeInterval(votingMinutes * 60)
        do {
            try host.configure(
                familyCount: familyCount,
                werewolfCount: min(werewolfCount, max(1, (familyCount - 1) / 2)),
                settings: settings
            )
        } catch let error as HostError {
            errorMessage = error.message
        } catch {
            errorMessage = "\(error)"
        }
    }
}

private struct FamiliesTable: View {
    let host: GameHost
    let onShowQR: (FamilyInfo) -> Void

    var body: some View {
        Table(families) {
            TableColumn("Family", value: \.name)
            TableColumn("Join code") { (family: FamilyInfo) in
                Text(family.joinCode).font(.body.monospaced()).textSelection(.enabled)
            }
            TableColumn("Members") { (family: FamilyInfo) in
                Text("\(host.state.members(of: family.id).count) of \(host.state.maxFamilySize)")
            }
            TableColumn("Head of family") { (family: FamilyInfo) in
                HeadCell(name: headName(of: family))
            }
            TableColumn("QR") { (family: FamilyInfo) in
                Button("Show QR", systemImage: "qrcode") { onShowQR(family) }
                    .labelStyle(.iconOnly)
                    .help("Show a QR code for \(family.name)")
            }
        }
    }

    private var families: [FamilyInfo] {
        host.state.families.values.sorted { $0.id < $1.id }
    }

    private func headName(of family: FamilyInfo) -> String? {
        family.head.flatMap { host.state.players[$0]?.name }
    }
}

private struct HeadCell: View {
    let name: String?

    var body: some View {
        if let name {
            Label(name, systemImage: "star.fill")
        } else {
            Text("Not chosen").foregroundStyle(.secondary)
        }
    }
}
