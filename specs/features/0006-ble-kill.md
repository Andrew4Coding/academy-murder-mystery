---
id: 0006
title: BLE proximity kill
status: draft
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
- [ ] **AC2 Sighting**: Given a scan result above the RSSI threshold, when it is stable for the freshness window, then the device reports the sighting to the host.
- [ ] **AC3 Kill available**: Given a werewolf device with a fresh sighting of a living villager family, when the phase is running and the cooldown is over, then the kill button shows that family and is enabled.
- [ ] **AC4 Kill**: Given an enabled kill, when the werewolf confirms, then the host validates, kills the whole family, notifies the victim devices and the killer's cooldown starts.
- [ ] **AC5 Out of range**: Given no fresh sighting, when the werewolf tries to kill, then the host rejects it.
- [ ] **AC6 Threshold**: Given Admin settings, when the OC changes the RSSI threshold or freshness window, then clients use the new values within 5 s.
- [ ] **AC7 Override**: Given Admin, when the OC force-kills or revives a family, then the engine applies it with an `ocOverride` event.
- [ ] **AC8 Privacy**: Given tokens, when inspected, then they are random per game and carry no player or family identity.

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

- Default RSSI threshold and freshness window; decide at the venue dry run.

## Implementation notes

Filled during and after build by the `codebase-sync` skill.
