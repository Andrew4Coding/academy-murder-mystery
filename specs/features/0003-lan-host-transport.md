---
id: 0003
title: LAN host transport and persistence
status: draft
owner: AND
app: all
created: 2026-10-22
updated: 2026-10-22
related: [decisions/0002-mac-hosted-lan-authority.md, 0002-game-engine.md]
---

# 0003: LAN host transport and persistence

## Summary

The Mac Admin hosts the game on the local network over Bonjour; iOS devices connect as clients. The host maps client commands to the engine ([0002](0002-game-engine.md)), persists accepted events with SwiftData, and resumes after a restart. Clients reconnect and rejoin automatically.

## User stories

- As a **player**, I want my phone to find the game by itself, so I only need my family code.
- As the **Town Hall OC**, I want the game to survive a crash of the Mac app, so the event never restarts.

## Acceptance criteria

- [ ] **AC1 Discovery**: Given the host is running, when an iOS client opens, then it discovers the host over Bonjour and connects without typing an address.
- [ ] **AC2 Auth**: Given a client, when it sends a valid family code or the OC PIN, then the host accepts it; invalid codes are rejected and rate-limited.
- [ ] **AC3 Command flow**: Given a connected client, when it sends a command, then the host runs it through the engine, persists the resulting events and broadcasts the new state only to clients allowed to see it (roles and task lists stay private).
- [ ] **AC4 Resume**: Given a game in progress, when the Mac app is killed and relaunched, then state, cooldowns and timers are restored from persisted events.
- [ ] **AC5 Reconnect**: Given a client loses the connection, when it reconnects, then it rejoins its family by stored identity and shows correct countdowns computed from host timestamps.
- [ ] **AC6 Connectivity check**: Given the Admin app, when the OC runs "Check connectivity", then it lists connected devices and flags devices that cannot be reached.
- [ ] **AC7 Clock**: Given any client, when it shows a countdown, then it derives it from host time offset, never from its own authoritative timer.

## UX

| State | What the user sees |
|---|---|
| Empty | iOS: "Looking for game"; Admin: "No devices connected" |
| Loading | iOS: "Connecting"; Admin: "Restoring game" |
| Content | iOS: connected indicator; Admin: device list with status |
| Error | iOS: "Can't reach the host" with retry; Admin: unreachable device list |

Design link: TODO (Figma)

Accessibility notes: connection status exposed to VoiceOver; Admin device list fully keyboard-navigable.

## Data

New SwiftData models `GameRecord` and `GameEventRecord` (schema V1 of the real domain), `GameRepository` protocol plus `SwiftDataGameRepository`. Wire protocol: versioned JSON messages (`command`, `state`, `error`).

## Constraints check

- [x] Fits `specs/constraints.md` and target constraints (Local Network and server entitlements recorded)
- [x] No new dependency (Network.framework and Foundation only)

## Out of scope

- Internet or cloud sync.
- Encryption beyond a per-game join secret (LAN event).

## Open questions

- Does the venue Wi-Fi allow client-to-client traffic? Check before the event; fallback is a travel router run by OC.

## Implementation notes

Filled during and after build by the `codebase-sync` skill.
