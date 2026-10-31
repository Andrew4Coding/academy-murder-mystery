import SwiftUI

struct FamilyLobbyView: View {
    let lobby: LobbyView
    let client: GameClient

    @State private var confirmingLeave = false
    @State private var isRenaming = false
    @State private var isTakingSelfie = false
    @State private var isShowingMap = false
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            ThemedScreen {
                ScreenSection(title: "Your family") {
                    HStack(spacing: Spacing.md) {
                        AvatarView(name: lobby.playerName, jpeg: client.selfies[lobby.playerID], size: 56)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(lobby.familyName).font(.title3.bold())
                            Text(lobby.playerName).secondaryText()
                        }
                    }
                    .accessibilityElement(children: .combine)
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text("Waiting for the organiser to start the game.").secondaryText()
                    }
                    .accessibilityElement(children: .combine)
                }

                Text("Keep your screen private once the game starts: it shows your secret role.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)

                if let map = client.boothMap {
                    ScreenSection(title: "Venue") {
                        BoothMapCard(map: map) { isShowingMap = true }
                    }
                }

                ScreenSection(title: "Get ready") {
                    if SelfieCamera.isAvailable {
                        Button("Take Selfie", systemImage: "camera") { isTakingSelfie = true }
                            .buttonStyle(.secondary)
                            .accessibilityHint("Your photo is shown to other players during meetings")
                    }
                    Button("Rename Family", systemImage: "pencil") {
                        renameText = lobby.familyName
                        isRenaming = true
                    }
                    .buttonStyle(.secondary)
                    if let error = client.lastError {
                        ErrorRow(message: error)
                    }
                }
            }
            .navigationTitle("Get Ready")
            .task {
                BluetoothPermission.shared.request()
                MeetingAlert.shared.prepare()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Leave", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { confirmingLeave = true }
                        .labelStyle(.iconOnly)
                }
            }
            .fullScreenCover(isPresented: $isTakingSelfie) {
                SelfieCamera { client.send(.selfie($0)) }.ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $isShowingMap) {
                if let map = client.boothMap {
                    BoothMapViewer(map: map) { isShowingMap = false }
                }
            }
            .onChange(of: client.boothMap == nil) { _, gone in
                if gone {
                    isShowingMap = false
                }
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
