import Foundation

struct RegistryRecord: Equatable, Sendable {
    var mode: HostMode
    var updatedAt: Date?
    var hasSnapshot: Bool
    var snapshotAt: Date?
}

extension RegistryRecord: Decodable {
    private enum CodingKeys: String, CodingKey {
        case mode, updatedAt, hasSnapshot, snapshotAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(HostMode.self, forKey: .mode)
        updatedAt = try container.decodeIfPresent(TimeInterval.self, forKey: .updatedAt).map(Date.init(timeIntervalSince1970:))
        hasSnapshot = try container.decodeIfPresent(Bool.self, forKey: .hasSnapshot) ?? false
        snapshotAt = try container.decodeIfPresent(TimeInterval.self, forKey: .snapshotAt).map(Date.init(timeIntervalSince1970:))
    }
}

enum RegistryCredential: Equatable, Sendable {
    case pin(String)
    case secret(String)

    var header: (name: String, value: String) {
        switch self {
        case let .pin(pin): ("X-Moonfall-Pin", pin)
        case let .secret(secret): ("X-Moonfall-Secret", secret)
        }
    }
}

enum RegistryError: Error, Equatable, Sendable {
    case unreachable(String)
    case unauthorized
    case locked
    case notFound
    case server(Int)
    case invalidResponse
    case missingCredential

    var message: String {
        switch self {
        case let .unreachable(reason): "The cloud host can't be reached. \(reason)"
        case .unauthorized: "The cloud host refused the PIN or pairing secret."
        case .locked: "Too many attempts. Wait a moment and try again."
        case .notFound: "The cloud host has no saved game yet."
        case let .server(code): "The cloud host answered with error \(code)."
        case .invalidResponse: "The cloud host sent an answer the app can't read."
        case .missingCredential: "Enter the pairing secret or OC PIN first."
        }
    }
}

protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

extension URLSession: HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RegistryError.invalidResponse }
        return (data, http.statusCode)
    }
}

@MainActor
protocol HostRegistry: AnyObject {
    func fetch() async throws -> RegistryRecord
    func setMode(_ mode: HostMode) async throws
    func putSnapshot(_ snapshot: HostSnapshot) async throws
    func getSnapshot() async throws -> HostSnapshot
    func importState(_ snapshot: HostSnapshot) async throws
    func exportState() async throws -> HostSnapshot
    func takeOver(pin: String) async throws
}

@MainActor
final class HostRegistryClient: HostRegistry {
    private let baseURL: URL
    private let http: any HTTPClient
    private let credential: @MainActor () -> RegistryCredential?

    init(
        baseURL: URL = CloudConfig.baseURL,
        http: any HTTPClient = URLSession.shared,
        credential: @escaping @MainActor () -> RegistryCredential? = { nil }
    ) {
        self.baseURL = baseURL
        self.http = http
        self.credential = credential
    }

    static func live(credential: @escaping @MainActor () -> RegistryCredential? = { nil }) -> HostRegistryClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = CloudConfig.transferTimeout
        configuration.waitsForConnectivity = false
        return HostRegistryClient(http: URLSession(configuration: configuration), credential: credential)
    }

    func fetch() async throws -> RegistryRecord {
        try await decode(RegistryRecord.self, from: call("GET", "registry", authorized: false, timeout: CloudConfig.registryTimeout))
    }

    func setMode(_ mode: HostMode) async throws {
        _ = try await call("PUT", "registry", body: JSONEncoder().encode(["mode": mode.rawValue]), authorized: true)
    }

    func putSnapshot(_ snapshot: HostSnapshot) async throws {
        _ = try await call("PUT", "snapshot", body: WireCodec.encode(snapshot), authorized: true)
    }

    func getSnapshot() async throws -> HostSnapshot {
        try await decode(HostSnapshot.self, from: call("GET", "snapshot", authorized: true))
    }

    func importState(_ snapshot: HostSnapshot) async throws {
        _ = try await call("PUT", "import", body: WireCodec.encode(snapshot), authorized: true)
    }

    func exportState() async throws -> HostSnapshot {
        try await decode(HostSnapshot.self, from: call("GET", "export", authorized: true))
    }

    func takeOver(pin: String) async throws {
        _ = try await call("POST", "takeover", body: JSONEncoder().encode(["pin": pin]), authorized: false)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try WireCodec.decode(type, from: data)
        } catch {
            throw RegistryError.invalidResponse
        }
    }

    private func call(
        _ method: String,
        _ path: String,
        body: Data? = nil,
        authorized: Bool,
        timeout: TimeInterval? = nil
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        if let timeout {
            request.timeoutInterval = timeout
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authorized {
            guard let credential = credential() else { throw RegistryError.missingCredential }
            request.setValue(credential.header.value, forHTTPHeaderField: credential.header.name)
        }
        let data: Data
        let status: Int
        do {
            (data, status) = try await http.send(request)
        } catch let error as RegistryError {
            throw error
        } catch {
            throw RegistryError.unreachable(error.localizedDescription)
        }
        try Self.validate(status: status)
        return data
    }

    private static func validate(status: Int) throws {
        switch status {
        case 200 ..< 300: return
        case 401: throw RegistryError.unauthorized
        case 404: throw RegistryError.notFound
        case 429: throw RegistryError.locked
        default: throw RegistryError.server(status)
        }
    }
}
