import Foundation
import Testing
@testable import MurderMystery

@MainActor
struct GameHostTestingToolsTests {
    @Test func testingStartAcceptsOneFamilyAndKeepsTheChosenRoles() throws {
        var generator = SeededGenerator(seed: 3)
        let (engine, events) = try GameEngine.startForTesting(roles: [1: .werewolf], at: t0, using: &generator)
        #expect(engine.state.families.count == 1)
        #expect(engine.state.families[1]?.role == .werewolf)
        #expect(engine.state.families[1]?.tasks.count == 5)
        #expect(events.first?.kind == .gameStarted(werewolves: [1]))
        #expect(throws: RuleError.invalidSetup("At least one family is required")) {
            try GameEngine.startForTesting(roles: [:], at: t0, using: &generator)
        }
    }

    @Test func relaxedIssuesOnlyAskForAFamily() {
        var state = HostState(ocPin: "1111")
        #expect(state.setupIssues(testing: true) == ["Create at least 1 family."])
        state.families[1] = FamilyInfo(id: 1, name: "Family 1", joinCode: "AAA111")
        #expect(state.setupIssues(testing: true).isEmpty)
        #expect(!state.setupIssues().isEmpty)
    }

    @Test func startTestGameIsRefusedUnlessTestingToolsAreOn() throws {
        let harness = try HostHarness()
        #expect(harness.host.testingToolsEnabled == TestingTools.isEnabled)
        harness.host.testingToolsEnabled = false
        #expect(throws: HostError.setup("Testing tools are off. Run the MurderMysteryAdmin-Testing scheme.")) {
            try harness.host.startTestGame(roles: [1: .werewolf])
        }
        #expect(harness.host.state.isLobby)
    }

    @Test func oneMemberCanStartAloneAndSeesTheChosenRole() async throws {
        let harness = try HostHarness()
        harness.host.testingToolsEnabled = true
        let client = harness.makeClient()
        client.join(code: "AAA111", name: "Dewi")
        #expect(await eventually { client.isSignedIn })

        try harness.host.startTestGame(roles: [1: .werewolf, 2: .villager])

        #expect(await eventually { client.view?.game != nil })
        let game = try #require(client.view?.game)
        #expect(game.role == .werewolf)
        #expect(game.isHead)
        #expect(game.tasks.count == 5)
        #expect(game.allies?.isEmpty == true)
        #expect(harness.host.state.simulated)
        #expect(harness.host.state.families[2]?.head == nil)
        #expect(harness.host.state.engine?.state.families[2]?.role == .villager)
    }
}
