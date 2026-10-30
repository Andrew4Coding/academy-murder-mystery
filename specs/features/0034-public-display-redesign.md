---
id: 0034
title: Public Display redesign
status: approved
owner: AND
app: admin
created: 2026-10-31
updated: 2026-10-31
related: [0031, 0032]
---

# 0034: Public Display redesign

## Summary

The Public Display, the window the Mac mirrors to a TV or projector over AirPlay, becomes a cinematic dark stage: moon and wolf motif, red glow and vignette, bold SF Pro type, monospaced countdowns, tidier layouts. It stays readable from across a room and never shows roles except the existing reveal rules.

## User stories

- As a **spectator in the room**, I want big, clear, good-looking information on the screen, so that I can follow the game from my seat.

## Acceptance criteria

- [ ] **AC1**: Given every `PublicDisplayState.screen`, when shown at 1920x1080 and 1280x720, then content fits without clipping or overlap.
- [ ] **AC2**: Given any text on the display, when measured, then it meets 4.5:1 contrast on its background.
- [ ] **AC3**: Given Reduce Motion, when the display is shown, then the background animation and symbol effects are static.
- [ ] **AC4**: Given the display, when it renders, then it only reads `PublicDisplayState` and shows roles only as the existing reveals.
- [ ] **AC5**: Given the sabotage alarm, when active, then it is conveyed by icon and text as well as red.

## UX

Fonts: SF Pro only (default, rounded and condensed widths). Always dark, independent of the system appearance.

## Data

None.

## Constraints check

- [x] Fits constraints; `GameState` and `GameView` never reach the display
- [x] No new dependency or font file

## Out of scope

- Custom fonts, new display screens or content.

## Open questions

-

## Implementation notes

Filled by `codebase-sync`.
