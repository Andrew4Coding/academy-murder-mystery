import ActivityKit
import SwiftUI
import WidgetKit

struct GameLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GameActivityAttributes.self) { context in
            LockScreenView(state: context.state, isStale: context.isStale)
                .padding(16)
                .activityBackgroundTint(.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let isStale = context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: isStale ? "arrow.clockwise" : state.kind.symbol)
                        .foregroundStyle(isStale ? .gray : state.kind.tint)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(end: state.countdownEnd, isStale: isStale)
                        .font(.title2.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(isStale ? "Open Moonfall to refresh" : state.kind.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TaskProgressRow(state: state)
                }
            } compactLeading: {
                Image(systemName: isStale ? "arrow.clockwise" : state.kind.symbol)
                    .foregroundStyle(isStale ? .gray : state.kind.tint)
            } compactTrailing: {
                if let end = state.countdownEnd, !isStale, end > .now {
                    CountdownText(end: end, isStale: false)
                        .monospacedDigit()
                        .frame(maxWidth: 52)
                } else {
                    Text("\(state.tasksDone)/\(state.tasksTotal)")
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: isStale ? "arrow.clockwise" : state.kind.symbol)
                    .foregroundStyle(isStale ? .gray : state.kind.tint)
            }
        }
    }
}

private struct LockScreenView: View {
    let state: GameActivityState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(isStale ? "Open Moonfall to refresh" : state.kind.title)
                        .font(.headline)
                } icon: {
                    Image(systemName: isStale ? "arrow.clockwise" : state.kind.symbol)
                        .foregroundStyle(isStale ? .gray : state.kind.tint)
                }
                Spacer()
                CountdownText(end: state.countdownEnd, isStale: isStale)
                    .font(.title.monospacedDigit().bold())
            }
            TaskProgressRow(state: state)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

private struct CountdownText: View {
    let end: Date?
    let isStale: Bool

    var body: some View {
        if let end, !isStale, end > .now {
            Text(timerInterval: .now ... end, countsDown: true)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct TaskProgressRow: View {
    let state: GameActivityState

    var body: some View {
        if state.isEnded {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Booths stamped \(state.tasksDone) of \(state.tasksTotal)")
                    .font(.subheadline)
                ProgressView(value: Double(state.tasksDone), total: Double(max(state.tasksTotal, 1)))
                    .tint(.green)
            }
        }
    }
}
