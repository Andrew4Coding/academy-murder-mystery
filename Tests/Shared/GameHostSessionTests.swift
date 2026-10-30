import Foundation
import Testing
@testable import Moonfall

@MainActor
struct GameHostSessionTests {
    @Test func validFamilyCodeJoinsAndReceivesPrivateView() async throws {
        let harness = try HostHarness()
        let client = harness.makeClient()
        client.join(code: " aaa111 ", name: "Dewi")
        #expect(await eventually { client.view != nil })
        #expect(client.isSignedIn)
        guard case let .player(_, name, family)? = client.view?.identity else {
            Issue.record("Expected a player identity")
            return
        }
        #expect(name == "Dewi")
        #expect(family == 1)
        #expect(client.view?.familyName == "Family 1")
    }

    @Test func invalidCodesAndMissingNamesAreRejected() async throws {
        let harness = try HostHarness()
        let client = harness.makeClient()
        client.join(code: "NOPE00", name: "Dewi")
        #expect(await eventually { client.lastError != nil })
        #expect(client.lastError == HostError.invalidCredential.message)
        client.join(code: "AAA111", name: "  ")
        #expect(await eventually { client.lastError == HostError.nameRequired.message })
        #expect(!client.isSignedIn)
    }

    @Test func repeatedFailuresLockTheConnectionUntilTheDelayPasses() async throws {
        let harness = try HostHarness()
        let client = harness.makeClient()
        for _ in 0 ..< GameHost.maxFailures {
            client.join(code: "WRONG1", name: "Dewi")
            _ = await eventually { client.lastError == HostError.invalidCredential.message }
            client.signOut()
        }
        client.join(code: "AAA111", name: "Dewi")
        #expect(await eventually { client.lastError == HostError.tooManyAttempts.message })
        harness.clock.advance(by: GameHost.lockDuration + 1)
        client.join(code: "AAA111", name: "Dewi")
        #expect(await eventually { client.isSignedIn })
    }

    @Test func ocPinNeedsAStationAndTheRightPin() async throws {
        let harness = try HostHarness()
        let wrong = harness.makeClient()
        wrong.signInAsOC(pin: "0000", station: .townHall)
        #expect(await eventually { wrong.lastError != nil })
        #expect(!wrong.isSignedIn)

        let right = harness.makeClient()
        right.signInAsOC(pin: "4242", station: .sabotage(.oxygen))
        #expect(await eventually { right.view != nil })
        #expect(harness.host.state.ocDevices.count == 1)
        guard case let .oc(_, station)? = right.view?.identity else {
            Issue.record("Expected an OC identity")
            return
        }
        #expect(station == .sabotage(.oxygen))
    }

    @Test func fullFamiliesAndStartedGamesRejectNewMembers() async throws {
        let harness = try HostHarness()
        for index in 0 ..< 6 {
            let client = harness.makeClient()
            client.join(code: "AAA111", name: "P\(index)")
            #expect(await eventually { client.isSignedIn })
        }
        let extra = harness.makeClient()
        extra.join(code: "AAA111", name: "Late")
        #expect(await eventually { extra.lastError == HostError.familyFull.message })
    }

    @Test func unsupportedProtocolVersionsAreRejected() async throws {
        let harness = try HostHarness()
        let transport = harness.hub.makeClient()
        transport.start()
        transport.send(.hello(Hello(version: 99, credential: .familyCode("AAA111"), name: "Dewi")))
        var iterator = transport.events.makeAsyncIterator()
        var rejection: String?
        while let event = await iterator.next() {
            if case let .message(.rejected(reason)) = event {
                rejection = reason; break
            }
        }
        #expect(rejection == HostError.unsupportedVersion.message)
    }
}
