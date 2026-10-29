import Foundation
import Testing
@testable import MurderMystery

@MainActor
struct GameHostLifecycleTests {
    @Test func aPlayerCanLeaveInTheLobbyAndTheHeadPassesToAnotherMember() async throws {
        let (harness, heads) = try await HostHarness.seated(families: 3)
        let familyOne = try #require(harness.host.state.families[1])
        let second = harness.makeClient()
        second.join(code: familyOne.joinCode, name: "Ayu")
        #expect(await eventually { second.view?.lobby?.members.count == 2 })

        heads[1]?.leave()
        #expect(await eventually { second.view?.lobby?.isHead == true })
        #expect(heads[1]?.view == nil)
        #expect(harness.host.state.members(of: 1).map(\.name) == ["Ayu"])
    }

    @Test func leavingIsRefusedOnceTheGameHasStarted() async throws {
        let (harness, heads) = try await HostHarness.seated(families: 3)
        try harness.host.startTestGame(roles: [1: .werewolf])
        let client = try #require(heads[2])
        client.send(.leave)
        #expect(await eventually { client.lastError == HostError.gameAlreadyStarted.message })
        #expect(client.view?.game != nil)
    }

    @Test func newGameResetsConnectedClientsWithoutARelaunch() async throws {
        let (harness, heads) = try await HostHarness.seated(families: 3)
        let client = try #require(heads[1])
        #expect(client.view != nil)
        try harness.host.newGame()
        #expect(await eventually { client.view == nil && !client.isResuming })
    }

    @Test func syncDeliversTheCurrentViewAfterATimerFired() async throws {
        let (harness, heads) = try await HostHarness.seated(families: 3)
        try harness.host.startTestGame(roles: [1: .werewolf])
        try harness.host.applyAsOC(.startMeeting)
        let client = try #require(heads[2])
        #expect(await eventually { client.view?.game?.phase.isMeeting == true })
        harness.clock.advance(by: harness.host.state.settings.discussionDuration + 1)
        client.send(.sync)
        #expect(await eventually {
            if case .voting = client.view?.game?.phase { true } else { false }
        })
    }

    @Test func clientsDoNotSendBeforeTheHostHasConfirmedTheirIdentity() async throws {
        let harness = try HostHarness(families: [])
        let client = harness.makeClient()
        client.send(.sightings([]))
        #expect(client.lastError == nil)
    }
}
