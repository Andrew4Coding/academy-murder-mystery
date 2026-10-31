import Foundation
import Observation

@MainActor
protocol LocalHostControlling: AnyObject {
    var host: GameHost { get }
    func startListening() async
    func stopListening()
}

extension HostController: LocalHostControlling {
    func startListening() async {
        await start()
    }

    func stopListening() {
        stop()
    }
}

@MainActor @Observable
final class HostModeController {
    enum Phase: Equatable {
        case selfHost
        case switchingToCloud
        case cloud
        case switchingToSelfHost

        var isSwitching: Bool {
            self == .switchingToCloud || self == .switchingToSelfHost
        }
    }

    private(set) var phase: Phase = .selfHost
    private(set) var lastError: String?
    private(set) var registryRecord: RegistryRecord?
    private(set) var adminClient: GameClient?
    let uploader: SnapshotUploader

    @ObservationIgnored private let local: any LocalHostControlling
    @ObservationIgnored private let registry: any HostRegistry
    @ObservationIgnored private let makeAdminClient: @MainActor () -> GameClient
    @ObservationIgnored private let defaults: UserDefaults

    init(
        local: any LocalHostControlling,
        registry: any HostRegistry,
        defaults: UserDefaults = .standard,
        makeAdminClient: @escaping @MainActor () -> GameClient = {
            GameClient(transport: WebSocketClientTransport(url: CloudConfig.socketURL), store: InMemoryIdentityStore())
        }
    ) {
        self.local = local
        self.registry = registry
        self.defaults = defaults
        self.makeAdminClient = makeAdminClient
        uploader = SnapshotUploader(host: local.host, registry: registry)
    }

    var pairingSecret: String {
        get { defaults.string(forKey: CloudConfig.pairingSecretKey) ?? "" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: CloudConfig.pairingSecretKey) }
    }

    var credential: RegistryCredential? {
        Self.credential(secret: pairingSecret, pin: local.host.state.ocPin)
    }

    static func credential(secret: String, pin: String) -> RegistryCredential? {
        if !secret.isEmpty { return .secret(secret) }
        return pin.isEmpty ? nil : .pin(pin)
    }

    var isGameRunning: Bool {
        phase == .cloud ? adminClient?.view?.admin?.isLobby == false : local.host.state.engine != nil
    }

    func bootstrap() async {
        let record = try? await registry.fetch()
        registryRecord = record
        if record?.mode == .cloud {
            enterCloud()
        } else {
            await local.startListening()
            uploader.isEnabled = true
        }
    }

    func refresh() async {
        do {
            registryRecord = try await registry.fetch()
        } catch let error as RegistryError {
            lastError = error.message
        } catch {
            lastError = error.localizedDescription
        }
    }

    func switchToCloud() async {
        guard phase == .selfHost else { return }
        phase = .switchingToCloud
        lastError = nil
        uploader.isEnabled = false
        await uploader.waitUntilIdle()
        local.stopListening()
        do {
            try await registry.importState(local.host.exportSnapshot())
            enterCloud()
            await refresh()
        } catch {
            await local.startListening()
            uploader.isEnabled = true
            lastError = Self.describe(error)
            phase = .selfHost
        }
    }

    func switchToSelfHost() async {
        guard phase == .cloud else { return }
        phase = .switchingToSelfHost
        lastError = nil
        do {
            let snapshot = try await registry.exportState()
            leaveCloud()
            try local.host.importSnapshot(snapshot)
            await local.startListening()
            do {
                try await registry.setMode(.selfHost)
            } catch {
                local.stopListening()
                throw error
            }
            uploader.isEnabled = true
            phase = .selfHost
            await refresh()
        } catch {
            lastError = Self.describe(error)
            enterCloud()
        }
    }

    func send(_ command: AdminCommand) {
        adminClient?.send(.admin(command))
    }

    private func enterCloud() {
        leaveCloud()
        let client = makeAdminClient()
        adminClient = client
        client.start()
        client.signInAsOC(pin: local.host.state.ocPin, station: .admin)
        phase = .cloud
    }

    private func leaveCloud() {
        adminClient?.stop()
        adminClient = nil
    }

    private static func describe(_ error: any Error) -> String {
        if let error = error as? RegistryError { return error.message }
        if let error = error as? HostError { return error.message }
        return error.localizedDescription
    }
}
