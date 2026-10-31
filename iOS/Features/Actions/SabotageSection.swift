import SwiftUI

struct SabotageSection: View {
    let game: GameView
    let client: GameClient

    @State private var pending: SabotageKind?
    @State private var requestCount = 0

    var body: some View {
        BentoSection(title: "Sabotage", footer: footer) {
            if let sabotage = game.sabotage {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = sabotage.endsAt.timeIntervalSince(client.serverClock.now(local: context.date))
                    BentoTile(
                        title: sabotage.kind.title,
                        subtitle: "Fix time left \(Duration.clock(remaining))",
                        systemImage: sabotage.kind.symbol,
                        isProminent: true
                    )
                    .accessibilityElement(children: .combine)
                }
            } else if game.phase.isMeeting {
                BentoTile(
                    title: "Unavailable",
                    subtitle: "Not available during meetings",
                    systemImage: "person.3",
                    tint: Theme.textSecondary
                )
                .opacity(0.7)
            } else {
                ForEach(SabotageKind.allCases, id: \.self) { kind in
                    tile(for: kind)
                }
            }
        }
        .confirmationDialog(
            pending.map { "Sabotage \($0.title)?" } ?? "",
            isPresented: Binding(get: { pending != nil }, set: {
                if !$0 {
                    pending = nil
                }
            }),
            titleVisibility: .visible
        ) {
            if let pending {
                Button("Start Sabotage", role: .destructive) {
                    client.send(.requestSabotage(pending))
                    requestCount += 1
                }
            }
        } message: {
            Text("Everyone is alerted at once.")
        }
        .sensoryFeedback(.impact, trigger: requestCount)
    }

    private var footer: LocalizedStringKey? {
        game.sabotage == nil && !game.phase.isMeeting
            ? "Villagers must fix it at the booth in time, or the werewolves win. Werewolves share one cooldown."
            : nil
    }

    private func tile(for kind: SabotageKind) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = client.serverClock.now(local: context.date)
            if let readyAt = game.sabotageReadyAt, now < readyAt {
                BentoTile(
                    title: kind.title,
                    subtitle: "Cooling down \(Duration.clock(readyAt.timeIntervalSince(now)))",
                    systemImage: kind.symbol,
                    tint: Theme.warning
                )
                .opacity(0.7)
                .accessibilityElement(children: .combine)
            } else {
                Button { pending = kind } label: {
                    BentoTile(
                        title: kind.title,
                        subtitle: "Villagers get \(duration(of: kind)) to fix it",
                        systemImage: kind.symbol,
                        isProminent: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func duration(of kind: SabotageKind) -> String {
        let seconds = Int(game.sabotageTimings.first { $0.kind == kind }?.duration ?? 90)
        return seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds / 60) min \(seconds % 60) s"
    }

    private var serverNow: @Sendable (Date) -> Date {
        let clock = client.serverClock
        return { clock.now(local: $0) }
    }
}

extension SabotageKind {
    var symbol: String {
        switch self {
        case .reactor: "atom"
        case .oxygen: "wind"
        }
    }
}
