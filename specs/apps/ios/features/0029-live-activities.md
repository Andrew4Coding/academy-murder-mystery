---
id: 0029
title: Live Activities
status: in-progress
owner: AND
app: ios
created: 2026-10-30
updated: 2026-10-30
related: [0005, 0007, 0013, 0015, 0018, 0024, 0025]
---

# 0029: Live Activities

## Summary

While a game is running, the MoonfalliOS player app shows a Live Activity on the Lock Screen and in the Dynamic Island with the player's current game headline: killed, meeting, voting, sabotage, or booth progress. Countdowns keep ticking while the phone is locked, so players do not have to keep the app open to see how long a meeting, vote or sabotage has left.

## User stories

- As a **player**, I want to see the meeting, voting and sabotage countdown on my Lock Screen, so that I do not miss a deadline while the phone is locked.
- As a **player**, I want to see overall booth progress without opening the app, so that I know how close the villagers are to winning.
- As a **player**, I want to see at a glance that I was killed, so that I know to stop acting as an alive player.
- As a **werewolf**, I want the activity to look the same as a villager's, so that the Lock Screen never gives away my role.

## Acceptance criteria

- [ ] **AC1**: Given a signed-in `.player` identity whose `ClientView.game` becomes non-nil while the app is foregrounded, when the view arrives, then one Live Activity is requested; given OC or admin identities, then none is requested.
- [ ] **AC2**: Given a running activity, when a new `ClientView` arrives that changes the headline, task count, or a deadline, then the activity updates; unchanged views cause no update.
- [ ] **AC3**: Headline priority is killed or expelled, then meeting (`.discussion`), then voting (`.voting`, with a final-vote label when `isFinal`), then active sabotage, then booth progress.
- [ ] **AC4**: Given a meeting, vote or sabotage deadline, then the countdown is rendered with `Text(timerInterval:)` from the absolute deadline converted by the `ServerClock` offset, so it ticks without app updates and does not drift by host-device skew.
- [ ] **AC5**: Given the host edits a timer (`adjustTimer`, spec 0025), when the new `ClientView` arrives, then the activity shows the new deadline.
- [ ] **AC6**: `ContentState` never contains role, allies, kill or sabotage cooldowns, proximity or body data, votes, `bleToken`, or other families' roles. Villager and werewolf views of the same game map to the same `ContentState`.
- [ ] **AC7**: Given `life` is `.killed` or `.expelled`, then the activity shows the killed headline immediately, without waiting for `announcedDeaths`, and still shows booth progress (spec 0024).
- [ ] **AC8**: Given the app is suspended and a deadline passes, then at `staleDate` the headline becomes a neutral "Open Moonfall to refresh" and never shows a wrong phase.
- [ ] **AC9**: Given `phase` is `.ended`, then the activity ends with a final content state that shows the winner and stays on screen for about 10 minutes, unless the player dismisses it.
- [ ] **AC10**: Given the player leaves the game or the client signs out, then any running activity ends immediately.
- [ ] **AC11**: Given Live Activities are disabled in Settings (`ActivityAuthorizationInfo().areActivitiesEnabled == false`), then no activity is requested and the game is unaffected.
- [ ] **AC12**: Given the app relaunches mid-game with an activity already running, then it is reused or replaced, so there is never more than one.
- [ ] **AC13**: Dynamic Island provides compact, minimal and expanded layouts. No layout contains buttons or other interactive controls.

## UX

| State | What the user sees |
|---|---|
| Playing | "Moonfall", booth progress as `n of 7` with a progress bar |
| Killed | Killed headline with booth progress |
| Meeting | Meeting headline with a countdown |
| Voting | Voting headline with a countdown; final-vote label when `isFinal` |
| Sabotage | Sabotage headline (reactor or oxygen) with a countdown |
| Stale | "Open Moonfall to refresh" |
| Ended | Game over with the winner |

Compact: leading icon, trailing timer or progress. Minimal: icon. Expanded: headline, timer and progress. Strings use `GameLabels`.

Design link: none. Built from the existing design tokens.

Accessibility notes: text carries meaning, not colour (use `StatusLabel`). Dynamic Type scales via `scaledSystemFont`. Check `accessibilityReduceMotion` before any animation.

## Data

No SwiftData or schema changes. New `GameActivityAttributes` (with a role-neutral `ContentState`) in a new `Shared/LiveActivity/` folder, compiled into both the app and a new widget extension. New `LiveActivityController` in `iOS/` observes `GameClient` and owns `Activity` lifecycle. New widget extension target `MoonfalliOSLiveActivity`. New Info.plist key `NSSupportsLiveActivities` in `project.yml`.

## Constraints check

- [ ] Fits `specs/constraints.md` and `specs/apps/ios/constraints.md`: no cloud backend (local updates only, no APNs), role-neutral content, foreground play still the baseline
- [ ] No new dependency (ActivityKit and WidgetKit are first-party), so no ADR

## Out of scope

- Remote ActivityKit push (APNs) and any backend
- Background modes to keep the socket alive
- Interactive buttons and App Intents in the activity
- OC iPad and Mac admin activities
- Werewolf-only information (kill cooldown, sabotage readiness)
- Overall game clock (`finalVoteAt` exists only in `AdminView`)

## Open questions

- Accepted trade-off: showing "killed" immediately (AC7) lets a bystander see the kill before the public announcement.

## Implementation notes

Filled during and after build by the `codebase-sync` skill.
