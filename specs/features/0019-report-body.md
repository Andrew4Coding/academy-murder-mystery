---
id: 0019
title: Report body over BLE
status: approved
owner: AND
app: all
created: 2026-10-30
updated: 2026-10-30
related: [0006-ble-kill.md, 0005-meetings-and-voting.md, 0013-kill-notice-and-game-end.md]
---

# 0019: Report body over BLE

## Summary

An alive player can report a body in the app, but only while standing close to it. A killed family's phones keep advertising over BLE until the body is reported; every alive phone scans, and the host decides whether a body is near. A valid report opens a discussion at once. This brings back the report-body idea that was cancelled earlier, with BLE so nobody can report from afar.

## User stories

- As an **alive player**, I want to report a body I found, so that a meeting starts.
- As an **organiser**, I want reports to need real proximity, so that nobody can call meetings from across the venue.

## Acceptance criteria

- [x] **AC1 Body beacon**: Given a killed family whose death has not been announced, then its phones keep advertising their BLE token; after the next meeting starts they stop.
- [x] **AC2 Everyone scans**: Given an alive player of any role, then the phone scans and reports sightings, so scanning does not reveal werewolves.
- [x] **AC3 Near body**: Given a fresh sighting at or above the RSSI threshold, then the host lists that family as a nearby body for that viewer.
- [x] **AC4 Report**: Given the game is running and a body is nearby, when the player reports it, then the host starts a discussion and the death is announced.
- [x] **AC5 Too far**: Given no fresh nearby sighting, when a report arrives, then the host rejects it.
- [x] **AC6 Not twice**: Given a body already announced in a meeting, then it cannot be reported again.
- [x] **AC7 Eligibility**: Dead, expelled and OC devices cannot report, and reports during a meeting are rejected.

## UX

| State | What the user sees |
|---|---|
| Empty | "No body nearby" |
| Loading | n/a |
| Content | "Report" button per nearby body |
| Error | "Get closer to the body" |

Design link: TODO (Figma)

Accessibility notes: the Report button is at least 44 pt and says whose body it is.

## Data

`GameCommand.reportBody(by:body:)`, `ClientMessage.reportBody`, `GameView.nearbyBodies` and `bodyActive`; nothing persisted.

## Constraints check

- [x] Fits `specs/constraints.md`: BLE is only for proximity, the host decides, no role leaks
- [x] No new dependency

## Out of scope

- Reporting from the Apple Watch; reporting by OC devices.

## Open questions

- Whether a report should also let the OC ring the physical bell: for now it only opens the app discussion.

## Implementation notes

Filled by `codebase-sync`.
