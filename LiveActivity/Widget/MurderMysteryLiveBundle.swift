import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MurderMysteryLiveBundle: WidgetBundle {
    var body: some Widget {
        GameLiveActivity()
    }
}

struct GameLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GameActivityAttributes.self) { context in
            LockScreenView(state: context.state, family: context.attributes.familyName, isStale: context.isStale)
                .activityBackgroundTint(context.state.kind.tint.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.kind.symbol)
                        .font(.title2)
                        .foregroundStyle(context.state.kind.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.isStale, let end = context.state.endsAt, end > .now {
                        Text(timerInterval: Date.now ... end, countsDown: true)
                            .monospacedDigit()
                            .frame(width: 64)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.isStale ? "Reconnecting…" : context.state.title).font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.isStale ? "Open the app to refresh." : context.state.detail)
                        .font(.subheadline)
                }
            } compactLeading: {
                Image(systemName: context.state.kind.symbol).foregroundStyle(context.state.kind.tint)
            } compactTrailing: {
                if !context.isStale, let end = context.state.endsAt, end > .now {
                    Text(timerInterval: Date.now ... end, countsDown: true)
                        .monospacedDigit()
                        .frame(width: 44)
                }
            } minimal: {
                Image(systemName: context.state.kind.symbol).foregroundStyle(context.state.kind.tint)
            }
        }
    }
}

private struct LockScreenView: View {
    let state: GameActivityAttributes.ContentState
    let family: String
    let isStale: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state.kind.symbol)
                .font(.largeTitle)
            VStack(alignment: .leading, spacing: 2) {
                Text(isStale ? "Reconnecting…" : state.title).font(.headline)
                Text(isStale ? "Open the app to refresh." : state.detail).font(.subheadline)
                Text(family).font(.caption).opacity(0.8)
            }
            Spacer()
            if !isStale, let end = state.endsAt, end > .now {
                Text(timerInterval: Date.now ... end, countsDown: true)
                    .font(.title2.monospacedDigit().bold())
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .foregroundStyle(.white)
        .padding()
    }
}

private extension GameActivityAttributes.ContentState.Kind {
    var symbol: String {
        switch self {
        case .lobby: "person.3"
        case .playing: "gamecontroller"
        case .discussion: "bubble.left.and.bubble.right"
        case .voting: "hand.raised"
        case .sabotage: "exclamationmark.triangle.fill"
        case .killed: "xmark.circle.fill"
        case .over: "flag.checkered"
        }
    }

    var tint: Color {
        switch self {
        case .sabotage, .killed: .red
        case .discussion, .voting: .orange
        case .over: .indigo
        case .lobby, .playing: .blue
        }
    }
}
