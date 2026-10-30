import SwiftUI

struct GameTab: View {
    let admin: AdminView
    let client: GameClient

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
        .themedBackground()
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
                Button("End Game", role: .destructive) { client.send(.admin(.endGame(side))) }
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                statusCard
                actions
                if let result = admin.lastResult {
                    resultCard(result)
                }
                if let error = client.lastError {
                    StatusLabel.error(error).themedCard()
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .themedBackground()
    }

    private func resultCard(_ result: VoteResultView) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(result.isFinal ? "Final vote result" : "Last vote").font(.headline)
            if result.expelled.isEmpty {
                Text("Nobody was voted out.").foregroundStyle(Theme.textSecondary)
            }
            ForEach(result.expelled) { Label("\($0.name) was voted out", systemImage: "person.fill.xmark") }
            ForEach(result.rows) { LabeledContent($0.name, value: "\($0.count)") }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
        .accessibilityElement(children: .contain)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title).font(.title2.bold())
            switch admin.phase {
            case .running:
                if let end = admin.gameEndsAt {
                    labeled("Game clock") { CountdownView(until: end, now: serverNow) }
                }
            case let .discussion(until):
                Text("Skip votes: \(admin.skipVotes) of \(admin.votersTotal) families").foregroundStyle(Theme.textSecondary)
                labeled("Time left") { CountdownView(until: until, now: serverNow) }
            case let .voting(until, _):
                Text("Votes: \(admin.votesCast) of \(admin.votersTotal) families").foregroundStyle(Theme.textSecondary)
                labeled("Time left") { CountdownView(until: until, now: serverNow) }
            case let .ended(outcome):
                Text(outcome.reason.explanation).foregroundStyle(Theme.textSecondary)
            }
            if let sabotage = admin.sabotage {
                Divider().overlay(Theme.separator)
                StatusLabel("Sabotage: \(sabotage.kind.title)", systemImage: "exclamationmark.triangle.fill", tint: Theme.accent)
                    .font(.headline)
                labeled("Fix time left") { CountdownView(until: sabotage.endsAt, now: serverNow) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch admin.phase {
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

    private var actions: some View {
        BentoGrid {
            BentoButton(
                title: "Ring Bell",
                subtitle: "Rings on the Mac. Doesn't start the discussion.",
                systemImage: "bell.fill",
                tint: Theme.warning
            ) {
                client.send(.admin(.ringBell))
            }
            BentoButton(
                title: "Start Discussion",
                subtitle: "Call everyone to the Town Hall",
                systemImage: "person.3.fill",
                isProminent: admin.phase == .running
            ) {
                client.send(.admin(.startMeeting))
            }
            .disabled(admin.phase != .running)
            Menu {
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
            } label: {
                BentoTile(
                    title: "Vote for a Family",
                    subtitle: "Cast a vote for a family that can't",
                    systemImage: "hand.raised.fill",
                    tint: Theme.accent,
                    isProminent: isVoting
                )
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .disabled(!isVoting)
            TimerAdjustMenu(
                meeting: admin.phase.isMeeting,
                gameClock: !isEnded,
                sabotage: admin.sabotage != nil
            ) { target, seconds in
                client.send(.admin(.adjustTimer(target, seconds: seconds)))
            }
            BentoButton(
                title: "Resolve Sabotage",
                subtitle: "Mark the active sabotage as fixed",
                systemImage: "checkmark.shield.fill",
                tint: Theme.success,
                isProminent: admin.sabotage != nil
            ) {
                client.send(.admin(.resolveSabotage))
            }
            .disabled(admin.sabotage == nil)
            Menu {
                Button("Villagers Win") { confirmingEnd = .villagers }
                Button("Werewolves Win") { confirmingEnd = .werewolves }
            } label: {
                BentoTile(title: "End Game", subtitle: "Declare a winner", systemImage: "flag.checkered", tint: Theme.accent)
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .disabled(isEnded)
        }
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
