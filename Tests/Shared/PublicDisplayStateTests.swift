import Foundation
import Testing
@testable import MurderMystery

@MainActor
struct PublicDisplayStateTests {
    private func startedGame() async throws -> (HostHarness, [FamilyID: GameClient]) {
        let (harness, heads) = try await HostHarness.seated(families: 5, werewolves: 1)
        try harness.host.startGame()
        harness.clock.advance(by: 121)
        return (harness, heads)
    }

    private func wolf(_ harness: HostHarness) -> FamilyID {
        harness.host.state.engine!.state.families.values.first { $0.role == .werewolf }!.id
    }

    @Test func showsWaitingBeforeTheGameAndOfflineWhenTheHostIsDown() throws {
        let harness = try HostHarness()
        #expect(harness.host.publicDisplayState().screen == .waiting)
        #expect(harness.host.publicDisplayState(hostRunning: false).screen == .hostOffline)
    }

    @Test func showsTheGameClockWhilePlayingWithoutAnyRole() async throws {
        let (harness, _) = try await startedGame()
        let display = harness.host.publicDisplayState()
        let engine = harness.host.state.engine!.state
        #expect(display.screen == .playing(gameEndsAt: engine.finalVoteAt))
        #expect(display.familiesRemaining == 5)
        let json = try String(decoding: JSONEncoder().encode(display), as: UTF8.self).lowercased()
        #expect(!json.contains("werewolf"))
        #expect(!json.contains("villager"))
    }

    @Test func showsMeetingTimersAndVoteProgressButNeverTheChoices() async throws {
        let (harness, _) = try await startedGame()
        try harness.host.applyAsOC(.startMeeting)
        let now = harness.clock.now
        #expect(harness.host.publicDisplayState().screen == .discussion(until: now.addingTimeInterval(120)))
        harness.clock.advance(by: 121)
        harness.host.tick()
        try harness.host.applyAsOC(.proxyVote(for: 1, choice: .family(2)))
        let display = harness.host.publicDisplayState()
        guard case let .voting(_, isFinal, cast, total) = display.screen else {
            Issue.record("Expected voting")
            return
        }
        #expect(!isFinal)
        #expect(cast == 1)
        #expect(total == 5)
    }

    @Test func showsSabotageWithItsBoothDuringAnyPhase() async throws {
        let (harness, _) = try await startedGame()
        let wolfID = wolf(harness)
        try harness.host.applyAsOC(.requestSabotage(by: wolfID, kind: .oxygen))
        #expect(harness.host.publicDisplayState().alarm?.kind == .oxygen)
        try harness.host.applyAsOC(.startMeeting)
        #expect(harness.host.publicDisplayState().alarm?.endsAt == harness.host.state.engine?.state.sabotage?.endsAt)
    }

    @Test func revealsTheRoleOfAnExpelledFamilyOnTheResultScreen() async throws {
        let (harness, _) = try await HostHarness.seated(families: 6, werewolves: 2)
        try harness.host.startGame()
        harness.clock.advance(by: 121)
        let wolves = harness.host.state.engine!.state.families.values.filter { $0.role == .werewolf }.map(\.id).sorted()
        try harness.host.applyAsOC(.startMeeting)
        harness.clock.advance(by: 121)
        harness.host.tick()
        for id in harness.host.state.families.keys.sorted() {
            try harness.host.applyAsOC(.proxyVote(for: id, choice: .family(wolves[0])))
        }
        guard case let .result(view) = harness.host.publicDisplayState().screen else {
            Issue.record("Expected a result screen")
            return
        }
        let name = harness.host.state.families[wolves[0]]!.name
        #expect(view.expelled == [ExpelledView(name: name, role: .werewolf)])
    }

    @Test func showsTheResultForThirtySecondsThenReturnsToThePlayingScreen() async throws {
        let (harness, _) = try await startedGame()
        let wolfID = wolf(harness)
        let decoy = harness.host.state.engine!.state.families.values.filter { $0.role == .villager }.map(\.id).sorted()[0]
        try harness.host.applyAsOC(.startMeeting)
        harness.clock.advance(by: 121)
        harness.host.tick()
        for id in harness.host.state.families.keys.sorted() {
            try harness.host.applyAsOC(.proxyVote(for: id, choice: .family(decoy)))
        }
        guard case let .result(view) = harness.host.publicDisplayState().screen else {
            Issue.record("Expected a result screen")
            return
        }
        #expect(view.expelled.map(\.role) == [.villager])
        _ = wolfID
        harness.clock.advance(by: PublicDisplayState.resultDuration + 1)
        guard case .playing = harness.host.publicDisplayState().screen else {
            Issue.record("Expected to return to playing")
            return
        }
    }

    @Test func endShowsTheWinningSideAndReason() async throws {
        let (harness, _) = try await startedGame()
        try harness.host.applyAsOC(.override(.endGame(.werewolves)))
        #expect(harness.host.publicDisplayState().screen == .ended(Outcome(winner: .werewolves, reason: .ocEnded)))
    }

    @Test func werewolfWinRevealsEveryFamilyWithFacesAndMarksTheWolves() async throws {
        let (harness, _) = try await startedGame()
        let wolfID = wolf(harness)
        let player = try #require(harness.host.state.player(of: wolfID))
        harness.host.selfies[player.id] = Data([1, 2, 3])
        try harness.host.applyAsOC(.override(.endGame(.werewolves)))
        let reveal = harness.host.publicDisplayState().reveal
        #expect(reveal.count == 5)
        #expect(reveal.filter(\.isWerewolf).map(\.id) == [wolfID])
        #expect(reveal.first { $0.id == wolfID }?.selfie == Data([1, 2, 3]))
    }

    @Test func noRolesOrFacesLeakBeforeTheEndOrWhenVillagersWin() async throws {
        let (harness, _) = try await startedGame()
        #expect(harness.host.publicDisplayState().reveal.isEmpty)
        try harness.host.applyAsOC(.override(.endGame(.villagers)))
        #expect(harness.host.publicDisplayState().reveal.isEmpty)
    }

    @Test func timersAreLargeEnoughForALabTv() {
        #expect(PublicDisplayLayout.timerFontSize >= 120)
    }
}
