#if DEBUG
    import SwiftUI

    @MainActor
    struct GalleryPreview: View {
        let state: GalleryState
        @State private var context = GalleryContext()

        init(_ state: GalleryState) {
            self.state = state
        }

        var body: some View {
            state.view(context)
        }
    }

    #Preview("Join, connected") { GalleryPreview(.joinConnected) }

    #Preview("Join, searching for host") { GalleryPreview(.joinSearching) }

    #Preview("Join, host unreachable") { GalleryPreview(.joinFailed) }

    #Preview("Join, rejected code") { GalleryPreview(.joinRejected) }

    #Preview("Organiser sign-in") { GalleryPreview(.ocSignIn) }

    #Preview("Organiser sign-in, wrong PIN") { GalleryPreview(.ocSignInError) }

    #Preview("Lobby") { GalleryPreview(.lobby) }

    #Preview("Lobby with booth map") { GalleryPreview(.lobbyWithMap) }

    #Preview("Lobby, error") { GalleryPreview(.lobbyError) }

    #Preview("Villager, role hidden") { GalleryPreview(.roleVillagerHidden) }

    #Preview("Villager, role revealed") { GalleryPreview(.roleVillagerRevealed) }

    #Preview("Werewolf, role revealed") { GalleryPreview(.roleWerewolfRevealed) }

    #Preview("Eliminated family") { GalleryPreview(.roleKilled) }

    #Preview("Voted-out werewolf") { GalleryPreview(.roleExpelled) }

    #Preview("Werewolf, kill ready") { GalleryPreview(.actionsKillReady) }

    #Preview("Werewolf, kill cooldown") { GalleryPreview(.actionsKillCooldown) }

    #Preview("Werewolf, nobody nearby") { GalleryPreview(.actionsNobodyNearby) }

    #Preview("Bluetooth off") { GalleryPreview(.actionsBluetoothOff) }

    #Preview("Body nearby, report") { GalleryPreview(.actionsReport) }

    #Preview("Villager, no body nearby") { GalleryPreview(.actionsVillagerNoBody) }

    #Preview("Sabotage ready") { GalleryPreview(.actionsSabotageReady) }

    #Preview("Sabotage cooldown") { GalleryPreview(.actionsSabotageCooldown) }

    #Preview("Sabotage running") { GalleryPreview(.actionsSabotageActive) }

    #Preview("No meeting") { GalleryPreview(.meetingIdle) }

    #Preview("After a meeting, results") { GalleryPreview(.meetingIdleResult) }

    #Preview("Discussion") { GalleryPreview(.meetingDiscussion) }

    #Preview("Discussion, skip voted") { GalleryPreview(.meetingSkipVoted) }

    #Preview("Voting") { GalleryPreview(.meetingVoting) }

    #Preview("Final vote") { GalleryPreview(.meetingFinalVoting) }

    #Preview("Voting, family out") { GalleryPreview(.meetingVotingDead) }

    #Preview("Voting, error") { GalleryPreview(.meetingVotingError) }

    #Preview("Vote results") { GalleryPreview(.meetingResults) }

    #Preview("Meeting, game ended") { GalleryPreview(.meetingEnded) }

    #Preview("Sabotage banner") { GalleryPreview(.sabotageBanner) }

    #Preview("Booth station, idle") { GalleryPreview(.ocStationIdle) }

    #Preview("Booth station, sabotage here") { GalleryPreview(.ocStationActive) }

    #Preview("Booth station, other booth") { GalleryPreview(.ocStationOtherBooth) }

    #Preview("Admin station on phone") { GalleryPreview(.ocAdminStation) }

    #Preview("Removed station") { GalleryPreview(.ocStationRemoved) }

    #Preview("You were killed") { GalleryPreview(.killedNotice) }

    #Preview("Game over, villagers") { GalleryPreview(.gameOverVillagers) }

    #Preview("Game over, werewolves") { GalleryPreview(.gameOverWerewolves) }

    #Preview("Game starting") { GalleryPreview(.startCountdown) }

    #Preview("Looking for game") { GalleryPreview(.connectionSearching) }

    #Preview("Connecting") { GalleryPreview(.connectionConnecting) }

    #Preview("Connected") { GalleryPreview(.connectionConnected) }

    #Preview("Can't reach host") { GalleryPreview(.connectionFailed) }

    #Preview("Reconnecting") { GalleryPreview(.reconnecting) }

    #Preview("Waiting for game state") { GalleryPreview(.waitingForState) }
#endif
