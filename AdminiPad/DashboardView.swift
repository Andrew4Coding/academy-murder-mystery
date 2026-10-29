import SwiftUI

struct DashboardView: View {
    let admin: AdminView
    let client: GameClient

    var body: some View {
        NavigationSplitView {
            List {
                statusSection
                if admin.isLobby {
                    joinSection
                }
                controlsSection
                if let error = client.lastError {
                    Section { StatusLabel.error(error) }
                }
            }
            .navigationTitle("Dashboard")
            .navigationSplitViewColumnWidth(min: 320, ideal: 380)
            .toolbar { ToolbarItem { Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") { client.signOut() } } }
        } detail: {
            FamiliesTable(families: admin.families, canDelete: admin.isLobby) { client.send(.admin(.removeFamily($0))) }
                .navigationTitle("Families")
        }
    }

    private var statusSection: some View {
        Section("Status") {
            switch admin.phase {
            case .running:
                LabeledContent("Phase", value: admin.isLobby ? "Lobby" : "Playing")
                if let end = admin.gameEndsAt, !admin.isLobby {
                    LabeledContent("Until the final vote") { CountdownView(until: end, now: serverNow) }
                }
            case let .discussion(until):
                LabeledContent("Phase", value: "Discussion")
                LabeledContent("Time left") { CountdownView(until: until, now: serverNow) }
                LabeledContent("Skip votes", value: "\(admin.skipVotes) of \(admin.votersTotal)")
            case let .voting(until, isFinal):
                LabeledContent("Phase", value: isFinal ? "Final vote" : "Voting")
                LabeledContent("Time left") { CountdownView(until: until, now: serverNow) }
            case let .ended(outcome):
                LabeledContent("Result", value: outcome.winner == .villagers ? "Villagers win" : "Werewolves win")
                Text(outcome.reason.explanation)
            }
            if let sabotage = admin.sabotage {
                LabeledContent {
                    CountdownView(until: sabotage.endsAt, now: serverNow)
                } label: {
                    StatusLabel("Sabotage: \(sabotage.kind.title)", systemImage: "exclamationmark.triangle.fill", tint: .red)
                }
            }
        }
    }

    private var joinSection: some View {
        Section("Join") {
            if let code = admin.joinCode {
                LabeledContent("Game code") { Text(code).font(.title3.monospaced()) }
            }
            LabeledContent("Players joined", value: "\(admin.playersJoined)")
        }
    }

    private var controlsSection: some View {
        Section("Controls") {
            Button("Start Discussion", systemImage: "bell.fill") { client.send(.admin(.startMeeting)) }
                .disabled(admin.isLobby || admin.phase != .running)
            TimerAdjustMenu(
                meeting: isMeeting,
                gameClock: !admin.isLobby && !isEnded,
                sabotage: admin.sabotage != nil
            ) { target, seconds in
                client.send(.admin(.adjustTimer(target, seconds: seconds)))
            }
            Button("Approve Skip", systemImage: "forward.end.fill") { client.send(.admin(.approveSkipDiscussion)) }
                .disabled(!(isDiscussion && admin.skipRequested))
            Button("Resolve Sabotage", systemImage: "checkmark.shield") { client.send(.admin(.resolveSabotage)) }
                .disabled(admin.sabotage == nil)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var isMeeting: Bool {
        admin.phase.isMeeting
    }

    private var isEnded: Bool {
        if case .ended = admin.phase {
            true
        } else {
            false
        }
    }

    private var isDiscussion: Bool {
        if case .discussion = admin.phase {
            true
        } else {
            false
        }
    }

    private var serverNow: @Sendable (Date) -> Date {
        let clock = client.serverClock
        return { clock.now(local: $0) }
    }
}

private struct FamiliesTable: View {
    let families: [AdminFamilyRow]
    let canDelete: Bool
    let onDelete: (FamilyID) -> Void

    @State private var deleting: AdminFamilyRow?

    var body: some View {
        Table(families) {
            TableColumn("Family", value: \.name)
            TableColumn("Player") { Text($0.playerName ?? "-") }
            TableColumn("Status") { Text($0.life.title) }
            TableColumn("Stamps") { Text($0.stampsTotal == 0 ? "-" : "\($0.stampsDone) of \($0.stampsTotal)") }
            TableColumn("Delete") { family in
                Button("Delete \(family.name)", systemImage: "trash", role: .destructive) { deleting = family }
                    .labelStyle(.iconOnly)
                    .disabled(!canDelete)
            }
        }
        .confirmationDialog(
            deleting.map { "Delete \($0.name)?" } ?? "",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            if let family = deleting {
                Button("Delete \(family.name)", role: .destructive) {
                    onDelete(family.id)
                    deleting = nil
                }
            }
        } message: {
            Text("The player in this family goes back to the join screen.")
        }
    }
}
