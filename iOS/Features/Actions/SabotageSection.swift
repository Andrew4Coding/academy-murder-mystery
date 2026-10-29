import SwiftUI

struct SabotageSection: View {
    let game: GameView
    let client: GameClient

    @State private var pending: SabotageKind?
    @State private var requestCount = 0

    var body: some View {
        Group {
            if let sabotage = game.sabotage {
                Section("Sabotage") {
                    LabeledContent(sabotage.kind.title) {
                        CountdownView(until: sabotage.endsAt, now: serverNow)
                    }
                    Text("A sabotage is already running.").foregroundStyle(.secondary)
                }
            } else if game.phase.isMeeting {
                Section("Sabotage") {
                    Label("Not during meetings", systemImage: "person.3").foregroundStyle(.secondary)
                }
            } else {
                ForEach(SabotageKind.allCases, id: \.self) { kind in
                    card(for: kind)
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

    private func card(for kind: SabotageKind) -> some View {
        Section {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = client.serverClock.now(local: context.date)
                if let readyAt = game.sabotageReadyAt, now < readyAt {
                    LabeledContent("Ready in") { CountdownView(until: readyAt, now: serverNow) }
                } else {
                    Button(kind.title, systemImage: kind.symbol) { pending = kind }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .frame(maxWidth: .infinity)
                }
            }
        } header: {
            Text("Sabotage: \(kind.title)")
        } footer: {
            Text("Villagers get \(duration(of: kind)) to fix it at the matching booth. If they can't, the werewolves win. Werewolf families share one cooldown.")
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
