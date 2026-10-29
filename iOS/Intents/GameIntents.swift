import AppIntents

@MainActor
enum GameClientRegistry {
    static weak var client: GameClient?
}

extension SabotageKind: AppEnum {
    nonisolated static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sabotage")
    nonisolated static let caseDisplayRepresentations: [SabotageKind: DisplayRepresentation] = [
        .reactor: "Reactor",
        .oxygen: "Oxygen"
    ]
}

private enum IntentReply {
    static let unavailable: LocalizedStringResource = "Not available right now."

    @MainActor
    static func hostReply(from client: GameClient, sent: LocalizedStringResource) async -> LocalizedStringResource {
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
        guard let client = GameClientRegistry.client, let game = client.view?.game,
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
        guard let client = GameClientRegistry.client, let game = client.view?.game, game.role == .werewolf else {
            return .result(dialog: IntentDialog(IntentReply.unavailable))
        }
        client.send(.requestSabotage(kind))
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
    }
}
