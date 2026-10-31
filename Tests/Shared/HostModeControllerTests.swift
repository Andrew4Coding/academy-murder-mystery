import Foundation
import Testing
@testable import Moonfall

@MainActor
final class FakeLocalHost: LocalHostControlling {
    let host: GameHost
    private(set) var listening = false
    private(set) var starts = 0

    init(host: GameHost) {
        self.host = host
    }

    func startListening() async {
        listening = true
        starts += 1
    }

    func stopListening() {
        listening = false
    }
}

@MainActor
struct HostModeControllerTests {
    private struct Rig {
        let local: FakeLocalHost
        let registry: FakeRegistry
        let cloudHost: GameHost
        let hub: LoopbackHub
        let controller: HostModeController
    }

    private func makeRig(families: Int = 2) throws -> Rig {
        var state = HostState(ocPin: "4242")
        for index in 1 ... families {
            state.families[FamilyID(index)] = FamilyInfo(id: FamilyID(index), name: "Family \(index)", joinCode: "F\(index)")
        }
        let macHost = try GameHost(repository: InMemoryGameRepository(), initialState: state)
        let local = FakeLocalHost(host: macHost)
        let registry = FakeRegistry()
        let cloudHost = try GameHost(repository: InMemoryGameRepository())
        let hub = LoopbackHub()
        cloudHost.attach(hub.host)
        registry.onImport = { try? cloudHost.importSnapshot($0) }
        let defaults = UserDefaults(suiteName: "mode-\(UUID().uuidString)")!
        let controller = HostModeController(local: local, registry: registry, defaults: defaults) {
            GameClient(transport: hub.makeClient(), store: InMemoryIdentityStore())
        }
        return Rig(local: local, registry: registry, cloudHost: cloudHost, hub: hub, controller: controller)
    }

    @Test func switchingToCloudMovesStateAndStopsTheLocalListener() async throws {
        let rig = try makeRig()
        await rig.local.startListening()
        rig.local.host.state.families[1]?.name = "Renamed"
        await rig.controller.switchToCloud()

        #expect(rig.controller.phase == .cloud)
        #expect(!rig.local.listening)
        #expect(rig.registry.mode == .cloud)
        #expect(rig.registry.live?.state == rig.local.host.state)
        #expect(rig.cloudHost.state.families[1]?.name == "Renamed")
        #expect(rig.controller.adminClient != nil)
    }

    @Test func aFailedImportRestoresTheLocalHost() async throws {
        let rig = try makeRig()
        await rig.local.startListening()
        rig.registry.failImport = true
        await rig.controller.switchToCloud()

        #expect(rig.controller.phase == .selfHost)
        #expect(rig.local.listening)
        #expect(rig.controller.lastError != nil)
        #expect(rig.registry.mode == .selfHost)
        #expect(rig.controller.adminClient == nil)
    }

    @Test func switchingBackBringsTheCloudStateHomeAndFlipsTheRegistry() async throws {
        let rig = try makeRig()
        await rig.local.startListening()
        await rig.controller.switchToCloud()
        var moved = rig.cloudHost.exportSnapshot()
        moved.state.families[2]?.name = "Played in cloud"
        rig.registry.live = moved

        await rig.controller.switchToSelfHost()
        #expect(rig.controller.phase == .selfHost)
        #expect(rig.local.listening)
        #expect(rig.local.host.state.families[2]?.name == "Played in cloud")
        #expect(rig.registry.mode == .selfHost)
        #expect(rig.controller.adminClient == nil)
        #expect(rig.registry.calls.last?.hasPrefix("fetch") == true)
        #expect(rig.registry.calls.contains("setMode:local"))
    }

    @Test func aFailedExportKeepsTheCloudActive() async throws {
        let rig = try makeRig()
        await rig.controller.switchToCloud()
        rig.registry.live = nil
        await rig.controller.switchToSelfHost()
        #expect(rig.controller.phase == .cloud)
        #expect(!rig.local.listening)
        #expect(rig.controller.lastError != nil)
        #expect(rig.controller.adminClient != nil)
    }

    @Test func aFailedRegistryFlipStopsTheLocalListenerAgain() async throws {
        let rig = try makeRig()
        await rig.controller.switchToCloud()
        rig.registry.failSetMode = true
        await rig.controller.switchToSelfHost()
        #expect(rig.controller.phase == .cloud)
        #expect(!rig.local.listening)
    }

    @Test func switchesAreIgnoredInTheWrongPhase() async throws {
        let rig = try makeRig()
        await rig.controller.switchToSelfHost()
        #expect(rig.controller.phase == .selfHost)
        #expect(rig.registry.calls.isEmpty)
    }

    @Test func bootstrapFollowsTheRegistry() async throws {
        let cloud = try makeRig()
        cloud.registry.mode = .cloud
        await cloud.controller.bootstrap()
        #expect(cloud.controller.phase == .cloud)
        #expect(!cloud.local.listening)

        let local = try makeRig()
        await local.controller.bootstrap()
        #expect(local.controller.phase == .selfHost)
        #expect(local.local.listening)

        let offline = try makeRig()
        offline.registry.mode = .cloud
        offline.registry.reachable = false
        await offline.controller.bootstrap()
        #expect(offline.controller.phase == .selfHost)
        #expect(offline.local.listening)
    }

    @Test func cloudModeSignsInAsAdminAndSendsAdminCommands() async throws {
        let rig = try makeRig()
        await rig.controller.switchToCloud()
        let client = try #require(rig.controller.adminClient)
        #expect(await eventually { client.view?.admin != nil })
        rig.controller.send(.ringBell)
        #expect(await eventually { rig.cloudHost.bellRings == 1 })
        rig.controller.send(.regenerateOCPIN)
        #expect(await eventually { rig.cloudHost.state.ocPin != "4242" })
    }

    @Test func credentialPrefersThePairingSecretThenThePin() throws {
        #expect(HostModeController.credential(secret: "s", pin: "1") == .secret("s"))
        #expect(HostModeController.credential(secret: "", pin: "1") == .pin("1"))
        #expect(HostModeController.credential(secret: "", pin: "") == nil)
        let rig = try makeRig()
        #expect(rig.controller.credential == .pin("4242"))
        rig.controller.pairingSecret = "  abc  "
        #expect(rig.controller.credential == .secret("abc"))
    }
}
