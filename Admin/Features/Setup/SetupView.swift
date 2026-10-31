import SwiftUI
import UniformTypeIdentifiers

struct SetupView: View {
    let controller: HostController

    @State private var isPinVisible = false
    @State private var familyCount = TestingTools.isEnabled ? 4 : 12
    @State private var werewolfCount = 2
    @State private var discussionMinutes = 2
    @State private var votingMinutes = 2
    @State private var rssiThreshold = -75.0
    @State private var sightingFreshness = 10
    @State private var testRoles: [FamilyID: Role] = [:]
    @State private var debugMode = false
    @State private var killCooldown = GameSettings.standard.killCooldown
    @State private var sabotageCooldown = GameSettings.standard.sabotageCooldown
    @State private var sabotageDuration = GameSettings.standard.sabotageDuration
    @State private var oxygenCooldown = GameSettings.standard.sabotageCooldown
    @State private var oxygenDuration = GameSettings.standard.sabotageDuration
    @State private var gameMinutes = Int(GameSettings.standard.gameDuration / 60)
    @State private var renaming: FamilyInfo?
    @State private var renameText = ""
    @State private var deleting: FamilyInfo?
    @State private var errorMessage: String?
    @State private var confirmingNewGame = false
    @State private var isChoosingMap = false

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
            SetupBento(title: "Game") {
                Button(action: startFromForm) {
                    BentoTile(
                        title: isLobby ? "Start Game" : "Game in progress",
                        subtitle: !isLobby ? "Use the Game screen" : issues.first ?? "Assign roles and start",
                        systemImage: isLobby ? "play.fill" : "play.circle.fill",
                        tint: issues.isEmpty ? Theme.success : Theme.warning,
                        isProminent: isLobby && issues.isEmpty
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isLobby || !issues.isEmpty)
                ToggleTile(title: "Debug Mode", subtitle: "Two families, no cooldowns", systemImage: "ladybug.fill", isOn: $debugMode)
                    .disabled(!isLobby)
            }

            SetupBento(title: "Family count") {
                StatTile(
                    title: "Families",
                    value: "\(host.state.families.count)",
                    subtitle: "\(host.state.players.count) players joined",
                    systemImage: "person.3.fill"
                )
                if testing {
                    StepperTile(
                        title: "Families",
                        subtitle: "Rehearsal size",
                        systemImage: "person.crop.rectangle.stack.fill",
                        valueText: "\(familyCount)",
                        value: $familyCount,
                        range: 1 ... 40
                    )
                    .disabled(!isLobby)
                } else {
                    StepperTile(
                        title: "Werewolf families",
                        subtitle: "Fewer than half of all families",
                        systemImage: "moon.stars.fill",
                        valueText: "\(werewolfCount)",
                        value: $werewolfCount,
                        range: 1 ... 10
                    )
                    .disabled(!isLobby)
                }
            }

            SetupBento(title: "Players") {
                if !testing, let code = host.state.gameCode {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        QRCodeView(text: code)
                            .frame(width: 96, height: 96)
                            .accessibilityLabel("QR code to join with code \(code)")
                        Text(code).font(.title2.monospaced().bold()).textSelection(.enabled)
                        Text("Join code").font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
                    .padding(Spacing.md)
                    .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
                }
                Menu {
                    Button(isPinVisible ? "Hide PIN" : "Show PIN", systemImage: isPinVisible ? "eye.slash" : "eye") {
                        isPinVisible.toggle()
                    }
                    Button("New PIN", systemImage: "arrow.triangle.2.circlepath") { host.regenerateOCPIN() }
                } label: {
                    BentoTile(
                        title: "OC PIN",
                        subtitle: isPinVisible ? host.state.ocPin : "Tap to show or change",
                        systemImage: "key.fill"
                    )
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
            }

            SetupBento(title: "Meetings") {
                DurationTile(
                    title: "Discussion",
                    subtitle: "Per meeting",
                    systemImage: "bubble.left.and.bubble.right.fill",
                    seconds: Binding(get: { TimeInterval(discussionMinutes * 60) }, set: { discussionMinutes = Int($0 / 60) }),
                    range: 60 ... 300,
                    secondsStep: 60
                )
                .disabled(!isLobby)
                DurationTile(
                    title: "Voting",
                    subtitle: "Per meeting",
                    systemImage: "hand.raised.fill",
                    seconds: Binding(get: { TimeInterval(votingMinutes * 60) }, set: { votingMinutes = Int($0 / 60) }),
                    range: 60 ... 300,
                    secondsStep: 60
                )
                .disabled(!isLobby)
            }

            SetupBento(title: "Sabotage", footer: "Fix time is how long villagers have at the booth. After a sabotage, the cooldown of the booth that was used applies to every werewolf family.") {
                DurationTile(title: "Reactor fix time", subtitle: "Villagers' window", systemImage: "bolt.fill", seconds: $sabotageDuration)
                    .disabled(!isLobby)
                DurationTile(
                    title: "Reactor cooldown",
                    subtitle: "Before the next sabotage",
                    systemImage: "bolt.slash.fill",
                    seconds: $sabotageCooldown,
                    range: 0 ... 600
                )
                .disabled(!isLobby)
                DurationTile(title: "Oxygen fix time", subtitle: "Villagers' window", systemImage: "wind", seconds: $oxygenDuration)
                    .disabled(!isLobby)
                DurationTile(
                    title: "Oxygen cooldown",
                    subtitle: "Before the next sabotage",
                    systemImage: "wind.snow",
                    seconds: $oxygenCooldown,
                    range: 0 ... 600
                )
                .disabled(!isLobby)
            }

            SetupBento(title: "Bluetooth", footer: "Higher (closer to zero) means players must stand closer for a kill. Calibrate with real phones at the venue.") {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(systemName: "dot.radiowaves.left.and.right").font(.title2).foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                    Spacer(minLength: Spacing.sm)
                    Text("\(Int(rssiThreshold)) dBm").font(.largeTitle.bold()).monospacedDigit()
                    Text("Kill range").font(.headline)
                    Slider(value: $rssiThreshold, in: -90 ... -40, step: 1) { Text("Signal threshold") }
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
                .padding(Spacing.md)
                .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
                StepperTile(
                    title: "Sighting valid for",
                    subtitle: "Seconds a Bluetooth sighting counts",
                    systemImage: "eye.fill",
                    valueText: "\(sightingFreshness) s",
                    value: $sightingFreshness,
                    range: 1 ... 10
                )
            }

            if testing {
                testingSection
            }

            BoothMapSection(
                map: host.boothMap,
                onChoose: { isChoosingMap = true },
                onRemove: {
                    do { try host.removeBoothMap() } catch { errorMessage = "\(error)" }
                }
            )

            Section("Families") {
                FamiliesTable(host: host, onRename: { renameText = $0.name; renaming = $0 }, onDelete: { deleting = $0 })
                    .frame(minHeight: 220)
            }
            .themedRows()
        }
        .formStyle(.grouped)
        .themedBackground()
        .navigationTitle("Setup")
        .onAppear(perform: loadDraft)
        .onChange(of: host.state.settings) { _, _ in loadDraft() }
        .onChange(of: host.state.werewolfCount) { _, _ in loadDraft() }
        .onChange(of: host.state.rssiThreshold) { _, _ in loadDraft() }
        .onChange(of: host.state.sightingFreshness) { _, _ in loadDraft() }
        .onChange(of: familyCount) { _, _ in apply() }
        .onChange(of: werewolfCount) { _, _ in apply() }
        .onChange(of: discussionMinutes) { _, _ in apply() }
        .onChange(of: votingMinutes) { _, _ in apply() }
        .onChange(of: debugMode) { _, _ in apply() }
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
                Button("Start Game", systemImage: "play.fill", action: startFromForm)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!isLobby || !issues.isEmpty)
                    .help(issues.first ?? "Assign roles and start the game")
            }
        }
        .fileImporter(isPresented: $isChoosingMap, allowedContentTypes: [.image]) { result in
            importMap(result)
        }
        .alert("Rename family", isPresented: Binding(get: { renaming != nil }, set: {
            if !$0 {
                renaming = nil
            }
        })) {
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
        .confirmationDialog(
            deleting.map { "Delete \($0.name)?" } ?? "",
            isPresented: Binding(get: { deleting != nil }, set: {
                if !$0 {
                    deleting = nil
                }
            }),
            titleVisibility: .visible
        ) {
            if let family = deleting {
                Button("Delete \(family.name)", role: .destructive) {
                    do { try host.removeFamily(family.id) } catch let error as HostError {
                        errorMessage = error.message
                    } catch { errorMessage = "\(error)" }
                    deleting = nil
                }
            }
        } message: {
            Text("The player in this family goes back to the join screen.")
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

    private func importMap(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try host.setBoothMap(imageData: Data(contentsOf: url))
        } catch let error as HostError {
            errorMessage = error.message
        } catch {
            errorMessage = "Couldn't read that file."
        }
    }

    private func startFromForm() {
        do { try startGame() } catch let error as HostError { errorMessage = error.message } catch {
            errorMessage = "\(error)"
        }
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
            Text(
                "Rehearsal only. Pick each family's role, then start with as few as one family and one phone. Families without a phone stand in for others: use the Game screen to eliminate, vote and trigger sabotage for them. The game can end early, because the usual win rules still apply."
            )
        }
        .disabled(!isLobby)
        .themedRows()
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
        debugMode = state.settings.isDebug
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
        settings.debugMode = debugMode
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
    let onDelete: (FamilyInfo) -> Void

    var body: some View {
        Table(families) {
            TableColumn("Family", value: \.name)
            TableColumn("Player") { (family: FamilyInfo) in
                if let name = host.state.player(of: family.id)?.name {
                    Text(name)
                } else {
                    Text("Waiting for a player…").foregroundStyle(Theme.textSecondary)
                }
            }
            TableColumn("Rename") { (family: FamilyInfo) in
                Button("Rename", systemImage: "pencil") { onRename(family) }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Rename \(family.name)")
                    .help("Rename \(family.name)")
            }
            TableColumn("Delete") { (family: FamilyInfo) in
                Button("Delete \(family.name)", systemImage: "trash", role: .destructive) { onDelete(family) }
                    .labelStyle(.iconOnly)
                    .disabled(!host.state.isLobby)
                    .help("Delete \(family.name)")
            }
        }
    }

    private var families: [FamilyInfo] {
        host.state.families.values.sorted { $0.id < $1.id }
    }
}
