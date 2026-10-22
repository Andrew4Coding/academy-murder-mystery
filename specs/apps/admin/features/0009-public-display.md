---
id: 0009
title: Public Display
status: draft
owner: AND
app: admin
created: 2026-10-22
updated: 2026-10-22
related: [0005-meetings-and-voting.md, 0007-sabotage.md]
---

# 0009: Public Display

## Summary

A dedicated window in the Mac Admin app that the OC sends to the lab TVs via AirPlay or a second display. It shows the game clock, meeting timers, sabotage countdown, vote results and reveals of expelled families, and never shows secrets.

## User stories

- As a **player**, I want to see the timers on the TV, so I can plan.
- As the **Town Hall OC**, I want a window that can never leak roles, so I can leave it on a public screen.

## Acceptance criteria

- [ ] **AC1 Window**: Given Admin, when the OC opens Public Display, then a separate window opens that can be moved to an AirPlay or second display.
- [ ] **AC2 Content by phase**: Given the game phase, when it changes, then the window shows the game clock (running), discussion/voting timers (meeting), the sabotage countdown with booth name (sabotage) and the result (after voting).
- [ ] **AC3 No secrets**: Given any state, when the window renders, then no living family's role, task list or vote choice is shown.
- [ ] **AC4 Reveal**: Given an expelled family, when the result shows, then its role is revealed on screen.
- [ ] **AC5 End**: Given the game ended, when the engine reports a winner, then the window shows the winning side and reason.
- [ ] **AC6 Readability**: Given a TV at the back of the room, when content shows, then timers are at least 120 pt and legible at 1080p.

## UX

| State | What the user sees |
|---|---|
| Empty | Game title and "Waiting for the game" |
| Loading | "Restoring game" |
| Content | Clock, timers, results and reveals |
| Error | "Host offline" |

Design link: TODO (Figma)

Accessibility notes: high contrast; sound cue with sabotage; no information by colour alone.

## Data

Read-only view of host state, no new models.

## Constraints check

- [x] Fits `specs/constraints.md` and Admin constraints
- [x] No new dependency

## Out of scope

- Separate display app or tvOS target.

## Open questions

- Show the death announcement list on the TV or only on phones? Proposed: both.

## Implementation notes

Filled during and after build by the `codebase-sync` skill.
