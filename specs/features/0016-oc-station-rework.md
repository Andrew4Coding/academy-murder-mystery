---
id: 0016
title: OC station rework
status: approved
owner: AND
app: ios
created: 2026-10-29
updated: 2026-10-29
related: [0008-oc-mode-and-stamping.md, 0007-sabotage.md]
---

# 0016: OC station rework

## Summary

The booth OC screen does not make it obvious that the OC must stamp a family. It becomes a grid of large family cards under a clear "Stamp a family" title. The Town Hall observer station is removed because the Mac Admin already has game control and Resolve Sabotage.

## User stories

- As a **booth OC**, I want to see at once which families to stamp, so that I do not have to be told.

## Acceptance criteria

- [ ] **AC1 Title**: Given a task-booth OC signed in, then the screen is titled "Stamp a family" with a one-line instruction.
- [ ] **AC2 Card grid**: Given families, then each is a large card; tap, confirm and stamp.
- [ ] **AC3 States**: Given a card, then stamped families are green, families without this booth are disabled, and off-list stamps still ask for confirmation.
- [ ] **AC4 Observer removed**: Given the station picker, then only Task booths (7) and Sabotage booths (2) are offered; the Town Hall observer view is deleted.
- [ ] **AC5 No roles**: OC devices still never receive roles (`OCView` rows carry stamp progress only).

## UX

| State | What the user sees |
|---|---|
| Empty | "No families yet" |
| Loading | "Waiting for the host" |
| Content | Card grid |
| Error | Existing stamp errors |

Design link: TODO (Figma)

Accessibility notes: cards are 44 pt or larger with the state spoken (stamped, not stamped).

## Data

None.

## Constraints check

- [ ] Fits `specs/apps/ios/constraints.md`
- [x] No new dependency

## Out of scope

- QR-scan stamping.

## Open questions

- None.

## Implementation notes

Filled by `codebase-sync`.
