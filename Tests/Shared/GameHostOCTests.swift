import Foundation
import Testing
@testable import Moonfall

@MainActor
struct GameHostOCTests {
    private func startedGame() async throws -> (HostHarness, [FamilyID: GameClient]) {
        let (harness, heads) = try await HostHarness.seated(families: 5, werewolves: 1)
        try harness.host.startGame()
        _ = await eventually { heads.values.allSatisfy { $0.view?.game != nil } }
        return (harness, heads)
    }

    private func oc(_ harness: HostHarness, station: OCStation) async -> GameClient {
        let client = harness.makeClient()
        client.signInAsOC(pin: "4242", station: station)
        _ = await eventually { client.view?.oc != nil }
        return client
    }

    private func onListBooth(_ harness: HostHarness, family: FamilyID) -> Booth {
        harness.host.state.engine!.state.families[family]!.tasks.sorted { $0.rawValue < $1.rawValue }[0]
    }

    private func offListBooth(_ harness: HostHarness, family: FamilyID) -> Booth {
        let tasks = harness.host.state.engine!.state.families[family]!.tasks
        return Booth.allCases.first { !tasks.contains($0) }!
    }

    @Test func wrongPinsAreRejectedAndLockedOut() async throws {
        let (harness, _) = try await startedGame()
        let client = harness.makeClient()
        for _ in 0 ..< GameHost.maxFailures {
            client.signInAsOC(pin: "0000", station: .townHall)
            _ = await eventually { client.lastError == HostError.invalidCredential.message }
            client.signOut()
        }
        client.signInAsOC(pin: "4242", station: .townHall)
        #expect(await eventually { client.lastError == HostError.tooManyAttempts.message })
    }

    @Test func aBoothOCStampsAFamilyAndTheFamilySeesProgress() async throws {
        let (harness, heads) = try await startedGame()
        let booth = onListBooth(harness, family: 1)
        let ocClient = await oc(harness, station: .booth(booth))
        ocClient.send(.stamp(family: 1, confirmOffList: false))
        #expect(await eventually { heads[1]!.view?.game?.tasks.first { $0.booth == booth }?.done == true })
        #expect(ocClient.view?.oc?.families.first { $0.id == 1 }?.stamped == true)
        #expect(ocClient.view?.oc?.families.first { $0.id == 1 }?.stampsDone == 1)
    }

    @Test func werewolfAndVillagerFamiliesLookTheSameToAnOC() async throws {
        let (harness, _) = try await startedGame()
        let ocClient = await oc(harness, station: .booth(.painting))
        let json = try String(decoding: JSONEncoder().encode(ocClient.view), as: UTF8.self).lowercased()
        #expect(!json.contains("werewolf"))
        #expect(!json.contains("villager"))
        let wolf = harness.host.state.engine!.state.families.values.first { $0.role == .werewolf }!.id
        let booth = onListBooth(harness, family: wolf)
        let wolfOC = await oc(harness, station: .booth(booth))
        wolfOC.send(.stamp(family: wolf, confirmOffList: false))
        #expect(await eventually { wolfOC.view?.oc?.families.first { $0.id == wolf }?.stamped == true })
        #expect(harness.host.state.engine?.state.outcome == nil)
    }

    @Test func stampingTwiceIsReportedAsAlreadyStamped() async throws {
        let (harness, _) = try await startedGame()
        let booth = onListBooth(harness, family: 1)
        let ocClient = await oc(harness, station: .booth(booth))
        ocClient.send(.stamp(family: 1, confirmOffList: false))
        #expect(await eventually { ocClient.view?.oc?.families.first { $0.id == 1 }?.stamped == true })
        ocClient.send(.stamp(family: 1, confirmOffList: false))
        #expect(await eventually { ocClient.lastError == RuleError.alreadyStamped.message })
    }

    @Test func aBoothNotOnTheFamilysListNeedsConfirmation() async throws {
        let (harness, _) = try await startedGame()
        let booth = offListBooth(harness, family: 1)
        let ocClient = await oc(harness, station: .booth(booth))
        #expect(ocClient.view?.oc?.families.first { $0.id == 1 }?.onList == false)
        ocClient.send(.stamp(family: 1, confirmOffList: false))
        #expect(await eventually { ocClient.lastError == HostError.offList.message })
        ocClient.send(.stamp(family: 1, confirmOffList: true))
        #expect(await eventually { ocClient.view?.oc?.families.first { $0.id == 1 }?.stamped == true })
        #expect(ocClient.view?.oc?.families.first { $0.id == 1 }?.stampsDone == 0)
    }

    @Test func undoWorksWithinSixtySecondsAndOnlyForTheOwnBooth() async throws {
        let (harness, _) = try await startedGame()
        let booth = onListBooth(harness, family: 1)
        let ocClient = await oc(harness, station: .booth(booth))
        ocClient.send(.stamp(family: 1, confirmOffList: false))
        #expect(await eventually { ocClient.view?.oc?.families.first { $0.id == 1 }?.stamped == true })
        ocClient.send(.undoStamp(family: 1))
        #expect(await eventually { ocClient.view?.oc?.families.first { $0.id == 1 }?.stamped == false })

        ocClient.send(.stamp(family: 1, confirmOffList: false))
        #expect(await eventually { ocClient.view?.oc?.families.first { $0.id == 1 }?.stamped == true })
        harness.clock.advance(by: GameHost.undoWindow + 1)
        ocClient.send(.undoStamp(family: 1))
        #expect(await eventually { ocClient.lastError == HostError.undoExpired.message })

        let other = await oc(harness, station: .booth(offListBooth(harness, family: 1)))
        other.send(.undoStamp(family: 1))
        #expect(await eventually { other.lastError == HostError.undoExpired.message })
    }

    @Test func nonBoothStationsAndPlayersCannotStamp() async throws {
        let (harness, heads) = try await startedGame()
        let townHall = await oc(harness, station: .townHall)
        townHall.send(.stamp(family: 1, confirmOffList: false))
        #expect(await eventually { townHall.lastError == HostError.wrongStation.message })
        heads[1]!.send(.stamp(family: 1, confirmOffList: false))
        #expect(await eventually { heads[1]!.lastError == HostError.notOC.message })
    }

    @Test func theMacRecordsAndRemovesStampsWithTheSameRules() async throws {
        let (harness, heads) = try await startedGame()
        let booth = offListBooth(harness, family: 1)
        #expect(throws: HostError.offList) { try harness.host.recordStamp(family: 1, booth: booth, confirmOffList: false) }
        let listed = onListBooth(harness, family: 1)
        try harness.host.recordStamp(family: 1, booth: listed, confirmOffList: false)
        #expect(await eventually { heads[1]!.view?.game?.tasks.first { $0.booth == listed }?.done == true })
        try harness.host.removeStamp(family: 1, booth: listed)
        #expect(await eventually { heads[1]!.view?.game?.tasks.first { $0.booth == listed }?.done == false })
    }
}
