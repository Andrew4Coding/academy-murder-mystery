---
id: 0006
title: One game code, families filled automatically
status: accepted
date: 2026-10-29
deciders: [AND]
---

# 0006: One game code, families filled automatically

## Context

Per-family join codes meant organisers handed out codes by hand and fixed the family count before anyone arrived. Playtest showed it is faster to show one QR on the Public Display.

## Options considered

1. **One game-wide code, families created as needed**: scan once, fill Family 1 to capacity, then Family 2.
2. **Keep per-family codes**: precise control, but slow and error-prone at the door.

## Decision

`HostState.gameCode` is the only code players need. The host places a joiner in the lowest-numbered family below `maxFamilySize` (the capacity the Admin sets) and creates a new family when all are full, up to 40. The first joiner of a family is its head; if the head leaves in the lobby, the next member takes over. `FamilyInfo.joinCode` stays only so stored games, rehearsals and simulation bots keep working.

## Consequences

- Positive: faster joining, no manual family count, no hand-over flow.
- Negative: the last family can be partly filled; the setup rules must still hold at start.
- Follow-ups: [spec 0012](../features/0012-join-and-families.md).
