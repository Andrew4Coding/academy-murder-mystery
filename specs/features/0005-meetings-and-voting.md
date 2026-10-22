---
id: 0005
title: Meetings and voting
status: draft
owner: AND
app: all
created: 2026-10-22
updated: 2026-10-22
related: [0002-game-engine.md, 0004-lobby-and-roles.md]
---

# 0005: Meetings and voting

## Summary

When someone shouts "body" the Town Hall OC rings the bell and taps Start Discussion in Admin. Every device alerts, kills and sabotage are blocked, discussion runs (default 120 s) and voting opens (default 120 s). Only each family's head votes, anonymously, with Skip allowed. The result expels one family or nobody. The final vote at 45:00 uses the same screens.

## User stories

- As a **head of family**, I want a clear vote screen with a timer, so I can vote in time.
- As the **Town Hall OC**, I want one tap to start a meeting, so the event keeps moving.

## Acceptance criteria

- [ ] **AC1 Start**: Given a running game, when the OC taps Start Discussion, then every device shows a meeting alert, announces families that died since the last meeting, and shows the discussion countdown from host time.
- [ ] **AC2 Auto vote**: Given discussion ends, when time elapses, then voting opens automatically with the voting countdown.
- [ ] **AC3 Vote**: Given voting is open, when a living family's head selects a family or Skip, then one vote is recorded for that family; non-heads see a read-only screen; a head can change their vote until voting closes.
- [ ] **AC4 Anonymous**: Given voting, when results are stored, then only per-target tallies are persisted, never who voted for whom.
- [ ] **AC5 Close**: Given all living families voted or time elapsed, when voting closes, then the result is computed per [0002 AC7](0002-game-engine.md) and shown on every device and the Public Display.
- [ ] **AC6 Expulsion**: Given a family is expelled, when the result shows, then its role is revealed, its devices show the expelled status, and win conditions are re-evaluated.
- [ ] **AC7 Final vote**: Given the clock hits 45:00, when the engine enters the final vote, then every device alerts everyone to gather and uses the voting screen with the top-N rule from [0002 AC11](0002-game-engine.md).
- [ ] **AC8 No head change**: Given discussion or voting, when a head change is requested, then it is rejected.

## UX

| State | What the user sees |
|---|---|
| Empty | "No meeting in progress" |
| Loading | "Waiting for votes" |
| Content | Discussion countdown, then vote list (families plus Skip) with the countdown |
| Error | "Only the head of family can vote" |

Design link: TODO (Figma)

Accessibility notes: countdown announced at key moments; vote targets at least 44 pt; Admin has keyboard shortcuts for Start Discussion.

## Data

`Meeting`, `VoteTally` (no voter identity), `MeetingEvent` records.

## Constraints check

- [x] Fits `specs/constraints.md` (anonymous votes)
- [x] No new dependency

## Out of scope

- In-app body reporting.
- Chat in the app.

## Open questions

- If the head's phone is offline during voting, may the OC vote on their behalf? Proposed: yes, as an `ocOverride` event.

## Implementation notes

Filled during and after build by the `codebase-sync` skill.
