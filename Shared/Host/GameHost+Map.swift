import Foundation

extension GameHost {
    func setBoothMap(imageData: Data) throws {
        let map = try BoothMapImporter.makeMap(from: imageData)
        try boothMapStore.save(map)
        applyBoothMap(map)
    }

    func removeBoothMap() throws {
        try boothMapStore.save(nil)
        applyBoothMap(nil)
    }

    private func applyBoothMap(_ map: BoothMap?) {
        boothMap = map
        for (id, session) in sessions where session.identity != nil {
            send(.map(map), to: id)
        }
    }
}
