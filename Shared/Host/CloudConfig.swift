import Foundation

enum CloudConfig {
    static let baseURL = URL(string: "https://moonfall.andrewaryo.com")!
    static let socketURL = URL(string: "wss://moonfall.andrewaryo.com/ws")!
    static let registryTimeout: TimeInterval = 3
    static let transferTimeout: TimeInterval = 60
    static let pairingSecretKey = "cloudPairingSecret"
    static let lastModeKey = "hostModeLastKnown"
}

enum HostMode: String, Codable, Sendable, CaseIterable {
    case selfHost = "local"
    case cloud

    var title: String {
        switch self {
        case .selfHost: "Self-host"
        case .cloud: "Cloud"
        }
    }
}
