import Foundation
import Testing
@testable import Moonfall

@MainActor
struct CloudTakeoverControllerTests {
    @Test func takeOverActivatesTheLatestSnapshotAndRefreshesTheRegistry() async {
        let registry = FakeRegistry()
        registry.stored = HostSnapshot(state: HostState(ocPin: "4242"), selfies: [], boothMap: nil)
        let controller = CloudTakeoverController(registry: registry)
        await controller.takeOver(pin: " 4242 ")
        #expect(controller.state == .done)
        #expect(registry.takeOverPins == ["4242"])
        #expect(registry.mode == .cloud)
        #expect(controller.record?.mode == .cloud)
    }

    @Test func failuresAreReportedWithoutChangingTheRegistry() async {
        let registry = FakeRegistry()
        let controller = CloudTakeoverController(registry: registry)
        await controller.takeOver(pin: "4242")
        #expect(controller.state == .failed(RegistryError.notFound.message))
        #expect(registry.mode == .selfHost)

        registry.reachable = false
        await controller.takeOver(pin: "4242")
        if case .failed = controller.state {} else {
            Issue.record("expected failure")
        }
    }

    @Test func emptyPinsNeverReachTheNetwork() async {
        let registry = FakeRegistry()
        let controller = CloudTakeoverController(registry: registry)
        await controller.takeOver(pin: "  ")
        #expect(registry.calls.isEmpty)
        #expect(controller.state == .idle)
    }

    @Test func refreshReportsAnUnreachableRegistry() async {
        let registry = FakeRegistry()
        registry.reachable = false
        let controller = CloudTakeoverController(registry: registry)
        await controller.refresh()
        #expect(controller.registryError != nil)
        #expect(controller.record == nil)
    }
}
