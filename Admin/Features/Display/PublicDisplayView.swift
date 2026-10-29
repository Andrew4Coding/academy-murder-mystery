import Charts
import SwiftUI

enum PublicDisplayWindow {
    static let id = "public-display"
}

struct PublicDisplayView: View {
    let controller: HostController

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isRunning: Bool {
        if case .running = controller.status {
            true
        } else {
            false
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let display = controller.host.publicDisplayState(hostRunning: isRunning)
            let now = controller.host.clock.now
            VStack(spacing: 32) {
                if let alarm = display.alarm {
                    AlarmBanner(alarm: alarm, now: now, animate: !reduceMotion)
                }
                Spacer(minLength: 0)
                content(display, now: now)
                Spacer(minLength: 0)
                if let remaining = display.familiesRemaining {
                    Text("\(remaining) families still in the game")
                        .font(.system(size: PublicDisplayLayout.detailFontSize))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
        }
    }

    @ViewBuilder
    private func content(_ display: PublicDisplayState, now: Date) -> some View {
        switch display.screen {
        case .hostOffline:
            Headline("Host offline", detail: "The game host isn't running.")
        case .waiting:
            JoinBlock(code: display.joinCode, joined: controller.host.state.players.count)
        case let .playing(gameEndsAt):
            TimerBlock(title: "Time until the final vote", until: gameEndsAt, now: now)
        case let .discussion(until):
            TimerBlock(title: "Discussion", until: until, now: now)
            DeathList(names: display.announcedDeaths)
        case let .voting(until, isFinal, cast, total):
            TimerBlock(title: isFinal ? "Final vote" : "Voting", until: until, now: now)
            Text("\(cast) of \(total) families have voted")
                .font(.system(size: PublicDisplayLayout.detailFontSize))
        case let .result(result):
            ResultBlock(result: result)
        case let .ended(outcome):
            Headline(
                outcome.winner == .villagers ? "Villagers win!" : "Werewolves win!",
                detail: outcome.reason.explanation
            )
        }
    }
}

private struct JoinBlock: View {
    let code: String?
    let joined: Int

    var body: some View {
        VStack(spacing: 24) {
            Text("Scan to join")
                .font(.system(size: PublicDisplayLayout.headlineFontSize, weight: .semibold))
            if let code {
                QRCodeView(text: code)
                    .frame(width: 420, height: 420)
                    .padding(16)
                    .background(.white)
                Text(code)
                    .font(.system(size: PublicDisplayLayout.detailFontSize, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
            }
            Text("\(joined) players joined")
                .font(.system(size: PublicDisplayLayout.detailFontSize))
                .foregroundStyle(.white.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Headline: View {
    let title: String
    let detail: String

    init(_ title: String, detail: String) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: PublicDisplayLayout.timerFontSize * 0.6, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: PublicDisplayLayout.headlineFontSize))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TimerBlock: View {
    let title: String
    let until: Date
    let now: Date

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: PublicDisplayLayout.headlineFontSize, weight: .semibold))
            Text(Duration.seconds(max(0, until.timeIntervalSince(now))), format: .time(pattern: .minuteSecond))
                .font(.system(size: PublicDisplayLayout.timerFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DeathList: View {
    let names: [String]

    var body: some View {
        VStack(spacing: 8) {
            Text("Since the last meeting")
                .font(.system(size: PublicDisplayLayout.detailFontSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            if names.isEmpty {
                Text("No families were eliminated")
                    .font(.system(size: PublicDisplayLayout.headlineFontSize * 0.7))
            } else {
                Text(names.joined(separator: ", "))
                    .font(.system(size: PublicDisplayLayout.headlineFontSize * 0.7, weight: .bold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct ResultBlock: View {
    let result: VoteResultView

    var body: some View {
        VStack(spacing: 24) {
            Text(result.isFinal ? "Final vote result" : "Vote result")
                .font(.system(size: PublicDisplayLayout.headlineFontSize, weight: .semibold))
            if let expelled = result.expelled.first {
                Text("\(expelled.name) was voted out")
                    .font(.system(size: PublicDisplayLayout.headlineFontSize * 1.4, weight: .bold))
                Label(
                    "\(expelled.role.title) family",
                    systemImage: expelled.role.symbol
                )
                .font(.system(size: PublicDisplayLayout.headlineFontSize * 1.2, weight: .bold))
                .foregroundStyle(expelled.role == .werewolf ? .red : .blue)
            } else {
                Text("Nobody was voted out")
                    .font(.system(size: PublicDisplayLayout.headlineFontSize * 1.4, weight: .bold))
            }
            if !result.rows.isEmpty {
                Chart(result.rows) { row in
                    BarMark(x: .value("Votes", row.count), y: .value("Candidate", row.name))
                        .foregroundStyle(row.isSkip ? Color.gray : Color.red)
                        .annotation(position: .trailing) {
                            Text("\(row.count)").font(.system(size: PublicDisplayLayout.detailFontSize, design: .rounded))
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.system(size: PublicDisplayLayout.detailFontSize * 0.8))
                    }
                }
                .frame(maxWidth: 1000, maxHeight: 420)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}

private struct AlarmBanner: View {
    let alarm: PublicDisplayState.Alarm
    let now: Date
    let animate: Bool

    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolEffect(.pulse, isActive: animate)
            Text("SABOTAGE: \(alarm.kind.title)")
            Spacer()
            Text(Duration.seconds(max(0, alarm.endsAt.timeIntervalSince(now))), format: .time(pattern: .minuteSecond))
                .monospacedDigit()
        }
        .font(.system(size: PublicDisplayLayout.headlineFontSize, weight: .bold))
        .padding(24)
        .background(.red, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}
