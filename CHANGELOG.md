# Changelog

All notable user-visible changes, in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.
Each target is versioned on its own ([SemVer](https://semver.org)), via `MARKETING_VERSION` in its `.xcconfig`. A release heading names its target, e.g. `## [ios 0.2.0] - YYYY-MM-DD`.
Tooling and refactors that users can't see don't go here.

## [Unreleased]

### MurderMysteryiOS

#### Added

- Finds the game host on the local network and shows connection status ([0003](specs/features/0003-lan-host-transport.md)).
- Join a family with a code or QR, choose the head of family, and see your role and tasks ([0004](specs/features/0004-lobby-and-roles.md)).
- Meeting tab with discussion and voting timers, announced deaths, head-only anonymous voting and results ([0005](specs/features/0005-meetings-and-voting.md)).
- Werewolf Actions tab: eliminate a nearby villager family over Bluetooth, with cooldown ([0006](specs/features/0006-ble-kill.md)).
- Sabotage: werewolves start Reactor or Oxygen sabotage, everyone sees an alert banner with the countdown ([0007](specs/features/0007-sabotage.md)).
- Organiser mode: sign in with the OC PIN, stamp families at a booth with undo, resolve sabotage, or observe from the Town Hall ([0008](specs/features/0008-oc-mode-and-stamping.md)).

#### Removed

- Sample Items list, detail and editor ([0002](specs/features/0002-game-engine.md)).

### MurderMysteryAdmin

#### Added

- Hosts the game on the local network and lists connected devices, with a connectivity check ([0003](specs/features/0003-lan-host-transport.md)).
- Setup screen: families, join codes and QR, timings, OC PIN, Start Game and New Game ([0004](specs/features/0004-lobby-and-roles.md)).
- Game screen: start discussion, proxy votes, results and a family status table with optional roles ([0005](specs/features/0005-meetings-and-voting.md)).
- Bluetooth range settings, and Eliminate, Revive and End Game overrides ([0006](specs/features/0006-ble-kill.md)).
- Sabotage status and a Resolve Sabotage button ([0007](specs/features/0007-sabotage.md)).
- Record and undo stamps from the family table ([0008](specs/features/0008-oc-mode-and-stamping.md)).
- Public Display window for the lab screens: game clock, meeting timers, sabotage alarm, vote results and winner ([0009](specs/apps/admin/features/0009-public-display.md)).

#### Removed

- Sample Items list, detail and editor ([0002](specs/features/0002-game-engine.md)).
