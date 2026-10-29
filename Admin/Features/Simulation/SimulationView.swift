import SwiftUI

struct SimulationView: View {
    let controller: SimulationController

    @State private var config = Simulation.Config()
    @State private var seedText = "1"

    var body: some View {
        Form {
            Section {
                Stepper("Bot families: \(config.familyCount)", value: $config.familyCount, in: 4 ... 40)
                Stepper(
                    "Werewolf families: \(config.werewolfCount)",
                    value: $config.werewolfCount,
                    in: 1 ... max(1, (config.familyCount - 1) / 2)
                )
                LabeledContent("Seed") {
                    HStack {
                        TextField("Seed", text: $seedText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .multilineTextAlignment(.trailing)
                        Button("Random", systemImage: "dice") { seedText = String(UInt32.random(in: 1 ... 999_999)) }
                    }
                }
            } header: {
                Text("Rehearsal")
            } footer: {
                Text(
                    "Runs a full game with bots on the real rules. It never touches the real game, its families or its devices. The same seed plays out the same way."
                )
            }

            Section("Speed") {
                Picker("Speed", selection: Binding(get: { controller.speed }, set: { controller.speed = $0 })) {
                    ForEach(SimulationController.Speed.allCases) { speed in
                        Text(speed.title).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let message = controller.errorMessage {
                Section {
                    StatusLabel.error("Simulation can't start with these settings: \(message)")
                }
            }

            if let simulation = controller.simulation {
                SimulationStatus(simulation: simulation)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Simulation")
        .toolbar {
            ToolbarItem {
                Button("Run to End", systemImage: "forward.end.fill") { controller.runToEnd() }
                    .disabled(!controller.isActive || controller.simulation?.isFinished == true)
            }
            ToolbarItem {
                Button("Discard", systemImage: "trash", role: .destructive) { controller.discard() }
                    .disabled(!controller.isActive)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(controller.isActive ? "Restart" : "Start Simulation", systemImage: "play.fill") {
                    config.seed = UInt64(seedText) ?? 1
                    controller.start(config)
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}

private struct SimulationStatus: View {
    let simulation: Simulation

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let names = simulation.host.state.families.mapValues(\.name)
            Section("Status") {
                LabeledContent("Simulated time", value: Duration.seconds(simulation.elapsed).formatted(.time(pattern: .minuteSecond)))
                if let game = simulation.host.state.engine?.state {
                    LabeledContent("Phase", value: phase(game.phase))
                    LabeledContent("Families in the game", value: "\(game.aliveFamilies().count) of \(game.families.count)")
                    if let sabotage = game.sabotage {
                        LabeledContent("Sabotage", value: sabotage.kind.title)
                    }
                }
            }
            Section("Event log") {
                ForEach(Array(SimulationLog.lines(for: simulation.events, names: names).enumerated()), id: \.offset) { _, line in
                    Text(line).font(.callout.monospaced())
                }
            }
        }
    }

    private func phase(_ phase: Phase) -> String {
        switch phase {
        case .running: "Playing"
        case .discussion: "Discussion"
        case let .voting(_, isFinal): isFinal ? "Final vote" : "Voting"
        case let .ended(outcome): outcome.winner == .villagers ? "Villagers won" : "Werewolves won"
        }
    }
}
