---
id: 0024
title: Dead families keep doing tasks
status: approved
owner: AND
app: all
created: 2026-10-29
updated: 2026-10-29
related: [0002-game-engine.md, 0005-meetings-and-voting.md, 0008-oc-mode-and-stamping.md, 0013-kill-notice-and-game-end.md]
---

# 0024: Dead families keep doing tasks

## Summary

Villagers also win when every villager family finishes its tasks. A killed or expelled family must therefore keep doing its tasks, otherwise that win can become impossible. Dead families still cannot vote, kill, sabotage or report bodies. This answers the open question in [0013](0013-kill-notice-and-game-end.md).

## User stories

- As a **dead player**, I want to keep stamping my tasks, so that my team can still win by tasks.
- As a **booth OC**, I want to stamp any family the same way, so that I do not have to remember who is dead.

## Acceptance criteria

- [ ] **AC1 Stamp when dead**: Given a killed or expelled family, when a booth OC stamps it, then the stamp is recorded and its progress updates (today the engine throws `familyNotAlive`).
- [ ] **AC2 Task win**: Given every villager family (alive or not) has all stamps, when the last stamp is recorded, then the villagers win with `allTasksDone`.
- [ ] **AC3 No vote**: Given a dead family, when it votes, proxy-votes or votes to skip discussion, then it is rejected, and it is not counted in `votersTotal` or in the all-voted check.
- [ ] **AC4 Still dead**: Given a dead family, when it stamps, then it stays dead and cannot kill, sabotage or report a body.
- [ ] **AC5 Phone UI**: Given a dead player, then the Role tab still shows the task list with progress and says "You are out, keep finishing your tasks"; the vote controls are read-only.
- [ ] **AC6 OC UI**: Given a booth OC screen and the Mac Admin, then dead families are shown as dead but stay tappable for stamping.

## UX

| State | What the user sees |
|---|---|
| Empty | n/a |
| Loading | n/a |
| Content | Dead family: tasks list with progress, banner "You are out, keep finishing your tasks" |
| Error | Existing stamp errors |

Design link: TODO (Figma)

Accessibility notes: the banner is text, not colour alone.

## Data

None. `GameEngine.recordStamp` drops its alive check.

## Constraints check

- [x] Fits `specs/constraints.md` (OC devices still never see roles)
- [x] No new dependency

## Out of scope

- Telling an impostor that a target is already dead (the ambiguity stays on purpose).

## Open questions

- None.

## Implementation notes

Filled during and after build.
