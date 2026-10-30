import SwiftUI

struct RoleView: View {
    let game: GameView
    let boothMap: BoothMap?

    @Environment(\.scenePhase) private var scenePhase
    @State private var isRevealed = false
    @State private var isShowingMap = false

    var body: some View {
        NavigationStack {
            List {
                if game.life == .alive {
                    Section {
                        RoleCard(role: game.role, isRevealed: $isRevealed)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } footer: {
                        Text("Keep your role secret. Never show your screen to anyone. It hides again when you leave the app.")
                    }
                }

                if game.life != .alive {
                    Section {
                        StatusLabel(
                            game.life == .killed ? "Your family was eliminated" : "Your family was voted out",
                            systemImage: "xmark.circle.fill",
                            tint: .red
                        )
                        Text(game.role == .werewolf
                            ? "You can't vote anymore. Your werewolf family can still use sabotage."
                            : "You can't vote anymore, but keep finishing your tasks: "
                            + "your team still wins when every villager family is done.")
                    }
                }

                Section {
                    ForEach(game.tasks, id: \.self) { booth in
                        Text(booth.title)
                    }
                } header: {
                    Text("Your booths")
                } footer: {
                    Text(game.role == .werewolf
                        ? "Pretend to do these so nobody suspects you."
                        : "Visit these booths and complete their challenges.")
                }

                if let allies = game.allies, isRevealed || game.life != .alive {
                    Section("Fellow werewolf families") {
                        if allies.isEmpty {
                            Text("You are the only werewolf family.")
                        }
                        ForEach(allies) { ally in
                            HStack {
                                Text(ally.name)
                                Spacer()
                                Text(ally.life.title).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let boothMap {
                    Section {
                        BoothMapCard(map: boothMap) { isShowingMap = true }
                    }
                }

                Section {
                    LabeledContent("Family", value: game.familyName)
                }
            }
            .navigationTitle(game.familyName)
            .navigationBarTitleDisplayMode(.inline)
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
                if gone { isShowingMap = false }
            }
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
            VStack(spacing: 12) {
                Image(systemName: isRevealed ? role.symbol : "eye.slash.fill")
                    .scaledSystemFont(size: 56)
                    .symbolRenderingMode(.hierarchical)
                Text(isRevealed ? role.title : "Tap to show your role")
                    .font(.title.bold())
                if isRevealed {
                    Text(role.objective)
                        .font(.body)
                        .multilineTextAlignment(.center)
                    Text("Tap to hide")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .padding()
            .background(isRevealed ? role.tint.opacity(0.15) : Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            .foregroundStyle(isRevealed ? role.tint : .primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityLabel(isRevealed ? "Your role: \(role.title). \(role.objective)" : "Role hidden")
        .accessibilityHint(isRevealed ? "Hides your role" : "Shows your role")
    }
}

extension Role {
    var tint: Color {
        switch self {
        case .villager: .blue
        case .werewolf: .red
        }
    }

    var objective: String {
        switch self {
        case .villager: "Finish every family's tasks together, or vote the werewolves out of the village."
        case .werewolf: "Eliminate villager families until there are as many werewolves as villagers, without being caught."
        }
    }
}
