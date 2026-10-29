---
id: 0020
title: One person per family
status: implemented
owner: AND
app: all
created: 2026-10-30
updated: 2026-10-30
related: [0004-lobby-and-roles.md, 0012-join-and-families.md, 0014-meeting-upgrade.md]
---

# 0020: One person per family

## Summary

In this event one family is one person with one phone. The member and head-of-family system is removed: every player who scans the game code becomes their own family, and that player votes, reports and acts for it. This supersedes the capacity and head rules of 0012.

## User stories

- As a **player**, I want to join and simply be my own family, so that there is no head or member list to manage.
- As an **organiser**, I want no capacity setting, so that the family count is just the number of players.

## Acceptance criteria

- [x] **AC1 Own family**: Given the game code, when a player joins, then they get the lowest empty family or a new one, never a shared one.
- [x] **AC2 No capacity**: The players-per-family setting is removed from Setup.
- [x] **AC3 No members or head**: No screen shows a member list, "head of family", Hand Over or head-only voting; `MemberView`, `FamilyInfo.head` and `HostError.notHead` are gone.
- [x] **AC4 Player acts**: The player votes, votes to skip discussion and renames their family with no head check.
- [x] **AC5 Leave**: Given the lobby, when a player leaves, then their family is removed (kept only in testing mode).
- [x] **AC6 Display**: The Admin, iPad dashboard and Public Display lobby list each family with its one player; setup issues say "Family N has no player."
- [x] **AC7 Simulation**: Bots are one per family.

## UX

| State | What the user sees |
|---|---|
| Empty | "Waiting…" for a family with no player |
| Content | Family name, the player's name and selfie |
| Error | "Game is full" past 40 families |

Design link: n/a

Accessibility notes: unchanged.

## Data

`HostState.maxFamilySize` and `FamilyInfo.head` are dropped; stored games still decode because extra keys are ignored. `HostState.player(of:)` replaces `members(of:)`.

## Constraints check

- [x] Fits `specs/constraints.md`
- [x] No new dependency

## Out of scope

- Two or more people sharing a family again.

## Open questions

- Whether a family should be named after its player by default instead of "Family N".

## Implementation notes

- `GameView` and `LobbyView` lose `members`, `isHead` and `hasHead`; `FamilySummary` and `AdminFamilyRow` carry `playerID` and `playerName`; the Public Display lobby shows one name per family. ADR 0007.
