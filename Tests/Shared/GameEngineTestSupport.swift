import Foundation
@testable import Moonfall

let t0 = Date(timeIntervalSinceReferenceDate: 0)

func at(_ seconds: TimeInterval) -> Date {
    t0.addingTimeInterval(seconds)
}

struct Fixture {
    var engine: GameEngine
    let werewolves: [FamilyID]
    let villagers: [FamilyID]

    init(families: Int = 6, werewolves count: Int = 1, settings: GameSettings = .standard, seed: UInt64 = 7) throws {
        var generator = SeededGenerator(seed: seed)
        let (engine, _) = try GameEngine.start(
            familyIDs: (1 ... families).map { FamilyID($0) },
            werewolfCount: count,
            settings: settings,
            at: t0,
            using: &generator
        )
        self.engine = engine
        werewolves = engine.state.families.values.filter { $0.role == .werewolf }.map(\.id).sorted()
        villagers = engine.state.families.values.filter { $0.role == .villager }.map(\.id).sorted()
    }

    @discardableResult
    mutating func apply(_ command: GameCommand, at seconds: TimeInterval) throws -> [GameEvent] {
        try engine.apply(command, at: at(seconds))
    }

    mutating func advance(to seconds: TimeInterval) -> [GameEvent] {
        engine.advance(to: at(seconds))
    }

    func family(_ id: FamilyID) -> Family {
        engine.state.families[id]!
    }
}

extension [GameEvent] {
    var kinds: [GameEvent.Kind] {
        map(\.kind)
    }

    var outcome: Outcome? {
        for case let .gameEnded(outcome) in kinds {
            return outcome
        }
        return nil
    }
}
