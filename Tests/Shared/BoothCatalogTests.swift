import Foundation
import Testing
@testable import Moonfall

@MainActor
struct BoothCatalogTests {
    @Test func aFreshHostIsSeededWithTheGuideBooths() throws {
        let host = try GameHost(repository: InMemoryGameRepository())
        #expect(host.boothCatalog.booths.count == 9)
        #expect(host.boothCatalog.booths.allSatisfy { booth in booth.image != nil })
        #expect(host.boothCatalog.booths.first?.title == "Booth 1 – Decipher Clue")
        #expect(host.boothCatalog.booths.last?.title == "Sabotage Booth 7A – Heist Plan")
        #expect(host.boothCatalog.booths.allSatisfy { !$0.steps.isEmpty && !$0.task.isEmpty })
    }

    @Test func editsAddDeleteAndReorderPersistAcrossANewGameAndRestart() throws {
        let store = InMemoryBoothStore()
        let host = try GameHost(repository: InMemoryGameRepository(), boothStore: store)
        let first = try #require(host.boothCatalog.booths.first)

        var edited = first
        edited.title = "Renamed"
        try host.saveBooth(edited)
        try host.saveBooth(Booth(title: "Extra"))
        try host.deleteBooth(host.boothCatalog.booths[1].id)
        try host.reorderBooths(host.boothCatalog.booths.map(\.id).reversed())
        try host.newGame()

        let restarted = try GameHost(repository: InMemoryGameRepository(), boothStore: store)
        #expect(restarted.boothCatalog == host.boothCatalog)
        #expect(restarted.boothCatalog.booths.first?.title == "Extra")
        #expect(restarted.boothCatalog.booths.map(\.title).contains("Renamed"))
        #expect(restarted.boothCatalog.booths.count == 9)
    }

    @Test func savingNeverTouchesTheStoredImage() throws {
        let host = try GameHost(repository: InMemoryGameRepository())
        let id = try #require(host.boothCatalog.booths.first?.id)
        try host.setBoothImage(id, imageData: BoothMapTests.pngData(width: 3200, height: 1600))
        let image = try #require(host.boothCatalog.booths.first?.image)
        #expect(image.jpeg.starts(with: [0xFF, 0xD8]))

        var edited = try #require(host.boothCatalog.booths.first)
        edited.image = nil
        edited.task = "New task"
        try host.saveBooth(edited)
        #expect(host.boothCatalog.booths.first?.image == image)

        try host.removeBoothImage(id)
        #expect(host.boothCatalog.booths.first?.image == nil)
    }

    @Test func nonImagesAndUnknownBoothsAreRejected() throws {
        let host = try GameHost(repository: InMemoryGameRepository())
        let id = try #require(host.boothCatalog.booths.first?.id)
        #expect(throws: HostError.invalidImage) {
            try host.setBoothImage(id, imageData: Data("nope".utf8))
        }
        #expect(throws: HostError.unknownBooth) { try host.deleteBooth(UUID()) }
        #expect(throws: HostError.unknownBooth) { try host.removeBoothImage(UUID()) }
    }

    @Test func restoreDefaultsBringsBackTheGuideBoothsWithTheirDefaultPictures() throws {
        let host = try GameHost(repository: InMemoryGameRepository())
        let id = try #require(host.boothCatalog.booths.first?.id)
        try host.setBoothImage(id, imageData: BoothMapTests.pngData(width: 100, height: 100))
        try host.saveBooth(Booth(title: "Extra"))
        var edited = try #require(host.boothCatalog.booths.first)
        edited.title = "Changed"
        try host.saveBooth(edited)

        try host.restoreBoothDefaults()
        #expect(host.boothCatalog.booths.map(\.title) == BoothDefaults.booths.map(\.title))
        #expect(host.boothCatalog.booths.first?.image == BoothDefaults.booths.first?.image)
    }

    @Test func settingTheDefaultPictureKeepsItByteForByte() throws {
        let host = try GameHost(repository: InMemoryGameRepository())
        let first = try #require(host.boothCatalog.booths.first)
        let defaultImage = try #require(first.image)
        try host.removeBoothImage(first.id)
        #expect(host.boothCatalog.booths.first?.image == nil)

        try host.setBoothImage(first.id, imageData: defaultImage.jpeg)
        #expect(host.boothCatalog.booths.first?.image == defaultImage)
    }

    @Test func playersNeverReceiveStaffNotes() async throws {
        let harness = try HostHarness()
        try harness.host.saveBooth(Booth(title: "With notes", staffNotes: ["MC only"]))
        #expect(harness.host.boothCatalog.booths.contains { !$0.staffNotes.isEmpty })

        let client = harness.makeClient()
        client.join(code: "AAA111", name: "Dewi")
        #expect(await eventually { client.booths.booths.count == 10 })
        #expect(client.booths.booths.allSatisfy { booth in booth.staffNotes.isEmpty })

        var edited = try #require(harness.host.boothCatalog.booths.first)
        edited.task = "Updated for everyone"
        try harness.host.saveBooth(edited)
        #expect(await eventually { client.booths.booths.first?.task == "Updated for everyone" })
        #expect(client.booths.booths.allSatisfy { booth in booth.staffNotes.isEmpty })
    }

    @Test func aClientHoldingTheSameRevisionIsNotSentTheCatalogAgain() async throws {
        let harness = try HostHarness()
        let transport = harness.hub.makeClient()
        transport.start()
        transport.send(.hello(Hello(
            credential: .familyCode("AAA111"),
            name: "Dewi",
            boothsRevision: harness.host.boothCatalog.revision
        )))
        var iterator = transport.events.makeAsyncIterator()
        var received: [ServerMessage] = []
        while let event = await iterator.next() {
            guard case let .message(message) = event else { continue }
            received.append(message)
            if case .state = message {
                break
            }
        }
        #expect(!received.contains {
            if case .booths = $0 {
                true
            } else {
                false
            }
        })
    }

    @Test func fileStoreRoundTrips() throws {
        let url = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "booths.json")
        let store = FileBoothStore(url: url)
        #expect(store.load() == nil)
        let catalog = BoothCatalog(booths: [Booth(title: "A", steps: ["x"], image: BoothImage(jpeg: Data([1, 2])))])
        try store.save(catalog)
        #expect(store.load() == catalog)
    }
}
