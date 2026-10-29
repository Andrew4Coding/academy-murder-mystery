---
id: 0018
title: Apple Watch intents
status: approved
owner: AND
app: ios
created: 2026-10-29
updated: 2026-10-29
related: [0006-ble-kill.md, 0007-sabotage.md, 0015-sabotage-rework.md]
---

# 0018: Apple Watch intents

## Summary

A werewolf can trigger Kill and Sabotage from an Apple Watch through App Intents, so no phone screen is shown. The Watch is only a remote: the iPhone keeps BLE and the connection to the host, and the host validates everything. Body report was cancelled and is not included.

## User stories

- As a **werewolf**, I want to act from my wrist, so that nobody sees my screen.

## Acceptance criteria

- [ ] **AC1 Kill intent**: Given a werewolf with a nearby villager family, when they trigger Kill on the Watch, then the iPhone sends it and the host validates (cooldown, range).
- [ ] **AC2 Sabotage intent**: Given the cooldown is over, when they trigger Reactor or Oxygen, then it behaves as in 0015.
- [ ] **AC3 Feedback**: Given a result, then the Watch shows success or the host's error.
- [ ] **AC4 Roles**: Villagers and OC devices expose no intents and the Watch never receives a role.
- [ ] **AC5 Authority**: No rule runs on the Watch or the phone; both only send `GameCommand`s.

## UX

| State | What the user sees |
|---|---|
| Empty | "Open the game on your iPhone" |
| Loading | Sending |
| Content | Kill and Sabotage actions |
| Error | Host error text |

Design link: TODO (Figma)

Accessibility notes: haptic confirmation; large tap targets.

## Data

None.

## Constraints check

- [ ] Fits `specs/apps/ios/constraints.md`; add a Watch target to `project.yml`
- [x] No new dependency (AppIntents, WatchConnectivity are first-party)

## Out of scope

- Body report; running BLE on the Watch.

## Open questions

- Does the iPhone have to stay foregrounded for BLE? (Yes today.) Confirm what the Watch can do if it is not.

## Implementation notes

Filled by `codebase-sync`.
