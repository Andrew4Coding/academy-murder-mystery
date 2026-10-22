---
id: 0008
title: OC mode and task stamping
status: approved
owner: AND
app: all
created: 2026-10-22
updated: 2026-10-22
related: [0002-game-engine.md, 0004-lobby-and-roles.md, 0007-sabotage.md]
---

# 0008: OC mode and task stamping

## Summary

Organisers unlock OC mode in the iOS app with the game's OC PIN and choose a booth. A task-booth OC records a stamp for a family when its paper card is stamped; a sabotage-booth OC marks the sabotage Resolved. Town Hall OC uses the Mac Admin for the same actions and overrides. Family task lists are assigned by the engine ([0002](0002-game-engine.md)).

## User stories

- As a **booth OC**, I want a quick way to find a family and record the stamp, so queues stay short.
- As a **player**, I want my task list to update after a stamp, so I know what is left.

## Acceptance criteria

- [ ] **AC1 Unlock**: Given the iOS app, when a user chooses "I'm an OC" and enters the PIN, then OC mode opens and asks for a booth (7 task booths, 2 sabotage booths, Town Hall observer); a wrong PIN is rejected and rate-limited.
- [ ] **AC2 Stamp**: Given a task booth OC, when they select a family and confirm Stamp, then the host records one stamp for that booth and the family's progress updates on its devices.
- [ ] **AC3 Disguise**: Given a werewolf family at a booth, when stamped, then the OC flow is identical to a villager's and no role is shown.
- [ ] **AC4 Idempotent**: Given a family already stamped at a booth, when stamped again, then the host ignores it and the OC sees "Already stamped".
- [ ] **AC5 Wrong booth**: Given a booth not on the family's list, when the OC tries to stamp, then the app warns "Not on this family's list" and requires confirmation.
- [ ] **AC6 Undo**: Given a recent stamp, when the OC taps Undo within 60 s, then it is removed and progress recomputed.
- [ ] **AC7 Sabotage resolve**: Given a sabotage booth OC, when a sabotage is active at their booth, then a Resolved button is enabled and clears it per [0007](0007-sabotage.md).
- [ ] **AC8 Admin parity**: Given the Mac Admin, when the Town Hall OC opens a family, then they can stamp, undo and resolve sabotage with the same rules.
- [ ] **AC9 Privacy**: Given OC mode, when it shows families, then roles of living families are never shown to a booth OC.

## UX

| State | What the user sees |
|---|---|
| Empty | "No families yet" |
| Loading | "Connecting to the host" |
| Content | Searchable family list, stamp confirmation, progress per family |
| Error | "Wrong PIN", "Already stamped" |

Design link: TODO (Figma)

Accessibility notes: search field labelled; confirm actions have clear VoiceOver labels; large tap targets for crowded booths.

## Data

`Stamp` (familyId, booth, at, ocBoothId), OC session records per device.

## Constraints check

- [x] Fits `specs/constraints.md`
- [x] No new dependency

## Out of scope

- Per-booth PINs.
- Scoring beyond stamp counts.

## Open questions

- Should booth OCs see a family's whole list or only their booth? Proposed: only whether their booth is on the list and already stamped.

## Implementation notes

Filled during and after build by the `codebase-sync` skill.
