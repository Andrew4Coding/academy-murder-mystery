#if DEBUG
    import SwiftUI

    private struct TabScreen<Content: View>: View {
        @State private var client: GameClient
        private let admin: AdminView
        private let content: (AdminView, GameClient) -> Content

        init(_ admin: AdminView, @ViewBuilder content: @escaping (AdminView, GameClient) -> Content) {
            self.admin = admin
            _client = State(initialValue: AdminFixtures.client())
            self.content = content
        }

        var body: some View {
            NavigationStack { content(admin, client) }
        }
    }

    private struct SignInScreen: View {
        @State private var client: GameClient

        init(status: ConnectionStatus, error: String? = nil) {
            _client = State(initialValue: AdminFixtures.client(status: status, error: error))
        }

        var body: some View {
            PinView(client: client)
        }
    }

    private struct DashboardScreen: View {
        let admin: AdminView
        @State private var client = AdminFixtures.client()

        var body: some View {
            DashboardView(admin: admin, client: client)
        }
    }

    struct PadGalleryEntry: Identifiable {
        let id: String
        let title: String
        let screen: AnyView

        init(_ title: String, @ViewBuilder screen: () -> some View) {
            id = title
            self.title = title
            self.screen = AnyView(screen())
        }
    }

    @MainActor
    enum PadScreens {
        static let signIn: [PadGalleryEntry] = [
            PadGalleryEntry("Sign in: ready") { SignInScreen(status: .connected) },
            PadGalleryEntry("Sign in: searching for host") { SignInScreen(status: .searching) },
            PadGalleryEntry("Sign in: wrong PIN") {
                SignInScreen(status: .connected, error: "That PIN isn't right. Check Setup on the Mac.")
            },
            PadGalleryEntry("Reconnecting") { ReconnectingView(onStartOver: {}) }
        ]

        static let setup: [PadGalleryEntry] = [
            PadGalleryEntry("Setup: issues to fix") { TabScreen(AdminFixtures.adminView(.setupIssues)) { SetupTab(admin: $0, client: $1) }
            },
            PadGalleryEntry("Setup: ready to start") { TabScreen(AdminFixtures.adminView(.lobbyReady)) { SetupTab(admin: $0, client: $1) } }
        ]

        static let game: [PadGalleryEntry] = [
            PadGalleryEntry("Game: lobby") { TabScreen(AdminFixtures.adminView(.lobbyReady)) { GameTab(admin: $0, client: $1) } },
            PadGalleryEntry("Game: running") { TabScreen(AdminFixtures.adminView(.running)) { GameTab(admin: $0, client: $1) } },
            PadGalleryEntry("Game: discussion") { TabScreen(AdminFixtures.adminView(.discussion)) { GameTab(admin: $0, client: $1) } },
            PadGalleryEntry("Game: voting") { TabScreen(AdminFixtures.adminView(.voting)) { GameTab(admin: $0, client: $1) } },
            PadGalleryEntry("Game: vote result") { TabScreen(AdminFixtures.adminView(.result)) { GameTab(admin: $0, client: $1) } },
            PadGalleryEntry("Game: sabotage") { TabScreen(AdminFixtures.adminView(.sabotage)) { GameTab(admin: $0, client: $1) } },
            PadGalleryEntry("Game: ended") { TabScreen(AdminFixtures.adminView(.ended)) { GameTab(admin: $0, client: $1) } }
        ]

        static let families: [PadGalleryEntry] = [
            PadGalleryEntry("Families: none yet") { TabScreen(AdminFixtures.emptyAdminView()) { FamiliesTab(admin: $0, client: $1) } },
            PadGalleryEntry("Families: lobby") { TabScreen(AdminFixtures.adminView(.lobbyReady)) { FamiliesTab(admin: $0, client: $1) } },
            PadGalleryEntry("Families: voting") { TabScreen(AdminFixtures.adminView(.voting)) { FamiliesTab(admin: $0, client: $1) } }
        ]

        static let devices: [PadGalleryEntry] = [
            PadGalleryEntry("Devices: none connected") { TabScreen(AdminFixtures.emptyAdminView()) { DevicesTab(admin: $0, client: $1) } },
            PadGalleryEntry("Devices: mixed status") { TabScreen(AdminFixtures.adminView(.running)) { DevicesTab(admin: $0, client: $1) } }
        ]

        static let dashboard: [PadGalleryEntry] = [
            PadGalleryEntry("Dashboard: sidebar and game") { DashboardScreen(admin: AdminFixtures.adminView(.voting)) }
        ]

        static let all = signIn + dashboard + setup + game + families + devices
    }

    #Preview("Sign in: ready", traits: .landscapeLeft) { PadScreens.signIn[0].screen }
    #Preview("Sign in: searching for host", traits: .landscapeLeft) { PadScreens.signIn[1].screen }
    #Preview("Sign in: wrong PIN", traits: .landscapeLeft) { PadScreens.signIn[2].screen }
    #Preview("Reconnecting", traits: .landscapeLeft) { PadScreens.signIn[3].screen }
    #Preview("Dashboard", traits: .landscapeLeft) { PadScreens.dashboard[0].screen }
    #Preview("Setup: issues to fix", traits: .landscapeLeft) { PadScreens.setup[0].screen }
    #Preview("Setup: ready to start", traits: .landscapeLeft) { PadScreens.setup[1].screen }
    #Preview("Game: lobby", traits: .landscapeLeft) { PadScreens.game[0].screen }
    #Preview("Game: running", traits: .landscapeLeft) { PadScreens.game[1].screen }
    #Preview("Game: discussion", traits: .landscapeLeft) { PadScreens.game[2].screen }
    #Preview("Game: voting", traits: .landscapeLeft) { PadScreens.game[3].screen }
    #Preview("Game: vote result", traits: .landscapeLeft) { PadScreens.game[4].screen }
    #Preview("Game: sabotage", traits: .landscapeLeft) { PadScreens.game[5].screen }
    #Preview("Game: ended", traits: .landscapeLeft) { PadScreens.game[6].screen }
    #Preview("Families: none yet", traits: .landscapeLeft) { PadScreens.families[0].screen }
    #Preview("Families: lobby", traits: .landscapeLeft) { PadScreens.families[1].screen }
    #Preview("Families: voting", traits: .landscapeLeft) { PadScreens.families[2].screen }
    #Preview("Devices: none connected", traits: .landscapeLeft) { PadScreens.devices[0].screen }
    #Preview("Devices: mixed status", traits: .landscapeLeft) { PadScreens.devices[1].screen }
#endif
