import SwiftUI

struct CountdownView: View {
    let until: Date
    let now: @Sendable (Date) -> Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = max(0, until.timeIntervalSince(now(context.date)).rounded(.up))
            Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
                .monospacedDigit()
                .accessibilityLabel("Time left")
                .accessibilityValue(Self.spoken(remaining))
        }
    }

    static func spoken(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.up))
        let (minutes, rest) = (whole / 60, whole % 60)
        return minutes > 0 ? "\(minutes) minutes \(rest) seconds" : "\(rest) seconds"
    }
}

extension PhaseView {
    var isMeeting: Bool {
        switch self {
        case .discussion, .voting: true
        case .running, .ended: false
        }
    }
}
