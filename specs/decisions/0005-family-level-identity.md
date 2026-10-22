---
id: 0005
title: Family-level identity, one role and one vote per family
status: accepted
date: 2026-10-22
deciders: [AND]
---

# 0005: Family-level identity, one role and one vote per family

## Context

Each family has 6 members who all install the app. The PRD assigns the role, kills, task progress and votes to the family, and only the head of family attends the Town Hall.

## Options considered

1. **Family is the game entity; players are members with a head**: matches the PRD.
2. **Per-player roles and votes**: simpler for networking, but contradicts the game.

## Decision

`Family` is the unit for role, life state, stamps, cooldowns and votes. A `Player` belongs to one family and sees the family's role and task list. Only the current head of family can cast the family's vote, and the head can change only outside meetings. OC create families in Admin; players join with a family code or QR. Kills and expulsions affect the whole family.

## Consequences

- Positive: rules match the physical game and the engine stays small.
- Negative: a member's phone going offline must not affect the family; any member's device counts for BLE.
- Follow-ups: [spec 0004](../features/0004-lobby-and-roles.md).
