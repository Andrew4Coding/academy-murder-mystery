import Foundation
import Synchronization
import Testing
@testable import Moonfall

final class FakeHTTP: HTTPClient {
    private let recorded = Mutex<[URLRequest]>([])
    private let reply = Mutex<(Data, Int)>((Data(), 200))
    private let failure = Mutex<(any Error)?>(nil)

    var requests: [URLRequest] {
        recorded.withLock { $0 }
    }

    func respond(_ body: String, status: Int = 200) {
        reply.withLock { $0 = (Data(body.utf8), status) }
    }

    func fail(with error: any Error) {
        failure.withLock { $0 = error }
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        recorded.withLock { $0.append(request) }
        if let error = failure.withLock({ $0 }) {
            throw error
        }
        return reply.withLock { $0 }
    }
}

@MainActor
struct HostRegistryClientTests {
    private let base = URL(string: "https://example.test")!

    private func client(_ http: FakeHTTP, credential: RegistryCredential? = .secret("s3cret")) -> HostRegistryClient {
        HostRegistryClient(baseURL: base, http: http, credential: { credential })
    }

    @Test func fetchesTheRegistryWithoutCredentials() async throws {
        let http = FakeHTTP()
        http.respond(#"{"mode":"cloud","updatedAt":1700000000,"hasSnapshot":true,"snapshotAt":1700000100}"#)
        let record = try await client(http).fetch()
        #expect(record.mode == .cloud)
        #expect(record.hasSnapshot)
        #expect(record.snapshotAt == Date(timeIntervalSince1970: 1_700_000_100))
        let request = try #require(http.requests.first)
        #expect(request.url?.path == "/registry")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "X-Moonfall-Secret") == nil)
    }

    @Test func writesCarryTheSecretOrPin() async throws {
        let http = FakeHTTP()
        http.respond(#"{"ok":true}"#)
        try await client(http).setMode(.selfHost)
        try await client(http, credential: .pin("4242")).setMode(.cloud)
        #expect(http.requests[0].httpMethod == "PUT")
        #expect(http.requests[0].url?.path == "/registry")
        #expect(http.requests[0].value(forHTTPHeaderField: "X-Moonfall-Secret") == "s3cret")
        #expect(http.requests[1].value(forHTTPHeaderField: "X-Moonfall-Pin") == "4242")
        let body = String(bytes: http.requests[1].httpBody ?? Data(), encoding: .utf8) ?? ""
        #expect(body.contains("cloud"))
    }

    @Test func writesWithoutACredentialNeverReachTheNetwork() async {
        let http = FakeHTTP()
        await #expect(throws: RegistryError.missingCredential) {
            try await client(http, credential: nil).putSnapshot(HostSnapshot(state: HostState(ocPin: "1"), selfies: [], boothMap: nil))
        }
        #expect(http.requests.isEmpty)
    }

    @Test func snapshotRoutesUseTheContractPathsAndMethods() async throws {
        let http = FakeHTTP()
        let snapshot = HostSnapshot(state: HostState(ocPin: "4242"), selfies: [], boothMap: nil)
        http.respond(#"{"ok":true}"#)
        let registry = client(http)
        try await registry.putSnapshot(snapshot)
        try await registry.importState(snapshot)
        try http.respond(String(bytes: WireCodec.encode(snapshot), encoding: .utf8) ?? "")
        #expect(try await registry.getSnapshot() == snapshot)
        #expect(try await registry.exportState() == snapshot)
        let routes = http.requests.map { "\($0.httpMethod ?? "") \($0.url?.path ?? "")" }
        #expect(routes == ["PUT /snapshot", "PUT /import", "GET /snapshot", "GET /export"])
    }

    @Test func takeOverSendsThePinInTheBodyOnly() async throws {
        let http = FakeHTTP()
        http.respond(#"{"ok":true}"#)
        try await client(http, credential: nil).takeOver(pin: "4242")
        let request = try #require(http.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/takeover")
        #expect((String(bytes: request.httpBody ?? Data(), encoding: .utf8) ?? "").contains("4242"))
        #expect(request.value(forHTTPHeaderField: "X-Moonfall-Pin") == nil)
    }

    @Test func statusCodesBecomeTypedErrors() async {
        let http = FakeHTTP()
        let registry = client(http)
        http.respond("{}", status: 401)
        await #expect(throws: RegistryError.unauthorized) { try await registry.setMode(.cloud) }
        http.respond("{}", status: 404)
        await #expect(throws: RegistryError.notFound) { _ = try await registry.getSnapshot() }
        http.respond("{}", status: 429)
        await #expect(throws: RegistryError.locked) { try await registry.setMode(.cloud) }
        http.respond("{}", status: 503)
        await #expect(throws: RegistryError.server(503)) { try await registry.setMode(.cloud) }
        http.fail(with: URLError(.timedOut))
        await #expect(throws: RegistryError.self) { _ = try await registry.fetch() }
    }
}
