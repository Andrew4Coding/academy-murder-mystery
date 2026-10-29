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
            List {
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
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
                }
            }
            .navigationTitle("Actions")
            .navigationBarTitleDisplayMode(.inline)
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
        Section {
            if !proximity.bluetoothState.isUsable {
                BluetoothOffRow()
            } else if game.nearbyBodies.isEmpty {
                Label("No body nearby", systemImage: "figure.fall")
                    .foregroundStyle(.secondary)
            }
            ForEach(game.nearbyBodies) { body in
                HStack {
                    Text("\(body.name)'s body")
                    Spacer()
                    Button("Report", role: .destructive) {
                        client.send(.reportBody(body.id))
                        reportCount += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(game.phase != .running)
                }
            }
        } header: {
            Text("Report a body")
        } footer: {
            Text("Walk up to a fallen family and keep this app open. Reporting calls everyone to the Town Hall.")
        }
    }

    private var killSection: some View {
        Section {
            if !proximity.bluetoothState.isUsable {
                BluetoothOffRow()
            } else if displayed.isEmpty {
                Label("No one nearby", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
            }
            ForEach(displayed) { family in
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let ready = isReady(at: client.serverClock.now(local: context.date))
                    HStack {
                        Text(family.name)
                        Spacer()
                        Button("Eliminate", role: .destructive) { target = family }
                            .buttonStyle(.borderedProminent)
                            .disabled(!ready)
                    }
                }
            }
            if let readyAt = game.killReadyAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = readyAt.timeIntervalSince(client.serverClock.now(local: context.date))
                    LabeledContent("Kill") {
                        if remaining > 0 {
                            CountdownView(until: readyAt, now: serverNow)
                        } else {
                            Text("Ready").foregroundStyle(.green)
                        }
                    }
                }
            }
        } header: {
            Text("Nearby villager families")
        } footer: {
            Text("Stand close to a villager family and keep this app open. Families that are close enough appear here.")
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
        VStack(alignment: .leading, spacing: 8) {
            Label("Bluetooth is off", systemImage: "bolt.horizontal.circle")
                .foregroundStyle(.orange)
            Text("Turn on Bluetooth and allow it for this app, so the game can tell who is close.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
            }
        }
    }
}
