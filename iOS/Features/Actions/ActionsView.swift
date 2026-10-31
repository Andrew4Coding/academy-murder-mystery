import SwiftUI
import UIKit

struct ActionsView: View {
    let game: GameView
    let client: GameClient
    let proximity: ProximityService

    @State private var target: FamilySummary?
    @State private var killCount = 0
    @State private var reportCount = 0
    @State private var displayed: [FamilySummary] = []

    var body: some View {
        NavigationStack {
            ThemedScreen {
                if game.role == .werewolf, game.life == .alive {
                    killSection
                }
                if game.life == .alive {
                    reportSection
                }
                if game.role == .werewolf {
                    SabotageSection(game: game, client: client)
                }
                if let error = client.lastError {
                    ErrorRow(message: error)
                }
            }
            .navigationTitle("Actions")
            .navigationBarTitleDisplayMode(.inline)
            .refreshToolbar(client)
            .confirmationDialog(
                target.map { "Eliminate \($0.name)?" } ?? "",
                isPresented: Binding(get: { target != nil }, set: {
                    if !$0 {
                        target = nil
                    }
                }),
                titleVisibility: .visible
            ) {
                if let target {
                    Button("Eliminate \(target.name)", role: .destructive) {
                        client.send(.kill(victim: target.id))
                        displayed.removeAll { $0.id == target.id }
                        killCount += 1
                    }
                }
            } message: {
                Text("The whole family is out of the game.")
            }
            .sensoryFeedback(.impact, trigger: killCount)
            .sensoryFeedback(.warning, trigger: reportCount)
            .onAppear { displayed = game.nearby }
            .onChange(of: game.nearby) { _, nearby in
                if !nearby.isEmpty {
                    displayed = nearby
                }
            }
            .task(id: game.nearby.isEmpty) {
                guard game.nearby.isEmpty else { return }
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled {
                    displayed = []
                }
            }
        }
    }

    private var reportSection: some View {
        ScreenSection(
            title: "Report a body",
            footer: game.sabotage != nil
                ? "Nobody can call a meeting while a sabotage is active."
                : "Walk up to a fallen family and keep this app open. Reporting calls everyone to the Town Hall."
        ) {
            if !proximity.bluetoothState.isUsable {
                BluetoothOffRow()
            } else if game.nearbyBodies.isEmpty {
                Label("No body nearby", systemImage: "figure.fall").secondaryText()
            }
            ForEach(game.nearbyBodies) { body in
                HStack {
                    Text("\(body.name)'s body")
                    Spacer()
                    Button("Report") {
                        client.send(.reportBody(body.id))
                        reportCount += 1
                    }
                    .buttonStyle(.accentFill)
                    .fixedSize()
                    .disabled(game.phase != .running || game.sabotage != nil)
                    .accessibilityLabel("Report \(body.name)'s body")
                }
            }
        }
    }

    private var killSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Eliminate")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let readyAt = game.killReadyAt {
                cooldownRow(readyAt: readyAt)
            }
            BentoGrid(minimum: 150) {
                killTiles
            }
            Text("Stand close to a villager family and keep this app open. Families that are close enough appear here.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func cooldownRow(readyAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = readyAt.timeIntervalSince(client.serverClock.now(local: context.date))
            HStack {
                Text("Elimination").font(.subheadline.weight(.semibold))
                Spacer()
                if remaining > 0 {
                    StatusLabel("Ready in \(Duration.clock(remaining))", systemImage: "hourglass", tint: Theme.warning)
                } else {
                    StatusLabel("Ready", systemImage: "checkmark.circle.fill", tint: Theme.success)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Theme.surface, in: .rect(cornerRadius: Radius.md))
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var killTiles: some View {
            if !proximity.bluetoothState.isUsable {
                BluetoothOffRow()
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
                    .background(Theme.surface, in: .rect(cornerRadius: Radius.lg))
            } else if displayed.isEmpty {
                BentoTile(
                    title: "No one nearby",
                    subtitle: "Villager families appear when close",
                    systemImage: "dot.radiowaves.left.and.right",
                    tint: Theme.textSecondary
                )
                .opacity(0.7)
            }
            ForEach(displayed) { family in
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let ready = isReady(at: client.serverClock.now(local: context.date))
                    Button { target = family } label: {
                        BentoTile(
                            title: family.name,
                            subtitle: ready ? "Tap to eliminate" : "Cooling down",
                            systemImage: "person.fill.xmark",
                            isProminent: ready
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!ready)
                    .accessibilityLabel("Eliminate \(family.name)")
                    .accessibilityHint(ready ? "Asks you to confirm" : "Not ready yet, wait for the cooldown")
                }
            }
    }

    private func isReady(at now: Date) -> Bool {
        guard let readyAt = game.killReadyAt else { return false }
        return now >= readyAt
    }

    private var serverNow: @Sendable (Date) -> Date {
        let clock = client.serverClock
        return { clock.now(local: $0) }
    }
}

private struct BluetoothOffRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            StatusLabel("Bluetooth is off", systemImage: "bolt.horizontal.circle", tint: Theme.warning)
                .font(.headline)
            Text("Turn on Bluetooth and allow it for this app, so the game can tell who is close.")
                .secondaryText()
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .frame(minHeight: 44)
            }
        }
    }
}
