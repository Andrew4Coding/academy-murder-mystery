---
id: 0017
title: iPad admin dashboard
status: implemented
owner: AND
app: admin
created: 2026-10-29
updated: 2026-10-29
related: [0003-lan-host-transport.md, 0009-public-display.md]
---

# 0017: iPad admin dashboard

## Summary

The Admin runs on macOS only. A new iPad target gives organisers a dashboard (game control, family status, meeting controls) by reusing the admin views, which move into `Shared/`.

## User stories

- As an **organiser**, I want an iPad dashboard, so that I can run the game while walking around.

## Acceptance criteria

- [x] **AC1 Target**: `project.yml` defines `MoonfallAdminiPad` (iPad, iOS 26+) with its own scheme and test bundle.
- [ ] **AC2 Reuse**: Admin views used by both Mac and iPad live in `Shared/` with no `#if os()`; platform differences are injected.
- [x] **AC3 Dashboard**: The iPad shows game status, families, meeting controls (add time, start discussion, approve skip) and Resolve Sabotage.
- [x] **AC4 Host model**: One authority only. The iPad is a client of the Mac host (not a second host) unless an ADR changes ADR-0002.

## UX

| State | What the user sees |
|---|---|
| Empty | "Looking for the host" |
| Loading | Connecting |
| Content | Split-view dashboard |
| Error | Host offline banner |

Design link: TODO (Figma)

Accessibility notes: Dynamic Type, VoiceOver and keyboard support.

## Data

New admin-client message identity on the wire; no schema change.

## Constraints check

- [ ] Fits `specs/apps/admin/constraints.md`; update it for iPad
- [ ] ADR if the iPad ever hosts

## Out of scope

- Hosting a game from the iPad.

## Open questions

- Which controls need an authentication step (the OC PIN?).

## Implementation notes

- Target `MoonfallAdminiPad` (`AdminiPad/`, scheme only, no test bundle yet). The iPad is an OC device with `OCStation.admin`, authenticated by the OC PIN (answers the PIN open question); `GameHost.adminView()` builds `AdminView` and `GameHost.adminCommand` runs `AdminCommand`s. No roles are sent.
- Deviation from AC2: the Mac admin views use macOS-only APIs (`Table` windows, `NSSound`, toolbars), so they were not moved into `Shared/`. The iPad has its own small dashboard on the shared client types. AC2 stays unticked.
- Not run on a real iPad.
