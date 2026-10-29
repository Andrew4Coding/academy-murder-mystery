---
id: 0007
title: One person per family
status: accepted
date: 2026-10-30
deciders: [AND]
---

# 0007: One person per family

## Context

ADR 0005 assumed six members per family with one head. At the event each family is one person, so members, heads and capacity are dead weight.

## Options considered

1. **Remove members and heads**: a player is their family.
2. **Keep the model and fix the family size at 1**: less churn, but every screen keeps head and member code that can never apply.

## Decision

A `Player` belongs to a family that holds only them. The host gives each joiner the lowest empty family or creates one. Votes, skip votes and renames come straight from the player. `maxFamilySize`, `FamilyInfo.head` and the member views are removed. This supersedes the member and head parts of ADR 0005 and the capacity part of ADR 0006.

## Consequences

- Positive: simpler lobby, no head hand-over, no capacity setting.
- Negative: if a team ever shares a phone again, the model must grow back.
- Follow-ups: [spec 0020](../features/0020-one-person-per-family.md).
