import SwiftUI

struct TownHallObserverView: View {
    let oc: OCView?
    let client: GameClient

    @State private var confirming = false

    var body: some View {
        NavigationStack {
            List {
                if let sabotage = oc?.sabotage {
                    Section("Sabotage") {
                        LabeledContent(sabotage.kind.title) { CountdownView(until: sabotage.endsAt, now: serverNow) }
                        Button("Mark as Resolved", systemImage: "checkmark.shield") { confirming = true }
                    }
                }
                Section {
                    ForEach(oc?.families ?? []) { family in
                        LabeledContent(family.name) {
                            if family.life == .alive {
                                Text("\(family.stampsDone) of \(family.stampsTotal) stamps")
                            } else {
                                Text(family.life.title).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Families")
                } footer: {
                    Text("Start meetings and manage the game from the Mac.")
                }
            }
            .overlay {
                if oc?.families.isEmpty != false {
                    WaitingForGameView()
                }
            }
            .navigationTitle("Town Hall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { OCSignOutButton(client: client) } }
            .confirmationDialog("Mark the sabotage as resolved?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Mark as Resolved") { client.send(.resolveSabotage) }
            }
        }
    }

    private var serverNow: @Sendable (Date) -> Date {
        let clock = client.serverClock
        return { clock.now(local: $0) }
    }
}
