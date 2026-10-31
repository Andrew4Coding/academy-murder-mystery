---
id: 0035
title: Cloud host server
status: in-progress
owner: AND
app: all
created: 2026-10-31
updated: 2026-10-31
related: [0003, 0036, ADR 0009]
---

# 0035: Cloud host server

## Summary

A TypeScript server in `cloud/` that behaves like `GameHost` over `wss://`: same JSON messages, same rules, same persistence of state, selfies and booth map. Runs in Docker behind nginx on `moonfall.andrewaryo.com`. It is only ever authoritative when the registry says `cloud` ([0036](0036-host-switching.md)).

## User stories

- As an **organiser**, I want a host that survives my MacBook failing, so the game continues.
- As a **player**, I want to join over cellular or any Wi-Fi.

## Acceptance criteria

- [x] **AC1**: Given a seeded trace exported by the Swift `GameEngine`, when the TypeScript engine replays it, then the resulting state equals the Swift state (golden test).
- [x] **AC2**: Given the Swift wire JSON for every `ClientMessage`, `ServerMessage` and `AdminCommand` case, when the server decodes and re-encodes it, then the JSON is equal (wire fixtures).
- [x] **AC3**: Given a client over WebSocket, when it sends `hello` with the game code, OC PIN or resume ID, then it gets `welcome`, `selfies`, `map` (if the hash differs) and a `state`, as `GameHost` does.
- [x] **AC4**: Given 5 failed logins from one IP, when it tries again, then it is locked out with an escalating delay, regardless of connection.
- [x] **AC5**: Given a restart, when the server starts, then it restores state, selfies and the booth map from SQLite.
- [x] **AC6**: Given the registry says `local`, when a client connects with a game credential, then the server rejects it as not the active host.
- [x] **AC7**: Given a selfie over 150,000 bytes or a non-lobby selfie, then it is rejected as in `GameHost`.
- [x] **AC8**: Given the cloud is active, when an admin connection signs in, then it receives the admin view and `PublicDisplayState` updates.

## Data

SQLite on a Docker volume: `host_state` (HostState JSON), `events`, `selfies`, `booth_map`, `registry`. No Swift schema change.

## Constraints check

- [x] Amends the "no cloud backend" rule through [ADR 0009](../decisions/0009-switchable-cloud-host.md)
- [x] No Swift dependency added. The server has its own npm dependencies (`ws`, `better-sqlite3`).

## Out of scope

Simulation, rehearsal tools and Gallery stay Mac-only. No selfie delta protocol. No automatic failover.

## Open questions

- None. Admin commands are already limited to OC admin stations in Swift, and the port matches.

## Implementation notes

- Server in `cloud/` (Node 22, `ws`, `better-sqlite3`, vitest); wire and routes in `cloud/CONTRACT.md`. 192 tests pass. Differences from Swift: selfies and the booth map persist, booth maps are stored as received (no resize), and a name is validated before a family is assigned.
- Not yet verified: Docker build and a live deployment on `moonfall.andrewaryo.com`.
