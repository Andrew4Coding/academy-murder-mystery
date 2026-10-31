# Changelog

All notable user-visible changes, in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.
Each target is versioned on its own ([SemVer](https://semver.org)), via `MARKETING_VERSION` in its `.xcconfig`. A release heading names its target, e.g. `## [ios 0.2.0] - YYYY-MM-DD`.
Tooling and refactors that users can't see don't go here.

## [Unreleased]

### MoonfalliOS

#### Added

- Follows the active host: reads the registry and connects to the cloud host over `wss://`, or the Mac over the local network when the registry says local or cannot be reached ([0036](specs/features/0036-host-switching.md)).
- Finds the game host on the local network and shows connection status ([0003](specs/features/0003-lan-host-transport.md)).
- Join with a code or QR and see your role and tasks ([0004](specs/features/0004-lobby-and-roles.md)).
- Meeting tab with discussion and voting timers, announced deaths, head-only anonymous voting and results ([0005](specs/features/0005-meetings-and-voting.md)).
- Werewolf Actions tab: eliminate a nearby villager family over Bluetooth, with cooldown ([0006](specs/features/0006-ble-kill.md)).
- Sabotage: werewolves start Reactor or Oxygen sabotage, everyone sees an alert banner with the countdown ([0007](specs/features/0007-sabotage.md)).
- Organiser mode: sign in with the OC PIN, stamp families at a booth with undo, resolve sabotage, or observe from the Town Hall ([0008](specs/features/0008-oc-mode-and-stamping.md)).

- Leave a family from the lobby, a reconnecting state instead of the join screen, and a sync when a timer ends ([0011](specs/features/0011-lifecycle-bugfixes.md)).
- Scan one game QR to be placed in a family automatically, as your own family, and rename it ([0012](specs/features/0012-join-and-families.md)).
- Full-screen notices when your family is killed and when the game ends with the winner ([0013](specs/features/0013-kill-notice-and-game-end.md)).
- Selfie and head name on meeting cards, a vote to skip discussion, and a bar chart of vote results ([0014](specs/features/0014-meeting-upgrade.md)).
- One sabotage card per booth, with its own fix time ([0015](specs/features/0015-sabotage-rework.md)).
- Timers and status text scale with Dynamic Type, honour Reduce Motion, and the sabotage banner uses Liquid Glass with a compliant contrast ([0027](specs/features/0027-hig-compliance.md)).
- Killed and voted-out families keep stamping their tasks, so the villagers can still win by tasks ([0024](specs/features/0024-dead-families-keep-tasks.md)).
- Booth stamping as a grid of large family cards ([0016](specs/features/0016-oc-station-rework.md)).
- Report a body: stand near a fallen family and tap Report to call a discussion ([0019](specs/features/0019-report-body.md)).
- Kill, sabotage and voting App Intents (vote for a family, vote skip, skip discussion), usable from Siri and Shortcuts, including on Apple Watch, and they work when the app is in the background ([0018](specs/apps/ios/features/0018-watch-intents.md)).
- Booth map: a card in the lobby and on the Family tab opens the map the OC uploaded, full screen, with pinch, pan and double-tap zoom ([0030](specs/features/0030-booth-map.md)).
- Booth details: tap a booth in your tasks or the lobby to see its picture, capacity, duration, task, steps and when it counts as done ([0037](specs/features/0037-booth-details.md)).
- Live Activity on the Lock Screen and Dynamic Island: meeting, voting and sabotage countdowns, booth progress, your own killed status and the winner, with no role information ([0029](specs/apps/ios/features/0029-live-activities.md)).

#### Fixed

- Bluetooth kills and body reports keep working while the phone is locked or the app is in the background (not after force-quitting the app).
- App icon now shows on the home screen.
- Meetings and body reports are refused while a sabotage is active.
- A majority of alive families voting to skip discussion opens voting at once, with no organiser approval.
- Game start shows a 10 second countdown on phones and the Public Display before roles appear.
- Voted-out families no longer reveal their role until the game ends.
- Refresh and Retry are toolbar buttons instead of a floating button that could not be tapped.
- Fellow werewolf families show right under the role card once you reveal your role.
- Every family sees all 7 booths with a short instruction for each, instead of 5 random ones.
- "Since the last meeting" is now "Last Found Dead".
- Phones that stayed on "Looking for the game host" now retry the search by themselves and tell you when Local Network access is blocked.
- The sabotage cooldown is shared by all werewolf families and starts when a sabotage ends, so no werewolf can sabotage right after another.
- Reconnecting is faster and keeps you in the game: heartbeat, refresh button, sync on return to the app, and a kill sent while reconnecting is queued.
- Meeting countdowns match across devices, and the Bluetooth prompt appears in the lobby instead of mid-game.
- A bell and notification call everyone to the Town Hall when a meeting starts.

#### Changed

- Your tasks lists the nine booths from the participant booth guide with details, and families no longer track tasks ([0037](specs/features/0037-booth-details.md)).
- Red and black look across every screen, with larger touch targets, clearer join steps and VoiceOver labels ([0031](specs/features/0031-red-black-theme-and-accessibility.md), [0033](specs/features/0033-screen-restyle-and-ui-flow.md)).
- Joining asks only for a family name, which is also shown as your name.
- New app icon: a wolf face cut out of a blood-red moon.
- Kill and sabotage are ready at the start of the game, with no opening cooldown ([0011](specs/features/0011-lifecycle-bugfixes.md)).

#### Removed

- Booth stamping, task progress and checkmarks, and the villagers' task win. The Family tab now only lists your booths ([ADR 0008](specs/decisions/0008-stamping-outside-the-app.md)).
- Hand Over, Become Head of Family and the member list: one family is one player ([0020](specs/features/0020-one-person-per-family.md)).
- Town Hall observer station ([0016](specs/features/0016-oc-station-rework.md)).
- Sample Items list, detail and editor ([0002](specs/features/0002-game-engine.md)).
- Connection badge from the Join toolbar.

### MoonfallAdminiPad

#### Changed

- Family rows no longer list tasks.
- Red and black look, setup grouped by task and a clearer game screen with a highlighted next step ([0031](specs/features/0031-red-black-theme-and-accessibility.md), [0033](specs/features/0033-screen-restyle-and-ui-flow.md)).
- Stamp menus and task progress removed from the Game tab, since stamping now happens outside the app.
- New app icon: the wolf moon with a teal check banner.
- Game tab actions (bell, discussion, votes, timers, sabotage, end game) are large labelled bento tiles instead of toolbar buttons.
- Families have their own sidebar item, with Show Roles, eliminate and revive; swipe left to delete a family in the lobby, and swipe left on a device in Devices to remove it.

#### Fixed

- New Game keeps the OC PIN and signed-in OC devices, so the iPad stays signed in.
- App icon now shows on the home screen.

#### Added

- Booths tab: edit every booth (text, steps, staff notes, picture), add, delete and reorder them ([0037](specs/features/0037-booth-details.md)).
- "Take over in cloud" with the OC PIN when the Mac is down, with the registry status shown ([0036](specs/features/0036-host-switching.md)).
- Follows the active host: reads the registry and connects to the cloud host over `wss://`, or the Mac over the local network when the registry says local or cannot be reached ([0036](specs/features/0036-host-switching.md)).
- Pause, resume, add or shorten time under the game clock, meeting and sabotage timers, and a bento Setup screen with native time steppers.
- Setup, Game and Devices tabs with everything the Mac has except Simulation and Display: settings, Bluetooth range, join QR, OC PIN, booth map, families, stamps, eliminate and revive, proxy votes, timers, end game, new game and a connection check.
- Booth map card on the dashboard opens the uploaded map in a zoomable viewer ([0030](specs/features/0030-booth-map.md)).
- Timers are one menu, and error and sabotage text keeps its colour on the icon only ([0027](specs/features/0027-hig-compliance.md)).
- Add or remove time on the meeting timer, game clock and sabotage countdown, with presets and a custom entry ([0025](specs/features/0025-editable-timers.md)).
- Delete a family from the dashboard's families list while in the lobby ([0021](specs/features/0021-delete-families.md)).
- iPad dashboard: connect to the Mac host with the OC PIN, see game status and families, start a discussion, add time, approve a skip and resolve a sabotage ([0017](specs/apps/admin/features/0017-ipad-admin.md)).

### MoonfallAdmin

#### Fixed

- Setup now picks up changes made from the iPad instead of overwriting them with stale values.
- App icon is shared with the iOS apps, from one Icon Composer bundle.
- Sidebar rows can be clicked again.

#### Added

- Booths section: edit every booth (text, steps, staff notes, picture), add, delete and reorder them, or restore the booth guide defaults ([0037](specs/features/0037-booth-details.md)).
- Host mode control in Devices: switch between self-host and the cloud host with the game state carried across, upload a cold-backup snapshot after every commit, and run the main game commands and the Public Display from the cloud ([0035](specs/features/0035-cloud-host-server.md), [0036](specs/features/0036-host-switching.md)).
- Pause, resume, add or shorten time under the game clock, meeting and sabotage timers, and a bento Setup screen with native time steppers.
- Booth map upload in Setup (PNG, JPEG or HEIC, shrunk to 3000 px) with preview, replace and remove; it stays across games and reaches every device ([0030](specs/features/0030-booth-map.md)).
- Ring Bell button, separate from Start Discussion, plus a live Public Display preview in Display; the bell and the looped sabotage alarm are bundled sounds.
- Debug Mode toggle in Setup: 2 families are enough, no kill or sabotage cooldown, and a kill never ends the game ([0028](specs/features/0028-debug-mode.md)).
- Game toolbar is grouped into five items (Show Roles, Meeting, Timers, Game, Start Discussion), with Shift-Cmd-K to approve a skip and Shift-Cmd-R to resolve a sabotage ([0027](specs/features/0027-hig-compliance.md)).
- Add or remove time on the meeting timer, game clock and sabotage countdown from the Game toolbar ([0025](specs/features/0025-editable-timers.md)).
- Public Display shows every family with its selfie and marks the werewolves when they win ([0026](specs/features/0026-werewolf-win-reveal.md)).
- Delete a family from the Setup families list while in the lobby ([0021](specs/features/0021-delete-families.md)).
- Hosts the game on the local network and lists connected devices, with a connectivity check ([0003](specs/features/0003-lan-host-transport.md)).
- Setup screen: families, join codes and QR, timings, OC PIN, Start Game and New Game ([0004](specs/features/0004-lobby-and-roles.md)).
- Game screen: start discussion, proxy votes, results and a family status table with optional roles ([0005](specs/features/0005-meetings-and-voting.md)).
- Bluetooth range settings, and Eliminate, Revive and End Game overrides ([0006](specs/features/0006-ble-kill.md)).
- Sabotage status and a Resolve Sabotage button ([0007](specs/features/0007-sabotage.md)).
- Record and undo stamps from the family table ([0008](specs/features/0008-oc-mode-and-stamping.md)).
- Public Display window for the lab screens: game clock, meeting timers, sabotage alarm, vote results and winner ([0009](specs/apps/admin/features/0009-public-display.md)).
- Simulation mode: rehearse a full game with seeded bots at up to 60x speed, separate from the real game ([0010](specs/apps/admin/features/0010-simulation-mode.md)).

- One join QR on the Public Display and in Setup, and family rename ([0012](specs/features/0012-join-and-families.md)).
- Add time to a meeting, approve a skip-discussion vote, and vote result charts ([0014](specs/features/0014-meeting-upgrade.md)).
- Open Display button in the toolbar, and the Public Display lobby screen lists families and members beside the join QR ([0012](specs/features/0012-join-and-families.md)).
- Fix time and cooldown per sabotage booth, and a looping alarm on the Public Display with a mute switch ([0015](specs/features/0015-sabotage-rework.md)).

#### Changed

- Red and black look, setup grouped by task, a clearer game control screen, and a redesigned Public Display with a moon and wolf stage, timer ring and tidier rosters ([0031](specs/features/0031-red-black-theme-and-accessibility.md), [0033](specs/features/0033-screen-restyle-and-ui-flow.md), [0034](specs/features/0034-public-display-redesign.md)).
- New app icon: the wolf moon with a gold star banner.
- Game screen actions (bell, discussion, votes, timers, sabotage, end game) are large labelled bento tiles instead of toolbar buttons.
- Families have their own sidebar item, with Show Roles, eliminate and revive.
- The OC PIN is hidden by default in Setup, with buttons to show it and to generate a new random one.
- The Public Display lobby list shows each family's selfie.
- Families are no longer set by a stepper: they fill from the game code ([0012](specs/features/0012-join-and-families.md)).

#### Removed

- The Tasks column in the Families table, and the separate Timers tile.
- Recording and undoing stamps, and the task progress column, from the Game screen ([ADR 0008](specs/decisions/0008-stamping-outside-the-app.md)).
- Sample Items list, detail and editor ([0002](specs/features/0002-game-engine.md)).
- Check Connectivity button in Devices, the sabotage alarm mute switch and the lab screens help in Display.
