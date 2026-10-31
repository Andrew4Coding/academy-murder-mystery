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
            BentoSection(title: "Families at the table") {
                ForEach(game.families.filter { $0.life == .alive }) { family in
                    FamilyTile(family: family, subtitle: nil, isSelected: false, client: client)
                }
            }
            DeathsSection(families: game.announcedDeaths)
        }
    }

    @ViewBuilder
    private var skipSection: some View {
        if game.life == .alive {
            BentoSection(
                title: "Skip the discussion",
                footer: "When more than half of the families agree, voting opens right away."
            ) {
                BentoButton(
                    title: game.mySkipVote ? "Withdraw skip vote" : "Vote to skip",
                    subtitle: "\(game.skipVotes) of \(game.votersTotal) families want to skip",
                    systemImage: game.mySkipVote ? "checkmark.circle.fill" : "forward.end",
                    isProminent: game.mySkipVote
                ) { client.send(.voteSkipDiscussion) }
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
                BentoSection(title: "Vote for a family", footer: "Tap a family to vote. You can change your vote until time is up.") {
                    ForEach(game.families.filter { $0.life == .alive }) { family in
                        Button { client.send(.vote(.family(family.id))) } label: {
                            FamilyTile(
                                family: family,
                                subtitle: game.myVote == .family(family.id) ? "Your vote" : "Tap to vote",
                                isSelected: game.myVote == .family(family.id),
                                client: client
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(family.name)
                        .accessibilityHint("Votes for \(family.name)")
                        .accessibilityAddTraits(game.myVote == .family(family.id) ? .isSelected : [])
                    }
                    BentoButton(
                        title: "Skip",
                        subtitle: game.myVote == .skip ? "Your vote" : "Vote for nobody",
                        systemImage: "forward.end.fill",
                        isProminent: game.myVote == .skip
                    ) { client.send(.vote(.skip)) }
                }
            }

            if let error = client.lastError {
                ErrorRow(message: error)
            }
        }
        .sensoryFeedback(.selection, trigger: game.myVote)
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

private struct FamilyTile: View {
    let family: FamilySummary
    let subtitle: String?
    let isSelected: Bool
    let client: GameClient

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            AvatarView(name: family.playerName ?? family.name, jpeg: family.playerID.flatMap { client.selfies[$0] }, size: 44)
                .accessibilityHidden(true)
            Spacer(minLength: Spacing.sm)
            Text(family.name)
                .font(.title3.bold())
                .foregroundStyle(isSelected ? Theme.onAccentFill : Theme.text)
            if let player = family.playerName, player != family.name {
                Text(player).font(.footnote).foregroundStyle(isSelected ? Theme.onAccentFill : Theme.textSecondary)
            }
            if let subtitle {
                Text(subtitle).font(.footnote.weight(.semibold)).foregroundStyle(isSelected ? Theme.onAccentFill : Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(Spacing.md)
        .background(isSelected ? Theme.accentFill : Theme.surface, in: .rect(cornerRadius: Radius.lg))
        .contentShape(.rect(cornerRadius: Radius.lg))
    }
}
