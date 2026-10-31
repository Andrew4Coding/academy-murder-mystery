import CryptoKit
import Foundation

struct BoothImage: Codable, Equatable, Sendable {
    let hash: String
    let jpeg: Data

    init(jpeg: Data) {
        self.jpeg = jpeg
        hash = SHA256.hash(data: jpeg).map { String(format: "%02x", $0) }.joined()
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(jpeg: container.decode(Data.self, forKey: .jpeg))
    }

    private enum CodingKeys: String, CodingKey {
        case hash, jpeg
    }
}

struct Booth: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var location: String
    var capacity: String
    var duration: String
    var task: String
    var steps: [String]
    var stampRequirement: String
    var staffNotes: [String]
    var image: BoothImage?

    init(
        id: UUID = UUID(),
        title: String = "",
        location: String = "",
        capacity: String = "",
        duration: String = "",
        task: String = "",
        steps: [String] = [],
        stampRequirement: String = "",
        staffNotes: [String] = [],
        image: BoothImage? = nil
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.capacity = capacity
        self.duration = duration
        self.task = task
        self.steps = steps
        self.stampRequirement = stampRequirement
        self.staffNotes = staffNotes
        self.image = image
    }

    func withoutStaffNotes() -> Booth {
        var copy = self
        copy.staffNotes = []
        return copy
    }
}

struct BoothCatalog: Codable, Equatable, Sendable {
    var revision: String
    var booths: [Booth]

    init(revision: String = UUID().uuidString, booths: [Booth]) {
        self.revision = revision
        self.booths = booths
    }

    static let empty = BoothCatalog(revision: "", booths: [])

    func forPlayers() -> BoothCatalog {
        BoothCatalog(revision: revision, booths: booths.map { $0.withoutStaffNotes() })
    }
}
