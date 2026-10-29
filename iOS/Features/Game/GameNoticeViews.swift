import SwiftUI

enum GameNotice: Identifiable, Equatable {
    case killed
    case over(Outcome)

    var id: String {
        switch self {
        case .killed: "killed"
        case .over: "over"
        }
    }
}

struct KilledNoticeView: View {
    let onDismiss: () -> Void

    var body: some View {
        NoticeScaffold(
            symbol: "xmark.circle.fill",
            tint: .red,
            title: "You were killed",
            message: "Your whole family is out. Sit at your assigned seat and keep doing your tasks.",
            onDismiss: onDismiss
        )
    }
}

struct GameOverView: View {
    let outcome: Outcome
    let onDismiss: () -> Void

    var body: some View {
        NoticeScaffold(
            symbol: outcome.winner == .villagers ? "house.fill" : "moon.stars.fill",
            tint: outcome.winner == .villagers ? .green : .indigo,
            title: outcome.winner == .villagers ? "Villagers win!" : "Werewolves win!",
            message: outcome.reason.explanation,
            onDismiss: onDismiss
        )
    }
}

private struct NoticeScaffold: View {
    let symbol: String
    let tint: Color
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: symbol)
                .scaledSystemFont(size: 96)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("OK", action: onDismiss)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(tint.opacity(0.12).ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}
