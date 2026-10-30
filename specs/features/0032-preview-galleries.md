---
id: 0032
title: Preview galleries for every screen state
status: in-progress
owner: AND
app: all
created: 2026-10-31
updated: 2026-10-31
related: [0031]
---

# 0032: Preview galleries for every screen state

## Summary

Each app target gets Xcode `#Preview` blocks for every screen and its states, plus one scrollable "all states" gallery, so the UI can be reviewed and screen-recorded without running a game. Mock data is built from the real engine and view types in a DEBUG-only fixture factory.

## User stories

- As a **designer or developer**, I want to flip through every state of every screen in the Xcode canvas, so that I can review and record the UI quickly.

## Acceptance criteria

- [ ] **AC1**: Given the iOS target, when the canvas is opened, then there are previews for join, lobby, role (villager and werewolf), actions, meeting, voting, results, sabotage, OC and game over.
- [ ] **AC2**: Given the Mac Admin target, when the canvas is opened, then there are previews for setup, game (each phase), families, devices, simulation and every Public Display screen.
- [ ] **AC3**: Given the iPad target, when the canvas is opened, then there are previews for sign-in, setup, game, families and devices.
- [ ] **AC4**: Given each target, when its gallery preview is opened, then all states are reachable in one scrolling or paged view, in dark and light.
- [ ] **AC5**: Given a Release build, when compiled, then no fixture or gallery code is included (`#if DEBUG`).

## UX

Gallery files live in `Gallery/` under each target folder. Shared fixtures live in `Shared/Preview/PreviewFixtures.swift`.

## Data

None.

## Constraints check

- [x] Fits constraints. `Shared/` stays free of `#if os()`; `#if DEBUG` is allowed.
- [x] No new dependency

## Out of scope

- Snapshot tests.

## Open questions

-

## Implementation notes

Galleries and fixtures exist for all three targets; previews not yet opened in Xcode canvas on every state.
