import SwiftUI

struct SabotageSection: View {
    let game: GameView
    let client: GameClient

    @State private var pending: SabotageKind?
    @State private var requestCount = 0

    var body: some View {
        Section {
            if let sabotage = game.sabotage {
                LabeledContent(sabotage.kind.title) {
                    CountdownView(until: sabotage.endsAt, now: serverNow)
                }
                Text("A sabotage is already running.").foregroundStyle(.secondary)
            } else if game.phase.isMeeting {
                Label("Not during meetings", systemImage: "person.3").foregroundStyle(.secondary)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let now = client.serverClock.now(local: context.date)
                    if let readyAt = game.sabotageReadyAt, now < readyAt {
                        LabeledContent("Sabotage ready in") { CountdownView(until: readyAt, now: serverNow) }
                    } else {
                        ForEach(SabotageKind.allCases, id: \.self) { kind in
                            Button(kind.title, systemImage: kind.symbol) { pending = kind }
                        }
                    }
                }
            }
        } header: {
            Text("Sabotage")
        } footer: {
            Text(
                "Villagers get 1 minute 30 seconds to fix it at the matching booth. If they can't, the werewolves win. Every werewolf family shares one cooldown."
            )
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
