---
id: 0015
title: Sabotage rework
status: implemented
owner: AND
app: all
created: 2026-10-29
updated: 2026-10-29
related: [0007-sabotage.md, 0009-public-display.md, 0011-lifecycle-bugfixes.md]
---

# 0015: Sabotage rework

## Summary

Reactor (Collab 7A) and Oxygen (Collab 6) get their own buttons, the Admin sets duration and cooldown per booth, and the Public Display plays a looping alarm while a sabotage runs. The cooldown stays shared between werewolf families. The reported "7A button missing" was the initial cooldown hiding every button; 0011 AC7 removes it.

## User stories

- As a **werewolf**, I want a separate button per booth, so that my choice is clear.
- As an **organiser**, I want to set minutes per booth, so that each sabotage is balanced.
- As a **villager**, I want a loud alarm on the big screen, so that I hear it from across the venue.

## Acceptance criteria

- [x] **AC1 Separate buttons**: Given a werewolf device with the cooldown over and no active sabotage, then Reactor and Oxygen each have their own button.
- [x] **AC2 Per-booth settings**: Given Setup, then the Admin sets duration and cooldown minutes for Reactor and for Oxygen; defaults are 90 s and 120 s.
- [x] **AC3 Applied values**: Given a triggered booth, then its duration drives the countdown and its cooldown becomes the shared cooldown for all werewolf families.
- [x] **AC4 Alarm**: Given an active sabotage, then the Public Display plays a looping alarm until it is resolved or expires; the iOS banner sound is unchanged.
- [x] **AC5 Rules kept**: One sabotage at a time, none during meetings (0007 AC6, AC7) still hold.

## UX

| State | What the user sees |
|---|---|
| Empty | Both buttons ready |
| Loading | n/a |
| Content | Countdown with booth name; cooldown remaining |
| Error | "Sabotage on cooldown" |

Design link: TODO (Figma)

Accessibility notes: alarm uses sound, haptics and text; the Public Display has a Mute toggle for the Mac.

## Data

`GameSettings` gains per-booth `sabotageDuration` and `sabotageCooldown`; SchemaV2 if persisted settings change shape.

## Constraints check

- [ ] Fits `specs/constraints.md`
- [x] No new dependency (AVFoundation is first-party)

## Out of scope

- More sabotage booths; per-family cooldowns.

## Open questions

- Alarm audio asset: bundle a royalty-free sound or synthesise one.

## Implementation notes

- `GameSettings.oxygenDuration` / `oxygenCooldown` (optional, Reactor uses the original fields). `GameView.sabotageTimings`. iOS: one card per booth. Admin: Sabotage section in Setup, looping `NSSound` ("Sosumi", a placeholder) with a mute switch in Display.
