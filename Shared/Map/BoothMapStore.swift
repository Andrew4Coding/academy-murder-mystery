import Foundation

protocol BoothMapStore: AnyObject {
    func load() -> BoothMap?
    func save(_ map: BoothMap?) throws
}

final class InMemoryBoothMapStore: BoothMapStore {
    private var map: BoothMap?

    init(map: BoothMap? = nil) {
        self.map = map
    }

    func load() -> BoothMap? {
        map
    }

    func save(_ map: BoothMap?) throws {
        self.map = map
    }
}

final class FileBoothMapStore: BoothMapStore {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    static func appSupport() -> FileBoothMapStore {
        let base = URL.applicationSupportDirectory.appending(path: "Moonfall", directoryHint: .isDirectory)
        return FileBoothMapStore(url: base.appending(path: "booth-map.jpg"))
    }

    func load() -> BoothMap? {
        (try? Data(contentsOf: url)).map { BoothMap(jpeg: $0) }
    }

    func save(_ map: BoothMap?) throws {
        guard let map else {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try map.jpeg.write(to: url, options: .atomic)
    }
}
