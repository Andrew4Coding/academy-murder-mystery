---
id: 0028
title: Debug mode
status: implemented
owner: AND
app: admin
created: 2026-10-29
updated: 2026-10-29
related: [0002-game-engine.md, 0007-sabotage.md, 0013-kill-notice-and-game-end.md]
---

# 0028: Debug mode

## Summary

A Setup toggle that relaxes the rules so the OC can test a full round with few devices: two families are enough, kill and sabotage have no cooldown, and a kill never ends the game.

## User stories

- As an **OC**, I want a Debug Mode toggle, so that I can try kills and sabotage repeatedly with two phones.

## Acceptance criteria

- [x] **AC1 Toggle**: Given the lobby, when the OC turns Debug Mode on or off in Setup, then `GameSettings.debugMode` changes; it is locked once the game starts.
- [x] **AC2 Two families**: Given debug mode, then a game can start with 2 families and 1 werewolf family; without it the 3-family and fewer-than-half rules apply.
- [x] **AC3 No cooldown**: Given debug mode, then a werewolf can kill and sabotage again straight away (kill and sabotage cooldowns are 0).
- [x] **AC4 No auto end on kill**: Given debug mode, when a werewolf kills a family, then the game keeps running even at parity. Parity never ends a debug game; the OC can still end it.
- [x] **AC5 Off by default**: Stored games without the setting decode with debug mode off.

## UX

| State | What the user sees |
|---|---|
| Content | A "Debug Mode" toggle in the Game section of Setup, with a footer explaining the relaxed rules |

Accessibility notes: a standard `Toggle`, labelled in text.

## Data

`GameSettings.debugMode: Bool?` (optional so stored games still decode). No schema version change.

## Constraints check

- [x] Fits `specs/constraints.md` and `specs/apps/admin/constraints.md`
- [x] No new dependency

## Out of scope

- Ending by task completion or by all werewolves removed still applies in debug mode.

## Open questions

-

## Implementation notes
