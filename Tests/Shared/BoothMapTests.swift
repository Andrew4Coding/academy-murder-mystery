import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Moonfall

@MainActor
struct BoothMapTests {
    static func pngData(width: Int, height: Int) -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }

    static func size(of map: BoothMap) throws -> (width: Int, height: Int) {
        let image = try #require(BoothMapImporter.decode(map.jpeg, maxPixelSize: 10000))
        return (image.width, image.height)
    }

    @Test func largeImagesAreDownscaledToJpegKeepingAspectRatio() throws {
        let map = try BoothMapImporter.makeMap(from: Self.pngData(width: 4000, height: 2000))
        let size = try Self.size(of: map)
        #expect(size.width == 3000)
        #expect(size.height == 1500)
        #expect(map.jpeg.starts(with: [0xFF, 0xD8]))
    }

    @Test func smallImagesKeepTheirSize() throws {
        let map = try BoothMapImporter.makeMap(from: Self.pngData(width: 800, height: 600))
        let size = try Self.size(of: map)
        #expect(size.width == 800)
        #expect(size.height == 600)
    }

    @Test func nonImagesAreRejected() {
        #expect(throws: HostError.invalidImage) {
            try BoothMapImporter.makeMap(from: Data("not an image".utf8))
        }
    }

    @Test func hashIsStableForTheSameBytesAndDiffersOtherwise() {
        let first = BoothMap(jpeg: Data([1, 2, 3]))
        #expect(first.hash == BoothMap(jpeg: Data([1, 2, 3])).hash)
        #expect(first.hash != BoothMap(jpeg: Data([1, 2, 4])).hash)
    }

    @Test func fileStoreRoundTripsAndRemoves() throws {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "booth-map.jpg")
        let store = FileBoothMapStore(url: url)
        #expect(store.load() == nil)
        let map = BoothMap(jpeg: Data([9, 8, 7]))
        try store.save(map)
        #expect(store.load() == map)
        try store.save(nil)
        #expect(store.load() == nil)
    }

    @Test func playersReceiveTheMapOnJoinAndWhenItChanges() async throws {
        let harness = try HostHarness()
        try harness.host.setBoothMap(imageData: Self.pngData(width: 100, height: 50))
        let map = try #require(harness.host.boothMap)

        let client = harness.makeClient()
        client.join(code: "AAA111", name: "Dewi")
        #expect(await eventually { client.boothMap == map })

        try harness.host.setBoothMap(imageData: Self.pngData(width: 120, height: 60))
        let replaced = try #require(harness.host.boothMap)
        #expect(replaced != map)
        #expect(await eventually { client.boothMap == replaced })

        try harness.host.removeBoothMap()
        #expect(await eventually { client.boothMap == nil })
    }

    @Test func theMapSurvivesANewGameAndAHostRestart() throws {
        let store = InMemoryBoothMapStore()
        let first = try GameHost(repository: InMemoryGameRepository(), boothMapStore: store)
        try first.setBoothMap(imageData: Self.pngData(width: 100, height: 50))
        let map = try #require(first.boothMap)
        try first.newGame()
        #expect(first.boothMap == map)
        let restarted = try GameHost(repository: InMemoryGameRepository(), boothMapStore: store)
        #expect(restarted.boothMap == map)
    }

    @Test func aClientHoldingTheSameMapIsNotSentItAgain() async throws {
        let harness = try HostHarness()
        try harness.host.setBoothMap(imageData: Self.pngData(width: 100, height: 50))
        let map = try #require(harness.host.boothMap)

        let transport = harness.hub.makeClient()
        transport.start()
        transport.send(.hello(Hello(credential: .familyCode("AAA111"), name: "Dewi", mapHash: map.hash)))
        var iterator = transport.events.makeAsyncIterator()
        var received: [ServerMessage] = []
        while let event = await iterator.next() {
            guard case let .message(message) = event else { continue }
            received.append(message)
            if case .state = message { break }
        }
        #expect(!received.contains { if case .map = $0 { true } else { false } })
    }

    @Test func aStaleClientIsToldTheMapWasRemoved() async throws {
        let harness = try HostHarness()
        let transport = harness.hub.makeClient()
        transport.start()
        transport.send(.hello(Hello(credential: .familyCode("AAA111"), name: "Dewi", mapHash: "stale")))
        var iterator = transport.events.makeAsyncIterator()
        var sawRemoval = false
        while let event = await iterator.next() {
            if case let .message(.map(map)) = event {
                sawRemoval = map == nil; break
            }
        }
        #expect(sawRemoval)
    }

    @Test func noMapMeansNoSetupIssue() throws {
        let harness = try HostHarness()
        #expect(harness.host.boothMap == nil)
        #expect(!harness.host.state.setupIssues().contains { $0.localizedCaseInsensitiveContains("map") })
    }
}
