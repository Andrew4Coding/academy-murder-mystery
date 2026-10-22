---
id: 0003
title: BLE proximity kill with RSSI threshold and OC override
status: accepted
date: 2026-10-22
deciders: [AND]
---

# 0003: BLE proximity kill with RSSI threshold and OC override

## Context

A kill must only work at close range. The PRD says the app uses Bluetooth Low Energy proximity between devices. Signal strength on phones varies, and iOS limits background Bluetooth.

## Options considered

1. **BLE advertise and scan with an RSSI threshold**: matches the PRD; needs venue calibration.
2. **Tap-to-confirm from a list of nearby families**: easier to tune but less precise about distance.
3. **BLE without any override**: no recourse when it misbehaves.

## Decision

Every player device advertises a per-game random token and scans for tokens of other families. A werewolf can kill a villager family only while the host has recently received a sighting of that family's token above the RSSI threshold from the werewolf's device. The host validates the sighting, cooldown and game phase through the engine, then kills the whole victim family. The RSSI threshold and sighting freshness window are settings in Admin. The Town Hall OC can force-kill or revive a family from Admin. The app must stay in the foreground during play.

## Consequences

- Positive: faithful to the PRD, tunable on site, with a safe manual fallback.
- Negative: BLE accuracy varies by device and body position; needs a real-device dry run.
- Follow-ups: [spec 0006](../features/0006-ble-kill.md); Bluetooth usage string and permission flow.
