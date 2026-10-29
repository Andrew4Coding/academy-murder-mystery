import Foundation
import Testing
@testable import MurderMystery

@MainActor
struct GameHostLobbyTests {
    @Test func setupIssuesExplainWhyAGameCannotStart() {
        var state = HostState(ocPin: "1111")
        #expect(state.setupIssues().contains("Create at least 3 families."))
        for id in 1 ... 6 {
            state.families[FamilyID(id)] = FamilyInfo(id: FamilyID(id), name: "Family \(id)", joinCode: "C\(id)")
        }
        state.werewolfCount = 3
        #expect(state.setupIssues().contains("Werewolf families must be fewer than half of all families."))
        state.werewolfCount = 0
        #expect(state.setupIssues().contains("At least one family must be werewolves."))
        state.werewolfCount = 2
        #expect(state.setupIssues().contains("Family 1 has no player."))
        let player = Player(id: UUID(), name: "Dewi", family: 1, bleToken: "AAAAAA")
        state.players[player.id] = player
        #expect(state.setupIssues().contains("Family 1 has no player."))
    }

    @Test func configureCreatesUniqueJoinCodesAndShrinksOnlyEmptyFamilies() async throws {
        let harness = try HostHarness(families: [])
        try harness.host.configure(familyCount: 8, werewolfCount: 2, settings: .standard)
        let codes = harness.host.state.families.values.map(\.joinCode)
        #expect(codes.count == 8)
        #expect(Set(codes).count == 8)
        #expect(codes.allSatisfy { $0.count == 6 })

        let client = harness.makeClient()
        try client.join(code: #require(harness.host.state.families[8]?.joinCode), name: "Dewi")
        #expect(await eventually { client.isSignedIn })
        #expect(throws: HostError.familyHasMembers) {
            try harness.host.configure(familyCount: 5, werewolfCount: 1, settings: .standard)
        }
        try harness.host.configure(familyCount: 8, werewolfCount: 1, settings: .standard)
        #expect(harness.host.state.families.count == 8)
    }

    @Test func aFamilyHoldsExactlyOnePlayerAndTheyCanRenameIt() async throws {
        let (harness, heads) = try await HostHarness.seated(families: 3)
        let familyOne = try #require(harness.host.state.families[1])
        let second = harness.makeClient()
        second.join(code: familyOne.joinCode, name: "Ayu")
        #expect(await eventually { second.lastError == HostError.familyFull.message })
        #expect(harness.host.state.players.values.filter { $0.family == 1 }.count == 1)

        heads[1]?.send(.renameFamily("Rockets"))
        #expect(await eventually { heads[1]?.view?.lobby?.familyName == "Rockets" })
    }

    @Test func everyPlayerWhoScansTheGameCodeGetsTheirOwnFamily() async throws {
        let harness = try HostHarness(families: [])
        let code = try #require(harness.host.state.gameCode)
        for index in 1 ... 4 {
            let client = harness.makeClient()
            client.join(code: code, name: "P\(index)")
            #expect(await eventually { client.isSignedIn })
        }
        #expect(harness.host.state.families.count == 4)
        #expect(harness.host.state.families.keys.allSatisfy { harness.host.state.player(of: $0) != nil })
    }

    @Test func startIsBlockedUntilEveryFamilyHasAPlayer() throws {
        let harness = try HostHarness(families: [])
        try harness.host.configure(familyCount: 3, werewolfCount: 1, settings: .standard)
        #expect(throws: HostError.setup("Family 1 has no player.")) { try harness.host.startGame() }
    }

    @Test func startAssignsRolesAndPrivatelyShowsEachFamilyItsRoleAndFiveBooths() async throws {
        let (harness, heads) = try await HostHarness.seated()
        try harness.host.startGame()
        #expect(await eventually { heads.values.allSatisfy { $0.view?.game != nil } })
        var werewolves = 0
        for client in heads.values {
            let game = try #require(client.view?.game)
            #expect(game.tasks.count == 5)
            #expect(game.tasks.allSatisfy { !$0.done })
            #expect(game.life == .alive)
            if game.role == .werewolf {
                werewolves += 1
            }
        }
        #expect(werewolves == 1)
        #expect(throws: HostError.gameAlreadyStarted) { try harness.host.startGame() }
    }

    @Test func werewolvesSeeAlliesAndVillagersNeverSeeAnyOtherRole() async throws {
        let (harness, heads) = try await HostHarness.seated(families: 7, werewolves: 3)
        try harness.host.startGame()
        #expect(await eventually { heads.values.allSatisfy { $0.view?.game != nil } })
        let wolfIDs = try Set(#require(harness.host.state.engine?.state.families.values.filter { $0.role == .werewolf }.map(\.id)))
        for (id, client) in heads {
            let game = try #require(client.view?.game)
            if wolfIDs.contains(id) {
                #expect(Set(game.allies?.map(\.id) ?? []) == wolfIDs.subtracting([id]))
            } else {
                #expect(game.allies == nil)
                let json = try String(decoding: JSONEncoder().encode(client.view), as: UTF8.self)
                #expect(!json.contains("werewolf"))
            }
            #expect(game.families.allSatisfy { $0.revealedRole == nil })
        }
    }

    @Test func expelledFamiliesAreRevealedToEveryone() async throws {
        let (harness, heads) = try await HostHarness.seated()
        try harness.host.startGame()
        let wolf = try #require(harness.host.state.engine?.state.families.values.first { $0.role == .werewolf }?.id)
        try harness.host.applyAsOC(.startMeeting)
        harness.clock.advance(by: 121)
        harness.host.tick()
        for (id, client) in heads where id != wolf {
            _ = client
            try harness.host.applyAsOC(.castVote(by: id, choice: .family(wolf)))
        }
        harness.clock.advance(by: 121)
        harness.host.tick()
        #expect(await eventually { heads.values.allSatisfy { $0.view?.game?.families.contains { $0.revealedRole == .werewolf } == true } })
    }

    @Test func killedFamiliesSeeTheirStatus() async throws {
        let (harness, heads) = try await HostHarness.seated()
        try harness.host.startGame()
        let victim = try #require(harness.host.state.engine?.state.families.values.first { $0.role == .villager }?.id)
        try harness.host.applyAsOC(.override(.forceKill(victim)))
        #expect(await eventually { heads[victim]?.view?.game?.life == .killed })
    }
}
