---
id: 0021
title: Delete families
status: implemented
owner: AND
app: all
created: 2026-10-30
updated: 2026-10-30
related: [0012-join-and-families.md, 0017-ipad-admin.md]
---

# 0021: Delete families

## Summary

In the lobby, the organiser can delete a family from the families list on the Mac and on the iPad, for example to clear a test join or someone who left their seat. The family's player goes back to the join screen. Once the game has started a family can only be eliminated, never deleted, because the engine's rules depend on the full set of families.

## User stories

- As an **organiser**, I want to remove a family from the list, so that the game starts with the right families.

## Acceptance criteria

- [x] **AC1 Mac delete**: Given the lobby, when the organiser deletes a family in Setup and confirms, then it leaves the list on every screen.
- [x] **AC2 iPad delete**: Given the lobby, when the organiser deletes a family on the iPad dashboard and confirms, then it leaves the list on every screen.
- [x] **AC3 Player reset**: Given a deleted family with a player, then that phone returns to the join screen and the player's selfie is removed.
- [x] **AC4 Lobby only**: Given a started game, then delete is disabled in both apps and the host rejects it.

## UX

| State | What the user sees |
|---|---|
| Empty | "No families yet" |
| Loading | n/a |
| Content | Trash button per row, confirmation naming the family |
| Error | "The game has already started." |

Design link: n/a

Accessibility notes: the trash button has a label ("Delete Family 2").

## Data

`GameHost.removeFamily`, `AdminCommand.removeFamily`; nothing persisted beyond the family list.

## Constraints check

- [x] Fits `specs/constraints.md`
- [x] No new dependency

## Out of scope

- Deleting a family during a game (use Eliminate).

## Open questions

- None.

## Implementation notes

- `GameHost.removeFamily` (lobby only; resets the player's phone, drops the selfie). Mac: trash column in Setup's families table with a confirmation. iPad: trash column on the dashboard via `AdminCommand.removeFamily`, disabled outside the lobby. Not run on devices.
