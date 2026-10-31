import Foundation
import Observation

@MainActor @Observable
final class CloudTakeoverController {
    enum State: Equatable {
        case idle
        case working
        case done
        case failed(String)
    }

    private(set) var record: RegistryRecord?
    private(set) var registryError: String?
    private(set) var state: State = .idle

    @ObservationIgnored private let registry: any HostRegistry

    init(registry: any HostRegistry) {
        self.registry = registry
    }

    static func live() -> CloudTakeoverController {
        CloudTakeoverController(registry: HostRegistryClient.live())
    }

    func refresh() async {
        do {
            record = try await registry.fetch()
            registryError = nil
        } catch let error as RegistryError {
            registryError = error.message
        } catch {
            registryError = error.localizedDescription
        }
    }

    func takeOver(pin: String) async {
        let trimmed = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, state != .working else { return }
        state = .working
        do {
            try await registry.takeOver(pin: trimmed)
            state = .done
            await refresh()
        } catch let error as RegistryError {
            state = .failed(error.message)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
