import Foundation
import Testing
@testable import Moonfall

private let outputDirectory = ProcessInfo.processInfo.environment["MOONFALL_WRITE_FIXTURES"]

private struct TraceStep: Encodable {
    var at: TimeInterval
    var command: GameCommand?
    var advanceTo: TimeInterval?
    var events: [GameEvent]
    var state: GameEngine
    var error: String?

    private enum CodingKeys: String, CodingKey {
        case at, command, advanceTo, events, state, error
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(at, forKey: .at)
        try container.encode(command, forKey: .command)
        try container.encode(advanceTo, forKey: .advanceTo)
        try container.encode(events, forKey: .events)
        try container.encode(state, forKey: .state)
        try container.encodeIfPresent(error, forKey: .error)
    }
}

private struct Trace: Encodable {
    var seed: UInt64
    var start: GameEngine
    var steps: [TraceStep]
}

private struct TraceRecorder {
    var fixture: Fixture
    let seed: UInt64
    private let start: GameEngine
    private var steps: [TraceStep] = []

    init(families: Int, werewolves: Int, seed: UInt64) throws {
        fixture = try Fixture(families: families, werewolves: werewolves, seed: seed)
        self.seed = seed
        start = fixture.engine
    }

    var wolves: [FamilyID] {
        fixture.werewolves
    }

    var villagers: [FamilyID] {
        fixture.villagers
    }

    mutating func apply(_ command: GameCommand, at seconds: TimeInterval) {
        do {
            let events = try fixture.apply(command, at: seconds)
            steps.append(TraceStep(at: seconds, command: command, advanceTo: nil, events: events, state: fixture.engine))
        } catch {
            let name = String(describing: error).prefix { $0 != "(" }
            steps.append(TraceStep(at: seconds, command: command, advanceTo: nil, events: [], state: fixture.engine, error: String(name)))
        }
    }

    mutating func advance(to seconds: TimeInterval) {
        let events = fixture.advance(to: seconds)
        steps.append(TraceStep(at: seconds, command: nil, advanceTo: seconds, events: events, state: fixture.engine))
    }

    func json() throws -> Data {
        try WireCodec.encode(Trace(seed: seed, start: start, steps: steps))
    }
}

@MainActor
struct GoldenFixtureGenerator {
    private static let now = Date(timeIntervalSinceReferenceDate: 812_345.5)
    private static let uuidA = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let uuidB = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])

    @Test(.enabled(if: outputDirectory != nil))
    func writeFixtures() throws {
        let directory = try URL(fileURLWithPath: #require(outputDirectory), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, data) in try Self.wireFixtures() + Self.traceFixtures() {
            try data.write(to: directory.appending(path: name))
        }
    }

    private static func wire(_ type: String, _ name: String, _ value: some Encodable) throws -> (String, Data) {
        let json = try WireCodec.encode(value)
        var data = Data(#"{"type":"\#(type)","json":"#.utf8)
        data.append(json)
        data.append(Data("}\n".utf8))
        return ("wire-swift-\(type)-\(name).json", data)
    }

    private static func wireFixtures() throws -> [(String, Data)] {
        var out: [(String, Data)] = []
        let command = AdminCommand.startGame
        let clientMessages: [(String, ClientMessage)] = [
            ("hello_familyCode", .hello(Hello(credential: .familyCode("K7M2QX"), name: "Dewi"))),
            ("hello_ocPin", .hello(Hello(credential: .ocPin("4242"), station: .admin, mapHash: "abc123"))),
            ("hello_ocPin_sabotage", .hello(Hello(credential: .ocPin("4242"), station: .sabotage(.oxygen)))),
            ("hello_resume", .hello(Hello(credential: .resume(uuidA)))),
            ("probeReply", .probeReply(uuidB)),
            ("renameFamily", .renameFamily("The Hendersons")),
            ("voteSkipDiscussion", .voteSkipDiscussion),
            ("reportBody", .reportBody(FamilyID(3))),
            ("admin", .admin(command)),
            ("selfie", .selfie(jpeg)),
            ("vote_family", .vote(.family(FamilyID(2)))),
            ("vote_skip", .vote(.skip)),
            ("sightings", .sightings([Sighting(token: "A1B2C3", rssi: -60), Sighting(token: "D4E5F6", rssi: -82)])),
            ("kill", .kill(victim: FamilyID(2))),
            ("requestSabotage", .requestSabotage(.reactor)),
            ("resolveSabotage", .resolveSabotage),
            ("leave", .leave),
            ("sync", .sync)
        ]
        for (name, message) in clientMessages {
            try out.append(wire("ClientMessage", name, message))
        }

        let admin = AdminFixtures.adminView(.running, now: now)
        let game = ClientFixtures.game(now: now)
        let adminState = ClientView(serverTime: now, identity: .oc(id: uuidA, station: .admin), admin: admin)
        let serverMessages: [(String, ServerMessage)] = [
            ("welcome", .welcome(Welcome(resumeID: uuidA, serverTime: now))),
            ("state_player", .state(ClientFixtures.playerView(now: now, game: game))),
            ("state_lobby", .state(ClientFixtures.playerView(now: now, lobby: ClientFixtures.lobby()))),
            ("state_admin", .state(adminState)),
            ("state_oc", .state(ClientView(serverTime: now, identity: .oc(id: uuidB, station: .townHall), oc: OCView(sabotage: nil)))),
            ("rejected", .rejected("That code isn't valid. Check it and try again.")),
            ("probe", .probe(uuidB)),
            ("reset", .reset),
            ("selfies", .selfies([Selfie(player: uuidA, jpeg: jpeg), Selfie(player: uuidB, jpeg: jpeg)])),
            ("map_some", .map(BoothMap(jpeg: jpeg))),
            ("map_none", .map(nil)),
            ("display_waiting", .display(DisplayFixtures.waitingMany)),
            ("display_voting", .display(DisplayFixtures.voting(isFinal: true, alarm: true))),
            ("display_result", .display(DisplayFixtures.resultExpelled())),
            ("display_ended", .display(DisplayFixtures.villagersWin()))
        ]
        for (name, message) in serverMessages {
            try out.append(wire("ServerMessage", name, message))
        }

        let family = FamilyID(2)
        let adminCommands: [(String, AdminCommand)] = [
            ("ringBell", .ringBell),
            ("startMeeting", .startMeeting),
            ("extendMeeting", .extendMeeting(seconds: 30)),
            ("adjustTimer", .adjustTimer(.finalVote, seconds: -15)),
            ("pauseTimer", .pauseTimer(.meeting)),
            ("resumeTimer", .resumeTimer(.sabotage)),
            ("approveSkipDiscussion", .approveSkipDiscussion),
            ("resolveSabotage", .resolveSabotage),
            ("removeFamily", .removeFamily(family)),
            ("removeDevice", .removeDevice(uuidA)),
            (
                "updateSettings",
                .updateSettings(werewolfCount: 2, settings: GameSettings(oxygenDuration: 60, oxygenCooldown: 90, debugMode: true))
            ),
            ("setProximity", .setProximity(rssiThreshold: -70, sightingFreshness: 8)),
            ("startGame", .startGame),
            ("newGame", .newGame),
            ("renameFamily", .renameFamily(family, "Renamed")),
            ("regenerateOCPIN", .regenerateOCPIN),
            ("setBoothMap", .setBoothMap(jpeg)),
            ("removeBoothMap", .removeBoothMap),
            ("eliminate", .eliminate([FamilyID(1), FamilyID(4)])),
            ("revive", .revive([FamilyID(4)])),
            ("proxyVote", .proxyVote(family: family, choice: .skip)),
            ("endGame", .endGame(.werewolves)),
            ("checkConnectivity", .checkConnectivity)
        ]
        for (name, command) in adminCommands {
            try out.append(wire("AdminCommand", name, command))
        }
        return out
    }

    private static func traceFixtures() throws -> [(String, Data)] {
        var lobby = try TraceRecorder(families: 8, werewolves: 2, seed: 11)
        lobby.advance(to: 5)
        lobby.advance(to: 100)
        lobby.advance(to: 1500)

        var kill = try TraceRecorder(families: 6, werewolves: 1, seed: 7)
        let killer = kill.wolves[0]
        let victims = kill.villagers
        kill.apply(.kill(killer: killer, victim: victims[0]), at: 70)
        kill.apply(.kill(killer: killer, victim: victims[1]), at: 80)
        kill.apply(.kill(killer: victims[1], victim: victims[2]), at: 90)
        kill.advance(to: 140)
        kill.apply(.kill(killer: killer, victim: victims[1]), at: 150)
        kill.apply(.reportBody(by: victims[2], body: victims[0]), at: 160)
        kill.advance(to: 300)

        var meeting = try TraceRecorder(families: 8, werewolves: 2, seed: 99)
        let wolves = meeting.wolves
        let town = meeting.villagers
        meeting.apply(.startMeeting, at: 100)
        meeting.apply(.voteSkipDiscussion(by: town[0]), at: 110)
        meeting.apply(.extendMeeting(seconds: 30), at: 120)
        meeting.advance(to: 260)
        for (index, voter) in town.enumerated() {
            meeting.apply(.castVote(by: voter, choice: index.isMultiple(of: 2) ? .family(wolves[0]) : .skip), at: 270 + TimeInterval(index))
        }
        meeting.apply(.castVote(by: wolves[0], choice: .family(wolves[0])), at: 290)
        meeting.apply(.castVote(by: town[0], choice: .family(town[1])), at: 291)
        meeting.advance(to: 400)
        meeting.advance(to: 450)
        meeting.advance(to: 3000)

        var sabotage = try TraceRecorder(families: 8, werewolves: 2, seed: 5)
        sabotage.apply(.requestSabotage(by: sabotage.wolves[0], kind: .reactor), at: 130)
        sabotage.apply(.requestSabotage(by: sabotage.wolves[1], kind: .oxygen), at: 135)
        sabotage.apply(.startMeeting, at: 140)
        sabotage.apply(.adjustTimer(.sabotage, seconds: 20), at: 150)
        sabotage.apply(.pauseTimer(.sabotage), at: 160)
        sabotage.apply(.resumeTimer(.sabotage), at: 170)
        sabotage.apply(.resolveSabotage, at: 180)
        sabotage.apply(.requestSabotage(by: sabotage.wolves[1], kind: .oxygen), at: 190)
        sabotage.advance(to: 250)
        sabotage.advance(to: 500)
        sabotage.apply(.requestSabotage(by: sabotage.wolves[1], kind: .oxygen), at: 520)
        sabotage.advance(to: 700)
        sabotage.apply(.override(.endGame(.villagers)), at: 710)

        return try [
            ("trace-swift-lobby-start.json", lobby),
            ("trace-swift-kill.json", kill),
            ("trace-swift-meeting-vote.json", meeting),
            ("trace-swift-sabotage.json", sabotage)
        ].map { try ($0.0, $0.1.json() + Data("\n".utf8)) }
    }
}
