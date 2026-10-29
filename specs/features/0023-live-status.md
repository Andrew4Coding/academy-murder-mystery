---
id: 0023
title: Live status on the Lock Screen
status: implemented
owner: AND
app: ios
created: 2026-10-30
updated: 2026-10-30
related: [0013-kill-notice-and-game-end.md, 0015-sabotage-rework.md, 0018-watch-intents.md]
---

# 0023: Live status on the Lock Screen

## Summary

While a game runs, the iPhone shows a Live Activity on the Lock Screen and in the Dynamic Island: what phase the game is in, a sabotage countdown, meeting timers, "You were killed" and the winner. There is no push server (the host is a Mac on the local network), so the activity is updated by the app itself and only stays fresh while the app keeps running; the app asks iOS for background time and shows a "reconnecting" look when an update is overdue.

## User stories

- As a **player**, I want to glance at my Lock Screen and see what is happening, so that I don't have to open the app in front of others.

## Acceptance criteria

- [x] **AC1 Start and end**: Given a signed-in player, then a Live Activity starts in the lobby or game and ends when the player signs out or 5 minutes after the game ends.
- [x] **AC2 Phases**: Given a running game, then the activity shows playing (with task progress), discussion and voting with their countdowns.
- [x] **AC3 Sabotage**: Given an active sabotage, then the activity turns red with the booth and countdown.
- [x] **AC4 Killed and over**: Given the family is killed or voted out, or the game ends, then the activity says so, with the winner and reason at the end.
- [x] **AC5 Privacy**: The activity never shows the role, nearby families, ballots or tasks by name.
- [x] **AC6 Freshness**: Given no update for 90 s, then the activity is marked stale and shows "Reconnecting".

## UX

| State | What the user sees |
|---|---|
| Empty | No activity outside a game |
| Loading | n/a |
| Content | Icon, title, detail and a countdown |
| Error | "Reconnecting" when stale |

Design link: TODO (Figma)

Accessibility notes: titles carry the state in words, not colour alone; timers use system timer text.

## Data

`GameActivityAttributes` (shared by the app and the widget extension); nothing persisted.

## Constraints check

- [x] Fits `specs/constraints.md`; the activity carries no secrets
- [x] No new third-party dependency (ActivityKit, WidgetKit)

## Out of scope

- Remote push updates (needs a server); updates while the app is suspended.
- Apple Watch complications.

## Open questions

- How long iOS keeps the app running in the background with only Bluetooth modes and a background task: measure on devices. If too short, a server or a silent-audio mode would be needed.
- "You were killed" is visible on the Lock Screen to bystanders; accepted because it is announced at the next meeting anyway.

## Implementation notes

- Widget extension `MurderMysteryLive` (`LiveActivity/Widget`) shares `GameActivityAttributes` with the app. `iOS/Live/LiveStatusController` maps `ClientView` to a state (ended, sabotage, meeting, killed, playing, lobby), refreshes every 30 s with a 90 s `staleDate`, takes a background task on `.background`, and ends the activity on sign-out or 5 min after the game. `iOS/Info.plist` gains `NSSupportsLiveActivities` and the Bluetooth background modes (set in `project.yml`). `ProximityPlan` still only advertises and scans in the foreground.
- Not run on a device: how long iOS keeps the app alive in the background is unmeasured (see Open questions).
