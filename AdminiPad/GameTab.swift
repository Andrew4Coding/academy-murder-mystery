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
        Form {
            Section { actions }
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

    private var actions: some View {
        BentoGrid {
            BentoButton(title: "Ring Bell", subtitle: "Rings on the Mac. Doesn't start the discussion.", systemImage: "bell.fill", tint: .orange) {
                client.send(.admin(.ringBell))
            }
            BentoButton(title: "Start Discussion", subtitle: "Call everyone to the Town Hall", systemImage: "person.3.fill", tint: .blue) {
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
                BentoTile(title: "Vote for a Family", subtitle: "Cast a vote for a family that can't", systemImage: "hand.raised.fill", tint: .teal)
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
            BentoButton(title: "Resolve Sabotage", subtitle: "Mark the active sabotage as fixed", systemImage: "checkmark.shield.fill", tint: .green) {
                client.send(.admin(.resolveSabotage))
            }
            .disabled(admin.sabotage == nil)
            Menu {
                Button("Villagers Win") { confirmingEnd = .villagers }
                Button("Werewolves Win") { confirmingEnd = .werewolves }
            } label: {
                BentoTile(title: "End Game", subtitle: "Declare a winner", systemImage: "flag.checkered", tint: .red)
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .disabled(isEnded)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
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
