---
id: 0009
title: Switchable cloud host beside the Mac host
status: accepted
date: 2026-10-31
deciders: [AND]
---

# 0009: Switchable cloud host beside the Mac host

## Context

[ADR 0002](0002-mac-hosted-lan-authority.md) makes the Mac the only authority. It is a single point of failure: sleep, a crash or venue Wi-Fi with client isolation ends the game. We want a second, internet-reachable host that can replace the Mac, without ever having two live hosts.

## Options considered

1. **Switchable host**: exactly one authority is live, either the Mac or a cloud server. A registry says which. State moves between them on a switch.
2. **Hot standby with automatic failover**: risks two live hosts after a Wi-Fi blip, and needs replication.
3. **Cloud only**: drops the offline fallback.
4. **Cloud server in Swift on Linux**: one engine, but the shared code is not a package and uses Apple-only frameworks.

## Decision

Option 1. The cloud server is a TypeScript service (Node, Docker, SQLite) on `moonfall.andrewaryo.com` that speaks the same Codable JSON as today over `wss://`. It ports `GameEngine` and the host logic. Swift and TypeScript engines are kept equal by golden traces: Swift exports seeded command traces, and the TypeScript engine must replay them to identical state in CI.

The Mac Admin app carries a Self-host / Cloud switch. In Cloud mode the Mac is an admin client of the cloud. While self-hosting, the Mac uploads a snapshot to the cloud after every commit as a cold backup. If the Mac dies, an OC-PIN-protected "Take over in cloud" action activates the latest snapshot and flips the registry. There is no automatic failover. Phones read the registry and fall back to Bonjour when it is unreachable.

This amends the root rule "no cloud backend": the cloud host is an optional replacement for the Mac host, never a second authority, and the LAN host remains the default and the offline fallback.

## Consequences

- Positive: survives Mac failure, works on venue networks without device-to-device traffic, keeps offline mode.
- Negative: game rules exist twice (mitigated by golden traces), a public endpoint needs TLS and rate limits, selfies and state now leave the venue (privacy section of the root constraints is updated).
- Follow-ups: [spec 0035](../features/0035-cloud-host-server.md), [spec 0036](../features/0036-host-switching.md).
