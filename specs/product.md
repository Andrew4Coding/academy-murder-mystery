---
status: draft
owner: AND
updated: 2026-10-22
---

# Product: Moonfall

## One-liner

A phone-and-Mac companion for a physical, venue-wide werewolf-versus-villager party game, "PRD yang ga boleh malas", that runs roles, BLE kills, sabotage, meetings, voting and win conditions so organisers can focus on the booths.

## Problem

The game is "Among Us in real life": families of 6 move around a venue doing booth tasks while hidden werewolves kill and sabotage. Doing this on paper does not work: roles must stay secret, kills need proximity and cooldowns, votes must be anonymous, timers must be shared by every phone and the lab TVs, and the organisers (OC) need one place that always knows who is alive and who has finished which task.

## Vision

Participants play without friction: they get a role, see their five tasks, visit booths and vote in under two minutes. OC trust the app as the single source of truth and can always override it from the Mac.

## Targets

| Target | Platform | Primary user | Role in the product | Details |
|---|---|---|---|---|
| `MoonfalliOS` | iOS | Player (family member or head); booth OC | Join a family, see role and tasks, kill, sabotage, vote; OC mode for stamping and resolving sabotage | [apps/ios/product.md](apps/ios/product.md) |
| `MoonfallAdmin` | macOS | Town Hall OC | Authoritative LAN host, game setup, meetings, overrides, public display, simulation | [apps/admin/product.md](apps/admin/product.md) |

## Venue

Lab 1 is the Town Hall (meetings, bell, OC control). The collab spaces are the 7 task booths. Collab 7A (Reactor) and Collab 6 (Oxygen) are the sabotage booths. Lab 1 and Lab 2 have AirPlay displays.

## Personas

- **Family member (player)**: one of 6 people moving as a family; wants to know the role and the tasks without being seen by others.
- **Head of family**: the member who goes to the Town Hall and casts the family's vote; can change only between meetings.
- **Booth OC**: stands at a booth, stamps families, marks sabotage resolved.
- **Town Hall OC**: runs the game from the Mac: starts the game and meetings, rings the bell, overrides.

## Rules the product implements

Roles are per family. Villagers win when all werewolf families are expelled (the stamp-based win moved outside the app, ADR 0008). Werewolves win when alive villager families are not more than alive werewolf families, a sabotage timer expires, or the final vote at 45:00 fails. The full rule set is owned by [features/0002-game-engine.md](features/0002-game-engine.md).

## Success metrics

| Metric | Target | How measured |
|---|---|---|
| Full game completes without OC falling back to paper | 100% of rehearsal games | Venue dry run checklist |
| Vote result shown after voting closes | under 2 s | Simulation and dry run |
| Kill by BLE triggers on real devices | at least 90% of intended close-range attempts, no kills beyond the threshold | Venue dry run |
| Game survives a Mac Admin restart | state restored, timers correct | Manual test and engine tests |

## Non-goals

- Login, accounts or any cloud backend.
- Localization: the UI is English only.
- Analytics, ads or tracking.
- In-app "report body" (players shout to the Town Hall OC).
- A separate display app: the lab TVs show a Mac window over AirPlay.

## Open questions

- Venue Wi-Fi may isolate clients, which would break the LAN host. See [decisions/0002-mac-hosted-lan-authority.md](decisions/0002-mac-hosted-lan-authority.md).
- The PRD gives two discussion/voting timings (3+1 and 2+2 minutes); the default is 2+2, configurable by OC.
