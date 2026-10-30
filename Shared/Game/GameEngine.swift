import Foundation

struct GameEngine: Codable, Equatable, Sendable {
    private(set) var state: GameState

    static func start(
        familyIDs: [FamilyID],
        werewolfCount: Int,
        settings: GameSettings = .standard,
        at now: Date,
        using generator: inout some RandomNumberGenerator
    ) throws -> (engine: GameEngine, events: [GameEvent]) {
        let ids = familyIDs.sorted()
        guard Set(ids).count == ids.count else { throw RuleError.invalidSetup("Family IDs must be unique") }
        guard werewolfCount >= 1 else { throw RuleError.invalidSetup("At least one werewolf family is required") }
        guard settings.isDebug ? werewolfCount < ids.count : werewolfCount * 2 < ids.count else {
            throw RuleError.invalidSetup("Werewolf families must be fewer than half of all families")
        }

        let werewolves = Set(ids.shuffled(using: &generator).prefix(werewolfCount))
        let roles = Dictionary(uniqueKeysWithValues: ids.map { ($0, werewolves.contains($0) ? Role.werewolf : .villager) })
        return begin(roles: roles, settings: settings, at: now, using: &generator)
    }

    /// Rehearsal start: the caller picks every family's role and the usual setup rules (family count, werewolf share) are skipped.
    /// Only `GameHost.startTestGame` calls this, and only when testing tools are on.
    static func startForTesting(
        roles: [FamilyID: Role],
        settings: GameSettings = .standard,
        at now: Date,
        using generator: inout some RandomNumberGenerator
    ) throws -> (engine: GameEngine, events: [GameEvent]) {
        guard !roles.isEmpty else { throw RuleError.invalidSetup("At least one family is required") }
        return begin(roles: roles, settings: settings, at: now, using: &generator)
    }

    private static func begin(
        roles: [FamilyID: Role],
        settings: GameSettings,
        at now: Date,
        using generator: inout some RandomNumberGenerator
    ) -> (engine: GameEngine, events: [GameEvent]) {
        var families: [FamilyID: Family] = [:]
        for id in roles.keys.sorted() {
            let tasks = Set(Booth.allCases)
            families[id] = Family(
                id: id,
                role: roles[id] ?? .villager,
                life: .alive,
                tasks: tasks,
                killReadyAt: now
            )
        }

        let state = GameState(
            settings: settings,
            startedAt: now,
            families: families,
            sabotageReadyAt: now
        )
        let werewolves = families.values.filter { $0.role == .werewolf }.map(\.id).sorted()
        return (
            GameEngine(state: state),
            [GameEvent(at: now, kind: .gameStarted(werewolves: werewolves))]
        )
    }

    mutating func advance(to now: Date) -> [GameEvent] {
        settle(upTo: now)
    }

    mutating func apply(_ command: GameCommand, at now: Date) throws -> [GameEvent] {
        var next = self
        var events = next.settle(upTo: now)
        guard next.state.outcome == nil else { throw RuleError.gameEnded }
        events += try next.perform(command, at: now)
        self = next
        return events
    }
}

private extension GameEngine {
    enum Timer {
        case sabotageExpiry
        case phaseEnd
        case finalVote
    }

    mutating func settle(upTo now: Date) -> [GameEvent] {
        var events: [GameEvent] = []
        while let (time, timer) = nextTimer(), time <= now {
            events += fire(timer, at: time)
        }
        return events
    }

    func nextTimer() -> (Date, Timer)? {
        guard state.outcome == nil else { return nil }
        var best: (Date, Timer)?
        func consider(_ time: Date, _ timer: Timer) {
            if best == nil || time < best!.0 {
                best = (time, timer)
            }
        }
        if let sabotage = state.sabotage {
            consider(sabotage.endsAt, .sabotageExpiry)
        }
        switch state.phase {
        case let .discussion(until): consider(until, .phaseEnd)
        case let .voting(until, _): consider(until, .phaseEnd)
        case .running, .ended: break
        }
        if !state.finalVoteStarted {
            consider(state.finalVoteAt, .finalVote)
        }
        return best
    }

    mutating func fire(_ timer: Timer, at time: Date) -> [GameEvent] {
        switch timer {
        case .sabotageExpiry:
            state.sabotage = nil
            return [GameEvent(at: time, kind: .sabotageExpired)] + end(.werewolves, .sabotageExpired, at: time)
        case .phaseEnd:
            switch state.phase {
            case .discussion:
                state.phase = .voting(until: time.addingTimeInterval(state.settings.votingDuration), isFinal: false)
                return [GameEvent(at: time, kind: .votingOpened(isFinal: false))]
            case .voting:
                return closeVoting(at: time)
            case .running, .ended:
                return []
            }
        case .finalVote:
            state.finalVoteStarted = true
            if case .running = state.phase {
                return openFinalVote(at: time)
            }
            state.finalVotePending = true
            return []
        }
    }

    mutating func openFinalVote(at time: Date) -> [GameEvent] {
        let dead = state.deadSinceLastMeeting
        state.deadSinceLastMeeting = []
        state.announcedDeaths = dead
        state.lastResult = nil
        state.votes = [:]
        state.phase = .voting(until: time.addingTimeInterval(state.settings.votingDuration), isFinal: true)
        return [
            GameEvent(at: time, kind: .meetingStarted(deadFamilies: dead)),
            GameEvent(at: time, kind: .votingOpened(isFinal: true))
        ]
    }

    mutating func perform(_ command: GameCommand, at now: Date) throws -> [GameEvent] {
        switch command {
        case let .kill(killer, victim): try kill(killer: killer, victim: victim, at: now)
        case let .requestSabotage(by, kind): try requestSabotage(by: by, kind: kind, at: now)
        case .resolveSabotage: try resolveSabotage(at: now)
        case .startMeeting: try startMeeting(at: now)
        case let .reportBody(by, body): try reportBody(by: by, body: body, at: now)
        case let .castVote(by, choice): try castVote(by: by, choice: choice, at: now)
        case let .proxyVote(family, choice): try proxyVote(for: family, choice: choice, at: now)
        case let .extendMeeting(seconds): try extendMeeting(by: seconds)
        case let .adjustTimer(target, seconds): try adjustTimer(target, by: seconds, at: now)
        case let .voteSkipDiscussion(by): try voteSkipDiscussion(by: by, at: now)
        case .approveSkipDiscussion: try approveSkipDiscussion(at: now)
        case let .override(override): try applyOverride(override, at: now)
        }
    }

    mutating func kill(killer killerID: FamilyID, victim victimID: FamilyID, at now: Date) throws -> [GameEvent] {
        guard case .running = state.phase else { throw RuleError.wrongPhase }
        let killer = try state.family(killerID)
        let victim = try state.family(victimID)
        guard killer.role == .werewolf else { throw RuleError.notWerewolf(killerID) }
        guard killer.isAlive else { throw RuleError.familyNotAlive(killerID) }
        guard victim.role == .villager else { throw RuleError.notVillager(victimID) }
        guard victim.isAlive else { throw RuleError.familyNotAlive(victimID) }
        guard now >= killer.killReadyAt else { throw RuleError.cooldownActive(readyAt: killer.killReadyAt) }

        state.families[victimID]?.life = .killed
        state.deadSinceLastMeeting.append(victimID)
        state.families[killerID]?.killReadyAt = now.addingTimeInterval(state.settings.isDebug ? 0 : state.settings.killCooldown)
        let killed = GameEvent(at: now, kind: .familyKilled(victimID, by: killerID))
        return state.settings.isDebug ? [killed] : [killed] + evaluateWin(at: now)
    }

    mutating func requestSabotage(by id: FamilyID, kind: SabotageKind, at now: Date) throws -> [GameEvent] {
        guard case .running = state.phase else { throw RuleError.wrongPhase }
        let family = try state.family(id)
        guard family.role == .werewolf else { throw RuleError.notWerewolf(id) }
        guard state.sabotage == nil else { throw RuleError.sabotageAlreadyActive }
        guard now >= state.sabotageReadyAt else { throw RuleError.cooldownActive(readyAt: state.sabotageReadyAt) }

        let endsAt = now.addingTimeInterval(state.settings.sabotageDuration(for: kind))
        state.sabotage = ActiveSabotage(kind: kind, startedAt: now, endsAt: endsAt, triggeredBy: id)
        state.sabotageReadyAt = endsAt.addingTimeInterval(state.settings.sabotageCooldown(for: kind))
        return [GameEvent(at: now, kind: .sabotageStarted(kind: kind, by: id, endsAt: endsAt))]
    }

    mutating func resolveSabotage(at now: Date) throws -> [GameEvent] {
        guard let sabotage = state.sabotage else { throw RuleError.noActiveSabotage }
        state.sabotage = nil
        state.sabotageReadyAt = now.addingTimeInterval(state.settings.sabotageCooldown(for: sabotage.kind))
        return [GameEvent(at: now, kind: .sabotageResolved)]
    }

    mutating func reportBody(by id: FamilyID, body: FamilyID, at now: Date) throws -> [GameEvent] {
        guard case .running = state.phase else { throw RuleError.wrongPhase }
        guard state.sabotage == nil else { throw RuleError.sabotageActive }
        guard try state.family(id).isAlive else { throw RuleError.familyNotAlive(id) }
        guard state.deadSinceLastMeeting.contains(body), try state.family(body).life == .killed else {
            throw RuleError.notDead(body)
        }
        return try startMeeting(at: now)
    }

    mutating func startMeeting(at now: Date) throws -> [GameEvent] {
        guard case .running = state.phase else { throw RuleError.wrongPhase }
        guard state.sabotage == nil else { throw RuleError.sabotageActive }
        let dead = state.deadSinceLastMeeting
        state.deadSinceLastMeeting = []
        state.announcedDeaths = dead
        state.lastResult = nil
        state.votes = [:]
        state.skipVotes = []
        state.phase = .discussion(until: now.addingTimeInterval(state.settings.discussionDuration))
        return [GameEvent(at: now, kind: .meetingStarted(deadFamilies: dead))]
    }

    mutating func extendMeeting(by seconds: TimeInterval) throws -> [GameEvent] {
        guard seconds > 0 else { throw RuleError.wrongPhase }
        switch state.phase {
        case let .discussion(until):
            state.phase = .discussion(until: until.addingTimeInterval(seconds))
        case let .voting(until, isFinal):
            state.phase = .voting(until: until.addingTimeInterval(seconds), isFinal: isFinal)
        case .running, .ended:
            throw RuleError.wrongPhase
        }
        return []
    }

    mutating func adjustTimer(_ target: TimerTarget, by seconds: TimeInterval, at now: Date) throws -> [GameEvent] {
        let floor = now.addingTimeInterval(1)
        func moved(_ end: Date) -> Date {
            max(end.addingTimeInterval(seconds), floor)
        }
        switch target {
        case .meeting:
            switch state.phase {
            case let .discussion(until):
                state.phase = .discussion(until: moved(until))
            case let .voting(until, isFinal):
                state.phase = .voting(until: moved(until), isFinal: isFinal)
            case .running, .ended:
                throw RuleError.wrongPhase
            }
        case .finalVote:
            guard !state.finalVoteStarted else { throw RuleError.timerFinished }
            state.finalVoteOverride = moved(state.finalVoteAt)
        case .sabotage:
            guard var sabotage = state.sabotage else { throw RuleError.noActiveSabotage }
            sabotage.endsAt = moved(sabotage.endsAt)
            state.sabotage = sabotage
        }
        return [GameEvent(at: now, kind: .ocOverride(.timerAdjusted(target, seconds: seconds)))]
    }

    mutating func voteSkipDiscussion(by id: FamilyID, at now: Date) throws -> [GameEvent] {
        guard case .discussion = state.phase else { throw RuleError.wrongPhase }
        guard try state.family(id).isAlive else { throw RuleError.familyNotAlive(id) }
        if state.skipVotes.contains(id) {
            state.skipVotes.remove(id)
        } else {
            state.skipVotes.insert(id)
        }
        guard state.skipRequested else { return [] }
        return skipDiscussion(at: now)
    }

    mutating func skipDiscussion(at now: Date) -> [GameEvent] {
        state.skipVotes = []
        state.phase = .voting(until: now.addingTimeInterval(state.settings.votingDuration), isFinal: false)
        return [GameEvent(at: now, kind: .votingOpened(isFinal: false))]
    }

    mutating func approveSkipDiscussion(at now: Date) throws -> [GameEvent] {
        guard case .discussion = state.phase else { throw RuleError.wrongPhase }
        guard state.skipRequested else { throw RuleError.skipNotRequested }
        return skipDiscussion(at: now)
    }

    mutating func castVote(by id: FamilyID, choice: VoteChoice, at now: Date) throws -> [GameEvent] {
        guard case .voting = state.phase else { throw RuleError.wrongPhase }
        let voter = try state.family(id)
        guard voter.isAlive else { throw RuleError.familyNotAlive(id) }
        if case let .family(target) = choice {
            guard try state.family(target).isAlive else { throw RuleError.invalidVoteTarget }
        }
        state.votes[id] = choice
        var events = [GameEvent(at: now, kind: .voteCast(by: id))]
        events += closeVotingIfComplete(at: now)
        return events
    }

    mutating func proxyVote(for id: FamilyID, choice: VoteChoice, at now: Date) throws -> [GameEvent] {
        guard case .voting = state.phase else { throw RuleError.wrongPhase }
        var events = [GameEvent(at: now, kind: .ocOverride(.proxyVote(id)))]
        events += try castVote(by: id, choice: choice, at: now)
        return events
    }

    mutating func applyOverride(_ override: OCOverride, at now: Date) throws -> [GameEvent] {
        var events = [GameEvent(at: now, kind: .ocOverride(override))]
        switch override {
        case let .forceKill(id):
            guard try state.family(id).isAlive else { throw RuleError.familyNotAlive(id) }
            state.families[id]?.life = .killed
            state.deadSinceLastMeeting.append(id)
            state.votes[id] = nil
            events.append(GameEvent(at: now, kind: .familyKilled(id, by: nil)))
            events += evaluateWin(at: now)
            if state.outcome == nil {
                events += closeVotingIfComplete(at: now)
            }
        case let .revive(id):
            guard try !(state.family(id).isAlive) else { throw RuleError.notDead(id) }
            state.families[id]?.life = .alive
            state.deadSinceLastMeeting.removeAll { $0 == id }
            events += evaluateWin(at: now)
        case let .endGame(side):
            events += end(side, .ocEnded, at: now)
        case .proxyVote, .timerAdjusted:
            throw RuleError.wrongPhase
        }
        return events
    }

    mutating func closeVotingIfComplete(at now: Date) -> [GameEvent] {
        guard case .voting = state.phase, state.votes.count >= state.aliveFamilies().count else { return [] }
        return closeVoting(at: now)
    }

    mutating func closeVoting(at time: Date) -> [GameEvent] {
        guard case let .voting(_, isFinal) = state.phase else { return [] }
        let votes = state.votes
        state.votes = [:]
        let tally = Self.tally(votes)
        if isFinal {
            return closeFinalVote(votes: votes, tally: tally, at: time)
        }

        var expelled: [Reveal] = []
        if let leader = Self.uniqueLeader(in: tally), case let .family(id) = leader {
            state.families[id]?.life = .expelled
            expelled.append(Reveal(family: id, role: state.families[id]?.role ?? .villager))
        }
        state.phase = .running
        state.lastResult = VoteResult(tally: tally, expelled: expelled, isFinal: false, at: time)
        var events = [GameEvent(at: time, kind: .voteClosed(tally: tally, expelled: expelled, isFinal: false))]
        events += evaluateWin(at: time)
        if state.outcome == nil, state.finalVotePending {
            state.finalVotePending = false
            events += openFinalVote(at: time)
        }
        return events
    }

    mutating func closeFinalVote(votes: [FamilyID: VoteChoice], tally: [VoteCount], at time: Date) -> [GameEvent] {
        let living = state.aliveFamilies()
        let werewolves = Set(living.filter { $0.role == .werewolf }.map(\.id))
        var counts: [FamilyID: Int] = [:]
        for choice in votes.values {
            if case let .family(id) = choice {
                counts[id, default: 0] += 1
            }
        }
        let ranked = living.map(\.id).sorted { lhs, rhs in
            let (a, b) = (counts[lhs, default: 0], counts[rhs, default: 0])
            return a != b ? a > b : lhs < rhs
        }

        let cutoff = werewolves.count
        let cleanCut: Bool
        if cutoff >= ranked.count {
            cleanCut = true
        } else {
            let last = counts[ranked[cutoff - 1], default: 0]
            cleanCut = last > 0 && last > counts[ranked[cutoff], default: 0]
        }

        var expelled: [Reveal] = []
        if cleanCut {
            for id in ranked.prefix(cutoff) {
                state.families[id]?.life = .expelled
                expelled.append(Reveal(family: id, role: state.families[id]?.role ?? .villager))
            }
        }
        let caught = cleanCut && Set(ranked.prefix(cutoff)) == werewolves
        state.lastResult = VoteResult(tally: tally, expelled: expelled, isFinal: true, at: time)
        var events = [GameEvent(at: time, kind: .voteClosed(tally: tally, expelled: expelled, isFinal: true))]
        events += end(
            caught ? .villagers : .werewolves,
            caught ? .finalVoteSucceeded : .finalVoteFailed,
            at: time
        )
        return events
    }

    static func tally(_ votes: [FamilyID: VoteChoice]) -> [VoteCount] {
        var counts: [VoteChoice: Int] = [:]
        for choice in votes.values {
            counts[choice, default: 0] += 1
        }
        let families = counts.keys.compactMap { choice -> FamilyID? in
            if case let .family(id) = choice {
                id
            } else {
                nil
            }
        }.sorted()
        var result = families.map { VoteCount(choice: .family($0), count: counts[.family($0)] ?? 0) }
        if let skips = counts[.skip] {
            result.append(VoteCount(choice: .skip, count: skips))
        }
        return result
    }

    static func uniqueLeader(in tally: [VoteCount]) -> VoteChoice? {
        guard let top = tally.map(\.count).max() else { return nil }
        let leaders = tally.filter { $0.count == top }
        return leaders.count == 1 ? leaders[0].choice : nil
    }

    mutating func evaluateWin(at now: Date) -> [GameEvent] {
        let aliveWerewolves = state.aliveFamilies(role: .werewolf).count
        let aliveVillagers = state.aliveFamilies(role: .villager).count
        if aliveWerewolves == 0 {
            return end(.villagers, .allWerewolvesRemoved, at: now)
        }
        if !state.settings.isDebug, aliveVillagers <= aliveWerewolves {
            return end(.werewolves, .parity, at: now)
        }
        return []
    }

    mutating func end(_ winner: Side, _ reason: Outcome.Reason, at now: Date) -> [GameEvent] {
        let outcome = Outcome(winner: winner, reason: reason)
        state.phase = .ended(outcome)
        state.sabotage = nil
        state.votes = [:]
        return [GameEvent(at: now, kind: .gameEnded(outcome))]
    }
}
