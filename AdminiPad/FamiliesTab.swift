import SwiftUI

struct FamiliesTab: View {
    let admin: AdminView
    let client: GameClient

    @State private var showRoles = false
    @State private var selection: Set<FamilyID> = []
    @State private var deleting: AdminFamilyRow?

    var body: some View {
        Group {
            if admin.families.isEmpty {
                ContentUnavailableView(
                    "No families yet",
                    systemImage: "person.3.slash",
                    description: Text("Families appear here once players join with the game code.")
                )
            } else {
                List(selection: $selection) {
                    ForEach(admin.families) { family in
                        FamilyRow(family: family, showRoles: showRoles, isVoting: isVoting)
                            .tag(family.id)
                            .swipeActions(edge: .trailing) {
                                if admin.isLobby {
                                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = family }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if !admin.isLobby {
                                    if family.life == .alive {
                                        Button("Eliminate", systemImage: "xmark.circle") { client.send(.admin(.eliminate([family.id]))) }
                                            .tint(.red)
                                    } else {
                                        Button("Revive", systemImage: "arrow.uturn.backward.circle") { client.send(.admin(.revive([family.id]))) }
                                            .tint(.green)
                                    }
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Families")
        .toolbar {
            ToolbarItem {
                Toggle("Show Roles", systemImage: showRoles ? "eye" : "eye.slash", isOn: $showRoles)
            }
            ToolbarItem {
                Button("Eliminate", systemImage: "xmark.circle") { client.send(.admin(.eliminate(Array(selection)))) }
                    .disabled(selection.isEmpty || admin.isLobby)
            }
            ToolbarItem {
                Button("Revive", systemImage: "arrow.uturn.backward.circle") { client.send(.admin(.revive(Array(selection)))) }
                    .disabled(selection.isEmpty || admin.isLobby)
            }
            ToolbarItem {
                EditButton()
            }
        }
        .confirmationDialog(
            deleting.map { "Delete \($0.name)?" } ?? "",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            if let family = deleting {
                Button("Delete \(family.name)", role: .destructive) {
                    client.send(.admin(.removeFamily(family.id)))
                    deleting = nil
                }
            }
        } message: {
            Text("The player in this family goes back to the join screen.")
        }
    }

    private var isVoting: Bool {
        if case .voting = admin.phase {
            true
        } else {
            false
        }
    }
}

private struct FamilyRow: View {
    let family: AdminFamilyRow
    let showRoles: Bool
    let isVoting: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading) {
                Text(family.name).font(.headline)
                Text(family.playerName ?? "Waiting\u{2026}").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Label(family.life.title, systemImage: family.life == .alive ? "checkmark.circle" : "xmark.circle")
            if showRoles, let role = family.role {
                Label(role.title, systemImage: role.symbol)
            }
            if !family.tasks.isEmpty {
                Text(family.tasks.map(\.rawValue).sorted().map(String.init).joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
            if isVoting, family.life == .alive {
                Text(family.voted ? "Voted" : "Waiting").foregroundStyle(.secondary)
            }
        }
    }
}
