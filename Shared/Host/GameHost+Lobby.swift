import Foundation

extension HostState {
    /// `testing` relaxes the rules for rehearsals: one family is enough, and families may be empty or have no head.
    func setupIssues(testing: Bool = false) -> [String] {
        var issues: [String] = []
        if testing {
            if families.isEmpty {
                issues.append("Create at least 1 family.")
            }
            return issues
        }
        if families.count < 3 {
            issues.append("Create at least 3 families.")
        }
        if werewolfCount < 1 {
            issues.append("At least one family must be werewolves.")
        }
        if werewolfCount * 2 >= families.count, !families.isEmpty {
            issues.append("Werewolf families must be fewer than half of all families.")
        }
        if !(1 ... Booth.allCases.count).contains(settings.tasksPerFamily) {
            issues.append("Tasks per family must be between 1 and \(Booth.allCases.count).")
        }
        for family in families.values.sorted(by: { $0.id < $1.id }) where family.head == nil {
            issues.append(members(of: family.id).isEmpty ? "\(family.name) has no members." : "\(family.name) has no head of family.")
        }
        return issues
    }
}

extension GameHost {
    static let maxFamilies = 40
    static let joinCodeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    func configure(familyCount: Int, werewolfCount: Int, settings: GameSettings) throws {
        guard state.isLobby else { throw HostError.gameAlreadyStarted }
        let current = state.families.keys.sorted()
        if familyCount < current.count {
            for id in current.suffix(current.count - familyCount) {
                guard state.members(of: id).isEmpty else { throw HostError.familyHasMembers }
            }
        }
        replaceState { state in
            if familyCount < current.count {
                for id in current.suffix(current.count - familyCount) {
                    state.families[id] = nil
                }
            } else if familyCount > current.count {
                let used = Set(state.families.values.map(\.joinCode))
                var codes = used
                for number in (current.count + 1) ... familyCount {
                    let code = Self.makeJoinCode(excluding: codes)
                    codes.insert(code)
                    state.families[FamilyID(number)] = FamilyInfo(id: FamilyID(number), name: "Family \(number)", joinCode: code)
                }
            }
            state.werewolfCount = werewolfCount
            state.settings = settings
        }
    }

    func updateSettings(werewolfCount: Int, settings: GameSettings) throws {
        guard state.isLobby else { throw HostError.gameAlreadyStarted }
        replaceState { state in
            state.werewolfCount = werewolfCount
            state.settings = settings
        }
    }

    func setFamilyCapacity(_ capacity: Int) throws {
        guard state.isLobby else { throw HostError.gameAlreadyStarted }
        replaceState { $0.maxFamilySize = max(1, capacity) }
    }

    func startGame() throws {
        var generator = SystemRandomNumberGenerator()
        try startGame(using: &generator)
    }

    func startGame(using generator: inout some RandomNumberGenerator) throws {
        guard state.isLobby else { throw HostError.gameAlreadyStarted }
        if let issue = state.setupIssues().first {
            throw HostError.setup(issue)
        }
        let (engine, events) = try GameEngine.start(
            familyIDs: state.families.keys.sorted(),
            werewolfCount: state.werewolfCount,
            settings: state.settings,
            at: clock.now,
            using: &generator
        )
        state.engine = engine
        commit(events: events)
    }

    /// Rehearsal start with chosen roles. Families without members stay in the game as stand-ins, and a family with
    /// members but no head gets its first member as head. Marked simulated, so a restart never restores it as the real game.
    func startTestGame(roles: [FamilyID: Role]) throws {
        var generator = SystemRandomNumberGenerator()
        try startTestGame(roles: roles, using: &generator)
    }

    func startTestGame(roles: [FamilyID: Role], using generator: inout some RandomNumberGenerator) throws {
        guard testingToolsEnabled else {
            throw HostError.setup("Testing tools are off. Run the MurderMysteryAdmin-Testing scheme.")
        }
        guard state.isLobby else { throw HostError.gameAlreadyStarted }
        if let issue = state.setupIssues(testing: true).first {
            throw HostError.setup(issue)
        }
        var chosen: [FamilyID: Role] = [:]
        for id in state.families.keys {
            chosen[id] = roles[id] ?? .villager
            if state.families[id]?.head == nil, let first = state.members(of: id).first {
                state.families[id]?.head = first.id
            }
        }
        let (engine, events) = try GameEngine.startForTesting(roles: chosen, settings: state.settings, at: clock.now, using: &generator)
        state.engine = engine
        state.simulated = true
        commit(events: events)
    }

    func newGame() throws {
        var fresh = HostState(ocPin: Self.makePIN())
        fresh.gameCode = Self.makeJoinCode(excluding: [])
        fresh.settings = state.settings
        fresh.werewolfCount = state.werewolfCount
        fresh.maxFamilySize = state.maxFamilySize
        fresh.rssiThreshold = state.rssiThreshold
        fresh.sightingFreshness = state.sightingFreshness
        let count = state.families.count
        gameID = UUID()
        state = fresh
        selfies = [:]
        for id in sessions.keys {
            sessions[id]?.identity = nil
            send(.reset, to: id)
        }
        if count > 0, testingToolsEnabled {
            try configure(familyCount: count, werewolfCount: fresh.werewolfCount, settings: fresh.settings)
        } else {
            commit()
        }
    }

    func leave(identity: Identity, clientID: ClientID) throws {
        guard case let .player(playerID) = identity, let player = state.players[playerID] else { throw HostError.notAPlayer }
        guard state.isLobby else { throw HostError.gameAlreadyStarted }
        state.players[playerID] = nil
        if state.families[player.family]?.head == playerID {
            state.families[player.family]?.head = state.members(of: player.family).first?.id
        }
        sessions[clientID]?.identity = nil
        send(.reset, to: clientID)
        commit()
    }

    func sync(clientID: ClientID) throws {
        tick()
        let identity = try signedIn(clientID)
        if let view = view(for: identity) {
            send(.state(view), to: clientID)
        }
    }

    func assignFamily() throws -> FamilyID {
        let open = state.families.keys.sorted().first { state.members(of: $0).count < state.maxFamilySize }
        if let open {
            return open
        }
        guard state.families.count < Self.maxFamilies else { throw HostError.familyFull }
        let number = (state.families.keys.map(\.rawValue).max() ?? 0) + 1
        let used = Set(state.families.values.map(\.joinCode))
        let id = FamilyID(number)
        state.families[id] = FamilyInfo(id: id, name: "Family \(number)", joinCode: Self.makeJoinCode(excluding: used))
        return id
    }

    func renameFamily(identity: Identity, to name: String) throws {
        guard case let .player(playerID) = identity, let player = state.players[playerID] else { throw HostError.notAPlayer }
        guard state.families[player.family]?.head == playerID else { throw HostError.notHead }
        try renameFamily(player.family, to: name)
    }

    func renameFamily(_ family: FamilyID, to name: String) throws {
        guard state.isLobby else { throw HostError.gameAlreadyStarted }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1 ... 24).contains(trimmed.count), state.families[family] != nil else { throw HostError.invalidName }
        state.families[family]?.name = trimmed
        commit()
    }

    static let maxSelfieBytes = 150_000

    func storeSelfie(_ data: Data, identity: Identity) throws {
        guard case let .player(playerID) = identity, state.players[playerID] != nil else { throw HostError.notAPlayer }
        guard state.isLobby else { throw HostError.gameAlreadyStarted }
        guard data.count <= Self.maxSelfieBytes else { throw HostError.photoTooLarge }
        selfies[playerID] = data
        let update = ServerMessage.selfies(selfieList)
        for (clientID, session) in sessions where session.identity != nil {
            send(update, to: clientID)
        }
    }

    func voteSkipDiscussion(identity: Identity) throws {
        guard case let .player(playerID) = identity, let player = state.players[playerID] else { throw HostError.notAPlayer }
        guard state.families[player.family]?.head == playerID else { throw HostError.notHead }
        try applyAsOC(.voteSkipDiscussion(by: player.family))
    }

    func extendMeeting(seconds: TimeInterval) throws {
        try applyAsOC(.extendMeeting(seconds: seconds))
    }

    func approveSkipDiscussion() throws {
        try applyAsOC(.approveSkipDiscussion)
    }

    func vote(identity: Identity, choice: VoteChoice) throws {
        guard case let .player(playerID) = identity, let player = state.players[playerID] else { throw HostError.notAPlayer }
        guard state.families[player.family]?.head == playerID else { throw HostError.notHead }
        try applyAsOC(.castVote(by: player.family, choice: choice))
    }

    func applyAsOC(_ command: GameCommand) throws {
        guard var engine = state.engine else { throw RuleError.wrongPhase }
        let events = try engine.apply(command, at: clock.now)
        state.engine = engine
        commit(events: events)
    }

    static func makeJoinCode(excluding used: Set<String>) -> String {
        while true {
            let code = String((0 ..< 6).map { _ in joinCodeAlphabet.randomElement()! })
            if !used.contains(code) {
                return code
            }
        }
    }
}
