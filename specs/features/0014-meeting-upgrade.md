---
id: 0014
title: Meeting upgrade
status: approved
owner: AND
app: all
created: 2026-10-29
updated: 2026-10-29
related: [0005-meetings-and-voting.md, 0009-public-display.md, 0012-join-and-families.md]
---

# 0014: Meeting upgrade

## Summary

Meetings gain four things: the Admin can add time manually, family cards show a name and a selfie, a skip-discussion vote lets families end discussion early (with Admin approval), and vote results appear as a Swift Charts bar chart.

## User stories

- As an **organiser**, I want to add time to a meeting, so that a good argument is not cut off.
- As a **player**, I want to see names and faces, so that I know who I am voting for.
- As a **head of family**, I want to vote to skip a dull discussion, so that we get to the ballot.

## Acceptance criteria

- [ ] **AC1 Add time**: Given discussion or voting, when the Admin taps "+1 min" (or sets a custom amount), then every device and the Public Display show the new end time via the server clock.
- [ ] **AC2 Selfie**: Given the lobby, when a player takes a selfie, then it is compressed (about 100 KB), sent to the host and kept only for the game; it is deleted when the game ends.
- [ ] **AC3 Names**: Given a meeting, then family and member cards show name and selfie.
- [ ] **AC4 Skip-discussion vote**: Given discussion, when more than half of the living families vote to skip, then the Admin sees a request and, once approved, voting opens immediately.
- [ ] **AC5 Vote chart**: Given a closed vote, then every device and the Public Display show a horizontal Swift Charts bar chart of counts per candidate plus Skip; ballots stay anonymous and `GameState.votes` remains excluded from `Codable`.
- [ ] **AC6 Unchanged ballot**: Given voting, then the existing Skip option on the expulsion ballot and tie handling (a tie or skip lead expels no one) are unchanged.

## UX

| State | What the user sees |
|---|---|
| Empty | Camera denied: initials instead of a selfie |
| Loading | "Sending photo…" |
| Content | Cards with selfie and name; bar chart after the vote |
| Error | "Couldn't send photo, try again" |

Design link: TODO (Figma)

Accessibility notes: the chart exposes a VoiceOver summary (candidate and count); selfies have the name as label.

## Data

`GameCommand.extendMeeting(seconds)`, `.voteSkipDiscussion`, `.approveSkip`; selfie data in host memory only (not in SchemaV1). Add `NSCameraUsageDescription` in `project.yml`; update `PrivacyInfo.xcprivacy`.

## Constraints check

- [ ] Fits `specs/constraints.md`; update the privacy section for selfies
- [x] No new dependency (Swift Charts is first-party)

## Out of scope

- Selfie at every meeting; photo storage after the game.

## Open questions

- Selfie handling if a player rejoins mid-game.
- Who may retake a selfie, and when it locks.

## Implementation notes

Filled by `codebase-sync`.
