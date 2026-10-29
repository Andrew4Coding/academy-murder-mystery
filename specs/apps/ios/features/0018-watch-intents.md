---
id: 0018
title: Apple Watch intents
status: in-progress
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
- [x] **AC4 Roles**: Villagers and OC devices expose no intents and the Watch never receives a role.
- [x] **AC5 Authority**: No rule runs on the Watch or the phone; both only send `GameCommand`s.
- [x] **AC6 Voting without a screen**: Given a meeting, when a player runs "Vote" (choosing a family), "Vote Skip" or "Skip Discussion", then the vote is sent as from the app and the reply is neutral.
- [x] **AC7 Cold start**: Given the app is not in the foreground, when an intent runs, then it connects to the host and waits up to 5 s for a confirmed identity before replying "Not available right now."

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

- Deviation: no watchOS target. App Intents live in the iPhone app (`iOS/Intents/GameIntents.swift`: kill the single nearby family, start Reactor or Oxygen) and are offered to Siri, Shortcuts and Apple Watch through the paired phone. AC1 to AC3 still need a check on a real Watch. Non-werewolves get the same "not available" reply, so no role leaks.
- Added after the first pass: `GameClientRegistry.shared` is the one `GameClient` for the app and the intents, so intents launched in the background can connect (`connectedClient()` waits up to 5 s); `GameClient.start()` is now idempotent. New intents `VoteForFamilyIntent` (with `FamilyEntity` options from the alive families), `VoteSkipIntent` and `SkipDiscussionIntent`. Still unchecked on a real Watch (AC1 to AC3).
