import SwiftUI

struct FamilyLobbyView: View {
    let lobby: LobbyView
    let client: GameClient

    @State private var confirmingLeave = false
    @State private var isRenaming = false
    @State private var isTakingSelfie = false
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(lobby.members) { member in
                        HStack {
                            AvatarView(name: member.name, jpeg: client.selfies[member.id])
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
                    Text("Waiting for the game to start. Don't show your screen to anyone.")
                }

                Section {
                    if SelfieCamera.isAvailable {
                        Button("Take Selfie", systemImage: "camera") { isTakingSelfie = true }
                    }
                    if lobby.isHead {
                        Button("Rename Family", systemImage: "pencil") {
                            renameText = lobby.familyName
                            isRenaming = true
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Leave", role: .destructive) { confirmingLeave = true }
                }
            }
            .fullScreenCover(isPresented: $isTakingSelfie) {
                SelfieCamera { client.send(.selfie($0)) }.ignoresSafeArea()
            }
            .alert("Rename family", isPresented: $isRenaming) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Rename") { client.send(.renameFamily(renameText)) }
            }
            .confirmationDialog("Leave this family?", isPresented: $confirmingLeave, titleVisibility: .visible) {
                Button("Leave Family", role: .destructive) { client.leave() }
            } message: {
                Text("You can join again with a family code.")
            }
        }
    }
}
