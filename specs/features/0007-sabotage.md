---
id: 0007
title: Sabotage
status: approved
owner: AND
app: all
created: 2026-10-22
updated: 2026-10-22
related: [0002-game-engine.md, 0008-oc-mode-and-stamping.md]
---

# 0007: Sabotage

## Summary

A werewolf picks Reactor (Collab 7A, Heist Plan) or Oxygen (Collab 6, Scary Memory) and confirms. The sabotage activates immediately with a 1:30 countdown shown on every device and the Public Display. Villagers must clear the booth task; the sabotage booth OC (or Town Hall OC) taps Resolved. If time runs out, Werewolves win. One shared cooldown applies to every werewolf family.

## User stories

- As a **werewolf**, I want to trigger a sabotage, so villagers are pulled away from tasks.
- As a **villager**, I want a loud, clear countdown, so I know where to run.
- As a **sabotage booth OC**, I want one tap to mark it resolved, so the alarm stops.

## Acceptance criteria

- [ ] **AC1 Request**: Given a werewolf device (alive, dead or expelled family), when the shared cooldown is over and no sabotage is active outside a meeting, then the app offers Reactor and Oxygen.
- [ ] **AC2 Activate**: Given a confirmed choice, when the host accepts it, then the sabotage is active, a 90 s countdown starts on all devices and the Public Display, and the shared cooldown (default 120 s) starts for all werewolf families.
- [ ] **AC3 Villager alert**: Given an active sabotage, when villager devices update, then they show which booth to run to.
- [ ] **AC4 Resolve**: Given an active sabotage, when the booth OC or Town Hall OC taps Resolved, then it clears everywhere and no win is triggered.
- [ ] **AC5 Timeout**: Given an active sabotage, when 90 s pass, then Werewolves win.
- [ ] **AC6 One at a time**: Given an active sabotage, when another request comes, then it is rejected.
- [ ] **AC7 Blocked in meetings**: Given discussion or voting, when a sabotage request arrives, then it is rejected.
- [ ] **AC8 Persistence**: Given a Mac restart during a sabotage, when the host resumes, then the remaining time is correct.

## UX

| State | What the user sees |
|---|---|
| Empty | Werewolf: "Sabotage ready" |
| Loading | "Waiting for the host" |
| Content | Countdown with booth name, or cooldown remaining |
| Error | "Sabotage on cooldown" |

Design link: TODO (Figma)

Accessibility notes: alarm uses sound, haptics and text; countdown not conveyed by colour alone.

## Data

`Sabotage` (kind, startedAt, resolvedAt), `SabotageEvent`; settings `sabotageDuration`, `sabotageCooldown`.

## Constraints check

- [x] Fits `specs/constraints.md`
- [x] No new dependency

## Out of scope

- OC approval step before activation (the PRD flow is auto-activate).

## Open questions

- Should a sabotage pause when a meeting starts? Proposed: no; the countdown keeps running.

## Implementation notes

Filled during and after build by the `codebase-sync` skill.
