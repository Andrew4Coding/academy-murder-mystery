import SwiftUI

struct MeetingView: View {
    let game: GameView
    let client: GameClient

    var body: some View {
        NavigationStack {
            Group {
                switch game.phase {
                case .running:
                    idle
                case let .discussion(until):
                    discussion(until: until)
                case let .voting(until, isFinal):
                    voting(until: until, isFinal: isFinal)
                case let .ended(outcome):
                    ended(outcome)
                }
            }
            .navigationTitle("Meeting")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var idle: some View {
        if let result = game.lastResult {
            List {
                ResultSection(result: result)
                DeathsSection(families: game.announcedDeaths)
            }
        } else {
            ContentUnavailableView(
                "No meeting in progress",
                systemImage: "person.3",
                description: Text("When the organiser rings the bell, you'll be called to the Town Hall.")
            )
        }
    }

    private func discussion(until: Date) -> some View {
        List {
            Section {
                VStack(spacing: 4) {
                    Text("Discussion").font(.headline)
                    CountdownView(until: until, now: serverNow)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                    Text("Heads of family gather at the Town Hall. Everyone else sits at their assigned seat.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            } footer: {
                Text("Voting opens automatically when the time is up.")
            }
            DeathsSection(families: game.announcedDeaths)
        }
    }

    private func voting(until: Date, isFinal: Bool) -> some View {
        List {
            Section {
                VStack(spacing: 4) {
                    Text(isFinal ? "Final vote" : "Voting").font(.headline)
                    CountdownView(until: until, now: serverNow)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                    Text("\(game.votesCast) of \(game.votersTotal) families have voted")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            } footer: {
                if isFinal {
                    Text("The families with the most votes are voted out. Villagers win only if every werewolf family is among them.")
                }
            }

            if game.life != .alive {
                Section {
                    Label("Your family can't vote any more.", systemImage: "xmark.circle")
                }
            } else if game.isHead {
                Section("Vote for a family") {
                    ForEach(game.families.filter { $0.life == .alive }) { family in
                        ballot(title: family.name, choice: .family(family.id))
                    }
                    ballot(title: "Skip", choice: .skip)
                }
            } else {
                Section {
                    Label("Only your head of family votes. Talk to them before time runs out.", systemImage: "star.fill")
                }
            }

            if let error = client.lastError {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            }
        }
        .sensoryFeedback(.selection, trigger: game.myVote)
    }

    private func ballot(title: String, choice: VoteChoice) -> some View {
        Button {
            client.send(.vote(choice))
        } label: {
            HStack {
                Text(title)
                Spacer()
                if game.myVote == choice {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .foregroundStyle(.primary)
        .accessibilityAddTraits(game.myVote == choice ? .isSelected : [])
    }

    private func ended(_ outcome: Outcome) -> some View {
        ContentUnavailableView(
            outcome.winner == .villagers ? "Villagers win" : "Werewolves win",
            systemImage: outcome.winner == .villagers ? "house.fill" : "moon.stars.fill",
            description: Text(outcome.reason.explanation)
        )
    }

    private var serverNow: @Sendable (Date) -> Date {
        let clock = client.serverClock
        return { clock.now(local: $0) }
    }
}

private struct DeathsSection: View {
    let families: [FamilySummary]

    var body: some View {
        Section("Since the last meeting") {
            if families.isEmpty {
                Text("No families were eliminated.")
            } else {
                ForEach(families) { family in
                    Label(family.name, systemImage: "xmark.circle.fill").foregroundStyle(.red)
                }
            }
        }
    }
}

private struct ResultSection: View {
    let result: VoteResultView

    var body: some View {
        Section(result.isFinal ? "Final vote result" : "Last vote") {
            if result.expelled.isEmpty {
                Text("Nobody was voted out.")
            }
            ForEach(result.expelled) { family in
                Label("\(family.name) was a \(family.role.title.lowercased()) family", systemImage: family.role.symbol)
                    .foregroundStyle(family.role.tint)
            }
            ForEach(result.rows) { row in
                LabeledContent(row.name, value: "\(row.count)")
            }
        }
    }
}
