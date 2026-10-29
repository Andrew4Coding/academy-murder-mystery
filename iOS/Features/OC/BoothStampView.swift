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
                Label("Stamp the family's card, then tap that family below.", systemImage: "hand.tap")
                    .font(.headline)
            } header: {
                Text("Stamp a family")
            }
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(rows) { family in
                        Button { select(family) } label: { card(family) }
                            .buttonStyle(.plain)
                            .disabled(family.life != .alive || family.stamped == true)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
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

    private func card(_ family: OCFamilyRow) -> some View {
        let isOut = family.life != .alive
        let isStamped = family.stamped == true
        let tint: Color = isOut ? .gray : isStamped ? .green : family.onList == false ? .orange : .accentColor
        return VStack(spacing: 6) {
            Image(systemName: isStamped ? "checkmark.seal.fill" : "seal")
                .font(.title)
            Text(family.name)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text("\(family.stampsDone) of \(family.stampsTotal) stamps")
                .font(.caption)
            Text(isOut ? "Out of game" : isStamped ? "Stamped" : family.onList == false ? "Not on list" : "Tap to stamp")
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(8)
        .foregroundStyle(tint)
        .background(tint.opacity(0.14), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(tint.opacity(0.5), lineWidth: 1.5))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
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
