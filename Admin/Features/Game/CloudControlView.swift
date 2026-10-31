import SwiftUI

struct CloudControlView: View {
    let mode: HostModeController
    let title: String

    @State private var confirmingNewGame = false

    private var admin: AdminView? {
        mode.adminClient?.view?.admin
    }

    var body: some View {
        Form {
            Section {
                StatusLabel("The game is hosted in the cloud", systemImage: "cloud.fill", tint: Theme.success).themedRows()
                if let admin {
                    LabeledContent("Join code", value: admin.joinCode ?? "None").themedRows()
                    LabeledContent("Players joined", value: "\(admin.playersJoined)").themedRows()
                    LabeledContent("OC PIN", value: admin.ocPin).themedRows()
                    LabeledContent("Phase", value: phaseTitle(admin)).themedRows()
                } else {
                    StatusLabel(mode.adminClient?.lastError ?? "Waiting for the cloud host…", systemImage: "hourglass", tint: Theme.warning)
                        .themedRows()
                }
            } footer: {
                Text("Full game controls are on the iPad admin. This Mac sends the main commands and drives the Public Display.")
            }
            if let admin {
                Section("Controls") {
                    if admin.isLobby {
                        Button("Start Game", systemImage: "play.fill") { mode.send(.startGame) }
                            .disabled(!admin.setupIssues.isEmpty)
                            .themedRows()
                        ForEach(admin.setupIssues, id: \.self) { StatusLabel(
                            $0,
                            systemImage: "exclamationmark.triangle.fill",
                            tint: Theme.warning
                        ).themedRows() }
                    } else {
                        Button("Start Meeting", systemImage: "bell.badge") { mode.send(.startMeeting) }.themedRows()
                        Button("Resolve Sabotage", systemImage: "wrench.and.screwdriver") { mode.send(.resolveSabotage) }
                            .disabled(admin.sabotage == nil)
                            .themedRows()
                    }
                    Button("Ring Bell", systemImage: "bell") { mode.send(.ringBell) }.themedRows()
                    Button("New Game", systemImage: "arrow.counterclockwise", role: .destructive) { confirmingNewGame = true }.themedRows()
                }
                Section("Families") {
                    ForEach(admin.families) { family in
                        HStack {
                            Text(family.name)
                            Spacer()
                            Text(family.playerName ?? "Open").foregroundStyle(Theme.textSecondary)
                            Text(family.life.title).foregroundStyle(Theme.textSecondary)
                        }
                        .themedRows()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .themedBackground()
        .navigationTitle(title)
        .confirmationDialog("Start a new game?", isPresented: $confirmingNewGame, titleVisibility: .visible) {
            Button("New Game", role: .destructive) { mode.send(.newGame) }
        } message: {
            Text("The current game and every player are removed.")
        }
    }

    private func phaseTitle(_ admin: AdminView) -> String {
        if admin.isLobby {
            return "Lobby"
        }
        switch admin.phase {
        case .running: return "Playing"
        case .discussion: return "Discussion"
        case .voting: return "Voting"
        case .ended: return "Ended"
        }
    }
}
