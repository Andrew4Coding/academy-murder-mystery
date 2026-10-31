---
id: 0036
title: Host switching, registry and failover
status: in-progress
owner: AND
app: all
created: 2026-10-31
updated: 2026-10-31
related: [0003, 0035, ADR 0009]
---

# 0036: Host switching, registry and failover

## Summary

Clients, the Mac Admin app and the iPad admin can use either host. A registry on the cloud server names the active host. The Mac switches mode with full state transfer, uploads cold-backup snapshots while self-hosting, and the OC PIN can activate the cloud when the Mac is dead.

## User stories

- As an **organiser**, I want to switch between my Mac and the cloud from one control.
- As an **organiser**, I want to take over in the cloud if the Mac dies.
- As a **player**, I want my phone to follow the active host with no setting.

## Acceptance criteria

- [x] **AC1**: Given the registry says `cloud`, when a phone starts, then it connects to `wss://moonfall.andrewaryo.com`; given `local` or an unreachable registry, then it browses Bonjour.
- [x] **AC2**: Given the Mac self-hosts a game, when I choose Cloud, then the Mac exports `HostState`, selfies and booth map, the cloud imports them and the registry flips to `cloud`, and the local host stops listening.
- [x] **AC3**: Given the cloud is active, when I choose Self-host, then the state moves back the same way and the registry flips to `local`.
- [x] **AC4**: Given a switch, when phones reconnect, then they resume with the same resume ID and see the same game.
- [x] **AC5**: Given the Mac self-hosts, when it commits, then it uploads a snapshot to the cloud as a cold backup, and the cloud takes no action on it.
- [x] **AC6**: Given the Mac is unreachable, when the OC PIN is entered on the iPad admin or the take-over web page, then the cloud activates the latest snapshot and flips the registry to `cloud`.
- [x] **AC7**: Given the Mac is in Cloud mode, then it signs in to the cloud as an admin, sends every `AdminCommand` and drives the Public Display from the streamed `PublicDisplayState`.
- [x] **AC8**: Given any registry write, then it is accepted only with the OC PIN or the Mac's pairing secret.

## UX

Mac Admin: a Host mode control (Self-host / Cloud) with status (active host, last snapshot age, connected state) and a confirmation before switching during a game. iPad admin: a "Take over in cloud" action in Devices. Not conveyed by colour alone.

## Data

`HostState` snapshot encoding is the existing Codable JSON. A pairing secret is stored in the Mac's Keychain-free `UserDefaults` field `cloudPairingSecret` (test value only until Keychain is added).

## Constraints check

- [x] Amends the "no cloud backend" rule through [ADR 0009](../decisions/0009-switchable-cloud-host.md)
- [x] Uses only `URLSessionWebSocketTask`, no new dependency
- [x] Privacy: state and selfies leave the venue while the cloud is used. Root privacy section updated.

## Out of scope

Automatic failover, selfie deltas, Keychain pairing storage.

## Open questions

- Whether `URLSessionWebSocketTask` survives backgrounding. Checked on a real device.

## Implementation notes

- Swift: `Shared/Net/{WebSocketClientTransport,AdaptiveClientTransport}`, `Shared/Host/{CloudConfig,HostRegistryClient,HostEndpointResolver,HostSnapshot,SnapshotUploader,HostModeController,CloudTakeoverController}`, `Admin/Features/Devices/HostModeSection`, `Admin/Features/Cloud/CloudAdminScreen` (the Mac shows the iPad admin tabs from `Shared/Features/RemoteAdmin` in Cloud mode).
- Server and contract: `cloud/` (see `cloud/CONTRACT.md`). Golden fixtures are written by `Tests/Shared/GoldenFixtureGenerator.swift` when `MOONFALL_WRITE_FIXTURES=<dir>` is set.
- Not yet verified: live deployment, real-device WebSocket backgrounding. Votes cast before a switch are lost because ballots are never encoded. In Cloud mode the Mac shows the same Setup, Game, Families and Booths tabs as the iPad admin, sent to the cloud as `AdminCommand`s, plus the Public Display.
