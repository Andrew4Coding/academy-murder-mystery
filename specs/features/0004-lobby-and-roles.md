---
id: 0004
title: Lobby, family join and roles
status: implemented
owner: AND
app: all
created: 2026-10-22
updated: 2026-10-22
related: [decisions/0005-family-level-identity.md, 0002-game-engine.md, 0003-lan-host-transport.md]
---

# 0004: Lobby, family join and roles

## Summary

OC create families and settings in Admin, players join their family by code or QR, each family picks a head, and when the OC starts the game every device privately shows its family's role, task list and objective. Werewolf devices also see the other werewolf families.

## User stories

- As a **player**, I want to join my family by scanning a code, so I do not type a long name.
- As a **head of family**, I want to hand over the role of head before a meeting, so another member can go to the Town Hall.
- As a **werewolf**, I want to see my fellow werewolf families, so we do not kill each other.

## Acceptance criteria

- [x] **AC1 Setup**: Given Admin, when the OC sets number of families, werewolf families and timings, then invalid combinations (W < 1 or W >= N/2) block Start with a reason.
- [x] **AC2 Join**: Given a family code or QR, when a player enters a display name, then they join that family (max 6) and appear in Admin's lobby.
- [x] **AC3 Head**: Given a family, when a member claims or hands over head outside discussion and voting, then the host records the new head; during discussion and voting the request is rejected.
- [x] **AC4 Start**: Given all families have a head, when the OC taps Start Game, then roles and task lists are assigned by the engine and every device shows its family's role and 5 booths privately.
- [x] **AC5 Werewolf view**: Given a werewolf family, when roles are shown, then its devices list the other werewolf families; villager devices never receive that list.
- [x] **AC6 Leakage**: Given any client, when it inspects its own state, then it contains no other family's role (except revealed expelled families and its own werewolf allies).
- [x] **AC7 Dead family**: Given a killed or expelled family, when its device refreshes, then it shows its status and disables all features, except sabotage for werewolf families.

## UX

| State | What the user sees |
|---|---|
| Empty | iOS: "Enter your family code or scan the QR"; Admin: families with no members |
| Loading | "Waiting for the game to start" |
| Content | iOS: role card, objective, 5 booths with progress; Admin: lobby with member counts |
| Error | "Family is full", "Invalid code" |

Design link: TODO (Figma)

Accessibility notes: role card readable by VoiceOver; role reveal is not conveyed by colour alone; QR scanner has a manual code field.

## Data

`Family`, `Player`, `Role`, `TaskList` models and `FamilyRepository`; join codes and the OC PIN are generated per game.

## Constraints check

- [x] Fits `specs/constraints.md` (privacy: name only, no accounts)
- [x] No new dependency (AVFoundation camera scanning is system)

## Out of scope

- Joining after the game started.
- Moving a player between families after start.

## Open questions

- Families may have 1 to 6 members at start (implemented). Start also requires every family to have at least one member and a head.
- QR scanning (VisionKit) needs a real camera and was not exercised; the manual code field is the tested path.
- Dead-family "disables all features" currently means the role screen shows the status; there are no gameplay features to disable until 0005 to 0008.

## Implementation notes

- Host: `GameHost+Lobby` (`configure`, `startGame`, `newGame`, `claimHead`, `handOverHead`, `applyAsOC`), `HostState.setupIssues()`, `GameHost+Views` (per-identity `ClientView` with `LobbyView` / `GameView`; werewolf `allies`, `revealedRole` only for expelled families).
- iOS: `JoinView` (+ `CodeScannerView`, camera string in `project.yml`), `FamilyLobbyView`, `RoleView` (role hidden until tapped, hides again on leaving the app). Admin: `SetupView` (counts, timings, OC PIN, families table, QR popover, Start Game, New Game).
- Tests: `GameHostLobbyTests` cover AC1 to AC7; the join flow, Bonjour discovery and lobby were also checked by hand in the iOS simulator against the Mac app.
