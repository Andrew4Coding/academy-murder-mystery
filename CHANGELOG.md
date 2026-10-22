# Changelog

All notable user-visible changes, in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.
Each target is versioned on its own ([SemVer](https://semver.org)), via `MARKETING_VERSION` in its `.xcconfig`. A release heading names its target, e.g. `## [ios 0.2.0] - YYYY-MM-DD`.
Tooling and refactors that users can't see don't go here.

## [Unreleased]

### MurderMysteryiOS

#### Added

- Finds the game host on the local network and shows connection status ([0003](specs/features/0003-lan-host-transport.md)).

#### Removed

- Sample Items list, detail and editor ([0002](specs/features/0002-game-engine.md)).

### MurderMysteryAdmin

#### Added

- Hosts the game on the local network and lists connected devices, with a connectivity check ([0003](specs/features/0003-lan-host-transport.md)).

#### Removed

- Sample Items list, detail and editor ([0002](specs/features/0002-game-engine.md)).
