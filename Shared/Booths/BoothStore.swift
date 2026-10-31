import Foundation

protocol BoothStore: AnyObject {
    func load() -> BoothCatalog?
    func save(_ catalog: BoothCatalog) throws
}

final class InMemoryBoothStore: BoothStore {
    private var catalog: BoothCatalog?

    init(catalog: BoothCatalog? = nil) {
        self.catalog = catalog
    }

    func load() -> BoothCatalog? {
        catalog
    }

    func save(_ catalog: BoothCatalog) throws {
        self.catalog = catalog
    }
}

final class FileBoothStore: BoothStore {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    static func appSupport() -> FileBoothStore {
        let base = URL.applicationSupportDirectory.appending(path: "Moonfall", directoryHint: .isDirectory)
        return FileBoothStore(url: base.appending(path: "booths.json"))
    }

    func load() -> BoothCatalog? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BoothCatalog.self, from: data)
    }

    func save(_ catalog: BoothCatalog) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(catalog).write(to: url, options: .atomic)
    }
}
