import SwiftUI

struct DisplaySettingsView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section {
                Button("Open Public Display", systemImage: "tv") {
                    openWindow(id: PublicDisplayWindow.id)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            } footer: {
                Text("The Public Display shows timers, vote results and reveals for the lab screens. It never shows roles, tasks or votes.")
            }

            Section("Sending it to the lab screens") {
                Label("Open Control Center, choose Screen Mirroring and pick the Lab 1 or Lab 2 display.", systemImage: "airplayvideo")
                Label("Or drag the Public Display window to a second display.", systemImage: "rectangle.on.rectangle")
                Label("Then enter full screen with Control-Command-F.", systemImage: "arrow.up.left.and.arrow.down.right")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Display")
    }
}
