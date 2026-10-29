import SwiftUI

struct SetupView: View {
    let controller: HostController

    @State private var familyCount = TestingTools.isEnabled ? 4 : 12
    @State private var werewolfCount = 2
    @State private var discussionMinutes = 2
    @State private var votingMinutes = 2
    @State private var rssiThreshold = -65.0
    @State private var sightingFreshness = 5
    @State private var testRoles: [FamilyID: Role] = [:]
    @State private var killCooldown = GameSettings.standard.killCooldown
    @State private var sabotageCooldown = GameSettings.standard.sabotageCooldown
    @State private var sabotageDuration = GameSettings.standard.sabotageDuration
    @State private var oxygenCooldown = GameSettings.standard.sabotageCooldown
    @State private var oxygenDuration = GameSettings.standard.sabotageDuration
    @State private var gameMinutes = Int(GameSettings.standard.gameDuration / 60)
    @State private var renaming: FamilyInfo?
    @State private var renameText = ""
    @State private var errorMessage: String?
    @State private var confirmingNewGame = false

    private var host: GameHost {
        controller.host
    }

    private var isLobby: Bool {
        host.state.isLobby
    }

    private var testing: Bool {
        host.testingToolsEnabled
    }

    var body: some View {
        let issues = host.state.setupIssues(testing: testing)
        Form {
            Section("Game") {
                if testing {
                    Stepper("Families: \(familyCount)", value: $familyCount, in: 1 ... 40)
                } else {
                    Stepper("Werewolf families: \(werewolfCount)", value: $werewolfCount, in: 1 ... 10)
                }
                Stepper("Discussion: \(discussionMinutes) min", value: $discussionMinutes, in: 1 ... 5)
                Stepper("Voting: \(votingMinutes) min", value: $votingMinutes, in: 1 ... 5)
            }
            .disabled(!isLobby)

            Section {
                Stepper("Reactor fix time: \(Self.clock(sabotageDuration))", value: $sabotageDuration, in: 15 ... 600, step: 15)
                Stepper("Reactor cooldown: \(Self.clock(sabotageCooldown))", value: $sabotageCooldown, in: 0 ... 600, step: 15)
                Stepper("Oxygen fix time: \(Self.clock(oxygenDuration))", value: $oxygenDuration, in: 15 ... 600, step: 15)
                Stepper("Oxygen cooldown: \(Self.clock(oxygenCooldown))", value: $oxygenCooldown, in: 0 ... 600, step: 15)
            } header: {
                Text("Sabotage")
            } footer: {
                Text("Fix time is how long villagers have at the booth. After a sabotage, the cooldown of the booth that was used applies to every werewolf family.")
            }
            .disabled(!isLobby)

            if testing {
                testingSection
            }

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

            if !testing, let code = host.state.gameCode {
                Section {
                    HStack(spacing: 24) {
                        QRCodeView(text: code).frame(width: 160, height: 160)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(code).font(.title.monospaced()).textSelection(.enabled)
                            Text("\(host.state.players.count) players joined")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Join code")
                } footer: {
                    Text("The same QR is on the Public Display. Each player who scans becomes their own family.")
                }
            }

            Section("OC PIN") {
                LabeledContent("PIN for booth organisers") {
                    Text(host.state.ocPin)
                        .font(.title3.monospaced())
                        .textSelection(.enabled)
                }
            }

            Section("Families") {
                FamiliesTable(host: host, onRename: { renameText = $0.name; renaming = $0 })
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
        .onChange(of: killCooldown) { _, _ in apply() }
        .onChange(of: sabotageCooldown) { _, _ in apply() }
        .onChange(of: oxygenCooldown) { _, _ in apply() }
        .onChange(of: oxygenDuration) { _, _ in apply() }
        .onChange(of: sabotageDuration) { _, _ in apply() }
        .onChange(of: gameMinutes) { _, _ in apply() }
        .onChange(of: rssiThreshold) { _, _ in applyProximity() }
        .onChange(of: sightingFreshness) { _, _ in applyProximity() }
        .toolbar {
            ToolbarItem {
                Button("New Game", systemImage: "arrow.counterclockwise") { confirmingNewGame = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Start Game", systemImage: "play.fill") {
                    do { try startGame() } catch let error as HostError { errorMessage = error.message } catch {
                        errorMessage = "\(error)"
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!isLobby || !issues.isEmpty)
                .help(issues.first ?? "Assign roles and start the game")
            }
        }
        .alert("Rename family", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Rename") {
                if let family = renaming {
                    do { try host.renameFamily(family.id, to: renameText) } catch let error as HostError {
                        errorMessage = error.message
                    } catch { errorMessage = "\(error)" }
                }
                renaming = nil
            }
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

    private static func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }

    private func startGame() throws {
        if testing {
            try host.startTestGame(roles: testRoles)
        } else {
            try host.startGame()
        }
    }

    private var testingSection: some View {
        Section {
            ForEach(host.state.families.values.sorted { $0.id < $1.id }, id: \.id) { family in
                let player = host.state.player(of: family.id)
                Picker(selection: roleBinding(for: family.id)) {
                    ForEach([Role.villager, .werewolf], id: \.self) { role in
                        Label(role.title, systemImage: role.symbol).tag(role)
                    }
                } label: {
                    Text(family.name)
                    Text(player.map { "\($0.name) joined" } ?? "No phone: stands in as a family")
                }
            }
            Stepper("Kill cooldown: \(Int(killCooldown)) s", value: $killCooldown, in: 0 ... 300, step: 5)
            Stepper("Game length: \(gameMinutes) min", value: $gameMinutes, in: 1 ... 60)
        } header: {
            Text("Testing")
        } footer: {
            Text("Rehearsal only. Pick each family's role, then start with as few as one family and one phone. Families without a phone stand in for others: use the Game screen to stamp, eliminate, vote and trigger sabotage for them. The game can end early, because the usual win rules still apply.")
        }
        .disabled(!isLobby)
    }

    private func roleBinding(for id: FamilyID) -> Binding<Role> {
        Binding(get: { testRoles[id] ?? .villager }, set: { testRoles[id] = $0 })
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
        killCooldown = state.settings.killCooldown
        sabotageCooldown = state.settings.sabotageCooldown
        sabotageDuration = state.settings.sabotageDuration
        oxygenCooldown = state.settings.sabotageCooldown(for: .oxygen)
        oxygenDuration = state.settings.sabotageDuration(for: .oxygen)
        gameMinutes = max(1, Int(state.settings.gameDuration / 60))
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
        settings.sabotageCooldown = sabotageCooldown
        settings.sabotageDuration = sabotageDuration
        settings.oxygenCooldown = oxygenCooldown
        settings.oxygenDuration = oxygenDuration
        if testing {
            settings.killCooldown = killCooldown
            settings.gameDuration = TimeInterval(gameMinutes * 60)
        }
        do {
            if testing {
                try host.configure(
                    familyCount: familyCount,
                    werewolfCount: min(werewolfCount, max(1, (familyCount - 1) / 2)),
                    settings: settings
                )
            } else {
                try host.updateSettings(werewolfCount: werewolfCount, settings: settings)
            }
        } catch let error as HostError {
            errorMessage = error.message
        } catch {
            errorMessage = "\(error)"
        }
    }
}

private struct FamiliesTable: View {
    let host: GameHost
    let onRename: (FamilyInfo) -> Void

    var body: some View {
        Table(families) {
            TableColumn("Family", value: \.name)
            TableColumn("Player") { (family: FamilyInfo) in
                if let name = host.state.player(of: family.id)?.name {
                    Text(name)
                } else {
                    Text("Waiting…").foregroundStyle(.secondary)
                }
            }
            TableColumn("Rename") { (family: FamilyInfo) in
                Button("Rename", systemImage: "pencil") { onRename(family) }
                    .labelStyle(.iconOnly)
                    .help("Rename \(family.name)")
            }
        }
    }

    private var families: [FamilyInfo] {
        host.state.families.values.sorted { $0.id < $1.id }
    }

}
