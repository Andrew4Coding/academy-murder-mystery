import Foundation
import Testing
@testable import MurderMystery

struct GameEngineTimerTests {
    @Test func meetingTimersMoveInBothDirections() throws {
        var fixture = try Fixture()
        try fixture.apply(.startMeeting, at: 100)
        let events = try fixture.apply(.adjustTimer(.meeting, seconds: 60), at: 110)
        #expect(events.kinds == [.ocOverride(.timerAdjusted(.meeting, seconds: 60))])
        #expect(fixture.engine.state.phase == .discussion(until: at(280)))
        try fixture.apply(.adjustTimer(.meeting, seconds: -30), at: 111)
        #expect(fixture.engine.state.phase == .discussion(until: at(250)))
    }

    @Test func votingKeepsItsFinalFlagWhenAdjusted() throws {
        var fixture = try Fixture()
        try fixture.apply(.startMeeting, at: 100)
        _ = fixture.advance(to: 220)
        try fixture.apply(.adjustTimer(.meeting, seconds: 30), at: 230)
        #expect(fixture.engine.state.phase == .voting(until: at(370), isFinal: false))
    }

    @Test func aNegativeDeltaNeverPutsTheEndInThePast() throws {
        var fixture = try Fixture()
        try fixture.apply(.startMeeting, at: 100)
        try fixture.apply(.adjustTimer(.meeting, seconds: -10000), at: 150)
        #expect(fixture.engine.state.phase == .discussion(until: at(151)))
        let events = fixture.advance(to: 152)
        #expect(events.kinds == [.votingOpened(isFinal: false)])
    }

    @Test func meetingTimerNeedsAMeeting() throws {
        var fixture = try Fixture()
        #expect(throws: RuleError.wrongPhase) {
            try fixture.apply(.adjustTimer(.meeting, seconds: 60), at: 10)
        }
    }

    @Test func finalVoteClockMovesAndFiresAtTheNewTime() throws {
        var fixture = try Fixture()
        let original = fixture.engine.state.finalVoteAt
        try fixture.apply(.adjustTimer(.finalVote, seconds: -600), at: 10)
        let moved = original.addingTimeInterval(-600)
        #expect(fixture.engine.state.finalVoteAt == moved)
        #expect(fixture.advance(to: moved.timeIntervalSinceReferenceDate - 1).isEmpty)
        let events = fixture.advance(to: moved.timeIntervalSinceReferenceDate)
        #expect(events.kinds.contains(.votingOpened(isFinal: true)))
        #expect(throws: RuleError.timerFinished) {
            try fixture.apply(.adjustTimer(.finalVote, seconds: 60), at: moved.timeIntervalSinceReferenceDate + 1)
        }
    }

    @Test func sabotageCountdownMovesAndNeedsAnActiveSabotage() throws {
        var fixture = try Fixture()
        #expect(throws: RuleError.noActiveSabotage) {
            try fixture.apply(.adjustTimer(.sabotage, seconds: 30), at: 130)
        }
        try fixture.apply(.requestSabotage(by: fixture.werewolves[0], kind: .reactor), at: 130)
        let original = try #require(fixture.engine.state.sabotage).endsAt
        try fixture.apply(.adjustTimer(.sabotage, seconds: 45), at: 131)
        #expect(fixture.engine.state.sabotage?.endsAt == original.addingTimeInterval(45))
        #expect(fixture.advance(to: original.timeIntervalSinceReferenceDate + 1).outcome == nil)
    }

    @Test func gamesStoredBeforeTimerEditsStillDecode() throws {
        let fixture = try Fixture()
        let data = try JSONEncoder().encode(fixture.engine)
        let decoded = try JSONDecoder().decode(GameEngine.self, from: data)
        #expect(decoded.state.finalVoteOverride == nil)
        #expect(decoded.state.finalVoteAt == fixture.engine.state.finalVoteAt)
    }
}
