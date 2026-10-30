import ActivityKit
import Foundation

private enum ActivityOps {
    // Activity is not Sendable, so it must never leave these nonisolated functions: callers pass its id instead.
    private static func running(_ id: String?) -> Activity<GameActivityAttributes>? {
        let all = Activity<GameActivityAttributes>.activities
        guard let id else { return all.first }
        return all.first { $0.id == id }
    }

    @concurrent
    static func adopt() async -> String? {
        let all = Activity<GameActivityAttributes>.activities
        for extra in all.dropFirst() {
            await extra.end(nil, dismissalPolicy: .immediate)
        }
        return all.first?.id
    }

    @concurrent
    static func apply(_ content: ActivityContent<GameActivityState>, id: String?) async -> String? {
        if let activity = running(id) {
            await activity.update(content)
            return activity.id
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        let activity = try? Activity.request(
            attributes: GameActivityAttributes(),
            content: content,
            pushType: nil
        )
        return activity?.id
    }

    @concurrent
    static func end(
        id: String?,
        content: ActivityContent<GameActivityState>?,
        policy: ActivityUIDismissalPolicy
    ) async {
        guard let activity = running(id) else { return }
        await activity.end(content, dismissalPolicy: policy)
    }
}

@MainActor
final class LiveActivityController {
    private static let endedLinger: TimeInterval = 600

    private var activityID: String?
    private var lastState: GameActivityState?
    private var lastStale: Date?
    private var finished = false
    private var tail: Task<Void, Never>?

    init() {
        enqueue { [self] in activityID = await ActivityOps.adopt() }
    }

    func sync(view: ClientView?, clock: ServerClock) {
        guard let view, case .player = view.identity, let game = view.game else {
            finished = false
            lastState = nil
            lastStale = nil
            enqueue { [self] in await stop() }
            return
        }

        let state = GameActivityState(game: game, clockOffset: clock.offset)
        if state.isEnded {
            finish(with: state)
            return
        }
        finished = false

        let stale = GameActivityState.nextChange(of: game, clockOffset: clock.offset)
        guard state != lastState || stale != lastStale else { return }
        lastState = state
        lastStale = stale
        let content = ActivityContent(state: state, staleDate: stale)
        enqueue { [self] in activityID = await ActivityOps.apply(content, id: activityID) }
    }

    private func finish(with state: GameActivityState) {
        guard !finished else { return }
        finished = true
        lastState = nil
        lastStale = nil
        let content = ActivityContent(state: state, staleDate: nil)
        let dismissAt = Date().addingTimeInterval(Self.endedLinger)
        enqueue { [self] in
            guard let id = activityID else { return }
            activityID = nil
            await ActivityOps.end(id: id, content: content, policy: .after(dismissAt))
        }
    }

    private func stop() async {
        guard let id = activityID else { return }
        activityID = nil
        await ActivityOps.end(id: id, content: nil, policy: .immediate)
    }

    private func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = tail
        tail = Task {
            await previous?.value
            await work()
        }
    }
}
