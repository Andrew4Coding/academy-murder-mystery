import Foundation
import Testing
@testable import MurderMystery

@MainActor
struct SimulationControllerTests {
    @Test func speedScalesHowManySimulatedSecondsEachTickAdvances() {
        let controller = SimulationController()
        controller.start(Simulation.Config(familyCount: 6, werewolfCount: 1))
        defer { controller.discard() }
        controller.speed = .faster
        controller.tick(real: 0.1)
        #expect(controller.simulation?.elapsed == 2)
        controller.speed = .paused
        controller.tick(real: 0.1)
        #expect(controller.simulation?.elapsed == 2)
    }

    @Test func invalidSettingsAreReportedInsteadOfStarting() {
        let controller = SimulationController()
        controller.start(Simulation.Config(familyCount: 4, werewolfCount: 3))
        #expect(!controller.isActive)
        #expect(controller.errorMessage != nil)
    }

    @Test func theLogDescribesEventsWithFamilyNamesNewestFirst() throws {
        let sim = try Simulation(config: Simulation.Config(familyCount: 6, werewolfCount: 1))
        sim.step(by: 2700)
        let names = sim.host.state.families.mapValues(\.name)
        let lines = SimulationLog.lines(for: sim.events, names: names, limit: 200)
        #expect(lines.first?.hasPrefix("45:") == true || lines.first?.hasPrefix("44:") == true)
        #expect(lines.contains { $0.contains("Game started") })
    }

    @Test func discardingTheSimulationStopsAndClearsIt() {
        let controller = SimulationController()
        controller.start(Simulation.Config(familyCount: 6, werewolfCount: 1))
        controller.discard()
        #expect(!controller.isActive)
    }
}
