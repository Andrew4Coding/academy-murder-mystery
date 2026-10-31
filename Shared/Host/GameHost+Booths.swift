import Foundation

extension GameHost {
    func catalog(for identity: Identity) -> BoothCatalog {
        if case let .oc(id) = identity, state.ocDevices[id]?.station == .admin {
            return boothCatalog
        }
        return boothCatalog.forPlayers()
    }

    func saveBooth(_ booth: Booth) throws {
        var booths = boothCatalog.booths
        if let index = booths.firstIndex(where: { $0.id == booth.id }) {
            var updated = booth
            updated.image = booths[index].image
            booths[index] = updated
        } else {
            var created = booth
            created.image = nil
            booths.append(created)
        }
        try applyBooths(booths)
    }

    func deleteBooth(_ id: UUID) throws {
        guard boothCatalog.booths.contains(where: { $0.id == id }) else { throw HostError.unknownBooth }
        try applyBooths(boothCatalog.booths.filter { $0.id != id })
    }

    func reorderBooths(_ ids: [UUID]) throws {
        let byID = Dictionary(boothCatalog.booths.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var ordered = ids.compactMap { byID[$0] }
        let listed = Set(ids)
        ordered += boothCatalog.booths.filter { !listed.contains($0.id) }
        try applyBooths(ordered)
    }

    func setBoothImage(_ id: UUID, imageData: Data) throws {
        let image = try BoothMapImporter.makeBoothImage(from: imageData)
        try updateBooth(id) { $0.image = image }
    }

    func removeBoothImage(_ id: UUID) throws {
        try updateBooth(id) { $0.image = nil }
    }

    func restoreBoothDefaults() throws {
        try applyBooths(BoothDefaults.booths)
    }

    private func updateBooth(_ id: UUID, _ change: (inout Booth) -> Void) throws {
        var booths = boothCatalog.booths
        guard let index = booths.firstIndex(where: { $0.id == id }) else { throw HostError.unknownBooth }
        change(&booths[index])
        try applyBooths(booths)
    }

    private func applyBooths(_ booths: [Booth]) throws {
        let catalog = BoothCatalog(booths: booths)
        try boothStore.save(catalog)
        boothCatalog = catalog
        onCommit?()
        for (id, session) in sessions {
            guard let identity = session.identity else { continue }
            send(.booths(self.catalog(for: identity)), to: id)
        }
    }
}
