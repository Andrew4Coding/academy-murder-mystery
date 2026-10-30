import SwiftUI

@main
struct MoonfalliOSApp: App {
    private let client = GameClientRegistry.shared

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let raw = UserDefaults.standard.string(forKey: "GalleryState"), let state = GalleryState(rawValue: raw) {
                GalleryPreview(state)
            } else if ProcessInfo.processInfo.arguments.contains("-Gallery") {
                IOSGalleryView()
            } else {
                RootView(client: client)
            }
            #else
            RootView(client: client)
            #endif
        }
    }
}
