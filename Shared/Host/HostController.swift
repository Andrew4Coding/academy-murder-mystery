import Foundation
import Observation

@MainActor @Observable
final class HostController {
    enum Status: Equatable {
        case stopped
        case starting
        case running(port: UInt16?)
        case failed(String)
    }

    let host: GameHost
    private(set) var status: Status = .stopped

    @ObservationIgnored private var transport: (any HostTransport)?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(host: GameHost) {
        self.host = host
    }

    func start(using transport: any HostTransport = NetworkHostTransport()) async {
        guard status == .stopped || isFailed else { return }
        status = .starting
        host.attach(transport)
        do {
            try await transport.start()
            self.transport = transport
            status = .running(port: (transport as? NetworkHostTransport)?.port)
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(500))
                    self?.host.tick()
                }
            }
        } catch {
            host.detach()
            status = .failed(error.localizedDescription)
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        host.detach()
        transport = nil
        status = .stopped
    }

    private var isFailed: Bool {
        if case .failed = status {
            true
        } else {
            false
        }
    }
}
