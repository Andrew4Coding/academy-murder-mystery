---
id: 0004
title: Single pure game engine with injected clock
status: proposed
date: 2026-10-22
deciders: [AND]
---

# 0004: Single pure game engine with injected clock

## Context

Win rules, cooldowns, meeting phases, voting and sabotage timers are intricate and must behave identically on the host, in simulation and in tests. Timers make them hard to test, and a rule duplicated in a view or transport would drift.

## Options considered

1. **Pure value-type state machine in `Shared/` with an injected clock**: deterministic, testable without devices.
2. **Rules spread across view models and the transport**: fast to start, impossible to keep consistent.

## Decision

All game rules live in one pure Swift engine in `Shared/`: `apply(command, at: Date) -> Result<[Event], RuleError>` over a `GameState` value. It never touches networking, BLE, SwiftData or UI. Time comes only from an injected `Clock`. The host maps commands from clients to the engine and persists the resulting events. Simulation drives the same engine with bots and a fast-forward clock.

## Consequences

- Positive: rules are covered by fast fake-clock tests, simulation reuses real logic, and specs cite one source.
- Negative: transports and views must translate to and from commands and events.
- Follow-ups: [spec 0002](../features/0002-game-engine.md); the sample Items feature is removed when it is implemented.
