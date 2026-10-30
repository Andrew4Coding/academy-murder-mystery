import SwiftUI

struct RoleView: View {
    let game: GameView
    let boothMap: BoothMap?
    let client: GameClient

    @Environment(\.scenePhase) private var scenePhase
    @State private var isRevealed: Bool
    @State private var isShowingMap = false

    init(game: GameView, boothMap: BoothMap?, client: GameClient, startsRevealed: Bool = false) {
        self.game = game
        self.boothMap = boothMap
        self.client = client
        _isRevealed = State(initialValue: startsRevealed)
    }

    var body: some View {
        NavigationStack {
            ThemedScreen {
                if game.life == .alive {
                    RoleCard(role: game.role, isRevealed: $isRevealed)
                    Text("Keep your role secret. Never show your screen to anyone. It hides again when you leave the app.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    outSection
                }

                if let allies = game.allies, isRevealed || game.life != .alive {
                    ScreenSection(title: "Fellow werewolf families") {
                        if allies.isEmpty {
                            Text("You are the only werewolf family.")
                        }
                        ForEach(allies) { ally in
                            HStack {
                                Text(ally.name)
                                Spacer()
                                Text(ally.life.title).secondaryText()
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                ScreenSection(
                    title: "Your tasks",
                    footer: game.role == .werewolf
                        ? "Pretend to do these so nobody suspects you."
                        : "Visit every booth and complete its challenge."
                ) {
                    ForEach(Array(Booth.allCases.enumerated()), id: \.element) { index, booth in
                        if index > 0 {
                            Divider().overlay(Theme.separator)
                        }
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(booth.title).font(.body.weight(.semibold))
                            Text(booth.instructions).secondaryText()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                if let boothMap {
                    ScreenSection(title: "Venue") {
                        BoothMapCard(map: boothMap) { isShowingMap = true }
                    }
                }
            }
            .navigationTitle(game.familyName)
            .navigationBarTitleDisplayMode(.inline)
            .refreshToolbar(client)
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    isRevealed = false
                }
            }
            .fullScreenCover(isPresented: $isShowingMap) {
                if let boothMap {
                    BoothMapViewer(map: boothMap) { isShowingMap = false }
                }
            }
            .onChange(of: boothMap == nil) { _, gone in
                if gone {
                    isShowingMap = false
                }
            }
        }
    }

    private var outSection: some View {
        ScreenSection(title: "Status") {
            StatusLabel(
                game.life == .killed ? "Your family was eliminated" : "Your family was voted out",
                systemImage: "xmark.circle.fill",
                tint: Theme.accent
            )
            .font(.headline)
            Text(game.role == .werewolf
                ? "You can't vote anymore. Your werewolf family can still use sabotage."
                : "You can't vote anymore, but keep finishing your tasks: "
                + "your team still wins when every villager family is done.")
                .secondaryText()
        }
    }
}

private struct RoleCard: View {
    let role: Role
    @Binding var isRevealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .default) { isRevealed.toggle() }
        } label: {
            VStack(spacing: Spacing.md) {
                Image(systemName: isRevealed ? role.symbol : "eye.slash.fill")
                    .scaledSystemFont(size: 56)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isRevealed ? role.tint : Theme.textSecondary)
                    .accessibilityHidden(true)
                Text(isRevealed ? role.title : "Tap to show your role")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                if isRevealed {
                    Text(role.objective)
                        .font(.body)
                        .multilineTextAlignment(.center)
                    Text("Tap to hide")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, minHeight: 180)
            .padding(Spacing.md)
            .background(isRevealed ? Theme.surfaceRaised : Theme.surface, in: .rect(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(isRevealed ? role.tint : Theme.separator, lineWidth: isRevealed ? 2 : 1)
            )
            .contentShape(.rect(cornerRadius: Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? "Your role: \(role.title). \(role.objective)" : "Role hidden")
        .accessibilityHint(isRevealed ? "Hides your role" : "Shows your role")
    }
}

extension Role {
    var tint: Color {
        switch self {
        case .villager: Theme.success
        case .werewolf: Theme.accent
        }
    }

    var objective: String {
        switch self {
        case .villager: "Finish every family's tasks together, or vote the werewolves out of the village."
        case .werewolf: "Eliminate villager families until there are as many werewolves as villagers, without being caught."
        }
    }
}
