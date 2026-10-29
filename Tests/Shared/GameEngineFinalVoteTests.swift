import Foundation
import Testing
@testable import Moonfall

struct GameEngineFinalVoteTests {
    @Test func finalVoteOpensAtTheGameLimitAndAnnouncesDeaths() throws {
        var fixture = try Fixture()
        let victim = fixture.villagers[0]
        try fixture.apply(.kill(killer: fixture.werewolves[0], victim: victim), at: 100)
        let events = fixture.advance(to: 2700)
        #expect(events.kinds == [.meetingStarted(deadFamilies: [victim]), .votingOpened(isFinal: true)])
        #expect(fixture.engine.state.phase == .voting(until: at(2820), isFinal: true))
    }

    @Test func villagersWinWhenTheTopFamiliesAreExactlyTheWerewolves() throws {
        var fixture = try Fixture(families: 6, werewolves: 2)
        _ = fixture.advance(to: 2700)
        let wolves = fixture.werewolves
        for (index, id) in fixture.villagers.enumerated() {
            try fixture.apply(.castVote(by: id, choice: .family(wolves[index % 2])), at: 2710)
        }
        try fixture.apply(.castVote(by: wolves[0], choice: .family(fixture.villagers[0])), at: 2711)
        let events = try fixture.apply(.castVote(by: wolves[1], choice: .skip), at: 2712)
        #expect(events.outcome == Outcome(winner: .villagers, reason: .finalVoteSucceeded))
        #expect(fixture.family(wolves[0]).life == .expelled)
        #expect(fixture.family(wolves[1]).life == .expelled)
    }

    @Test func werewolvesWinWhenAVillagerOutranksAWerewolf() throws {
        var fixture = try Fixture()
        _ = fixture.advance(to: 2700)
        let scapegoat = fixture.villagers[0]
        for id in fixture.villagers {
            try fixture.apply(.castVote(by: id, choice: .family(scapegoat)), at: 2710)
        }
        let events = try fixture.apply(.castVote(by: fixture.werewolves[0], choice: .skip), at: 2711)
        #expect(events.outcome == Outcome(winner: .werewolves, reason: .finalVoteFailed))
        #expect(fixture.family(scapegoat).life == .expelled)
    }

    @Test func aTieAtTheCutoffCountsAsFailureForVillagers() throws {
        var fixture = try Fixture()
        _ = fixture.advance(to: 2700)
        let wolf = fixture.werewolves[0]
        let rival = fixture.villagers[0]
        let choices: [VoteChoice] = [.family(wolf), .family(wolf), .family(rival), .family(rival), .skip]
        for (id, choice) in zip(fixture.villagers, choices) {
            try fixture.apply(.castVote(by: id, choice: choice), at: 2710)
        }
        let events = try fixture.apply(.castVote(by: wolf, choice: .skip), at: 2711)
        #expect(events.outcome == Outcome(winner: .werewolves, reason: .finalVoteFailed))
        #expect(fixture.family(wolf).life == .alive)
    }

    @Test func finalVoteWaitsForAMeetingInProgress() throws {
        var fixture = try Fixture()
        try fixture.apply(.startMeeting, at: 2650)
        #expect(fixture.advance(to: 2700).isEmpty)
        #expect(fixture.engine.state.finalVotePending)
        _ = fixture.advance(to: 2770)
        let closing = fixture.advance(to: 2890)
        #expect(closing.kinds.contains(.votingOpened(isFinal: true)))
        #expect(fixture.engine.state.phase == .voting(until: at(3010), isFinal: true))
    }

    @Test func noVotesAtTheFinalVoteMeansWerewolvesWin() throws {
        var fixture = try Fixture()
        _ = fixture.advance(to: 2700)
        let events = fixture.advance(to: 2820)
        #expect(events.outcome == Outcome(winner: .werewolves, reason: .finalVoteFailed))
    }
}
