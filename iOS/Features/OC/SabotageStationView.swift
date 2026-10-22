import SwiftUI

struct SabotageStationView: View {
    let kind: SabotageKind
    let oc: OCView?
    let client: GameClient

    @State private var confirming = false
    @State private var resolveCount = 0

    var body: some View {
        NavigationStack {
            Group {
                if let sabotage = oc?.sabotage {
                    active(sabotage)
                } else {
                    ContentUnavailableView(
                        "No sabotage running",
                        systemImage: "checkmark.shield",
                        description: Text("You'll see a countdown here when werewolves sabotage \(kind.title).")
                    )
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { OCSignOutButton(client: client) } }
            .sensoryFeedback(.success, trigger: resolveCount)
        }
    }

    private func active(_ sabotage: SabotageView) -> some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text(sabotage.kind == kind ? "Sabotage at your booth" : "Sabotage at \(sabotage.kind.title)")
                        .font(.headline)
                    CountdownView(until: sabotage.endsAt, now: serverNow)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
            if sabotage.kind == kind {
                Section {
                    Button("Mark as Resolved", systemImage: "checkmark.shield") { confirming = true }
                        .frame(maxWidth: .infinity)
                } footer: {
                    Text("Tap once the villagers have finished the task at your booth.")
                    if let error = client.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                }
            }
        }
        .confirmationDialog("Mark the sabotage as resolved?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Mark as Resolved") {
                client.send(.resolveSabotage)
                resolveCount += 1
            }
        }
    }

    private var serverNow: @Sendable (Date) -> Date {
        let clock = client.serverClock
        return { clock.now(local: $0) }
    }
}
