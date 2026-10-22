---
id: 0002
title: Mac-hosted LAN authority with persisted state
status: proposed
date: 2026-10-22
deciders: [AND]
---

# 0002: Mac-hosted LAN authority with persisted state

## Context

Roles, kills, votes, stamps and timers must be consistent across about 100+ phones, booth OC phones, the Mac and the lab TVs. The PRD has no login. The event runs in one venue and should not depend on internet access or a paid backend.

## Options considered

1. **Mac Admin as LAN host (Bonjour + WebSocket/HTTP)**: no cloud, no accounts, works offline. Risk: venue Wi-Fi with client isolation blocks it.
2. **Cloud backend (Firebase, Supabase, CloudKit)**: works on any network but needs internet, an account and operations.
3. **MultipeerConnectivity peer to peer**: no server, but weaker range and session limits for this many peers.

## Decision

The Mac Admin runs the authoritative game host on the local network, advertised over Bonjour. iOS clients connect, authenticate with a family join code or the OC PIN, and exchange small JSON messages. The host validates every action with the game engine ([ADR 0004](0004-pure-game-engine.md)), persists accepted events to SwiftData, and can resume after a restart. Timers are computed from host timestamps. Clients reconnect automatically and rejoin by a stored identity.

## Consequences

- Positive: offline, no accounts, one source of truth, simple to reason about.
- Negative: depends on Wi-Fi that allows device-to-device traffic; the Mac is a single point of failure (mitigated by persistence and resume).
- Follow-ups: [spec 0003](../features/0003-lan-host-transport.md) must include a venue connectivity check; the Mac needs network server and Bonjour entitlements.
