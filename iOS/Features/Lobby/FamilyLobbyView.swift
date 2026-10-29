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
                    HStack {
                        AvatarView(name: lobby.playerName, jpeg: client.selfies[lobby.playerID])
                        Text(lobby.playerName)
                    }
                    .accessibilityElement(children: .combine)
                } header: {
                    Text(lobby.familyName)
                } footer: {
                    Text("Waiting for the game to start. Don't show your screen to anyone.")
                }

                Section {
                    if SelfieCamera.isAvailable {
                        Button("Take Selfie", systemImage: "camera") { isTakingSelfie = true }
                    }
                    Button("Rename Family", systemImage: "pencil") {
                        renameText = lobby.familyName
                        isRenaming = true
                    }
                } footer: {
                    if let error = client.lastError {
                        StatusLabel.error(error)
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
                Text("You can join again by scanning the QR.")
            }
        }
    }
}
