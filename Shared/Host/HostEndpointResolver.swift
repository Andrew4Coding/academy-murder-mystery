import Foundation

@MainActor
struct HostEndpointResolver {
    let registry: any HostRegistry
    let defaults: UserDefaults

    init(registry: any HostRegistry, defaults: UserDefaults = .standard) {
        self.registry = registry
        self.defaults = defaults
    }

    var lastKnown: HostMode? {
        defaults.string(forKey: CloudConfig.lastModeKey).flatMap(HostMode.init(rawValue:))
    }

    func resolve() async -> HostMode {
        do {
            let record = try await registry.fetch()
            defaults.set(record.mode.rawValue, forKey: CloudConfig.lastModeKey)
            return record.mode
        } catch {
            return .selfHost
        }
    }
}
