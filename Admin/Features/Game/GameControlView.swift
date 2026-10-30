import SwiftUI

struct GameControlView: View {
    let controller: HostController

    @State private var confirmingEnd: Side?
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
        .themedBackground()
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
        .alert("Can't do that", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func content(_ game: GameState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                PhaseCard(game: game, clock: host.clock)
                actions(game)
                if let result = game.lastResult {
                    resultCard(result)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .themedBackground()
    }

    private func resultCard(_ result: VoteResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(result.isFinal ? "Final vote result" : "Last vote").font(.headline)
            if result.expelled.isEmpty {
                Text("Nobody was voted out.").foregroundStyle(Theme.textSecondary)
            }
            ForEach(result.expelled, id: \.family) { reveal in
                Label("\(name(reveal.family)) was a \(reveal.role.title.lowercased()) family", systemImage: reveal.role.symbol)
            }
            ForEach(result.tally, id: \.choice) { count in
                LabeledContent(label(for: count.choice), value: "\(count.count)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
        .accessibilityElement(children: .contain)
    }

    private func actions(_ game: GameState) -> some View {
        BentoGrid {
            BentoButton(title: "Ring Bell", subtitle: "Plays on this Mac. Doesn't start the discussion.", systemImage: "bell.fill", tint: Theme.warning) {
                host.ringBell()
            }
            .keyboardShortcut("b", modifiers: .command)
            BentoButton(title: "Start Discussion", subtitle: "Call everyone to the Town Hall", systemImage: "person.3.fill", isProminent: game.phase == .running) {
                attempt { try host.applyAsOC(.startMeeting) }
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(game.phase != .running)
            Menu {
                ForEach(game.aliveFamilies().filter { game.votes[$0.id] == nil }, id: \.id) { voter in
                    Menu(name(voter.id)) {
                        ForEach(game.aliveFamilies(), id: \.id) { target in
                            Button(name(target.id)) { proxyVote(voter.id, .family(target.id)) }
                        }
                        Button("Skip") { proxyVote(voter.id, .skip) }
                    }
                }
            } label: {
                BentoTile(title: "Vote for a Family", subtitle: "Cast a vote for a family that can't", systemImage: "hand.raised.fill", tint: Theme.accent, isProminent: isVoting(game))
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .disabled(!isVoting(game))
            TimerAdjustMenu(
                meeting: game.phase.isMeetingPhase,
                gameClock: game.outcome == nil && !game.finalVoteStarted,
                sabotage: game.sabotage != nil
            ) { target, seconds in
                attempt { try host.applyAsOC(.adjustTimer(target, seconds: seconds)) }
            }
            BentoButton(title: "Resolve Sabotage", subtitle: "Mark the active sabotage as fixed", systemImage: "checkmark.shield.fill", tint: Theme.success, isProminent: game.sabotage != nil) {
                attempt { try host.applyAsOC(.resolveSabotage) }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(game.sabotage == nil)
            if host.testingToolsEnabled {
                Menu {
                    ForEach(game.families.values.filter { $0.role == .werewolf }.sorted { $0.id < $1.id }, id: \.id) { family in
                        Menu(name(family.id)) {
                            ForEach(SabotageKind.allCases, id: \.self) { kind in
                                Button(kind.title) {
                                    attempt { try host.applyAsOC(.requestSabotage(by: family.id, kind: kind)) }
                                }
                            }
                        }
                    }
                } label: {
                    BentoTile(title: "Trigger Sabotage", subtitle: "Testing only", systemImage: "exclamationmark.triangle.fill", tint: Theme.warning)
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .disabled(game.sabotage != nil || game.phase != .running)
            }
            Menu {
                Button("Villagers Win") { confirmingEnd = .villagers }
                Button("Werewolves Win") { confirmingEnd = .werewolves }
            } label: {
                BentoTile(title: "End Game", subtitle: "Declare a winner", systemImage: "flag.checkered", tint: Theme.accent)
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .disabled(game.outcome != nil)
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

private struct PhaseCard: View {
    let game: GameState
    let clock: any HostClock

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title).font(.title2.bold())
            switch game.phase {
            case .running:
                labeled("Game clock") {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(Duration.seconds(max(0, game.finalVoteAt.timeIntervalSince(clock.now))), format: .time(pattern: .minuteSecond))
                            .monospacedDigit()
                    }
                }
            case let .discussion(until):
                Text("Skip votes: \(game.skipVotes.count) of \(game.aliveFamilies().count) families")
                    .foregroundStyle(Theme.textSecondary)
                labeled("Time left") { CountdownView(until: until, now: { _ in clock.now }) }
            case let .voting(until, _):
                Text("Votes: \(game.votes.count) of \(game.aliveFamilies().count) families")
                    .foregroundStyle(Theme.textSecondary)
                labeled("Time left") { CountdownView(until: until, now: { _ in clock.now }) }
            case let .ended(outcome):
                Text(outcome.reason.explanation).foregroundStyle(Theme.textSecondary)
            }
            if let sabotage = game.sabotage {
                Divider().overlay(Theme.separator)
                StatusLabel("Sabotage: \(sabotage.kind.title)", systemImage: "exclamationmark.triangle.fill", tint: Theme.accent)
                    .font(.headline)
                labeled("Fix time left") { CountdownView(until: sabotage.endsAt, now: { _ in clock.now }) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch game.phase {
        case .running: "Game in progress"
        case .discussion: "Discussion"
        case let .voting(_, isFinal): isFinal ? "Final vote" : "Voting"
        case let .ended(outcome): outcome.winner == .villagers ? "Villagers win" : "Werewolves win"
        }
    }

    private func labeled(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Theme.textSecondary)
            value().countdownDisplay()
        }
    }
}

private extension Phase {
    var isMeetingPhase: Bool {
        switch self {
        case .discussion, .voting: true
        case .running, .ended: false
        }
    }

    var isDiscussionPhase: Bool {
        if case .discussion = self {
            true
        } else {
            false
        }
    }
}
