---
id: 0027
title: Apple HIG compliance pass
status: in-progress
owner: AND
app: all
created: 2026-10-29
updated: 2026-10-29
related: [0013-kill-notice-and-game-end.md, 0016-oc-station-rework.md, 0025-editable-timers.md]
---

# 0027: Apple HIG compliance pass

## Summary

The app is already native SwiftUI on iOS 26 and macOS 26, so system tab bars, lists and colours already follow the HIG. An audit found a short list of gaps: fixed-size text, low-contrast and colour-only status, no Reduce Motion or Reduce Transparency handling, hand-built banners that ignore Liquid Glass, an overloaded Mac toolbar, and thin VoiceOver coverage. This spec fixes those without changing any game rule or layout concept.

## User stories

- As a **player with low vision**, I want every timer and status to scale with my text size, so that I can read the game at a glance.
- As an **OC on a Mac**, I want a toolbar I can scan, so that I find Start Discussion and the timers fast.
- As a **VoiceOver user**, I want every control and card announced with its state.

## Acceptance criteria

- [x] **AC1 Scalable text**: Given the 56 pt countdowns (Meeting, Sabotage station), the 96 pt notice symbol and the 56 pt Role symbol, then they use `@ScaledMetric` or text styles; at the largest accessibility size no core text is truncated and nothing is clipped. (The 10-foot Public Display keeps fixed sizes.)
- [x] **AC2 Contrast**: Given the sabotage banner, the "Ready" label, the Bluetooth-off row and vote bars, then text and icons reach 4.5:1 (3:1 for large or bold text) in light, dark and Increase Contrast; white on `.red` (3.55:1) is replaced by a compliant pairing.
- [x] **AC3 Not colour alone**: Given any state shown by colour (ready, out, off list, sabotage, werewolf), then an icon or text says the same thing.
- [x] **AC4 Motion and transparency**: Given Reduce Motion or Reduce Transparency, then count-ups, sensory pulses, the reveal animation and glass surfaces fall back to static, opaque ones.
- [x] **AC5 Liquid Glass**: Given the floating sabotage banner and notice covers, then they use system glass or system containers; no custom opaque backgrounds sit behind system bars or sidebars.
- [x] **AC6 Mac toolbar**: Given the Mac Game screen at the 720 pt minimum width, then the toolbar groups its actions (Meeting, Timers, Game) into at most five items, and every action keeps a menu or keyboard shortcut.
- [ ] **AC7 VoiceOver**: Given any icon-only button, custom card or timer, then it has a label, value and hint where needed, read in a sensible order.
- [ ] **AC8 Verified**: Given iPhone, iPad and Mac in light and dark, at default and the largest accessibility text size, then screenshots are attached to the PR.

## UX

| State | What the user sees |
|---|---|
| Empty | unchanged |
| Loading | unchanged |
| Content | same screens, system text styles, glass banners, grouped Mac toolbar |
| Error | same errors, with icon and text and compliant colour |

Design link: TODO (Figma)

Accessibility notes: this spec is the accessibility pass; test with Accessibility Inspector, VoiceOver, Voice Control and Full Keyboard Access.

## Data

None.

## Constraints check

- [x] Fits `specs/constraints.md` (Dynamic Type, VoiceOver, Reduce Motion are already required there)
- [x] No new dependency

## Out of scope

- New screens, new navigation, or any game-rule change.
- Public Display typography (10-foot layout, intentionally large and fixed).
- New app icon or branding colours.

## Open questions

- Is there anything specific that looks off to you? Screenshots would let this spec target it.
- Do you want a brand accent colour, or keep the system accent?
- Include the Public Display in a later pass?

## Implementation notes

- Shared: `scaledSystemFont` / `countdownDisplay()` (`@ScaledMetric`) for the 56 and 96 pt text; `StatusLabel` keeps the colour on the icon and the text in the primary colour (replaces red, green and orange text); `TimerAdjustMenu` is now one "Timers" menu with a submenu per timer.
- iOS: `SabotageBanner` uses `glassEffect` with a dark red tint, notices use `.glassProminent`, Reduce Motion handled in `GameTabsView`, `RoleCard` and `ConnectionBadge`.
- Mac: the Game toolbar has five items (Show Roles, Meeting, Timers, Game, Start Discussion); Approve Skip is Shift-Cmd-K and Resolve Sabotage Shift-Cmd-R.
- Not done: AC7 (VoiceOver was reviewed in code only; icon-only buttons already use labelled `Label`s, nothing was run with VoiceOver) and AC8 (no screenshots at the largest text size or in Increase Contrast). AC2's contrast was calculated for the tint colour, not measured on the glass over live content.
- Public Display keeps its fixed 10-foot sizes and was not touched.
