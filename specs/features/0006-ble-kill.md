---
id: 0006
title: BLE proximity kill
status: implemented
owner: AND
app: all
created: 2026-10-22
updated: 2026-10-22
related: [decisions/0003-ble-proximity-kill.md, 0002-game-engine.md]
---

# 0006: BLE proximity kill

## Summary

Werewolf players can kill a nearby villager family from the iOS app. Devices advertise a per-game random token over BLE and report sightings of other families' tokens to the host. The host verifies range, cooldown and phase, kills the whole victim family and notifies it. The OC can force-kill or revive from Admin.

## User stories

- As a **werewolf**, I want a kill button that only works when a villager is really near, so the game feels fair.
- As the **Town Hall OC**, I want to override a kill when Bluetooth misbehaves, so the game stays fair.

## Acceptance criteria

- [ ] **AC1 Advertise and scan**: Given a running game, when the iOS app is in the foreground, then it advertises its token and scans for other tokens.
- [x] **AC2 Sighting**: Given a scan result above the RSSI threshold, when it is stable for the freshness window, then the device reports the sighting to the host.
- [x] **AC3 Kill available**: Given a werewolf device with a fresh sighting of a living villager family, when the phase is running and the cooldown is over, then the kill button shows that family and is enabled.
- [x] **AC4 Kill**: Given an enabled kill, when the werewolf confirms, then the host validates, kills the whole family, notifies the victim devices and the killer's cooldown starts.
- [x] **AC5 Out of range**: Given no fresh sighting, when the werewolf tries to kill, then the host rejects it.
- [x] **AC6 Threshold**: Given Admin settings, when the OC changes the RSSI threshold or freshness window, then clients use the new values within 5 s.
- [x] **AC7 Override**: Given Admin, when the OC force-kills or revives a family, then the engine applies it with an `ocOverride` event.
- [x] **AC8 Privacy**: Given tokens, when inspected, then they are random per game and carry no player or family identity.

## UX

| State | What the user sees |
|---|---|
| Empty | "No one nearby" |
| Loading | "Scanning" |
| Content | Nearby villager family and a Kill button, or the cooldown remaining |
| Error | "Bluetooth is off" with a Settings link |

Design link: TODO (Figma)

Accessibility notes: kill result announced by VoiceOver; avoid haptic-only feedback.

## Data

`Sighting` (transient), `KillEvent`; settings `rssiThreshold`, `sightingFreshness`.

## Constraints check

- [x] Fits `specs/constraints.md` (Bluetooth for proximity only)
- [x] No new dependency (CoreBluetooth)

## Out of scope

- Background BLE.
- Precise distance in metres.

## Open questions

- Default RSSI threshold (-65 dBm) and freshness window (5 s) are placeholders; calibrate at the venue dry run with real phones.
- AC1 (advertise and scan) is implemented with CoreBluetooth but cannot run in the simulator: check on two real iPhones. Sighting validation, range and cooldown rules are covered by host tests.

## Implementation notes

- Host: `ClientMessage.sightings` and `.kill`, `GameHost+Proximity` (ephemeral per-family sighting table, `nearbyFamilies`, `refreshNearby` called from `tick`, `kill`, `setProximity`). `GameView` gains `bleToken` (own only), `proximity`, `nearby`, `killReadyAt`.
- iOS: `ProximityService` (CoreBluetooth: advertises the token as the local name under one service UUID, scans only for alive werewolf families, smooths RSSI, reports every second; foreground only), `ActionsView` kill section (werewolf tab, confirmation, cooldown), `GameTabsView` starts and stops the service from the scene phase. Admin: Bluetooth range settings in `SetupView`; Eliminate, Revive and End Game in `GameControlView`.
- Tests: `GameHostKillTests`.
