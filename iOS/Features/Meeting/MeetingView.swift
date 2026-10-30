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
            .refreshToolbar(client)
        }
    }

    @ViewBuilder
    private var idle: some View {
        if let result = game.lastResult {
            ThemedScreen {
                ResultSection(result: result)
                DeathsSection(families: game.announcedDeaths)
            }
        } else {
            ContentUnavailableView(
                "No meeting in progress",
                systemImage: "person.3",
                description: Text("When the organiser rings the bell, you'll be called to the Town Hall.")
            )
            .foregroundStyle(Theme.text)
            .themedBackground()
        }
    }

    private func timerCard(title: String, until: Date, detail: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(title).font(.headline)
            CountdownView(until: until, now: serverNow)
                .countdownDisplay()
            Text(detail)
                .secondaryText()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .themedCard()
        .accessibilityElement(children: .combine)
    }

    private func discussion(until: Date) -> some View {
        ThemedScreen {
            timerCard(
                title: "Discussion",
                until: until,
                detail: "Heads of family gather at the Town Hall. Everyone else sits at their assigned seat. "
                    + "Voting opens automatically when the time is up."
            )
            skipSection
            ScreenSection(title: "Families at the table") {
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
            ScreenSection(
                title: "Skip the discussion",
                footer: "When more than half of the families agree, voting opens right away."
            ) {
                Button(
                    game.mySkipVote ? "Withdraw skip vote" : "Vote to skip discussion",
                    systemImage: game.mySkipVote ? "checkmark.circle.fill" : "forward.end"
                ) { client.send(.voteSkipDiscussion) }
                    .buttonStyle(.accentFill)
                ProgressView(value: Double(game.skipVotes), total: Double(max(game.votersTotal, 1)))
                    .tint(Theme.accent)
                    .accessibilityHidden(true)
                Text("\(game.skipVotes) of \(game.votersTotal) families want to skip.")
                    .secondaryText()
            }
        }
    }

    private func voting(until: Date, isFinal: Bool) -> some View {
        ThemedScreen {
            timerCard(
                title: isFinal ? "Final vote" : "Voting",
                until: until,
                detail: "\(game.votesCast) of \(game.votersTotal) families have voted"
            )
            if isFinal {
                Text("The families with the most votes are voted out. Villagers win only if every werewolf family is among them.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }

            if game.life != .alive {
                ScreenSection {
                    Label("Your family can't vote any more.", systemImage: "xmark.circle")
                }
            } else {
                ScreenSection(title: "Vote for a family", footer: "Tap a family to vote. You can change your vote until time is up.") {
                    ForEach(game.families.filter { $0.life == .alive }) { family in
                        ballot(title: family.name, choice: .family(family.id), family: family)
                        Divider().overlay(Theme.separator)
                    }
                    ballot(title: "Skip", choice: .skip)
                }
            }

            if let error = client.lastError {
                ErrorRow(message: error)
            }
        }
        .sensoryFeedback(.selection, trigger: game.myVote)
    }

    private func ballot(title: String, choice: VoteChoice, family: FamilySummary? = nil) -> some View {
        Button {
            client.send(.vote(choice))
        } label: {
            HStack(spacing: Spacing.sm) {
                if let family {
                    AvatarView(name: family.playerName ?? family.name, jpeg: family.playerID.flatMap { client.selfies[$0] })
                    VStack(alignment: .leading) {
                        Text(title)
                        if let player = family.playerName, player != family.name {
                            Text(player).font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                } else {
                    Text(title)
                }
                Spacer()
                if game.myVote == choice {
                    Label("Your vote", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .foregroundStyle(Theme.text)
        .accessibilityLabel(title)
        .accessibilityHint("Votes for \(title)")
        .accessibilityAddTraits(game.myVote == choice ? .isSelected : [])
    }

    private func ended(_ outcome: Outcome) -> some View {
        ContentUnavailableView(
            outcome.winner == .villagers ? "Villagers win" : "Werewolves win",
            systemImage: outcome.winner == .villagers ? "house.fill" : "moon.stars.fill",
            description: Text(outcome.reason.explanation)
        )
        .foregroundStyle(Theme.text)
        .themedBackground()
    }

    private var serverNow: @Sendable (Date) -> Date {
        let clock = client.serverClock
        return { clock.now(local: $0) }
    }
}

private struct DeathsSection: View {
    let families: [FamilySummary]

    var body: some View {
        ScreenSection(title: "Last found dead") {
            if families.isEmpty {
                Text("No families were eliminated.").secondaryText()
            } else {
                ForEach(families) { family in
                    StatusLabel(family.name, systemImage: "xmark.circle.fill", tint: Theme.accent)
                }
            }
        }
    }
}

private struct ResultSection: View {
    let result: VoteResultView

    var body: some View {
        ScreenSection(title: result.isFinal ? "Final vote result" : "Last vote") {
            if result.expelled.isEmpty {
                Text("Nobody was voted out.")
            }
            ForEach(result.expelled) { family in
                StatusLabel("\(family.name) was voted out", systemImage: "person.fill.xmark", tint: Theme.accent)
                    .font(.headline)
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
                .foregroundStyle(row.isSkip ? Theme.textSecondary : Theme.accent)
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
        HStack(spacing: Spacing.sm) {
            AvatarView(name: family.playerName ?? family.name, jpeg: family.playerID.flatMap { client.selfies[$0] })
            VStack(alignment: .leading) {
                Text(family.name)
                if let player = family.playerName, player != family.name {
                    Text(player).font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
