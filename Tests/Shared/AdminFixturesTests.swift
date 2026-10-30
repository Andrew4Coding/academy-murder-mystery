import Foundation
import Testing
@testable import Moonfall

@MainActor
struct AdminFixturesTests {
    @Test func everyStageBuilds() {
        for stage in AdminStage.allCases {
            let view = AdminFixtures.adminView(stage)
            #expect(!view.families.isEmpty, "\(stage)")
        }
    }

    @Test func stagesLandInTheirPhase() {
        #expect(AdminFixtures.adminView(.setupIssues).setupIssues.isEmpty == false)
        #expect(AdminFixtures.adminView(.lobbyReady).isLobby)
        #expect(AdminFixtures.adminView(.lobbyReady).setupIssues.isEmpty)
        #expect(AdminFixtures.adminView(.running).phase == .running)
        if case .discussion = AdminFixtures.adminView(.discussion).phase {} else { Issue.record("not discussion") }
        if case .voting = AdminFixtures.adminView(.voting).phase {} else { Issue.record("not voting") }
        #expect(AdminFixtures.adminView(.result).lastResult != nil)
        #expect(AdminFixtures.adminView(.result).phase == .running)
        #expect(AdminFixtures.adminView(.sabotage).sabotage != nil)
        if case .ended = AdminFixtures.adminView(.ended).phase {} else { Issue.record("not ended") }
    }

    @Test func simulationStagesBuild() {
        #expect(AdminFixtures.simulation(.idle).simulation == nil)
        #expect(AdminFixtures.simulation(.running).simulation != nil)
        #expect(AdminFixtures.simulation(.finished).simulation?.isFinished == true)
        #expect(AdminFixtures.simulation(.error).errorMessage != nil)
    }
}
