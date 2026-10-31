import AppIntents

@MainActor
enum GameClientRegistry {
    static let shared = GameClient(transport: AdaptiveClientTransport.live(), store: UserDefaultsIdentityStore())

    static func connectedClient() async -> GameClient? {
        shared.start()
        for _ in 0 ..< 20 {
            if shared.isSignedIn, shared.view?.game != nil {
                return shared
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return nil
    }
}

extension SabotageKind: AppEnum {
    nonisolated static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sabotage")
    nonisolated static let caseDisplayRepresentations: [SabotageKind: DisplayRepresentation] = [
        .reactor: "Reactor",
        .oxygen: "Oxygen"
    ]
}

struct FamilyEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Family")
    static let defaultQuery = FamilyQuery()

    let id: Int
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct FamilyQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [Int]) async throws -> [FamilyEntity] {
        options().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [FamilyEntity] {
        options()
    }

    @MainActor
    private func options() -> [FamilyEntity] {
        let families = GameClientRegistry.shared.view?.game?.families ?? []
        return families.filter { $0.life == .alive }.map { FamilyEntity(id: $0.id.rawValue, name: $0.name) }
    }
}

// Replies stay neutral so a spoken answer never reveals a role or an action to people nearby.
private enum IntentReply {
    static let unavailable: LocalizedStringResource = "Not available right now."

    @MainActor
    static func hostReply(from client: GameClient, sent: LocalizedStringResource) async -> LocalizedStringResource {
        client.clearError()
        try? await Task.sleep(for: .seconds(1))
        if let error = client.lastError {
            return "\(error)"
        }
        return sent
    }
}

struct KillNearbyFamilyIntent: AppIntent {
    static let title: LocalizedStringResource = "Eliminate nearby family"
    static let description = IntentDescription("Eliminates the one villager family that is close to you.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let client = await GameClientRegistry.connectedClient(), let game = client.view?.game,
              game.role == .werewolf, game.life == .alive
        else {
            return .result(dialog: IntentDialog(IntentReply.unavailable))
        }
        guard game.nearby.count == 1, let target = game.nearby.first else {
            return .result(dialog: game.nearby.isEmpty ? "No one nearby." : "More than one family is nearby. Use the app.")
        }
        client.send(.kill(victim: target.id))
        return .result(dialog: IntentDialog(await IntentReply.hostReply(from: client, sent: "Sent.")))
    }
}

struct StartSabotageIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a sabotage"
    static let description = IntentDescription("Starts a Reactor or Oxygen sabotage.")

    @Parameter(title: "Booth")
    var kind: SabotageKind

    init() {
        kind = .reactor
    }

    init(kind: SabotageKind) {
        self.kind = kind
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let client = await GameClientRegistry.connectedClient(), let game = client.view?.game, game.role == .werewolf else {
            return .result(dialog: IntentDialog(IntentReply.unavailable))
        }
        client.send(.requestSabotage(kind))
        return .result(dialog: IntentDialog(await IntentReply.hostReply(from: client, sent: "Sent.")))
    }
}

struct VoteForFamilyIntent: AppIntent {
    static let title: LocalizedStringResource = "Vote for a family"
    static let description = IntentDescription("Casts your family's vote without showing your screen.")

    @Parameter(title: "Family")
    var family: FamilyEntity

    init() {}

    init(family: FamilyEntity) {
        self.family = family
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let client = await GameClientRegistry.connectedClient(), let game = client.view?.game, game.life == .alive else {
            return .result(dialog: IntentDialog(IntentReply.unavailable))
        }
        client.send(.vote(.family(FamilyID(family.id))))
        return .result(dialog: IntentDialog(await IntentReply.hostReply(from: client, sent: "Vote sent.")))
    }
}

struct VoteSkipIntent: AppIntent {
    static let title: LocalizedStringResource = "Vote to skip"
    static let description = IntentDescription("Casts a Skip vote so nobody is voted out because of you.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let client = await GameClientRegistry.connectedClient(), let game = client.view?.game, game.life == .alive else {
            return .result(dialog: IntentDialog(IntentReply.unavailable))
        }
        client.send(.vote(.skip))
        return .result(dialog: IntentDialog(await IntentReply.hostReply(from: client, sent: "Vote sent.")))
    }
}

struct SkipDiscussionIntent: AppIntent {
    static let title: LocalizedStringResource = "Vote to skip discussion"
    static let description = IntentDescription("Votes to end the discussion early. The organiser still has to approve.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let client = await GameClientRegistry.connectedClient(), let game = client.view?.game, game.life == .alive else {
            return .result(dialog: IntentDialog(IntentReply.unavailable))
        }
        client.send(.voteSkipDiscussion)
        return .result(dialog: IntentDialog(await IntentReply.hostReply(from: client, sent: "Sent.")))
    }
}

struct GameShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: KillNearbyFamilyIntent(),
            phrases: ["Eliminate in \(.applicationName)"],
            shortTitle: "Eliminate",
            systemImageName: "scope"
        )
        AppShortcut(
            intent: StartSabotageIntent(kind: .reactor),
            phrases: ["Sabotage reactor in \(.applicationName)"],
            shortTitle: "Sabotage Reactor",
            systemImageName: "atom"
        )
        AppShortcut(
            intent: StartSabotageIntent(kind: .oxygen),
            phrases: ["Sabotage oxygen in \(.applicationName)"],
            shortTitle: "Sabotage Oxygen",
            systemImageName: "wind"
        )
        AppShortcut(
            intent: VoteForFamilyIntent(),
            phrases: ["Vote in \(.applicationName)"],
            shortTitle: "Vote",
            systemImageName: "hand.raised"
        )
        AppShortcut(
            intent: VoteSkipIntent(),
            phrases: ["Vote skip in \(.applicationName)"],
            shortTitle: "Vote Skip",
            systemImageName: "forward"
        )
        AppShortcut(
            intent: SkipDiscussionIntent(),
            phrases: ["Skip discussion in \(.applicationName)"],
            shortTitle: "Skip Discussion",
            systemImageName: "forward.end"
        )
    }
}
