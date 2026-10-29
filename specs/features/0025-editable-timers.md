---
id: 0025
title: Editable timers for the OC
status: approved
owner: AND
app: all
created: 2026-10-29
updated: 2026-10-29
related: [0005-meetings-and-voting.md, 0007-sabotage.md, 0017-ipad-admin.md, 0015-sabotage-rework.md]
---

# 0025: Editable timers for the OC

## Summary

The OC can only add 1, 2 or 5 minutes to a meeting timer today. They need to adjust every running timer freely, up or down: the meeting timer (discussion or voting), the time left until the final vote, and an active sabotage countdown. This must exist on both the iPad Admin dashboard and the Mac Admin.

## User stories

- As an **OC**, I want to add or remove time on any running timer, so that I can react to what happens at the event.

## Acceptance criteria

- [ ] **AC1 Adjust**: Given a running timer (discussion, voting, final-vote clock, active sabotage), when the OC applies a delta in seconds (positive or negative), then the engine moves that timer's end by the delta and all clients and the Public Display follow from host time.
- [ ] **AC2 Presets and custom**: Given the timer controls, then they offer presets (±30 s, ±1 min, ±5 min) and a custom minutes:seconds entry with add and subtract.
- [ ] **AC3 Floor**: Given a delta that would put the end at or before now, when applied, then the end becomes now plus 1 s (the timer fires on the next tick), never in the past.
- [ ] **AC4 Final vote clock**: Given the game is running, when the OC adjusts the game clock, then `finalVoteAt` moves; it cannot be changed once the final vote has started.
- [ ] **AC5 Sabotage**: Given an active sabotage, when adjusted, then its `endsAt` moves; without one the control is disabled. Cooldowns are not editable.
- [ ] **AC6 Both admins**: Given the iPad dashboard and the Mac Game screen, then both show the same timer controls, and the iPad sends them as an `AdminCommand` checked in `GameHost.adminCommand`.
- [ ] **AC7 Logged**: Given an adjustment, then an `ocOverride` event records which timer and the delta.
- [ ] **AC8 Existing add-time**: Given a meeting, then the existing `extendMeeting` behaviour keeps working (it becomes a special case of the new command).

## UX

| State | What the user sees |
|---|---|
| Empty | Controls disabled when no timer runs |
| Loading | n/a |
| Content | A row per running timer with its countdown and a "Adjust" menu: presets, custom field |
| Error | "Timer already finished" |

Design link: TODO (Figma)

Accessibility notes: buttons carry the delta in their label ("Add 1 minute to voting"); custom field is keyboard friendly on macOS.

## Data

New `GameCommand.adjustTimer(TimerTarget, seconds:)` with `TimerTarget` = `.meeting`, `.finalVote`, `.sabotage`; new `OCOverride.timerAdjusted`. `GameState.finalVoteAt` becomes derived from `startedAt + gameDuration` plus a stored `gameClockOffset` (stored games must still decode, default 0). No schema migration.

## Constraints check

- [x] Fits `specs/constraints.md` (timers stay host timestamps; rule lives in `GameEngine`)
- [x] No new dependency

## Out of scope

- Editing cooldowns or default durations mid-game (Setup still owns those before the game starts).

## Open questions

- None.

## Implementation notes

Filled during and after build.
