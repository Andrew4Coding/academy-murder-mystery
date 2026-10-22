---
id: 0004
title: Lobby, family join and roles
status: draft
owner: AND
app: all
created: 2026-10-22
updated: 2026-10-22
related: [decisions/0005-family-level-identity.md, 0002-game-engine.md, 0003-lan-host-transport.md]
---

# 0004: Lobby, family join and roles

## Summary

OC create families and settings in Admin, players join their family by code or QR, each family picks a head, and when the OC starts the game every device privately shows its family's role, task list and objective. Werewolf devices also see the other werewolf families.

## User stories

- As a **player**, I want to join my family by scanning a code, so I do not type a long name.
- As a **head of family**, I want to hand over the role of head before a meeting, so another member can go to the Town Hall.
- As a **werewolf**, I want to see my fellow werewolf families, so we do not kill each other.

## Acceptance criteria

- [ ] **AC1 Setup**: Given Admin, when the OC sets number of families, werewolf families and timings, then invalid combinations (W < 1 or W >= N/2) block Start with a reason.
- [ ] **AC2 Join**: Given a family code or QR, when a player enters a display name, then they join that family (max 6) and appear in Admin's lobby.
- [ ] **AC3 Head**: Given a family, when a member claims or hands over head outside discussion and voting, then the host records the new head; during discussion and voting the request is rejected.
- [ ] **AC4 Start**: Given all families have a head, when the OC taps Start Game, then roles and task lists are assigned by the engine and every device shows its family's role and 5 booths privately.
- [ ] **AC5 Werewolf view**: Given a werewolf family, when roles are shown, then its devices list the other werewolf families; villager devices never receive that list.
- [ ] **AC6 Leakage**: Given any client, when it inspects its own state, then it contains no other family's role (except revealed expelled families and its own werewolf allies).
- [ ] **AC7 Dead family**: Given a killed or expelled family, when its device refreshes, then it shows its status and disables all features, except sabotage for werewolf families.

## UX

| State | What the user sees |
|---|---|
| Empty | iOS: "Enter your family code or scan the QR"; Admin: families with no members |
| Loading | "Waiting for the game to start" |
| Content | iOS: role card, objective, 5 booths with progress; Admin: lobby with member counts |
| Error | "Family is full", "Invalid code" |

Design link: TODO (Figma)

Accessibility notes: role card readable by VoiceOver; role reveal is not conveyed by colour alone; QR scanner has a manual code field.

## Data

`Family`, `Player`, `Role`, `TaskList` models and `FamilyRepository`; join codes and the OC PIN are generated per game.

## Constraints check

- [x] Fits `specs/constraints.md` (privacy: name only, no accounts)
- [x] No new dependency (AVFoundation camera scanning is system)

## Out of scope

- Joining after the game started.
- Moving a player between families after start.

## Open questions

- Should families be allowed fewer than 6 members at start? Proposed: yes, any size from 1 to 6.

## Implementation notes

Filled during and after build by the `codebase-sync` skill.
