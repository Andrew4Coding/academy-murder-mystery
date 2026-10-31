#if DEBUG
    // swiftlint:disable cyclomatic_complexity function_body_length
    // One exhaustive switch keeps every previewable state in a single readable list.
    import CoreBluetooth
    import SwiftUI

    @MainActor
    final class GalleryContext {
        let now = Date()
        let connected = ClientFixtures.client()
        let searching = ClientFixtures.client(status: .searching)
        let connecting = ClientFixtures.client(status: .connecting)
        let failed = ClientFixtures.client(status: .failed("The network connection was lost."))
        let rejected = ClientFixtures.client(error: "That game code isn't valid.")
        let withMap = ClientFixtures.client(map: ClientFixtures.boothMap())
        let lobbyError = ClientFixtures.client(error: "That name is already taken.")
        let voteError = ClientFixtures.client(error: "Voting has already closed.")
        let map = ClientFixtures.boothMap()
        let bluetoothOn = ProximityService(previewState: .poweredOn)
        let bluetoothOff = ProximityService(previewState: .poweredOff)

        func game(
            role: Role = .villager,
            life: LifeState = .alive,
            phase: PhaseView = .running,
            configure: (inout GameConfig) -> Void = { _ in }
        ) -> GameView {
            var config = GameConfig(role: role, life: life, phase: phase)
            configure(&config)
            return config.build(now: now)
        }
    }

    struct GameConfig {
        var role: Role
        var life: LifeState
        var phase: PhaseView
        var nearby: [FamilySummary] = []
        var bodies: [FamilySummary] = []
        var killReadyAt: Date?
        var sabotage: SabotageView?
        var sabotageReadyAt: Date?
        var myVote: VoteChoice?
        var votesCast = 0
        var skipVotes = 0
        var mySkipVote = false
        var lastResult: VoteResultView?
        var announcedDeaths: [FamilySummary] = []

        @MainActor
        func build(now: Date) -> GameView {
            ClientFixtures.game(
                now: now, role: role, life: life, phase: phase, nearby: nearby, bodies: bodies,
                killReadyAt: killReadyAt, sabotage: sabotage, sabotageReadyAt: sabotageReadyAt,
                myVote: myVote, votesCast: votesCast, skipVotes: skipVotes, mySkipVote: mySkipVote,
                lastResult: lastResult, announcedDeaths: announcedDeaths
            )
        }
    }

    enum GalleryState: String, CaseIterable, Identifiable {
        case joinConnected, joinSearching, joinFailed, joinRejected, ocSignIn, ocSignInError
        case lobby, lobbyWithMap, lobbyError
        case roleVillagerHidden, roleVillagerRevealed, roleWerewolfRevealed, roleKilled, roleExpelled
        case actionsKillReady, actionsKillCooldown, actionsNobodyNearby, actionsBluetoothOff
        case actionsReport, actionsVillagerNoBody, actionsSabotageReady, actionsSabotageCooldown, actionsSabotageActive
        case meetingIdle, meetingIdleResult, meetingDiscussion, meetingSkipVoted, meetingVoting
        case meetingFinalVoting, meetingVotingDead, meetingVotingError, meetingResults, meetingEnded
        case sabotageBanner, ocStationIdle, ocStationActive, ocStationOtherBooth, ocAdminStation, ocStationRemoved
        case killedNotice, gameOverVillagers, gameOverWerewolves, startCountdown
        case connectionSearching, connectionConnecting, connectionConnected, connectionFailed, reconnecting, waitingForState

        var id: String {
            rawValue
        }

        enum Section: String, CaseIterable {
            case join = "Join and sign-in"
            case lobby = "Family lobby"
            case role = "Role and tasks"
            case actions = "Actions"
            case meeting = "Meetings and voting"
            case sabotage = "Sabotage and organiser"
            case notices = "Game notices"
            case connection = "Connection and empty states"
        }

        var section: Section {
            switch self {
            case .joinConnected, .joinSearching, .joinFailed, .joinRejected, .ocSignIn, .ocSignInError: .join
            case .lobby, .lobbyWithMap, .lobbyError: .lobby
            case .roleVillagerHidden, .roleVillagerRevealed, .roleWerewolfRevealed, .roleKilled, .roleExpelled: .role
            case .actionsKillReady, .actionsKillCooldown, .actionsNobodyNearby, .actionsBluetoothOff,
                 .actionsReport, .actionsVillagerNoBody, .actionsSabotageReady, .actionsSabotageCooldown,
                 .actionsSabotageActive: .actions
            case .meetingIdle, .meetingIdleResult, .meetingDiscussion, .meetingSkipVoted, .meetingVoting,
                 .meetingFinalVoting, .meetingVotingDead, .meetingVotingError, .meetingResults, .meetingEnded: .meeting
            case .sabotageBanner, .ocStationIdle, .ocStationActive, .ocStationOtherBooth, .ocAdminStation,
                 .ocStationRemoved: .sabotage
            case .killedNotice, .gameOverVillagers, .gameOverWerewolves, .startCountdown: .notices
            case .connectionSearching, .connectionConnecting, .connectionConnected, .connectionFailed,
                 .reconnecting, .waitingForState: .connection
            }
        }

        var title: String {
            switch self {
            case .joinConnected: "Join, connected"
            case .joinSearching: "Join, searching for host"
            case .joinFailed: "Join, host unreachable"
            case .joinRejected: "Join, rejected code"
            case .ocSignIn: "Organiser sign-in"
            case .ocSignInError: "Organiser sign-in, wrong PIN"
            case .lobby: "Lobby"
            case .lobbyWithMap: "Lobby with booth map"
            case .lobbyError: "Lobby, error"
            case .roleVillagerHidden: "Villager, role hidden"
            case .roleVillagerRevealed: "Villager, role revealed"
            case .roleWerewolfRevealed: "Werewolf, role revealed"
            case .roleKilled: "Eliminated family"
            case .roleExpelled: "Voted-out werewolf"
            case .actionsKillReady: "Werewolf, kill ready"
            case .actionsKillCooldown: "Werewolf, kill cooldown"
            case .actionsNobodyNearby: "Werewolf, nobody nearby"
            case .actionsBluetoothOff: "Bluetooth off"
            case .actionsReport: "Body nearby, report"
            case .actionsVillagerNoBody: "Villager, no body nearby"
            case .actionsSabotageReady: "Sabotage ready"
            case .actionsSabotageCooldown: "Sabotage cooldown"
            case .actionsSabotageActive: "Sabotage running"
            case .meetingIdle: "No meeting"
            case .meetingIdleResult: "After a meeting, results"
            case .meetingDiscussion: "Discussion"
            case .meetingSkipVoted: "Discussion, skip voted"
            case .meetingVoting: "Voting"
            case .meetingFinalVoting: "Final vote"
            case .meetingVotingDead: "Voting, family out"
            case .meetingVotingError: "Voting, error"
            case .meetingResults: "Vote results"
            case .meetingEnded: "Meeting, game ended"
            case .sabotageBanner: "Sabotage banner"
            case .ocStationIdle: "Booth station, idle"
            case .ocStationActive: "Booth station, sabotage here"
            case .ocStationOtherBooth: "Booth station, other booth"
            case .ocAdminStation: "Admin station on phone"
            case .ocStationRemoved: "Removed station"
            case .killedNotice: "You were killed"
            case .gameOverVillagers: "Game over, villagers"
            case .gameOverWerewolves: "Game over, werewolves"
            case .startCountdown: "Game starting"
            case .connectionSearching: "Looking for game"
            case .connectionConnecting: "Connecting"
            case .connectionConnected: "Connected"
            case .connectionFailed: "Can't reach host"
            case .reconnecting: "Reconnecting"
            case .waitingForState: "Waiting for game state"
            }
        }

        @MainActor @ViewBuilder
        func view(_ ctx: GalleryContext) -> some View {
            let now = ctx.now
            switch self {
            case .joinConnected: JoinView(client: ctx.connected)
            case .joinSearching: JoinView(client: ctx.searching)
            case .joinFailed: JoinView(client: ctx.failed)
            case .joinRejected: JoinView(client: ctx.rejected)
            case .ocSignIn: OCSignInView(client: ctx.connected)
            case .ocSignInError: OCSignInView(client: ctx.rejected)
            case .lobby: FamilyLobbyView(lobby: ClientFixtures.lobby(), client: ctx.connected)
            case .lobbyWithMap: FamilyLobbyView(lobby: ClientFixtures.lobby(), client: ctx.withMap)
            case .lobbyError: FamilyLobbyView(lobby: ClientFixtures.lobby(), client: ctx.lobbyError)
            case .roleVillagerHidden:
                RoleView(game: ctx.game(), boothMap: ctx.map, client: ctx.connected)
            case .roleVillagerRevealed:
                RoleView(game: ctx.game(), boothMap: nil, client: ctx.connected, startsRevealed: true)
            case .roleWerewolfRevealed:
                RoleView(game: ctx.game(role: .werewolf), boothMap: nil, client: ctx.connected, startsRevealed: true)
            case .roleKilled:
                RoleView(game: ctx.game(life: .killed), boothMap: nil, client: ctx.connected)
            case .roleExpelled:
                RoleView(game: ctx.game(role: .werewolf, life: .expelled), boothMap: nil, client: ctx.connected)
            case .actionsKillReady:
                ActionsView(
                    game: ctx
                        .game(role: .werewolf) {
                            $0.nearby = ClientFixtures.nearby; $0.killReadyAt = now.addingTimeInterval(-5); $0.sabotageReadyAt = now
                                .addingTimeInterval(-5)
                        },
                    client: ctx.connected,
                    proximity: ctx.bluetoothOn
                )
            case .actionsKillCooldown:
                ActionsView(
                    game: ctx
                        .game(role: .werewolf) {
                            $0.nearby = ClientFixtures.nearby; $0.killReadyAt = now.addingTimeInterval(42); $0.sabotageReadyAt = now
                                .addingTimeInterval(75)
                        },
                    client: ctx.connected,
                    proximity: ctx.bluetoothOn
                )
            case .actionsNobodyNearby:
                ActionsView(
                    game: ctx.game(role: .werewolf) { $0.killReadyAt = now.addingTimeInterval(-5) },
                    client: ctx.connected,
                    proximity: ctx.bluetoothOn
                )
            case .actionsBluetoothOff:
                ActionsView(game: ctx.game(role: .werewolf), client: ctx.connected, proximity: ctx.bluetoothOff)
            case .actionsReport:
                ActionsView(game: ctx.game { $0.bodies = [ClientFixtures.fallenFamily] }, client: ctx.connected, proximity: ctx.bluetoothOn)
            case .actionsVillagerNoBody:
                ActionsView(game: ctx.game(), client: ctx.connected, proximity: ctx.bluetoothOn)
            case .actionsSabotageReady:
                ActionsView(
                    game: ctx.game(role: .werewolf) { $0.sabotageReadyAt = now.addingTimeInterval(-5) },
                    client: ctx.connected,
                    proximity: ctx.bluetoothOn
                )
            case .actionsSabotageCooldown:
                ActionsView(
                    game: ctx.game(role: .werewolf) { $0.sabotageReadyAt = now.addingTimeInterval(95) },
                    client: ctx.connected,
                    proximity: ctx.bluetoothOn
                )
            case .actionsSabotageActive:
                ActionsView(
                    game: ctx.game(role: .werewolf) { $0.sabotage = ClientFixtures.sabotage(now: now) },
                    client: ctx.connected,
                    proximity: ctx.bluetoothOn
                )
            case .meetingIdle:
                MeetingView(game: ctx.game(), client: ctx.connected)
            case .meetingIdleResult:
                MeetingView(
                    game: ctx.game { $0.lastResult = ClientFixtures.voteResult(); $0.announcedDeaths = [ClientFixtures.fallenFamily] },
                    client: ctx.connected
                )
            case .meetingDiscussion:
                MeetingView(
                    game: ctx
                        .game(phase: .discussion(until: now.addingTimeInterval(95))) {
                            $0.skipVotes = 1; $0.announcedDeaths = [ClientFixtures.fallenFamily]
                        },
                    client: ctx.connected
                )
            case .meetingSkipVoted:
                MeetingView(
                    game: ctx.game(phase: .discussion(until: now.addingTimeInterval(95))) { $0.skipVotes = 3; $0.mySkipVote = true },
                    client: ctx.connected
                )
            case .meetingVoting:
                MeetingView(
                    game: ctx
                        .game(phase: .voting(until: now.addingTimeInterval(80), isFinal: false)) { $0.votesCast = 2; $0.myVote = .family(2)
                        },
                    client: ctx.connected
                )
            case .meetingFinalVoting:
                MeetingView(
                    game: ctx.game(phase: .voting(until: now.addingTimeInterval(80), isFinal: true)) { $0.votesCast = 3 },
                    client: ctx.connected
                )
            case .meetingVotingDead:
                MeetingView(
                    game: ctx.game(life: .killed, phase: .voting(until: now.addingTimeInterval(80), isFinal: false)),
                    client: ctx.connected
                )
            case .meetingVotingError:
                MeetingView(game: ctx.game(phase: .voting(until: now.addingTimeInterval(80), isFinal: false)), client: ctx.voteError)
            case .meetingResults:
                MeetingView(game: ctx.game { $0.lastResult = ClientFixtures.voteResult(isFinal: true) }, client: ctx.connected)
            case .meetingEnded:
                MeetingView(
                    game: ctx.game(phase: .ended(Outcome(winner: .villagers, reason: .allWerewolvesRemoved))),
                    client: ctx.connected
                )
            case .sabotageBanner:
                SabotageBanner(sabotage: ClientFixtures.sabotage(.oxygen, now: now), client: ctx.connected)
            case .ocStationIdle:
                SabotageStationView(kind: .reactor, oc: OCView(sabotage: nil), client: ctx.connected)
            case .ocStationActive:
                SabotageStationView(
                    kind: .reactor,
                    oc: OCView(sabotage: ClientFixtures.sabotage(.reactor, now: now)),
                    client: ctx.connected
                )
            case .ocStationOtherBooth:
                SabotageStationView(kind: .oxygen, oc: OCView(sabotage: ClientFixtures.sabotage(.reactor, now: now)), client: ctx.connected)
            case .ocAdminStation:
                OCRootView(view: ClientFixtures.ocView(now: now, station: .admin, sabotage: nil), client: ctx.connected)
            case .ocStationRemoved:
                OCRootView(view: ClientFixtures.ocView(now: now, station: .townHall, sabotage: nil), client: ctx.connected)
            case .killedNotice: KilledNoticeView {}
            case .gameOverVillagers: GameOverView(outcome: Outcome(winner: .villagers, reason: .finalVoteSucceeded)) {}
            case .gameOverWerewolves: GameOverView(outcome: Outcome(winner: .werewolves, reason: .parity)) {}
            case .startCountdown: StartCountdownView(startsAt: now.addingTimeInterval(8), client: ctx.connected)
            case .connectionSearching: ConnectionStatusView(status: .searching)
            case .connectionConnecting: ConnectionStatusView(status: .connecting)
            case .connectionConnected: ConnectionStatusView(status: .connected)
            case .connectionFailed: ConnectionStatusView(status: .failed("The network connection was lost."))
            case .reconnecting: ReconnectingView(client: ctx.connected)
            case .waitingForState: WaitingForStateView(client: ctx.connected)
            }
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
#endif
