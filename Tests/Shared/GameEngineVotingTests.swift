import Foundation
import Testing
@testable import Moonfall

struct GameEngineVotingTests {
    private func openVoting(_ fixture: inout Fixture, meetingAt start: TimeInterval = 100) throws {
        try fixture.apply(.startMeeting, at: start)
        _ = fixture.advance(to: start + 120)
    }

    @Test func meetingMovesFromDiscussionToVotingToRunning() throws {
        var fixture = try Fixture()
        let started = try fixture.apply(.startMeeting, at: 100)
        #expect(started.kinds == [.meetingStarted(deadFamilies: [])])
        #expect(fixture.engine.state.phase == .discussion(until: at(220)))
        #expect(fixture.advance(to: 220).kinds == [.votingOpened(isFinal: false)])
        #expect(fixture.engine.state.phase == .voting(until: at(340), isFinal: false))
        let closed = fixture.advance(to: 340)
        #expect(closed.kinds == [.voteClosed(tally: [], expelled: [], isFinal: false)])
        #expect(fixture.engine.state.phase == .running)
    }

    @Test func meetingAnnouncesFamiliesKilledSinceTheLastMeeting() throws {
        var fixture = try Fixture()
        let victim = fixture.villagers[0]
        try fixture.apply(.kill(killer: fixture.werewolves[0], victim: victim), at: 70)
        let events = try fixture.apply(.startMeeting, at: 100)
        #expect(events.kinds == [.meetingStarted(deadFamilies: [victim])])
        _ = fixture.advance(to: 340)
        let second = try fixture.apply(.startMeeting, at: 400)
        #expect(second.kinds == [.meetingStarted(deadFamilies: [])])
    }

    @Test func votesAreRejectedOutsideVotingAndFromDeadFamilies() throws {
        var fixture = try Fixture()
        let (voter, other) = (fixture.villagers[0], fixture.villagers[1])
        #expect(throws: RuleError.wrongPhase) {
            try fixture.apply(.castVote(by: voter, choice: .skip), at: 10)
        }
        try fixture.apply(.override(.forceKill(other)), at: 20)
        try openVoting(&fixture)
        #expect(throws: RuleError.familyNotAlive(other)) {
            try fixture.apply(.castVote(by: other, choice: .skip), at: 230)
        }
        #expect(throws: RuleError.invalidVoteTarget) {
            try fixture.apply(.castVote(by: voter, choice: .family(other)), at: 230)
        }
    }

    @Test func majorityExpelsAFamilyAndRevealsItsRole() throws {
        var fixture = try Fixture()
        let wolf = fixture.werewolves[0]
        try openVoting(&fixture)
        for voter in fixture.villagers.prefix(3) {
            try fixture.apply(.castVote(by: voter, choice: .family(wolf)), at: 230)
        }
        try fixture.apply(.castVote(by: wolf, choice: .family(fixture.villagers[0])), at: 231)
        let closed = fixture.advance(to: 340)
        #expect(closed.kinds.first == .voteClosed(
            tally: [VoteCount(choice: .family(fixture.villagers[0]), count: 1), VoteCount(choice: .family(wolf), count: 3)]
                .sorted { lhs, rhs in
                    if case let .family(a) = lhs.choice, case let .family(b) = rhs.choice {
                        return a < b
                    }
                    return false
                },
            expelled: [Reveal(family: wolf, role: .werewolf)],
            isFinal: false
        ))
        #expect(fixture.family(wolf).life == .expelled)
    }

    @Test func skipLeadOrTieExpelsNobody() throws {
        var fixture = try Fixture()
        let (a, b) = (fixture.villagers[0], fixture.villagers[1])
        try openVoting(&fixture)
        try fixture.apply(.castVote(by: a, choice: .skip), at: 230)
        try fixture.apply(.castVote(by: b, choice: .skip), at: 230)
        try fixture.apply(.castVote(by: fixture.villagers[2], choice: .family(a)), at: 230)
        _ = fixture.advance(to: 340)
        #expect(fixture.engine.state.aliveFamilies().count == 6)

        try openVoting(&fixture, meetingAt: 400)
        try fixture.apply(.castVote(by: a, choice: .family(b)), at: 530)
        try fixture.apply(.castVote(by: b, choice: .family(a)), at: 530)
        _ = fixture.advance(to: 640)
        #expect(fixture.engine.state.aliveFamilies().count == 6)
    }

    @Test func votingClosesEarlyWhenEveryLivingFamilyHasVoted() throws {
        var fixture = try Fixture(families: 4, werewolves: 1)
        try openVoting(&fixture)
        var closing: [GameEvent] = []
        for id in (1 ... 4).map({ FamilyID($0) }) {
            closing = try fixture.apply(.castVote(by: id, choice: .skip), at: 230)
        }
        #expect(closing.kinds.contains(.voteClosed(tally: [VoteCount(choice: .skip, count: 4)], expelled: [], isFinal: false)))
        #expect(fixture.engine.state.phase == .running)
    }

    @Test func aFamilyMayChangeItsVoteBeforeVotingCloses() throws {
        var fixture = try Fixture()
        let (voter, target) = (fixture.villagers[0], fixture.villagers[1])
        try openVoting(&fixture)
        try fixture.apply(.castVote(by: voter, choice: .family(target)), at: 230)
        try fixture.apply(.castVote(by: voter, choice: .skip), at: 235)
        let closed = fixture.advance(to: 340)
        #expect(closed.kinds.first == .voteClosed(tally: [VoteCount(choice: .skip, count: 1)], expelled: [], isFinal: false))
    }

    @Test func storedStateKeepsNoVoteChoicesAfterClosing() throws {
        var fixture = try Fixture()
        try openVoting(&fixture)
        try fixture.apply(.castVote(by: fixture.villagers[0], choice: .skip), at: 230)
        _ = fixture.advance(to: 340)
        #expect(fixture.engine.state.votes.isEmpty)
    }
}
