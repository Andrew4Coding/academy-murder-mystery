import Foundation
import Testing
@testable import Moonfall

private func makeGame(
    role: Role = .villager,
    life: LifeState = .alive,
    phase: PhaseView = .running,
    sabotage: SabotageView? = nil
) -> GameView {
    GameView(
        role: role,
        family: FamilyID(1),
        familyName: "Cedar",
        life: life,
        allies: role == .werewolf ? [] : nil,
        families: [],
        phase: phase,
        announcedDeaths: [],
        myVote: nil,
        votesCast: 0,
        votersTotal: 0,
        lastResult: nil,
        bleToken: role == .werewolf ? "wolf" : "villager",
        proximity: ProximitySettings(rssiThreshold: -70, sightingFreshness: 5),
        nearby: [],
        killReadyAt: role == .werewolf ? at(5) : nil,
        sabotage: sabotage,
        sabotageReadyAt: role == .werewolf ? at(9) : nil
    )
}

private let sabotage = SabotageView(kind: .oxygen, startedAt: at(0), endsAt: at(60))

@Test func playingShowsNoCountdown() {
    let state = GameActivityState(game: makeGame(), clockOffset: 0)
    #expect(state.kind == .playing)
    #expect(state.countdownEnd == nil)
}

@Test func headlinePriorityIsKilledThenMeetingThenVotingThenSabotage() {
    let meeting = PhaseView.discussion(until: at(30))
    #expect(GameActivityState(game: makeGame(phase: meeting, sabotage: sabotage), clockOffset: 0).kind == .meeting)
    let voting = PhaseView.voting(until: at(30), isFinal: false)
    #expect(GameActivityState(game: makeGame(phase: voting, sabotage: sabotage), clockOffset: 0).kind == .voting)
    #expect(GameActivityState(game: makeGame(sabotage: sabotage), clockOffset: 0).kind == .oxygen)
    let killed = GameActivityState(game: makeGame(life: .killed, phase: meeting, sabotage: sabotage), clockOffset: 0)
    #expect(killed.kind == .killed)
    #expect(killed.countdownEnd == nil)
}

@Test func finalVoteAndExpelledAreDistinct() {
    let final = PhaseView.voting(until: at(30), isFinal: true)
    #expect(GameActivityState(game: makeGame(phase: final), clockOffset: 0).kind == .finalVote)
    #expect(GameActivityState(game: makeGame(life: .expelled), clockOffset: 0).kind == .expelled)
}

@Test func countdownIsConvertedToDeviceTimeWithTheClockOffset() {
    let phase = PhaseView.discussion(until: at(100))
    let state = GameActivityState(game: makeGame(phase: phase), clockOffset: 12)
    #expect(state.countdownEnd == at(88))
    #expect(GameActivityState.nextChange(of: makeGame(phase: phase, sabotage: sabotage), clockOffset: 12) == at(48))
}

@Test func endedShowsTheWinnerWithoutACountdown() {
    let phase = PhaseView.ended(Outcome(winner: .werewolves, reason: .parity))
    let state = GameActivityState(game: makeGame(life: .killed, phase: phase), clockOffset: 0)
    #expect(state.kind == .werewolvesWon)
    #expect(state.isEnded)
    #expect(state.countdownEnd == nil)
}

@Test func villagerAndWerewolfViewsMapToTheSameState() {
    let phase = PhaseView.voting(until: at(30), isFinal: false)
    let villager = GameActivityState(game: makeGame(role: .villager, phase: phase, sabotage: sabotage), clockOffset: 0)
    let wolf = GameActivityState(game: makeGame(role: .werewolf, phase: phase, sabotage: sabotage), clockOffset: 0)
    #expect(villager == wolf)
}
