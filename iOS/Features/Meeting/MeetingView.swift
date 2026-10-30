import Charts
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
                        .countdownDisplay()
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
            skipSection
            Section("Families at the table") {
                ForEach(game.families.filter { $0.life == .alive }) { family in
                    FamilyRow(family: family, client: client)
                }
            }
            DeathsSection(families: game.announcedDeaths)
        }
    }

    @ViewBuilder
    private var skipSection: some View {
        if game.life == .alive {
            Section {
                Button(
                    game.mySkipVote ? "Withdraw skip vote" : "Vote to skip discussion",
                    systemImage: game.mySkipVote ? "checkmark.circle.fill" : "forward.end"
                ) { client.send(.voteSkipDiscussion) }
                    .buttonStyle(.borderedProminent)
                    .tint(game.mySkipVote ? .green : .accentColor)
                ProgressView(value: Double(game.skipVotes), total: Double(max(game.votersTotal, 1)))
                Text("\(game.skipVotes) of \(game.votersTotal) families want to skip.")
                    .foregroundStyle(.secondary)
            } footer: {
                Text("When more than half of the families agree, voting opens right away.")
            }
        }
    }

    private func voting(until: Date, isFinal: Bool) -> some View {
        List {
            Section {
                VStack(spacing: 4) {
                    Text(isFinal ? "Final vote" : "Voting").font(.headline)
                    CountdownView(until: until, now: serverNow)
                        .countdownDisplay()
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
            } else {
                Section("Vote for a family") {
                    ForEach(game.families.filter { $0.life == .alive }) { family in
                        ballot(title: family.name, choice: .family(family.id), family: family)
                    }
                    ballot(title: "Skip", choice: .skip)
                }
            }

            if let error = client.lastError {
                Section { StatusLabel.error(error) }
            }
        }
        .sensoryFeedback(.selection, trigger: game.myVote)
    }

    private func ballot(title: String, choice: VoteChoice, family: FamilySummary? = nil) -> some View {
        Button {
            client.send(.vote(choice))
        } label: {
            HStack {
                if let family {
                    AvatarView(name: family.playerName ?? family.name, jpeg: family.playerID.flatMap { client.selfies[$0] })
                    VStack(alignment: .leading) {
                        Text(title)
                        if let player = family.playerName {
                            Text(player).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text(title)
                }
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
                    StatusLabel(family.name, systemImage: "xmark.circle.fill", tint: .red)
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
                Label("\(family.name) was voted out", systemImage: "person.fill.xmark")
                    .foregroundStyle(.red)
            }
            if !result.rows.isEmpty {
                VoteChart(rows: result.rows)
                    .frame(height: CGFloat(max(result.rows.count, 2)) * 44)
            }
        }
    }
}

struct VoteChart: View {
    let rows: [ResultRow]

    var body: some View {
        Chart(rows) { row in
            BarMark(x: .value("Votes", row.count), y: .value("Candidate", row.name))
                .foregroundStyle(row.isSkip ? Color.gray : Color.accentColor)
                .annotation(position: .trailing) { Text("\(row.count)").font(.caption.monospacedDigit()) }
        }
        .chartXAxis(.hidden)
        .accessibilityElement()
        .accessibilityLabel("Vote results")
        .accessibilityValue(rows.map { "\($0.name): \($0.count)" }.joined(separator: ", "))
    }
}

private struct FamilyRow: View {
    let family: FamilySummary
    let client: GameClient

    var body: some View {
        HStack {
            AvatarView(name: family.playerName ?? family.name, jpeg: family.playerID.flatMap { client.selfies[$0] })
            VStack(alignment: .leading) {
                Text(family.name)
                if let player = family.playerName {
                    Text(player).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
