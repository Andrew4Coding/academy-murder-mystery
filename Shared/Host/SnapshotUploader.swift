import Foundation
import Observation

@MainActor @Observable
final class SnapshotUploader {
    enum Status: Equatable {
        case idle
        case uploading
        case uploaded(Date)
        case failed(String)
    }

    private(set) var status: Status = .idle
    var isEnabled = false {
        didSet {
            if isEnabled, !oldValue {
                resume()
            }
        }
    }

    @ObservationIgnored private var isPaused = false
    @ObservationIgnored private let host: GameHost
    @ObservationIgnored private let registry: any HostRegistry
    @ObservationIgnored private var dirty = false
    @ObservationIgnored private var running: Task<Void, Never>?

    init(host: GameHost, registry: any HostRegistry) {
        self.host = host
        self.registry = registry
        host.onCommit = { [weak self] in self?.schedule() }
    }

    var lastUploadedAt: Date? {
        if case let .uploaded(date) = status {
            date
        } else {
            nil
        }
    }

    func resume() {
        isPaused = false
        schedule()
    }

    func schedule() {
        guard isEnabled, !isPaused, !host.state.simulated else { return }
        dirty = true
        guard running == nil else { return }
        running = Task { [weak self] in
            await self?.drain()
        }
    }

    func waitUntilIdle() async {
        await running?.value
    }

    private func drain() async {
        while dirty, isEnabled {
            dirty = false
            status = .uploading
            do {
                try await registry.putSnapshot(host.exportSnapshot())
                status = .uploaded(Date())
            } catch let error as RegistryError {
                status = .failed(error.message)
                if error == .unauthorized || error == .locked {
                    isPaused = true
                }
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
        running = nil
    }
}
