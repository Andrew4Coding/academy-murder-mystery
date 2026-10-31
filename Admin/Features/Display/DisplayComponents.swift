import AppKit
import SwiftUI

struct StageBackground: View {
    let alarmActive: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                (alarmActive ? DisplayPalette.alarmBase : DisplayPalette.base)
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: proxy.size.height * 0.24, height: proxy.size.height * 0.24)
                    .position(x: proxy.size.width * 0.86, y: proxy.size.height * 0.2)
                Image(systemName: Role.werewolf.symbol)
                    .font(.system(size: proxy.size.height * 0.62))
                    .foregroundStyle(.white.opacity(0.05))
                    .rotationEffect(.degrees(-12))
                    .position(x: proxy.size.width * 0.12, y: proxy.size.height * 0.88)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct DisplayCard<Content: View>: View {
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(28)
            .background(tint ?? DisplayPalette.card, in: .rect(cornerRadius: 28))
    }
}

struct Eyebrow: View {
    let text: String
    var systemImage: String?

    init(_ text: String, systemImage: String? = nil) {
        self.text = text
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 14) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text.uppercased()).tracking(8)
        }
        .font(.stageRounded(34, weight: .bold))
        .foregroundStyle(DisplayPalette.redText)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

struct FaceView: View {
    let selfie: Data?
    let initial: String
    let size: CGFloat

    var body: some View {
        if let selfie, let image = NSImage(data: selfie) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.circle)
        } else {
            Text(initial.uppercased())
                .font(.stageRounded(size * 0.46, weight: .bold))
                .foregroundStyle(DisplayPalette.primary)
                .frame(width: size, height: size)
                .background(DisplayPalette.redFill.opacity(0.65), in: .circle)
        }
    }
}

struct Headline: View {
    let title: String
    let detail: String
    var systemImage: String?
    var tint: Color = DisplayPalette.primary

    var body: some View {
        VStack(spacing: 28) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 120, weight: .semibold))
                    .foregroundStyle(DisplayPalette.redText)
            }
            Text(title)
                .font(.stage(200))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            Text(detail)
                .font(.stageRounded(54, weight: .medium))
                .foregroundStyle(DisplayPalette.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TimerBlock: View {
    let title: String
    let until: Date
    let now: Date
    var compact = false

    private var remaining: TimeInterval {
        max(0, until.timeIntervalSince(now))
    }

    private var isUrgent: Bool {
        remaining <= PublicDisplayLayout.urgentSeconds
    }

    private var ringSize: CGFloat {
        compact ? 460 : 620
    }

    var body: some View {
        VStack(spacing: 28) {
            Eyebrow(title)
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 20)
                Circle()
                    .trim(from: 0, to: min(remaining, PublicDisplayLayout.ringSeconds) / PublicDisplayLayout.ringSeconds)
                    .stroke(
                        isUrgent ? DisplayPalette.redText : DisplayPalette.redBright,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 12) {
                    Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
                        .font(.stageDigits(ringSize * 0.31))
                        .foregroundStyle(isUrgent ? DisplayPalette.redText : DisplayPalette.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if isUrgent {
                        Label("Final seconds", systemImage: "exclamationmark.triangle.fill")
                            .font(.stageRounded(40, weight: .bold))
                            .foregroundStyle(DisplayPalette.redText)
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(width: ringSize, height: ringSize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(Duration.seconds(remaining).spoken)
    }
}

struct VotesCast: View {
    let cast: Int
    let total: Int

    var body: some View {
        VStack(spacing: 16) {
            Label("\(cast) of \(total) families have voted", systemImage: "checkmark.seal.fill")
                .font(.stageRounded(44, weight: .semibold))
                .foregroundStyle(DisplayPalette.primary)
            Capsule()
                .fill(.white.opacity(0.12))
                .frame(width: 640, height: 16)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(DisplayPalette.redBright)
                        .frame(width: total > 0 ? 640 * CGFloat(cast) / CGFloat(total) : 0)
                }
        }
        .accessibilityElement(children: .combine)
    }
}

struct DeathList: View {
    let names: [String]

    var body: some View {
        DisplayCard {
            VStack(spacing: 24) {
                Eyebrow("Since the last meeting", systemImage: "moon.zzz.fill")
                if names.isEmpty {
                    Label("No families were eliminated", systemImage: "checkmark.circle.fill")
                        .font(.stageRounded(44, weight: .semibold))
                        .foregroundStyle(DisplayPalette.primary)
                } else {
                    CenteredFlowLayout(spacing: 16) {
                        ForEach(names, id: \.self) { name in
                            Label(name, systemImage: "xmark.circle.fill")
                                .font(.stage(56))
                                .foregroundStyle(DisplayPalette.primary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(DisplayPalette.redFill, in: .capsule)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 820)
        .accessibilityElement(children: .combine)
    }
}

struct AlarmBanner: View {
    let alarm: PublicDisplayState.Alarm
    let now: Date
    let animate: Bool
    let playsSound: Bool

    @State private var sound = AdminSound("alarm", loops: true)

    var body: some View {
        HStack(spacing: 28) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64, weight: .bold))
                .symbolEffect(.pulse, isActive: animate)
            Text("SABOTAGE: \(alarm.kind.title)")
                .font(.stage(64))
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 16)
            Label {
                Text(Duration.seconds(max(0, alarm.endsAt.timeIntervalSince(now))), format: .time(pattern: .minuteSecond))
                    .font(.stageDigits(64))
            } icon: {
                Image(systemName: "timer").font(.system(size: 48, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 36)
        .padding(.vertical, 20)
        .background(DisplayPalette.redFill, in: .rect(cornerRadius: 28))
        .onAppear {
            if playsSound {
                sound.play()
            }
        }
        .onDisappear { sound.stop() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sabotage alarm: \(alarm.kind.title)")
        .accessibilityValue(Duration.seconds(max(0, alarm.endsAt.timeIntervalSince(now))).spoken)
    }
}

struct CenteredFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = rows(in: proposal.width ?? .infinity, subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var originY = bounds.minY
        for row in rows(in: bounds.width, subviews) {
            var originX = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: originX, y: originY), proposal: ProposedViewSize(size))
                originX += size.width + spacing
            }
            originY += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(in maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let added = rows[rows.count - 1].indices.isEmpty ? size.width : spacing + size.width
            if rows[rows.count - 1].width + added > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let isFirst = rows[rows.count - 1].indices.isEmpty
            rows[rows.count - 1].width += isFirst ? size.width : spacing + size.width
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            rows[rows.count - 1].indices.append(index)
        }
        return rows
    }
}

private extension Duration {
    var spoken: String {
        formatted(.units(allowed: [.minutes, .seconds], width: .wide)) + " remaining"
    }
}

struct FitToStage<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var natural: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let scale = natural > proxy.size.height && natural > 0 ? proxy.size.height / natural : 1
            content
                .frame(width: proxy.size.width)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { natural = $0 }
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
