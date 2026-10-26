import SwiftUI

struct GameControlView: View {
    let controller: HostController

    @State private var showRoles = false
    @State private var selection: Set<FamilyID> = []
    @State private var confirmingEnd: Side?
    @State private var offListStamp: OffListStamp?
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
        .confirmationDialog(
            confirmingEnd == .villagers ? "End the game with a villager win?" : "End the game with a werewolf win?",
            isPresented: Binding(get: { confirmingEnd != nil }, set: {
                if !$0 {
                    confirmingEnd = nil
                }
            }),
            titleVisibility: .visible
        ) {
            if let side = confirmingEnd {
                Button("End Game", role: .destructive) { attempt { try host.applyAsOC(.override(.endGame(side))) } }
            }
        }
        .confirmationDialog(
            "Not on this family's list",
            isPresented: Binding(get: { offListStamp != nil }, set: {
                if !$0 {
                    offListStamp = nil
                }
            }),
            titleVisibility: .visible,
            presenting: offListStamp
        ) { item in
            Button("Stamp Anyway", role: .destructive) {
                for id in item.ids {
                    attempt { try host.recordStamp(family: id, booth: item.booth, confirmOffList: true) }
                }
            }
        } message: { item in
            Text("\(item.booth.title) isn't on every selected family's list. The stamp won't count toward their tasks.")
        }
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
                if let sabotage = game.sabotage {
                    LabeledContent("Sabotage") {
                        HStack {
                            Text(sabotage.kind.title)
                            CountdownView(until: sabotage.endsAt, now: hostNow)
                        }
                    }
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
                FamilyStatusTable(
                    host: host,
                    game: game,
                    showRoles: showRoles,
                    selection: $selection,
                    onEliminate: eliminate,
                    onRevive: revive,
                    onStamp: stamp,
                    onUnstamp: unstamp
                )
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
            ToolbarItem {
                if host.testingToolsEnabled {
                    Menu("Trigger Sabotage", systemImage: "exclamationmark.triangle") {
                        ForEach(game.families.values.filter { $0.role == .werewolf }.sorted { $0.id < $1.id }, id: \.id) { family in
                            Menu(name(family.id)) {
                                ForEach(SabotageKind.allCases, id: \.self) { kind in
                                    Button(kind.title) {
                                        attempt { try host.applyAsOC(.requestSabotage(by: family.id, kind: kind)) }
                                    }
                                }
                            }
                        }
                    }
                    .disabled(game.sabotage != nil || game.phase != .running)
                    .help("Testing: start a sabotage as a werewolf family, to see what villager phones show")
                }
            }
            ToolbarItem {
                Button("Resolve Sabotage", systemImage: "checkmark.shield") {
                    attempt { try host.applyAsOC(.resolveSabotage) }
                }
                .disabled(game.sabotage == nil)
                .help("The villagers fixed the sabotage")
            }
            ToolbarItem {
                Menu("End Game", systemImage: "flag.checkered") {
                    Button("Villagers Win") { confirmingEnd = .villagers }
                    Button("Werewolves Win") { confirmingEnd = .werewolves }
                }
                .disabled(game.outcome != nil)
                .help("End the game now and declare a winner")
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

    private func stamp(_ ids: Set<FamilyID>, _ booth: Booth) {
        let tasks = host.state.engine?.state.families
        if ids.contains(where: { tasks?[$0]?.tasks.contains(booth) == false }) {
            offListStamp = OffListStamp(ids: ids, booth: booth)
        } else {
            for id in ids {
                attempt { try host.recordStamp(family: id, booth: booth, confirmOffList: false) }
            }
        }
    }

    private func unstamp(_ ids: Set<FamilyID>, _ booth: Booth) {
        for id in ids {
            attempt { try host.removeStamp(family: id, booth: booth) }
        }
    }

    private func eliminate(_ ids: Set<FamilyID>) {
        for id in ids {
            attempt { try host.applyAsOC(.override(.forceKill(id))) }
        }
    }

    private func revive(_ ids: Set<FamilyID>) {
        for id in ids {
            attempt { try host.applyAsOC(.override(.revive(id))) }
        }
    }

    private var hostNow: @Sendable (Date) -> Date {
        let clock = host.clock
        return { _ in clock.now }
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
    @Binding var selection: Set<FamilyID>
    let onEliminate: (Set<FamilyID>) -> Void
    let onRevive: (Set<FamilyID>) -> Void
    let onStamp: (Set<FamilyID>, Booth) -> Void
    let onUnstamp: (Set<FamilyID>, Booth) -> Void

    private var rows: [Family] {
        game.families.values.sorted { $0.id < $1.id }
    }

    var body: some View {
        Table(rows, selection: $selection) {
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
        .contextMenu(forSelectionType: FamilyID.self) { ids in
            Menu("Record Stamp", systemImage: "checkmark.seal") {
                ForEach(Booth.allCases, id: \.self) { booth in
                    Button(booth.title) { onStamp(ids, booth) }
                }
            }
            .disabled(ids.isEmpty)
            Menu("Undo Stamp", systemImage: "arrow.uturn.backward") {
                ForEach(Booth.allCases, id: \.self) { booth in
                    Button(booth.title) { onUnstamp(ids, booth) }
                }
            }
            .disabled(ids.isEmpty)
            Divider()
            Button("Eliminate Family", systemImage: "xmark.circle") { onEliminate(ids) }
                .disabled(ids.isEmpty)
            Button("Revive Family", systemImage: "arrow.uturn.backward.circle") { onRevive(ids) }
                .disabled(ids.isEmpty)
        }
    }

    private func voteStatus(_ family: Family) -> String {
        guard case .voting = game.phase, family.isAlive else { return "" }
        return game.votes[family.id] == nil ? "Waiting" : "Voted"
    }
}

private struct OffListStamp: Identifiable {
    let ids: Set<FamilyID>
    let booth: Booth

    var id: String {
        "\(booth.rawValue)-\(ids.map(\.rawValue).sorted())"
    }
}
