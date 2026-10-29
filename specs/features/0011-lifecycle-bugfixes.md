---
id: 0011
title: Lifecycle bugfixes
status: in-progress
owner: AND
app: all
created: 2026-10-29
updated: 2026-10-29
related: [0002-game-engine.md, 0004-lobby-and-roles.md, 0005-meetings-and-voting.md, 0006-ble-kill.md, 0007-sabotage.md]
---

# 0011: Lifecycle bugfixes

## Summary

Playtest found six defects in the game lifecycle: players cannot leave a family, a finished game needs an app restart before a new one, the discussion timer can leave clients stuck, every state broadcast flashes "No one nearby", a Werewolf device can show the join / OC PIN screen mid-game, and kill and sabotage start on a cooldown. This spec fixes them without adding features.

## User stories

- As a **player**, I want to leave or go back from a family while still in the lobby, so that a wrong join is recoverable.
- As an **organiser**, I want "New Game" to reset every connected phone, so that nobody has to relaunch the app.
- As a **werewolf**, I want kill and sabotage ready as soon as the game starts, so that the opening minutes are playable.

## Acceptance criteria

- [x] **AC1 Leave in lobby**: Given a joined player and no game started, when they tap Leave (or Back), then they are removed from the family, their identity is cleared and they see the Join screen.
- [x] **AC2 No leave in game**: Given a started game, when a player views the app, then Leave and Back are not offered; only the Admin can remove or reconnect a device.
- [x] **AC3 New game reset**: Given an ended game, when the Admin confirms New Game, then every connected iOS client returns to Join (or to the lobby of its new family) without restarting the app.
- [x] **AC4 Discussion timeout**: Given discussion with a 120 s timer, when it expires, then the host calls `advance(to:)`, voting opens and every client shows the ballot; a client that missed the broadcast catches up on its next state.
- [ ] **AC5 Nearby stability**: Given a werewolf with a villager in range, when any unrelated state broadcast arrives, then the nearby list does not clear and "No one nearby" does not flash.
- [x] **AC6 Werewolf routing**: Given a joined Werewolf device, when the connection drops and resumes or the app is backgrounded, then it returns to the game tabs, never to Join or OC PIN entry.
- [x] **AC7 No initial cooldown**: Given a game start, then `killReadyAt` and `sabotageReadyAt` equal the start time, so the first kill and sabotage are available at once; cooldowns apply only after use.

## UX

| State | What the user sees |
|---|---|
| Empty | Join screen after leaving |
| Loading | "Reconnecting…" banner, game tabs stay |
| Content | Game tabs; Leave only in the lobby |
| Error | Existing host error strings |

Design link: n/a

Accessibility notes: Leave is a labelled toolbar button with a confirmation dialog.

## Data

None. `GameEngine.start` changes the initial `killReadyAt` and `sabotageReadyAt`; `GameSettings` unchanged.

## Constraints check

- [ ] Fits `specs/constraints.md` and `specs/apps/ios/constraints.md`
- [x] No new dependency

## Out of scope

- Family capacity, auto-assign and head promotion (0012).

## Open questions

- Root cause of AC4 and AC5 is not yet reproduced; diagnose first (host timer driving `advance(to:)`; `refreshNearby` and `ActionsView` identity on each `ClientView`) and add a regression test before fixing.
- Root cause of AC6 (`RootView` routing when `client.view` is momentarily nil).

## Implementation notes

- Cooldowns start at zero in `GameEngine.begin`. Wire gains `ClientMessage.leave` / `.sync` and `ServerMessage.reset`; `GameHost.leave`, `sync` and `newGame` send them. `GameClient.send` drops messages until the host confirms the identity: the "Join a family or enter the OC PIN first" error was the phone's one-per-second sightings reaching the host before its resume hello after a reconnect.
- iOS: `FamilyLobbyView` Leave, `RootView` shows a reconnecting view while a resume ID exists, `GameTabsView` sends `.sync` when a phase or sabotage deadline passes.
- AC5 is only mitigated (`ActionsView` keeps the nearby list for 3 s after it empties); the root cause was not reproduced and needs a real-device check.
- Tests: `GameHostLifecycleTests` is written but was not run.
