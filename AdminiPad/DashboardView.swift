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
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                }
            }
            .navigationTitle("Dashboard")
            .navigationSplitViewColumnWidth(min: 320, ideal: 380)
            .toolbar { ToolbarItem { Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") { client.signOut() } } }
        } detail: {
            FamiliesTable(families: admin.families)
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
                LabeledContent("Sabotage: \(sabotage.kind.title)") { CountdownView(until: sabotage.endsAt, now: serverNow) }
                    .foregroundStyle(.red)
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
            Menu("Add Time", systemImage: "clock.badge.plus") {
                ForEach([1, 2, 5], id: \.self) { minutes in
                    Button("+\(minutes) min") { client.send(.admin(.extendMeeting(seconds: TimeInterval(minutes * 60)))) }
                }
            }
            .disabled(!isMeeting)
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

    var body: some View {
        Table(families) {
            TableColumn("Family", value: \.name)
            TableColumn("Head") { Text($0.headName ?? "-") }
            TableColumn("Members") { Text("\($0.members)") }
            TableColumn("Status") { Text($0.life.title) }
            TableColumn("Stamps") { Text($0.stampsTotal == 0 ? "-" : "\($0.stampsDone) of \($0.stampsTotal)") }
        }
    }
}
