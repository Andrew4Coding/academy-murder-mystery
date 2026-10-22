---
id: 0002
title: Game engine
status: implemented
owner: AND
app: all
created: 2026-10-22
updated: 2026-10-22
related: [decisions/0004-pure-game-engine.md, decisions/0005-family-level-identity.md]
---

# 0002: Game engine

## Summary

A pure, deterministic state machine in `Shared/` that owns every rule of the game: phases, role assignment, task assignment, stamps, kill and sabotage cooldowns, meetings, voting, the 45-minute final vote and win conditions. Every other feature spec cites this one and never restates a rule. First implementation commit removes the sample Items feature.

## User stories

- As the **Town Hall OC**, I want the game to end automatically and correctly, so I never have to count families by hand.
- As a **developer**, I want rules testable with a fake clock, so I can trust them without 100 phones.

## Acceptance criteria

- [x] **AC1 Setup**: Given N families and W werewolf families with W >= 1 and W < N/2, when the game starts, then W families get Werewolf at random, the rest Villager, and every family gets 5 distinct booths randomly chosen from 7.
- [x] **AC2 Phases**: Given a running game, when a meeting starts, then phase is discussion for the configured time (default 120 s), then voting (default 120 s), then back to running.
- [x] **AC3 Kill**: Given a werewolf family not on cooldown outside a meeting and a living villager family, when a valid kill is applied, then the whole victim family dies and the killer's kill cooldown (default 60 s) starts.
- [x] **AC4 Kill blocked**: Given discussion, voting or the cooldown, when a kill is applied, then it is rejected with a rule error.
- [x] **AC5 Sabotage**: Given the shared cooldown (default 120 s) has elapsed outside a meeting, when a werewolf family requests a sabotage, then it becomes active with a 90 s countdown and the shared cooldown starts for all werewolf families, including expelled or dead ones.
- [x] **AC6 Sabotage resolve**: Given an active sabotage, when it is resolved before 90 s, then it clears; when 90 s pass unresolved, then Werewolves win.
- [x] **AC7 Voting**: Given voting is open, when only living heads of family vote, then each family has one vote or Skip; at close or when all living families voted, the family with the most votes is expelled and its role revealed, but if Skip leads or there is a tie nobody is expelled.
- [x] **AC8 Task win**: Given every villager family (dead or alive) has 5 stamps, when the last stamp is recorded, then Villagers win. Stamps for werewolf families never count.
- [x] **AC9 Expulsion win**: Given all werewolf families are expelled or dead, when the last one is removed, then Villagers win.
- [x] **AC10 Parity win**: Given alive villager families <= alive werewolf families, when either count changes, then Werewolves win.
- [x] **AC11 Final vote**: Given the clock reaches 45:00, when the engine enters the final vote, then every living family votes once and the top N families are expelled where N is the number of living werewolf families; Villagers win only if all living werewolf families are among them, otherwise Werewolves win; a tie at the cutoff counts as failure for Villagers.
- [x] **AC12 Overrides**: Given any phase, when the OC applies force-kill, revive or end-game, then the engine applies it, records an `ocOverride` event and re-evaluates win conditions.
- [x] **AC13 Determinism**: Given the same commands and clock, when replayed, then the engine produces identical events and state.

## UX

None: the engine has no UI.

Accessibility notes: none.

## Data

`GameState` (families, roles, life states, stamps, cooldowns, phase, sabotage, votes, clock start) and an append-only `GameEvent` log. Persistence belongs to [0003](0003-lan-host-transport.md). Removes `Item`, `ItemRepository`, `Shared/Features/Items` and the Items tests and schema usage; SwiftData schema becomes V1 of the new models in 0003.

## Constraints check

- [x] Fits `specs/constraints.md` and target constraints
- [x] No new dependency

## Out of scope

- Networking, BLE, persistence and all UI.
- Late joiners after start.

## Open questions

- What should happen if the last villager family dies in the same instant a sabotage expires? Implemented: timers are processed in timestamp order; on an exact tie sabotage expiry fires first, so Werewolves win.
- Kill and sabotage cooldowns start at game start (60 s and 120 s), so nobody can kill or sabotage in the first minute. The PRD is silent; confirm.
- Stamps are rejected for killed or expelled families; stamps for booths outside a family's list are stored but never count toward the win.

## Implementation notes

- Code: `Shared/Game/` (`GameEngine`, `GameState`, `GameCommand`, `GameEvent`, `GameTypes`, `SeededGenerator`). `apply(_:at:)` is atomic; `advance(to:)` fires due timers (sabotage expiry, discussion/voting end, final vote).
- Votes are kept in `GameState.votes` only while voting is open and cleared on close; events carry tallies, never who voted for whom.
- A final vote due during a meeting is deferred until that meeting closes (`finalVotePending`).
- Tests: `Tests/Shared/GameEngine*Tests.swift` (AC1 setup, AC2 voting/phases, AC3-4 kill, AC5-6 sabotage, AC7 voting, AC8-10 win rules, AC11 final vote, AC12 overrides, AC13 determinism).
- The sample Items feature and its schema model were removed; `SchemaV1` has no models until spec 0003.
