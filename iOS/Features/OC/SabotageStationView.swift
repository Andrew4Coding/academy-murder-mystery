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
                    .foregroundStyle(Theme.text)
                    .themedBackground()
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { OCSignOutButton(client: client) } }
            .sensoryFeedback(.success, trigger: resolveCount)
        }
    }

    private func active(_ sabotage: SabotageView) -> some View {
        ThemedScreen {
            VStack(spacing: Spacing.sm) {
                Label(
                    sabotage.kind == kind ? "Sabotage at your booth" : "Sabotage at \(sabotage.kind.title)",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.headline)
                .foregroundStyle(Theme.accent)
                CountdownView(until: sabotage.endsAt, now: serverNow)
                    .countdownDisplay()
            }
            .frame(maxWidth: .infinity)
            .themedCard()
            .accessibilityElement(children: .combine)
            if sabotage.kind == kind {
                ScreenSection(footer: "Tap once the villagers have finished the task at your booth.") {
                    Button("Mark as Resolved", systemImage: "checkmark.shield") { confirming = true }
                        .buttonStyle(.accentFill)
                    if let error = client.lastError {
                        ErrorRow(message: error)
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
