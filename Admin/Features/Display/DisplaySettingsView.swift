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

        }
        .formStyle(.grouped)
        .navigationTitle("Display")
    }
}
