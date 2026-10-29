---
id: 0013
title: Kill notice and game end
status: approved
owner: AND
app: all
created: 2026-10-29
updated: 2026-10-29
related: [0002-game-engine.md, 0006-ble-kill.md, 0009-public-display.md, 0011-lifecycle-bugfixes.md]
---

# 0013: Kill notice and game end

## Summary

Today a killed player gets no clear signal and nobody is told who won when the game ends. This spec adds a full-screen "You were killed" notice with haptics for the victim, and a winner announcement on every phone and the Public Display, with the Admin starting a new game from the end screen.

## User stories

- As a **victim**, I want an unmistakable notice, so that I know to stop and follow the dead rules.
- As **anyone**, I want to see who won and why, so that the game has an ending.

## Acceptance criteria

- [ ] **AC1 Victim notice**: Given a kill, then the victim's devices show a full-screen "You were killed" and play a haptic; the killer is not shown.
- [ ] **AC2 No leak**: Given a kill, then other players see nothing new until the next meeting announces the deaths.
- [ ] **AC3 Winner screen**: Given the game ends, then every iOS device and the Public Display show the winning side and the `Outcome.Reason` explanation from `GameLabels`.
- [ ] **AC4 Reset from end**: Given the end screen, when the Admin starts a new game, then clients leave the end screen without a relaunch (the reset itself is 0011 AC3).

## UX

| State | What the user sees |
|---|---|
| Empty | n/a |
| Loading | n/a |
| Content | Full-screen killed card; winner card with reason |
| Error | n/a |

Design link: TODO (Figma)

Accessibility notes: notice is text plus haptic, never colour alone; respects Reduce Motion.

## Data

`ClientView` carries a `killedNotice` flag for the victim only; no new persisted data.

## Constraints check

- [ ] Fits `specs/constraints.md` (roles shown only as reveals of expelled families, OC devices never get roles)
- [x] No new dependency

## Out of scope

- Push notifications while the app is backgrounded (the app must stay in the foreground during play).

## Open questions

- **Dead players and tasks (pending, not decided)**: dead players keep doing tasks, so an Impostor cannot tell the dead from the living. Options: the app says "already dead" when an Impostor tries to kill a dead player; keep the ambiguity on purpose; or a physical marker. Decide before implementing AC1's follow-ups.

## Implementation notes

Filled by `codebase-sync`.
