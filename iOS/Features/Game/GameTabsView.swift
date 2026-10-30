import SwiftUI

struct GameTabsView: View {
    let game: GameView
    let client: GameClient

    private enum GameTab: Hashable {
        case family
        case meeting
        case actions
    }

    @State private var selection: GameTab = .family
    @State private var proximity = ProximityService()
    @State private var notice: GameNotice?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TabView(selection: $selection) {
            Tab("Family", systemImage: "house", value: .family) {
                RoleView(game: game, boothMap: client.boothMap)
            }
            Tab("Meeting", systemImage: "person.3", value: .meeting) {
                MeetingView(game: game, client: client)
            }
            if game.role == .werewolf || game.life == .alive {
                Tab("Actions", systemImage: "scope", value: .actions) {
                    ActionsView(game: game, client: client, proximity: proximity)
                }
            }
        }
        .onChange(of: game.phase.isMeeting) { _, isMeeting in
            if isMeeting {
                selection = .meeting
                MeetingAlert.shared.ring(
                    body: game.announcedDeaths.isEmpty
                        ? "A meeting was called. Go to the Town Hall."
                        : "Somebody reported a body. Go to the Town Hall."
                )
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("Refresh", systemImage: "arrow.clockwise") { client.refresh() }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .clipShape(.circle)
                .padding(.trailing, 12)
                .padding(.top, 4)
        }
        .overlay {
            if let startsAt = game.startsAt {
                StartCountdownView(startsAt: startsAt, client: client)
            }
        }
        .safeAreaInset(edge: .top) {
            if let sabotage = game.sabotage {
                SabotageBanner(sabotage: sabotage, client: client)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .default, value: game.sabotage)
        .onChange(of: game.life) { old, new in
            if old == .alive, new == .killed, notice == nil {
                notice = .killed
            }
        }
        .onChange(of: game.phase) { _, phase in
            if case let .ended(outcome) = phase {
                notice = .over(outcome)
            }
        }
        .fullScreenCover(item: $notice) { notice in
            switch notice {
            case .killed: KilledNoticeView { self.notice = nil }
            case let .over(outcome): GameOverView(outcome: outcome) { self.notice = nil }
            }
        }
        .sensoryFeedback(.error, trigger: notice)
        .sensoryFeedback(.warning, trigger: game.phase.isMeeting)
        .sensoryFeedback(.error, trigger: game.sabotage?.startedAt)
        .task(id: game.deadline) { await syncAfterDeadline() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { client.refresh() }
        }
        .task(id: ProximityPlan(game: game, isActive: scenePhase == .active)) { configureProximity() }
        .onDisappear { proximity.stop() }
    }

    private struct ProximityPlan: Hashable {
        let token: String
        let advertise: Bool
        let scan: Bool

        init(game: GameView, isActive: Bool) {
            token = game.bleToken
            let inPlay = isActive && !game.phase.isEnded
            advertise = inPlay && (game.life == .alive || game.bodyActive)
            scan = inPlay && game.life == .alive
        }
    }

    private func syncAfterDeadline() async {
        guard let deadline = game.deadline else { return }
        while !Task.isCancelled {
            let wait = deadline.timeIntervalSince(client.serverNow) + 1
            try? await Task.sleep(for: .seconds(max(wait, 2)))
            guard !Task.isCancelled else { return }
            client.send(.sync)
        }
    }

    private func configureProximity() {
        let plan = ProximityPlan(game: game, isActive: scenePhase == .active)
        guard plan.advertise else {
            proximity.stop()
            return
        }
        proximity.configure(token: plan.token, advertise: true, scan: plan.scan) { [client] sightings in
            client.send(.sightings(sightings))
        }
    }
}

private extension GameView {
    var deadline: Date? {
        let phaseEnd: Date? = switch phase {
        case let .discussion(until), let .voting(until, _): until
        case .running, .ended: nil
        }
        return [phaseEnd, sabotage?.endsAt].compactMap(\.self).min()
    }
}

private extension PhaseView {
    var isEnded: Bool {
        if case .ended = self {
            true
        } else {
            false
        }
    }
}

private struct StartCountdownView: View {
    let startsAt: Date
    let client: GameClient

    @State private var remaining: TimeInterval

    init(startsAt: Date, client: GameClient) {
        self.startsAt = startsAt
        self.client = client
        _remaining = State(initialValue: startsAt.timeIntervalSince(client.serverNow))
    }

    var body: some View {
        Group {
            if remaining > 0 {
                VStack(spacing: 12) {
                    Text("Game starts in").font(.title2)
                    Text("\(Int(remaining.rounded(.up)))")
                        .scaledSystemFont(size: 96, weight: .bold)
                        .monospacedDigit()
                    Text("Get ready. Keep this app open.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .accessibilityElement(children: .combine)
            }
        }
        .task(id: startsAt) {
            while !Task.isCancelled {
                remaining = startsAt.timeIntervalSince(client.serverNow)
                if remaining <= 0 { break }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }
}
