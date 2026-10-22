---
id: 0010
title: Simulation mode
status: implemented
owner: AND
app: admin
created: 2026-10-22
updated: 2026-10-22
related: [0002-game-engine.md, 0003-lan-host-transport.md]
---

# 0010: Simulation mode

## Summary

A rehearsal mode in Admin that fills a game with bot families, speeds up the clock and scripts kills, stamps and votes against the real engine, so the OC can test a whole game before the event.

## User stories

- As the **Town Hall OC**, I want to run a full game with bots, so I can rehearse and spot problems.

## Acceptance criteria

- [x] **AC1 Bots**: Given Admin setup, when the OC enables Simulation, then they choose the number of bot families and the rest are filled with bots that play their roles.
- [x] **AC2 Fast forward**: Given a simulated game, when the OC sets a speed (1x, 5x, 20x), then the engine clock advances accordingly and all timers still derive from it.
- [x] **AC3 Scripted actions**: Given a simulated game, when it runs, then bots stamp tasks, kill, sabotage, vote and skip according to a seeded random plan.
- [x] **AC4 Same engine**: Given simulation, when events are produced, then they come from the same engine and persistence as a real game and are marked `simulated`.
- [x] **AC5 Isolation**: Given simulation, when it ends, then its data is discarded or kept separately and never mixes with a real game.
- [x] **AC6 Seeded replay**: Given a seed, when the same simulation is run again, then it produces the same events.

## UX

| State | What the user sees |
|---|---|
| Empty | "Simulation off" |
| Loading | "Preparing bots" |
| Content | Speed control, bot summary, event log |
| Error | "Simulation can't start with these settings" |

Design link: TODO (Figma)

Accessibility notes: all controls keyboard-operable.

## Data

Marks events with `simulated: Bool` and a seed; no new persistence model.

## Constraints check

- [x] Fits `specs/constraints.md`
- [x] No new dependency

## Out of scope

- Simulating BLE signal strength; BLE is checked on real devices.

## Open questions

- Simulation runs on its own host with an in-memory store and only bots (implemented); mixing bots with real phones is not supported, so a rehearsal can never affect the real game. Revisit if the OC wants to test real phones together with bots.

## Implementation notes

- Shared: `Simulation` (separate `GameHost` with `ManualHostClock` and `InMemoryGameRepository`, `state.simulated = true`; bots are synchronous virtual connections that join, claim head, stamp, kill via sightings, sabotage, resolve, start meetings and vote through the normal host message path), `SimulationController` (speeds paused, 1x, 5x, 20x, 60x; run to end; discard), `SimulationLog`. `GameHost.startGame(using:)` takes the seeded generator.
- Admin: `SimulationView` (Simulation sidebar section: bots, werewolves, members, seed, speed, status, event log).
- SwiftData `latest()` skips simulated games, so a rehearsal can never be restored as a real game.
- Tests: `SimulationTests` (AC1 to AC6 including seeded replay), `SimulationControllerTests`.
- BLE signal strength is not simulated; bots report sightings directly.
