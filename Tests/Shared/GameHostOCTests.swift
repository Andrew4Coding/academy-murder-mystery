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

    @Test func ocViewsNeverContainRoles() async throws {
        let (harness, _) = try await startedGame()
        let ocClient = await oc(harness, station: .sabotage(.reactor))
        let json = try String(decoding: JSONEncoder().encode(ocClient.view), as: UTF8.self).lowercased()
        #expect(!json.contains("werewolf"))
        #expect(!json.contains("villager"))
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

}
