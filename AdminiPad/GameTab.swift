import SwiftUI

struct GameTab: View {
    let admin: AdminView
    let client: GameClient

    @State private var showRoles = false
    @State private var selection: Set<FamilyID> = []
    @State private var confirmingEnd: Side?

    var body: some View {
        Group {
            if admin.isLobby {
                ContentUnavailableView(
                    "No game running",
                    systemImage: "play.slash",
                    description: Text("Set up the families and start the game from Setup.")
                )
            } else {
                content
            }
        }
        .navigationTitle("Game")
        .confirmationDialog(
            confirmingEnd == .villagers ? "End the game with a villager win?" : "End the game with a werewolf win?",
            isPresented: Binding(get: { confirmingEnd != nil }, set: { if !$0 { confirmingEnd = nil } }),
            titleVisibility: .visible
        ) {
            if let side = confirmingEnd {
                Button("End Game", role: .destructive) { client.send(.admin(.endGame(side))) }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Form {
                statusSection
                if let result = admin.lastResult {
                    Section(result.isFinal ? "Final vote result" : "Last vote") {
                        if result.expelled.isEmpty {
                            Text("Nobody was voted out.")
                        }
                        ForEach(result.expelled) { Label("\($0.name) was voted out", systemImage: "person.fill.xmark") }
                        ForEach(result.rows) { LabeledContent($0.name, value: "\($0.count)") }
                    }
                }
                if let error = client.lastError {
                    Section { StatusLabel.error(error) }
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: 300)
            familiesTable
        }
        .toolbar { toolbar }
    }

    private var statusSection: some View {
        Section("Status") {
            switch admin.phase {
            case .running:
                LabeledContent("Phase", value: "Playing")
                if let end = admin.gameEndsAt {
                    LabeledContent("Game clock") { CountdownView(until: end, now: serverNow) }
                }
            case let .discussion(until):
                LabeledContent("Phase", value: "Discussion")
                LabeledContent("Skip votes", value: "\(admin.skipVotes) of \(admin.votersTotal)")
                LabeledContent("Time left") { CountdownView(until: until, now: serverNow) }
            case let .voting(until, isFinal):
                LabeledContent("Phase", value: isFinal ? "Final vote" : "Voting")
                LabeledContent("Votes", value: "\(admin.votesCast) of \(admin.votersTotal) families")
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

    private var familiesTable: some View {
        Table(admin.families, selection: $selection) {
            TableColumn("Family", value: \.name)
            TableColumn("Status") { (family: AdminFamilyRow) in
                Label(family.life.title, systemImage: family.life == .alive ? "checkmark.circle" : "xmark.circle")
            }
            TableColumn("Role") { (family: AdminFamilyRow) in
                if showRoles, let role = family.role {
                    Label(role.title, systemImage: role.symbol)
                } else {
                    Text("Hidden").foregroundStyle(.secondary)
                }
            }
            TableColumn("Tasks") { (family: AdminFamilyRow) in
                Text(family.tasks.isEmpty ? "-" : family.tasks.map(\.rawValue).sorted().map(String.init).joined(separator: ", "))
            }
            TableColumn("Vote") { (family: AdminFamilyRow) in
                Text(voteStatus(family))
            }
        }
        .contextMenu(forSelectionType: FamilyID.self) { ids in
            familyActions(ids)
        }
    }

    @ViewBuilder
    private func familyActions(_ ids: Set<FamilyID>) -> some View {
        Divider()
        Button("Eliminate Family", systemImage: "xmark.circle") { client.send(.admin(.eliminate(Array(ids)))) }
            .disabled(ids.isEmpty)
        Button("Revive Family", systemImage: "arrow.uturn.backward.circle") { client.send(.admin(.revive(Array(ids)))) }
            .disabled(ids.isEmpty)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Toggle("Show Roles", systemImage: showRoles ? "eye" : "eye.slash", isOn: $showRoles)
        }
        ToolbarItem {
            Menu("Selected", systemImage: "checklist") {
                familyActions(selection)
            }
        }
        ToolbarItem {
            Menu("Meeting", systemImage: "person.3") {
                Menu("Vote for a Family", systemImage: "hand.raised") {
                    ForEach(admin.families.filter { $0.life == .alive && !$0.voted }) { voter in
                        Menu(voter.name) {
                            ForEach(admin.families.filter { $0.life == .alive }) { target in
                                Button(target.name) {
                                    client.send(.admin(.proxyVote(family: voter.id, choice: .family(target.id))))
                                }
                            }
                            Button("Skip") { client.send(.admin(.proxyVote(family: voter.id, choice: .skip))) }
                        }
                    }
                }
                .disabled(!isVoting)
            }
        }
        ToolbarItem {
            TimerAdjustMenu(
                meeting: admin.phase.isMeeting,
                gameClock: !isEnded,
                sabotage: admin.sabotage != nil
            ) { target, seconds in
                client.send(.admin(.adjustTimer(target, seconds: seconds)))
            }
        }
        ToolbarItem {
            Menu("Game", systemImage: "flag.checkered") {
                Button("Resolve Sabotage", systemImage: "checkmark.shield") { client.send(.admin(.resolveSabotage)) }
                    .disabled(admin.sabotage == nil)
                Divider()
                Menu("End Game", systemImage: "flag.checkered") {
                    Button("Villagers Win") { confirmingEnd = .villagers }
                    Button("Werewolves Win") { confirmingEnd = .werewolves }
                }
                .disabled(isEnded)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Button("Ring Bell", systemImage: "bell.fill") { client.send(.admin(.ringBell)) }
                Button("Start Discussion", systemImage: "person.3.fill") { client.send(.admin(.startMeeting)) }
                    .disabled(admin.phase != .running)
            }
        }
    }

    private func voteStatus(_ family: AdminFamilyRow) -> String {
        guard isVoting, family.life == .alive else { return "" }
        return family.voted ? "Voted" : "Waiting"
    }

    private var isVoting: Bool {
        if case .voting = admin.phase {
            true
        } else {
            false
        }
    }

    private var isEnded: Bool {
        if case .ended = admin.phase {
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
