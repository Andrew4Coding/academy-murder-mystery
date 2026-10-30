---
id: 0033
title: Screen restyle and UI flow polish
status: in-progress
owner: AND
app: all
created: 2026-10-31
updated: 2026-10-31
related: [0027, 0031, 0032]
---

# 0033: Screen restyle and UI flow polish

## Summary

Apply the 0031 theme to every screen of MoonfalliOS, MoonfallAdmin and MoonfallAdminiPad, and make them follow the Apple HIG and be easier to understand: clearer hierarchy, grouped sections, plainer labels, helpful empty and error states, and reorganised screens or steps where it helps. Game rules, wire messages, schema and role-secrecy rules do not change.

## User stories

- As a **player**, I want to know what to do next on every screen, so that I never get stuck.
- As an **organiser**, I want setup and game control grouped by task, so that I can run the game under pressure.

## Acceptance criteria

- [ ] **AC1**: Given any screen, when shown, then it uses theme colours, system text styles and design-system spacing, with no fixed colours.
- [ ] **AC2**: Given any screen with no data or an error, when shown, then it has an explanatory empty or error state.
- [ ] **AC3**: Given the iPhone and iPad layouts, when rotated or resized, then content stays usable without clipping.
- [ ] **AC4**: Given the Mac Admin, when navigating by keyboard, then focus is visible and every action is reachable.
- [ ] **AC5**: Given the game engine and wire protocol, when this spec lands, then no rule, message or schema changes and all existing tests pass.

## UX

See the galleries from 0032 for every state.

## Data

None.

## Constraints check

- [x] Fits constraints; `OCView` still carries no roles
- [x] No new dependency

## Out of scope

- New game features, rules or protocol changes.

## Open questions

-

## Implementation notes

All three apps restyled; AX5 and VoiceOver passes not yet done in a simulator.
