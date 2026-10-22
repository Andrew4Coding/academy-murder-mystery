import Foundation
@testable import MurderMystery

@MainActor
func eventually(timeout: TimeInterval = 2, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

@MainActor
struct HostHarness {
    let host: GameHost
    let hub: LoopbackHub
    let clock: ManualHostClock
    let repository: any GameRepository

    init(
        families: [FamilyInfo] = [
            FamilyInfo(id: 1, name: "Family 1", joinCode: "AAA111"),
            FamilyInfo(id: 2, name: "Family 2", joinCode: "BBB222")
        ],
        repository: any GameRepository = InMemoryGameRepository(),
        clock: ManualHostClock = ManualHostClock(t0)
    ) throws {
        var state = HostState(ocPin: "4242")
        for family in families {
            state.families[family.id] = family
        }
        self.clock = clock
        self.repository = repository
        hub = LoopbackHub()
        host = try GameHost(repository: repository, clock: clock, initialState: state)
        host.attach(hub.host)
    }

    func makeClient(store: any IdentityStore = InMemoryIdentityStore()) -> GameClient {
        let client = GameClient(transport: hub.makeClient(), store: store)
        client.start()
        return client
    }
}
