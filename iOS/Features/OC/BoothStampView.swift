import SwiftUI

struct BoothStampView: View {
    let booth: Booth
    let oc: OCView?
    let client: GameClient

    private struct Recent: Identifiable {
        let id = UUID()
        let family: OCFamilyRow
        let at: Date
    }

    @State private var search = ""
    @State private var pending: OCFamilyRow?
    @State private var recent: [Recent] = []
    @State private var stampCount = 0

    private var rows: [OCFamilyRow] {
        let all = oc?.families ?? []
        guard !search.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if oc == nil || oc?.families.isEmpty == true {
                    WaitingForGameView()
                } else {
                    list
                }
            }
            .navigationTitle(booth.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { OCSignOutButton(client: client) } }
            .sensoryFeedback(.success, trigger: stampCount)
        }
    }

    private var list: some View {
        List {
            if let error = client.lastError {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            }
            if !recent.isEmpty {
                Section("Just stamped") {
                    ForEach(recent) { item in
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            HStack {
                                Text(item.family.name)
                                Spacer()
                                if context.date.timeIntervalSince(item.at) < GameHost.undoWindow {
                                    Button("Undo") { undo(item) }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
            Section {
                ForEach(rows) { family in
                    Button { select(family) } label: { row(family) }
                        .foregroundStyle(.primary)
                        .disabled(family.life != .alive || family.stamped == true)
                }
            } header: {
                Text("Families")
            } footer: {
                Text("Stamp the family's card, then confirm here.")
            }
        }
        .searchable(text: $search, prompt: "Find a family")
        .confirmationDialog(
            pending.map { "Stamp \($0.name)?" } ?? "",
            isPresented: Binding(get: { pending != nil }, set: {
                if !$0 {
                    pending = nil
                }
            }),
            titleVisibility: .visible
        ) {
            if let family = pending {
                Button("Stamp for \(booth.title)") { stamp(family, confirmOffList: false) }
            }
        }
        .alert(
            "Not on this family's list",
            isPresented: Binding(get: { offList != nil }, set: {
                if !$0 {
                    offList = nil
                }
            }),
            presenting: offList
        ) { family in
            Button("Stamp Anyway", role: .destructive) { stamp(family, confirmOffList: true) }
            Button("Cancel", role: .cancel) {}
        } message: { family in
            Text("\(family.name) doesn't need \(booth.title). A stamp here won't count toward their tasks.")
        }
    }

    @State private var offList: OCFamilyRow?

    private func row(_ family: OCFamilyRow) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(family.name)
                Text("\(family.stampsDone) of \(family.stampsTotal) stamps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if family.life != .alive {
                Text("Out of game").foregroundStyle(.secondary)
            } else if family.stamped == true {
                Label("Stamped", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else if family.onList == false {
                Text("Not on list").foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
    }

    private func select(_ family: OCFamilyRow) {
        if family.onList == false {
            offList = family
        } else {
            pending = family
        }
    }

    private func stamp(_ family: OCFamilyRow, confirmOffList: Bool) {
        client.send(.stamp(family: family.id, confirmOffList: confirmOffList))
        recent.insert(Recent(family: family, at: Date()), at: 0)
        recent = Array(recent.prefix(5))
        stampCount += 1
    }

    private func undo(_ item: Recent) {
        client.send(.undoStamp(family: item.family.id))
        recent.removeAll { $0.id == item.id }
    }
}
