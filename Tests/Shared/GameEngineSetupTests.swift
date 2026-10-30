import Foundation
import Testing
@testable import Moonfall

struct GameEngineSetupTests {
    @Test func assignsRolesAndEveryBoothToEveryFamily() throws {
        let fixture = try Fixture(families: 10, werewolves: 2)
        #expect(fixture.werewolves.count == 2)
        #expect(fixture.villagers.count == 8)
        for family in fixture.engine.state.families.values {
            #expect(family.tasks.count == Booth.allCases.count)
            #expect(family.life == .alive)
            }
    }

    @Test func rejectsInvalidSetups() throws {
        var generator = SeededGenerator(seed: 1)
        let ids = (1 ... 6).map { FamilyID($0) }
        #expect(throws: RuleError.self) {
            try GameEngine.start(familyIDs: ids, werewolfCount: 0, at: t0, using: &generator)
        }
        #expect(throws: RuleError.self) {
            try GameEngine.start(familyIDs: ids, werewolfCount: 3, at: t0, using: &generator)
        }
        #expect(throws: RuleError.self) {
            try GameEngine.start(familyIDs: [1, 1, 2, 3], werewolfCount: 1, at: t0, using: &generator)
        }
    }

    @Test func sameSeedGivesSameAssignment() throws {
        let first = try Fixture(seed: 42)
        let second = try Fixture(seed: 42)
        #expect(first.engine == second.engine)
    }

    @Test func engineSurvivesCodableRoundTrip() throws {
        var fixture = try Fixture()
        try fixture.apply(.startMeeting, at: 10)
        let data = try JSONEncoder().encode(fixture.engine)
        let decoded = try JSONDecoder().decode(GameEngine.self, from: data)
        #expect(decoded == fixture.engine)
    }
}
