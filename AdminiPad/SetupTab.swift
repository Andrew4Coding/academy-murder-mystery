import SwiftUI
import UniformTypeIdentifiers

struct SetupTab: View {
    let admin: AdminView
    let client: GameClient

    @State private var isPinVisible = false
    @State private var renaming: AdminFamilyRow?
    @State private var renameText = ""
    @State private var deleting: AdminFamilyRow?
    @State private var confirmingNewGame = false
    @State private var isChoosingMap = false
    @State private var isShowingMap = false
    @State private var mapError: String?

    var body: some View {
        Form {
            Section {
                if !admin.isLobby {
                    StatusLabel("Game in progress", systemImage: "play.circle.fill", tint: Theme.success)
                } else if admin.setupIssues.isEmpty {
                    StatusLabel("Ready to start", systemImage: "checkmark.circle.fill", tint: Theme.success)
                } else {
                    ForEach(admin.setupIssues, id: \.self) { issue in
                        StatusLabel(issue, systemImage: "exclamationmark.circle.fill", tint: Theme.warning)
                    }
                }
                Button("Start Game", systemImage: "play.fill") { client.send(.admin(.startGame)) }
                    .buttonStyle(.accentFill)
                    .disabled(!admin.isLobby || !admin.setupIssues.isEmpty)
                    .accessibilityHint(admin.setupIssues.first ?? "Assigns roles and starts the game")
            } header: {
                Text("Start the game")
            } footer: {
                if admin.isLobby {
                    Text("Players join with the code below. Start when every family has a player.")
                }
            }
            .themedRows()

            if let code = admin.joinCode {
                Section {
                    HStack(spacing: Spacing.lg) {
                        QRCodeView(text: code)
                            .frame(width: 160, height: 160)
                            .accessibilityLabel("QR code to join with code \(code)")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(code).font(.title.monospaced()).textSelection(.enabled)
                            Text("\(admin.playersJoined) players joined").foregroundStyle(Theme.textSecondary)
                        }
                    }
                } header: {
                    Text("Players join")
                } footer: {
                    Text("Each player who scans becomes their own family.")
                }
                .themedRows()
            }

            Section("OC PIN") {
                LabeledContent("PIN for sabotage organisers") {
                    HStack {
                        Text(isPinVisible ? admin.ocPin : "••••").font(.title3.monospaced()).textSelection(.enabled)
                        Button(isPinVisible ? "Hide PIN" : "Show PIN", systemImage: isPinVisible ? "eye.slash" : "eye") {
                            isPinVisible.toggle()
                        }
                        .labelStyle(.iconOnly)
                        Button("New PIN", systemImage: "arrow.triangle.2.circlepath") { client.send(.admin(.regenerateOCPIN)) }
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .themedRows()

            Section("Game") {
                Stepper("Werewolf families: \(admin.werewolfCount)", value: Binding(
                    get: { admin.werewolfCount },
                    set: { send(werewolfCount: $0, settings: admin.settings) }
                ), in: 1 ... 10)
                Toggle("Debug Mode", isOn: setting(\.isDebug) { $0.debugMode = $1 })
                Stepper("Discussion: \(Int(admin.settings.discussionDuration / 60)) min", value: minutes(\.discussionDuration), in: 1 ... 5)
                Stepper("Voting: \(Int(admin.settings.votingDuration / 60)) min", value: minutes(\.votingDuration), in: 1 ... 5)
            }
            .disabled(!admin.isLobby)
            .themedRows()

            Section {
                Stepper("Reactor fix time: \(Self.clock(admin.settings.sabotageDuration))", value: seconds(.reactor, duration: true), in: 15 ... 600, step: 15)
                Stepper("Reactor cooldown: \(Self.clock(admin.settings.sabotageCooldown))", value: seconds(.reactor, duration: false), in: 0 ... 600, step: 15)
                Stepper("Oxygen fix time: \(Self.clock(admin.settings.sabotageDuration(for: .oxygen)))", value: seconds(.oxygen, duration: true), in: 15 ... 600, step: 15)
                Stepper("Oxygen cooldown: \(Self.clock(admin.settings.sabotageCooldown(for: .oxygen)))", value: seconds(.oxygen, duration: false), in: 0 ... 600, step: 15)
            } header: {
                Text("Sabotage")
            } footer: {
                Text("Fix time is how long villagers have at the booth. After a sabotage, the cooldown of the booth that was used applies to every werewolf family.")
            }
            .disabled(!admin.isLobby)
            .themedRows()

            Section {
                LabeledContent("Kill range") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(admin.rssiThreshold) },
                            set: { client.send(.admin(.setProximity(rssiThreshold: Int($0), sightingFreshness: admin.sightingFreshness))) }
                        ), in: -90 ... -40, step: 1) {
                            Text("Signal threshold")
                        }
                        .frame(maxWidth: 260)
                        Text("\(admin.rssiThreshold) dBm").monospacedDigit().frame(minWidth: 80, alignment: .trailing)
                    }
                }
                Stepper("Sighting stays valid for \(Int(admin.sightingFreshness)) s", value: Binding(
                    get: { Int(admin.sightingFreshness) },
                    set: { client.send(.admin(.setProximity(rssiThreshold: admin.rssiThreshold, sightingFreshness: TimeInterval($0)))) }
                ), in: 1 ... 10)
            } header: {
                Text("Bluetooth")
            } footer: {
                Text("Higher (closer to zero) means players must stand closer for a kill. Calibrate with real phones at the venue.")
            }
            .themedRows()

            Section {
                if let map = client.boothMap {
                    BoothMapCard(map: map) { isShowingMap = true }
                    HStack {
                        Button("Replace…") { isChoosingMap = true }
                        Button("Remove", role: .destructive) { client.send(.admin(.removeBoothMap)) }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Choose Image…", systemImage: "map") { isChoosingMap = true }
                }
                if let mapError {
                    StatusLabel.error(mapError)
                }
            } header: {
                Text("Booth map")
            } footer: {
                Text("Optional. Players and OC devices can open it. Large images are shrunk to 3000 px.")
            }
            .themedRows()

            Section("Families") {
                ForEach(admin.families) { family in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(family.name)
                            Text(family.playerName ?? "Waiting for a player…").font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Button("Rename \(family.name)", systemImage: "pencil") {
                            renameText = family.name
                            renaming = family
                        }
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        Button("Delete \(family.name)", systemImage: "trash", role: .destructive) { deleting = family }
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .disabled(!admin.isLobby)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .themedRows()

            if let error = client.lastError {
                Section { StatusLabel.error(error) }
            }
        }
        .formStyle(.grouped)
        .themedBackground()
        .navigationTitle("Setup")
        .toolbar {
            ToolbarItem {
                Button("New Game", systemImage: "arrow.counterclockwise") { confirmingNewGame = true }
            }
        }
        .fullScreenCover(isPresented: $isShowingMap) {
            if let map = client.boothMap {
                BoothMapViewer(map: map) { isShowingMap = false }
            }
        }
        .onChange(of: client.boothMap == nil) { _, gone in
            if gone { isShowingMap = false }
        }
        .fileImporter(isPresented: $isChoosingMap, allowedContentTypes: [.image]) { importMap($0) }
        .alert("Rename family", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Rename") {
                if let family = renaming {
                    client.send(.admin(.renameFamily(family.id, renameText)))
                }
                renaming = nil
            }
        }
        .confirmationDialog(
            deleting.map { "Delete \($0.name)?" } ?? "",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            if let family = deleting {
                Button("Delete \(family.name)", role: .destructive) {
                    client.send(.admin(.removeFamily(family.id)))
                    deleting = nil
                }
            }
        } message: {
            Text("The player in this family goes back to the join screen.")
        }
        .confirmationDialog("Start a new game?", isPresented: $confirmingNewGame) {
            Button("New Game", role: .destructive) { client.send(.admin(.newGame)) }
        } message: {
            Text("This removes every family, player and result from the current game.")
        }
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }

    private func send(werewolfCount: Int, settings: GameSettings) {
        client.send(.admin(.updateSettings(werewolfCount: werewolfCount, settings: settings)))
    }

    private func setting<T>(_ read: KeyPath<GameSettings, T>, write: @escaping (inout GameSettings, T) -> Void) -> Binding<T> {
        Binding(
            get: { admin.settings[keyPath: read] },
            set: {
                var settings = admin.settings
                write(&settings, $0)
                send(werewolfCount: admin.werewolfCount, settings: settings)
            }
        )
    }

    private func minutes(_ path: WritableKeyPath<GameSettings, TimeInterval>) -> Binding<Int> {
        Binding(
            get: { Int(admin.settings[keyPath: path] / 60) },
            set: {
                var settings = admin.settings
                settings[keyPath: path] = TimeInterval($0 * 60)
                send(werewolfCount: admin.werewolfCount, settings: settings)
            }
        )
    }

    private func seconds(_ kind: SabotageKind, duration: Bool) -> Binding<TimeInterval> {
        Binding(
            get: { duration ? admin.settings.sabotageDuration(for: kind) : admin.settings.sabotageCooldown(for: kind) },
            set: {
                var settings = admin.settings
                switch (kind, duration) {
                case (.reactor, true): settings.sabotageDuration = $0
                case (.reactor, false): settings.sabotageCooldown = $0
                case (.oxygen, true): settings.oxygenDuration = $0
                case (.oxygen, false): settings.oxygenCooldown = $0
                }
                send(werewolfCount: admin.werewolfCount, settings: settings)
            }
        )
    }

    private func importMap(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            client.send(.admin(.setBoothMap(try Data(contentsOf: url))))
            mapError = nil
        } catch {
            mapError = "Couldn't read that file."
        }
    }
}
