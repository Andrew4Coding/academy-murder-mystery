---
id: 0026
title: Werewolf win reveal on the Public Display
status: draft
owner: AND
app: admin
created: 2026-10-29
updated: 2026-10-29
related: [0009-public-display.md, 0013-kill-notice-and-game-end.md, 0012-join-and-families.md]
---

# 0026: Werewolf win reveal on the Public Display

## Summary

When the werewolves win, the AirPlay Public Display shows who they were. After the winner card it shows every family with its player's selfie, with the werewolf families highlighted and labelled. This is the only moment roles of living families appear on the display, and only after the game has ended.

## User stories

- As an **audience member**, I want to see the families and faces at the end, so that the reveal feels like a payoff.

## Acceptance criteria

- [ ] **AC1 Reveal**: Given the game ends with winner werewolves, when the Public Display shows the end screen, then it shows a grid of all families with name and player selfie (initials when there is no selfie).
- [ ] **AC2 Marked**: Given the reveal, then werewolf families are highlighted and labelled "Werewolf" (text and colour, never colour alone); the rest are plain.
- [ ] **AC3 Villagers win**: Given the game ends with winner villagers, then the display shows the winner card as today with no roles revealed.
- [ ] **AC4 Not early**: Given a game still running, then `PublicDisplayState` carries no roles or selfies.
- [ ] **AC5 Cleared**: Given a new game, then the reveal and selfies are gone from the display.
- [ ] **AC6 Many families**: Given up to 20 families, then the grid fits the screen without scrolling at 1080p.

## UX

| State | What the user sees |
|---|---|
| Empty | n/a |
| Loading | n/a |
| Content | Winner card, then a family grid with faces; werewolf cards highlighted |
| Error | n/a |

Design link: TODO (Figma)

Accessibility notes: "Werewolf" label on each highlighted card; Reduce Motion respected for the reveal animation.

## Data

`PublicDisplayState.Screen.ended` gains an optional `EndReveal` (family name, selfie JPEG, `isWerewolf`), set only when werewolves won. The display is in the same process as the host, so the selfies come straight from `GameHost.selfies`. No persistence.

## Constraints check

- [ ] Fits `specs/constraints.md`: this amends the rule "roles appear on the display only as reveals of expelled families" to also allow the end-of-game reveal. Update `CLAUDE.md` and the privacy note in the same PR.
- [x] No new dependency

## Out of scope

- Reveal when villagers win.
- Showing the reveal on phones.

## Open questions

- None.

## Implementation notes

Filled during and after build.
