---
id: 0012
title: Join and families
status: approved
owner: AND
app: all
created: 2026-10-29
updated: 2026-10-29
related: [0004-lobby-and-roles.md, 0009-public-display.md, 0011-lifecycle-bugfixes.md]
---

# 0012: Join and families

## Summary

Joining becomes one QR on the Public Display. Scans fill Family 1 until it reaches the admin-set capacity, then Family 2, and so on. The first joiner of a family is its head automatically, so Hand Over and Become Head are removed. The head or the Admin can rename a family in the lobby. The role and join screens remind players not to show their phone to anyone.

## User stories

- As an **organiser**, I want one QR on the big screen, so that I do not hand out per-family codes.
- As a **player**, I want to join by scanning and be placed automatically, so that joining takes seconds.
- As a **head of family**, I want to rename my family, so that it is recognisable.

## Acceptance criteria

- [ ] **AC1 Single QR**: Given the lobby, then the Public Display shows one join QR and the Admin Setup shows the same one.
- [ ] **AC2 Auto-assign**: Given capacity N, when players scan, then they fill Family 1 up to N, then Family 2, and so on, in join order.
- [ ] **AC3 Family count**: Given the Admin starts the game, then the family count is derived from the joined players and capacity; the old manual families stepper is gone.
- [ ] **AC4 Auto head**: Given a family, then its first joiner is head; if the head leaves in the lobby, the longest-present member becomes head.
- [ ] **AC5 No hand-over**: Hand Over and Become Head of Family are removed from the app, and `.handOverHead` and `.claimHead` from the wire protocol.
- [ ] **AC6 Rename**: Given the lobby, when the head or the Admin renames a family, then every device and the Public Display show the new name; others cannot rename, and rename is refused once the game has started.
- [ ] **AC7 Phone-screen reminder**: Given the join and role-reveal screens, then they show "Don't show your screen to anyone."

## UX

| State | What the user sees |
|---|---|
| Empty | QR scanner or code fallback on Join |
| Loading | "Joining…" |
| Content | Lobby with family name, members, head badge |
| Error | "Game is full" when every family is at capacity |

Design link: TODO (Figma)

Accessibility notes: the QR also shows the typed fallback code; rename field has a label.

## Data

`HostState` gains `familyCapacity`; join code becomes game-wide. Families persisted in `GameRecord`: SchemaV2 and a migration stage if the stored shape changes (never edit SchemaV1). Needs an ADR superseding the "Family = 6 players" glossary entry.

## Constraints check

- [ ] Fits `specs/constraints.md`
- [x] No new dependency

## Out of scope

- Moving players between families after the game starts.

## Open questions

- Behaviour when the last family is partly filled at start (allow smaller family, or require full?).
- Does an existing wrong-size family break `werewolfCount * 2 < familyCount`?

## Implementation notes

Filled by `codebase-sync`.
