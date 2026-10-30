import CryptoKit
import Foundation

struct BoothMap: Codable, Equatable, Sendable {
    let hash: String
    let jpeg: Data

    init(jpeg: Data) {
        self.jpeg = jpeg
        hash = SHA256.hash(data: jpeg).map { String(format: "%02x", $0) }.joined()
    }
}
