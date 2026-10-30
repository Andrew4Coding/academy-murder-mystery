import SwiftUI

struct FamiliesView: View {
    let controller: HostController

    @State private var showRoles = false
    @State private var selection: Set<FamilyID> = []
    @State private var errorMessage: String?

    private var host: GameHost {
        controller.host
    }

    var body: some View {
        Group {
            if let engine = host.state.engine {
                FamilyStatusTable(
                    host: host,
                    game: engine.state,
                    showRoles: showRoles,
                    selection: $selection,
                    onEliminate: eliminate,
                    onRevive: revive
                )
            } else {
                ContentUnavailableView(
                    "No game running",
                    systemImage: "person.3.slash",
                    description: Text("Families appear here once the game starts. Create them from Setup.")
                )
            }
        }
        .themedBackground()
        .navigationTitle("Families")
        .toolbar {
            ToolbarItem {
                Toggle("Show Roles", systemImage: showRoles ? "eye" : "eye.slash", isOn: $showRoles)
                    .help("Anyone who can see this screen will see every family's role")
            }
            ToolbarItem {
                Button("Eliminate", systemImage: "xmark.circle") { eliminate(selection) }
                    .disabled(selection.isEmpty)
                    .help("Eliminate the selected families")
            }
            ToolbarItem {
                Button("Revive", systemImage: "arrow.uturn.backward.circle") { revive(selection) }
                    .disabled(selection.isEmpty)
                    .help("Bring the selected families back")
            }
        }
        .alert("Can't do that", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func eliminate(_ ids: Set<FamilyID>) {
        for id in ids {
            attempt { try host.applyAsOC(.override(.forceKill(id))) }
        }
    }

    private func revive(_ ids: Set<FamilyID>) {
        for id in ids {
            attempt { try host.applyAsOC(.override(.revive(id))) }
        }
    }

    private func attempt(_ action: () throws -> Void) {
        do { try action() } catch let error as RuleError { errorMessage = error.message } catch let error as HostError {
            errorMessage = error.message
        } catch { errorMessage = "\(error)" }
    }
}

struct FamilyStatusTable: View {
    let host: GameHost
    let game: GameState
    let showRoles: Bool
    @Binding var selection: Set<FamilyID>
    let onEliminate: (Set<FamilyID>) -> Void
    let onRevive: (Set<FamilyID>) -> Void

    private var rows: [Family] {
        game.families.values.sorted { $0.id < $1.id }
    }

    var body: some View {
        Table(rows, selection: $selection) {
            TableColumn("Family") { (family: Family) in
                Text(host.state.families[family.id]?.name ?? "Unknown")
            }
            TableColumn("Status") { (family: Family) in
                StatusLabel(
                    family.life.title,
                    systemImage: family.isAlive ? "checkmark.circle.fill" : "xmark.circle.fill",
                    tint: family.isAlive ? Theme.success : Theme.accent
                )
            }
            TableColumn("Role") { (family: Family) in
                if showRoles {
                    Label(family.role.title, systemImage: family.role.symbol)
                } else {
                    Text("Hidden").foregroundStyle(Theme.textSecondary)
                }
            }
            TableColumn("Tasks") { (family: Family) in
                Text(family.tasks.map(\.rawValue).sorted().map(String.init).joined(separator: ", "))
            }
            TableColumn("Vote") { (family: Family) in
                Text(voteStatus(family))
            }
        }
        .scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: FamilyID.self) { ids in
            Divider()
            Button("Eliminate Family", systemImage: "xmark.circle") { onEliminate(ids) }
                .disabled(ids.isEmpty)
            Button("Revive Family", systemImage: "arrow.uturn.backward.circle") { onRevive(ids) }
                .disabled(ids.isEmpty)
        }
    }

    private func voteStatus(_ family: Family) -> String {
        guard case .voting = game.phase, family.isAlive else { return "" }
        return game.votes[family.id] == nil ? "Waiting" : "Voted"
    }
}
