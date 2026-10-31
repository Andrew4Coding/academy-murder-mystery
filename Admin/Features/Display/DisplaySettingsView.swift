import SwiftUI

struct DisplaySettingsView: View {
    let controller: HostController
    let mode: HostModeController

    @Environment(\.openWindow) private var openWindow

    private static let canvas = CGSize(width: 1920, height: 1080)

    var body: some View {
        Form {
            Section {
                Button("Open Public Display", systemImage: "tv") {
                    openWindow(id: PublicDisplayWindow.id)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .themedRows()
            } footer: {
                Text("The Public Display shows timers, vote results and reveals for the lab screens. It never shows roles, tasks or votes.")
            }

            Section("Live preview") {
                Color.clear
                    .aspectRatio(Self.canvas.width / Self.canvas.height, contentMode: .fit)
                    .overlay {
                        GeometryReader { proxy in
                            PublicDisplayView(controller: controller, mode: mode, playsSound: false)
                                .frame(width: Self.canvas.width, height: Self.canvas.height)
                                .scaleEffect(proxy.size.width / Self.canvas.width, anchor: .topLeading)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 12))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .themedRows()
            }
        }
        .formStyle(.grouped)
        .themedBackground()
        .navigationTitle("Display")
    }
}
