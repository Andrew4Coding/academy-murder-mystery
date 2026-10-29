import ActivityKit
import UIKit

@MainActor
final class LiveStatusController {
    static let shared = LiveStatusController()

    private typealias State = GameActivityAttributes.ContentState

    private var activityID: String?
    private var lastState: State?
    private var lastFamily: String?
    private var refresher: Task<Void, Never>?
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    static let staleAfter: TimeInterval = 90

    func update(with view: ClientView?) {
        guard let (state, family) = Self.state(for: view) else {
            end(immediately: true)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard state != lastState || family != lastFamily else { return }
        lastState = state
        lastFamily = family
        push(state, family: family)
        if state.kind == .over {
            end(immediately: false)
        }
    }

    func appDidEnterBackground() {
        guard activityID != nil, backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "live-status") { [weak self] in
            Task { @MainActor in self?.finishBackgroundTask() }
        }
    }

    func appDidBecomeActive() {
        finishBackgroundTask()
        if let state = lastState, let family = lastFamily {
            push(state, family: family)
        }
    }

    private func finishBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func push(_ state: State, family: String) {
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(Self.staleAfter))
        if activityID == nil {
            activityID = Activity<GameActivityAttributes>.activities.first?.id
        }
        if let id = activityID {
            Task { await Self.apply(id: id, content: content) }
        } else {
            activityID = (try? Activity.request(
                attributes: GameActivityAttributes(familyName: family),
                content: content,
                pushType: nil
            ))?.id
        }
        startRefreshing()
    }

    // Activity is not Sendable, so it is only ever touched inside these nonisolated helpers, found again by id.
    private nonisolated static func apply(id: String, content: ActivityContent<State>) async {
        for activity in Activity<GameActivityAttributes>.activities where activity.id == id {
            await activity.update(content)
        }
    }

    private nonisolated static func finish(id: String, dismissal: ActivityUIDismissalPolicy) async {
        for activity in Activity<GameActivityAttributes>.activities where activity.id == id {
            await activity.end(nil, dismissalPolicy: dismissal)
        }
    }

    private func startRefreshing() {
        guard refresher == nil else { return }
        refresher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, let state = lastState, let family = lastFamily else { continue }
                push(state, family: family)
            }
        }
    }

    private func end(immediately: Bool) {
        refresher?.cancel()
        refresher = nil
        finishBackgroundTask()
        let finishedID = activityID
        activityID = nil
        if immediately {
            lastState = nil
            lastFamily = nil
        }
        guard let finishedID else { return }
        let policy: ActivityUIDismissalPolicy = immediately ? .immediate : .after(Date().addingTimeInterval(300))
        Task { await Self.finish(id: finishedID, dismissal: policy) }
    }

    private static func state(for view: ClientView?) -> (State, String)? {
        guard let view, case .player = view.identity else { return nil }
        if let game = view.game {
            return (state(for: game), game.familyName)
        }
        if let lobby = view.lobby {
            return (State(kind: .lobby, title: "Waiting to start", detail: "Keep the app open until the game begins.", endsAt: nil), lobby.familyName)
        }
        return nil
    }

    private static func state(for game: GameView) -> State {
        if case let .ended(outcome) = game.phase {
            return State(
                kind: .over,
                title: outcome.winner == .villagers ? "Villagers win!" : "Werewolves win!",
                detail: outcome.reason.explanation,
                endsAt: nil
            )
        }
        if let sabotage = game.sabotage {
            return State(kind: .sabotage, title: "Sabotage!", detail: "Go to \(sabotage.kind.title).", endsAt: sabotage.endsAt)
        }
        switch game.phase {
        case let .discussion(until):
            return State(kind: .discussion, title: "Discussion", detail: "Gather at the Town Hall.", endsAt: until)
        case let .voting(until, isFinal):
            return State(kind: .voting, title: isFinal ? "Final vote" : "Voting", detail: "Cast your vote.", endsAt: until)
        case .running, .ended:
            break
        }
        switch game.life {
        case .killed:
            return State(kind: .killed, title: "You were killed", detail: "Keep doing your tasks.", endsAt: nil)
        case .expelled:
            return State(kind: .killed, title: "Voted out", detail: "Sit at your seat until the game ends.", endsAt: nil)
        case .alive:
            let done = game.tasks.filter(\.done).count
            return State(kind: .playing, title: "In play", detail: "\(done) of \(game.tasks.count) tasks stamped.", endsAt: nil)
        }
    }
}
