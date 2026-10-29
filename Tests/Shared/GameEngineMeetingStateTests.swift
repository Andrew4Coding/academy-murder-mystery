import Foundation
import Testing
@testable import Moonfall

struct GameEngineMeetingStateTests {
    private func openVoting(_ fixture: inout Fixture) throws {
        try fixture.apply(.startMeeting, at: 100)
        _ = fixture.advance(to: 220)
    }

    @Test func meetingStartKeepsTheAnnouncedDeathsForClients() throws {
        var fixture = try Fixture()
        let victim = fixture.villagers[0]
        try fixture.apply(.kill(killer: fixture.werewolves[0], victim: victim), at: 70)
        try fixture.apply(.startMeeting, at: 100)
        #expect(fixture.engine.state.announcedDeaths == [victim])
        _ = fixture.advance(to: 340)
        try fixture.apply(.startMeeting, at: 400)
        #expect(fixture.engine.state.announcedDeaths.isEmpty)
    }

    @Test func closedVotesLeaveAPublicResultUntilTheNextMeeting() throws {
        var fixture = try Fixture()
        let wolf = fixture.werewolves[0]
        try openVoting(&fixture)
        try fixture.apply(.castVote(by: fixture.villagers[0], choice: .family(wolf)), at: 230)
        try fixture.apply(.castVote(by: fixture.villagers[1], choice: .family(wolf)), at: 231)
        _ = fixture.advance(to: 340)
        let result = try #require(fixture.engine.state.lastResult)
        #expect(result.expelled == [Reveal(family: wolf, role: .werewolf)])
        #expect(result.tally == [VoteCount(choice: .family(wolf), count: 2)])
        #expect(!result.isFinal)
    }

    @Test func storedGamesNeverContainBallots() throws {
        var fixture = try Fixture()
        try openVoting(&fixture)
        try fixture.apply(.castVote(by: fixture.villagers[0], choice: .family(fixture.villagers[1])), at: 230)
        #expect(!fixture.engine.state.votes.isEmpty)
        let data = try JSONEncoder().encode(fixture.engine)
        #expect(!String(decoding: data, as: UTF8.self).contains("votes"))
        let restored = try JSONDecoder().decode(GameEngine.self, from: data)
        #expect(restored.state.votes.isEmpty)
    }

    @Test func proxyVotesAreRecordedAsOverridesWithoutTheChoice() throws {
        var fixture = try Fixture()
        let family = fixture.villagers[0]
        try openVoting(&fixture)
        let events = try fixture.apply(.proxyVote(for: family, choice: .skip), at: 230)
        #expect(events.kinds == [.ocOverride(.proxyVote(family)), .voteCast(by: family)])
        #expect(fixture.engine.state.votes[family] == .skip)
        #expect(throws: RuleError.wrongPhase) {
            try fixture.apply(.override(.proxyVote(family)), at: 231)
        }
    }

    @Test func proxyVotesAreOnlyAllowedWhileVotingIsOpen() throws {
        var fixture = try Fixture()
        #expect(throws: RuleError.wrongPhase) {
            try fixture.apply(.proxyVote(for: fixture.villagers[0], choice: .skip), at: 10)
        }
    }
}
