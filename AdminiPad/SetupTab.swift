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
            SetupBento(title: "Game") {
                Button { client.send(.admin(.startGame)) } label: {
                    BentoTile(
                        title: admin.isLobby ? "Start Game" : "Game in progress",
                        subtitle: !admin.isLobby ? "Use the Game tab" : admin.setupIssues.first ?? "Assign roles and start",
                        systemImage: admin.isLobby ? "play.fill" : "play.circle.fill",
                        tint: admin.setupIssues.isEmpty ? Theme.success : Theme.warning,
                        isProminent: admin.isLobby && admin.setupIssues.isEmpty
                    )
                }
                .buttonStyle(.plain)
                .disabled(!admin.isLobby || !admin.setupIssues.isEmpty)
                ToggleTile(
                    title: "Debug Mode",
                    subtitle: "Two families, no cooldowns",
                    systemImage: "ladybug.fill",
                    isOn: setting(\.isDebug) { $0.debugMode = $1 }
                )
                .disabled(!admin.isLobby)
            }

            SetupBento(title: "Family count") {
                StepperTile(
                    title: "Werewolf families",
                    subtitle: "Fewer than half of all families",
                    systemImage: "moon.stars.fill",
                                        value: Binding(
                        get: { admin.werewolfCount },
                        set: { send(werewolfCount: $0, settings: admin.settings) }
                    ),
                    range: 1 ... 10
                )
                .disabled(!admin.isLobby)
            }

            SetupBento(title: "Players") {
                if let code = admin.joinCode {
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
                    Button("New PIN", systemImage: "arrow.triangle.2.circlepath") { client.send(.admin(.regenerateOCPIN)) }
                } label: {
                    BentoTile(
                        title: "OC PIN",
                        subtitle: isPinVisible ? admin.ocPin : "Tap to show or change",
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
                    seconds: setting(\.discussionDuration) { $0.discussionDuration = $1 },
                    range: 30 ... 600
                )
                .disabled(!admin.isLobby)
                DurationTile(
                    title: "Voting",
                    subtitle: "Per meeting",
                    systemImage: "hand.raised.fill",
                    seconds: setting(\.votingDuration) { $0.votingDuration = $1 },
                    range: 30 ... 600
                )
                .disabled(!admin.isLobby)
            }

            SetupBento(title: "Sabotage", footer: "Fix time is how long villagers have at the booth. After a sabotage, the cooldown of the booth that was used applies to every werewolf family.") {
                DurationTile(
                    title: "Reactor fix time",
                    subtitle: "Villagers' window",
                    systemImage: "bolt.fill",
                    seconds: seconds(.reactor, duration: true)
                )
                .disabled(!admin.isLobby)
                DurationTile(
                    title: "Reactor cooldown",
                    subtitle: "Before the next sabotage",
                    systemImage: "bolt.slash.fill",
                    seconds: seconds(.reactor, duration: false),
                    range: 0 ... 600
                )
                .disabled(!admin.isLobby)
                DurationTile(
                    title: "Oxygen fix time",
                    subtitle: "Villagers' window",
                    systemImage: "wind",
                    seconds: seconds(.oxygen, duration: true)
                )
                .disabled(!admin.isLobby)
                DurationTile(
                    title: "Oxygen cooldown",
                    subtitle: "Before the next sabotage",
                    systemImage: "wind.snow",
                    seconds: seconds(.oxygen, duration: false),
                    range: 0 ... 600
                )
                .disabled(!admin.isLobby)
            }

            SetupBento(title: "Bluetooth", footer: "Higher (closer to zero) means players must stand closer for a kill. Calibrate with real phones at the venue.") {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(systemName: "dot.radiowaves.left.and.right").font(.title2).foregroundStyle(Theme.accent)
                        .accessibilityHidden(true)
                    Spacer(minLength: Spacing.sm)
                    Text("\(admin.rssiThreshold) dBm").font(.largeTitle.bold()).monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("Kill range").font(.headline)
                    Slider(value: Binding(
                        get: { Double(admin.rssiThreshold) },
                        set: { client.send(.admin(.setProximity(rssiThreshold: Int($0), sightingFreshness: admin.sightingFreshness))) }
                    ), in: -90 ... -40, step: 1) { Text("Signal threshold") }
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
                .padding(Spacing.md)
                .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
                StepperTile(
                    title: "Sighting valid for",
                    subtitle: "Seconds a Bluetooth sighting counts",
                    systemImage: "eye.fill",
                    unit: "s",
                    value: Binding(
                        get: { Int(admin.sightingFreshness) },
                        set: { client.send(.admin(.setProximity(rssiThreshold: admin.rssiThreshold, sightingFreshness: TimeInterval($0)))) }
                    ),
                    range: 1 ... 10
                )
            }


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
            if gone {
                isShowingMap = false
            }
        }
        .fileImporter(isPresented: $isChoosingMap, allowedContentTypes: [.image]) { importMap($0) }
        .alert("Rename family", isPresented: Binding(get: { renaming != nil }, set: {
            if !$0 {
                renaming = nil
            }
        })) {
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
            isPresented: Binding(get: { deleting != nil }, set: {
                if !$0 {
                    deleting = nil
                }
            }),
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
            defer {
                if isScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            try client.send(.admin(.setBoothMap(Data(contentsOf: url))))
            mapError = nil
        } catch {
            mapError = "Couldn't read that file."
        }
    }
}
