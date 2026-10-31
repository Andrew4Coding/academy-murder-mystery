import AppKit
import SwiftUI

enum PublicDisplayWindow {
    static let id = "public-display"
}

struct PublicDisplayView: View {
    let controller: HostController
    let mode: HostModeController
    var playsSound = true

    private var inCloud: Bool {
        mode.phase == .cloud
    }

    private var cloudDisplay: PublicDisplayState {
        guard let client = mode.adminClient, client.status == .connected, let display = client.display else {
            return PublicDisplayState(screen: .hostOffline, familiesRemaining: nil, alarm: nil, announcedDeaths: [])
        }
        return display
    }

    private var isRunning: Bool {
        if case .running = controller.status {
            true
        } else {
            false
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            PublicDisplayScreen(
                display: inCloud ? cloudDisplay : controller.host.publicDisplayState(hostRunning: isRunning),
                now: inCloud ? (mode.adminClient?.serverNow ?? Date()) : controller.host.clock.now,
                joinedCount: inCloud ? nil : controller.host.state.players.count
            )
        }
        .onChange(of: isDiscussionOpen) { _, open in
            if open, playsSound {
                NSSound(named: "Hero")?.play()
            }
        }
    }

    private var isDiscussionOpen: Bool {
        if inCloud {
            if case .discussion = cloudDisplay.screen {
                return true
            }
            return false
        }
        if case .discussion? = controller.host.state.engine?.state.phase {
            return true
        }
        return false
    }
}

struct PublicDisplayScreen: View {
    let display: PublicDisplayState
    let now: Date
    var joinedCount: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsFixed = false
    @State private var fixedToken = 0

    private var bannerAnimation: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.5)
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / PublicDisplayLayout.canvas.width, proxy.size.height / PublicDisplayLayout.canvas.height)
            stage
                .frame(width: proxy.size.width / scale, height: proxy.size.height / scale)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(DisplayPalette.base)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .onChange(of: display.alarm) { old, new in
            guard old != nil, new == nil, !isEnded else { return }
            showsFixed = true
            fixedToken += 1
        }
        .task(id: fixedToken) {
            guard showsFixed else { return }
            try? await Task.sleep(for: .seconds(3))
            showsFixed = false
        }
    }

    private var isEnded: Bool {
        if case .ended = display.screen {
            true
        } else {
            false
        }
    }

    private var stage: some View {
        VStack(spacing: 32) {
            if let alarm = display.alarm {
                AlarmBanner(
                    alarm: alarm,
                    now: display.alarmPausedAt ?? now,
                    animate: !reduceMotion,
                    isPaused: display.alarmPausedAt != nil
                )
                .transition(banner)
            } else if showsFixed {
                SabotageFixedBanner()
                    .transition(banner)
            }
            FitToStage { content }
            if let remaining = display.familiesRemaining {
                Label("\(remaining) families still in the game", systemImage: "person.2.fill")
                    .font(.stageRounded(38, weight: .medium))
                    .foregroundStyle(DisplayPalette.secondary)
            }
        }
        .padding(.horizontal, PublicDisplayLayout.safeInsetX)
        .padding(.vertical, PublicDisplayLayout.safeInsetY)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(DisplayPalette.primary)
        .background { StageBackground(alarmActive: display.alarm != nil) }
        .animation(bannerAnimation, value: display.alarm != nil)
        .animation(bannerAnimation, value: showsFixed)
    }

    private var banner: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    private var screenNow: Date {
        display.pausedAt ?? now
    }

    private var compact: Bool {
        display.alarm != nil
    }

    @ViewBuilder
    private var content: some View {
        switch display.screen {
        case .hostOffline:
            Headline(title: "Host offline", detail: "The game host isn't running.", systemImage: "wifi.slash")
        case .waiting:
            JoinBlock(
                code: display.joinCode,
                joined: joinedCount ?? display.lobbyFamilies.filter { $0.player != nil }.count,
                families: display.lobbyFamilies
            )
        case let .starting(at):
            TimerBlock(title: "Game starts in", until: at, now: now, compact: compact)
        case let .playing(gameEndsAt):
            TimerBlock(title: "Time until the final vote", until: gameEndsAt, now: screenNow, compact: compact, isPaused: display.pausedAt != nil)
        case let .discussion(until):
            HStack(spacing: 64) {
                TimerBlock(title: "Discussion", until: until, now: screenNow, compact: true, isPaused: display.pausedAt != nil)
                DeathList(names: display.announcedDeaths)
            }
        case let .voting(until, isFinal, cast, total):
            VStack(spacing: 32) {
                TimerBlock(title: isFinal ? "Final vote" : "Voting", until: until, now: screenNow, compact: true, isPaused: display.pausedAt != nil)
                VotesCast(cast: cast, total: total)
            }
        case let .result(result):
            ResultBlock(result: result)
        case let .ended(outcome):
            if display.reveal.isEmpty {
                Headline(
                    title: outcome.winner == .villagers ? "Villagers win!" : "Werewolves win!",
                    detail: outcome.reason.explanation,
                    systemImage: outcome.winner == .villagers ? "sun.max.fill" : Role.werewolf.symbol
                )
            } else {
                RevealBlock(outcome: outcome, families: display.reveal)
            }
        }
    }
}
