---
id: 0008
title: Stamping and the task win move outside the app
status: accepted
date: 2026-10-30
deciders: [AND]
---

# 0008: Stamping and the task win move outside the app

## Context

Organisers now stamp families' cards by hand at the booths, so the app no longer needs to record progress. Keeping stamp state in the app made phones and the host disagree with the paper stamps.

## Options considered

1. **Keep stamps, add an admin override**: still two sources of truth.
2. **Remove stamps and the task win**: the app only lists each family's booths.

## Decision

We remove stamp recording, booth OC stations, task progress and the `allTasksDone` win. `Family.tasks` stays as a list of assigned booths. Villagers win only by expelling every werewolf family; werewolves win by parity, an expired sabotage or a failed final vote.

## Consequences

- Positive: one source of truth for task progress (the stamped cards).
- Negative / trade-offs: villagers lose the task route to victory, so games may run to the final vote more often.
- Follow-ups: specs 0002, 0008, 0016 and 0024 describe behaviour that no longer exists. `OCStation.booth` is gone, so stored games that contain a booth OC device no longer decode.
