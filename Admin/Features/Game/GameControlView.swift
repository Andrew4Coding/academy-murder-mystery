import SwiftUI

struct GameControlView: View {
    let controller: HostController

    @State private var showRoles = false
    @State private var errorMessage: String?

    private var host: GameHost {
        controller.host
    }

    var body: some View {
        Group {
            if let engine = host.state.engine {
                content(engine.state)
            } else {
                ContentUnavailableView(
                    "No game running",
                    systemImage: "play.slash",
                    description: Text("Set up the families and start the game from Setup.")
                )
            }
        }
        .navigationTitle("Game")
        .alert("Can't do that", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func content(_ game: GameState) -> some View {
        Form {
            Section("Status") {
                PhaseRow(game: game, clock: host.clock)
                if case .voting = game.phase {
                    LabeledContent("Votes", value: "\(game.votes.count) of \(game.aliveFamilies().count) families")
                }
            }

            if let result = game.lastResult {
                Section(result.isFinal ? "Final vote result" : "Last vote") {
                    if result.expelled.isEmpty {
                        Text("Nobody was voted out.")
                    }
                    ForEach(result.expelled, id: \.family) { reveal in
                        Label("\(name(reveal.family)) was a \(reveal.role.title.lowercased()) family", systemImage: reveal.role.symbol)
                    }
                    ForEach(result.tally, id: \.choice) { count in
                        LabeledContent(label(for: count.choice), value: "\(count.count)")
                    }
                }
            }

            Section("Families") {
                FamilyStatusTable(host: host, game: game, showRoles: showRoles)
                    .frame(minHeight: 260)
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem {
                Toggle("Show Roles", systemImage: showRoles ? "eye" : "eye.slash", isOn: $showRoles)
                    .help("Anyone who can see this screen will see every family's role")
            }
            ToolbarItem {
                Menu("Vote for a Family", systemImage: "hand.raised") {
                    ForEach(game.aliveFamilies().filter { game.votes[$0.id] == nil }, id: \.id) { voter in
                        Menu(name(voter.id)) {
                            ForEach(game.aliveFamilies(), id: \.id) { target in
                                Button(name(target.id)) { proxyVote(voter.id, .family(target.id)) }
                            }
                            Button("Skip") { proxyVote(voter.id, .skip) }
                        }
                    }
                }
                .disabled(!isVoting(game))
                .help("Cast a vote for a family whose head can't, for example because their phone is offline")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Start Discussion", systemImage: "bell.fill") {
                    attempt { try host.applyAsOC(.startMeeting) }
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(game.phase != .running)
                .help("Call everyone to the Town Hall. Ring the bell first.")
            }
        }
    }

    private func isVoting(_ game: GameState) -> Bool {
        if case .voting = game.phase {
            true
        } else {
            false
        }
    }

    private func proxyVote(_ family: FamilyID, _ choice: VoteChoice) {
        attempt { try host.applyAsOC(.proxyVote(for: family, choice: choice)) }
    }

    private func attempt(_ action: () throws -> Void) {
        do { try action() } catch let error as RuleError { errorMessage = error.message } catch let error as HostError {
            errorMessage = error.message
        } catch { errorMessage = "\(error)" }
    }

    private func name(_ id: FamilyID) -> String {
        host.state.families[id]?.name ?? "Unknown"
    }

    private func label(for choice: VoteChoice) -> String {
        switch choice {
        case let .family(id): name(id)
        case .skip: "Skip"
        }
    }
}

private struct PhaseRow: View {
    let game: GameState
    let clock: any HostClock

    var body: some View {
        switch game.phase {
        case .running:
            LabeledContent("Phase", value: "Playing")
            LabeledContent("Game clock") {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(Duration.seconds(max(0, game.finalVoteAt.timeIntervalSince(clock.now))), format: .time(pattern: .minuteSecond))
                        .monospacedDigit()
                }
            }
        case let .discussion(until):
            LabeledContent("Phase", value: "Discussion")
            LabeledContent("Time left") { CountdownView(until: until, now: { _ in clock.now }) }
        case let .voting(until, isFinal):
            LabeledContent("Phase", value: isFinal ? "Final vote" : "Voting")
            LabeledContent("Time left") { CountdownView(until: until, now: { _ in clock.now }) }
        case let .ended(outcome):
            LabeledContent("Result", value: outcome.winner == .villagers ? "Villagers win" : "Werewolves win")
            Text(outcome.reason.explanation)
        }
    }
}

private struct FamilyStatusTable: View {
    let host: GameHost
    let game: GameState
    let showRoles: Bool

    private var rows: [Family] {
        game.families.values.sorted { $0.id < $1.id }
    }

    var body: some View {
        Table(rows) {
            TableColumn("Family") { (family: Family) in
                Text(host.state.families[family.id]?.name ?? "Unknown")
            }
            TableColumn("Status") { (family: Family) in
                Label(family.life.title, systemImage: family.isAlive ? "checkmark.circle" : "xmark.circle")
            }
            TableColumn("Role") { (family: Family) in
                if showRoles {
                    Label(family.role.title, systemImage: family.role.symbol)
                } else {
                    Text("Hidden").foregroundStyle(.secondary)
                }
            }
            TableColumn("Tasks") { (family: Family) in
                Text("\(family.stamps.intersection(family.tasks).count) of \(family.tasks.count)")
            }
            TableColumn("Vote") { (family: Family) in
                Text(voteStatus(family))
            }
        }
    }

    private func voteStatus(_ family: Family) -> String {
        guard case .voting = game.phase, family.isAlive else { return "" }
        return game.votes[family.id] == nil ? "Waiting" : "Voted"
    }
}
