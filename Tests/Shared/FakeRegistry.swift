import Foundation
@testable import Moonfall

@MainActor
final class FakeRegistry: HostRegistry {
    var mode: HostMode = .selfHost
    var reachable = true
    var stored: HostSnapshot?
    var live: HostSnapshot?
    var failImport = false
    private(set) var calls: [String] = []
    private(set) var takeOverPins: [String] = []

    private func gate(_ name: String) throws {
        calls.append(name)
        if !reachable { throw RegistryError.unreachable("offline") }
    }

    func fetch() async throws -> RegistryRecord {
        try gate("fetch")
        return RegistryRecord(mode: mode, updatedAt: nil, hasSnapshot: stored != nil, snapshotAt: nil)
    }

    func setMode(_ mode: HostMode) async throws {
        try gate("setMode:\(mode.rawValue)")
        self.mode = mode
    }

    func putSnapshot(_ snapshot: HostSnapshot) async throws {
        try gate("putSnapshot")
        stored = snapshot
    }

    func getSnapshot() async throws -> HostSnapshot {
        try gate("getSnapshot")
        guard let stored else { throw RegistryError.notFound }
        return stored
    }

    func importState(_ snapshot: HostSnapshot) async throws {
        try gate("import")
        if failImport { throw RegistryError.server(500) }
        live = snapshot
        mode = .cloud
    }

    func exportState() async throws -> HostSnapshot {
        try gate("export")
        guard let live else { throw RegistryError.notFound }
        return live
    }

    func takeOver(pin: String) async throws {
        try gate("takeOver")
        takeOverPins.append(pin)
        guard let stored else { throw RegistryError.notFound }
        live = stored
        mode = .cloud
    }
}
