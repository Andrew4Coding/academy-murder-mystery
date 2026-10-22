import SwiftUI

struct FamilyLobbyView: View {
    let lobby: LobbyView
    let client: GameClient

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(lobby.members) { member in
                        HStack {
                            Text(member.name)
                            Spacer()
                            if member.isHead {
                                Label("Head of family", systemImage: "star.fill")
                                    .labelStyle(.titleAndIcon)
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text(lobby.familyName)
                } footer: {
                    Text("Family code \(lobby.joinCode). Waiting for the game to start.")
                }

                Section {
                    if lobby.isHead {
                        Menu("Hand Over to…", systemImage: "arrow.left.arrow.right") {
                            ForEach(lobby.members.filter { !$0.isHead }) { member in
                                Button(member.name) { client.send(.handOverHead(to: member.id)) }
                            }
                        }
                        .disabled(lobby.members.count < 2)
                    } else {
                        Button(lobby.hasHead ? "Take Over as Head of Family" : "Become Head of Family", systemImage: "star") {
                            client.send(.claimHead)
                        }
                    }
                } footer: {
                    Text("The head of family goes to the Town Hall and votes for the whole family.")
                    if let error = client.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Get Ready")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
