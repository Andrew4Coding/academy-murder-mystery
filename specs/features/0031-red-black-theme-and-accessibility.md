---
id: 0031
title: Red and black theme and accessibility pass
status: in-progress
owner: AND
app: all
created: 2026-10-31
updated: 2026-10-31
related: [0027]
---

# 0031: Red and black theme and accessibility pass

## Summary

One shared red-and-black visual language for all three apps, taken from the app icon (near-black plum background, crimson accent). It is defined once in `Shared/Core/DesignSystem` as colour assets with a dark primary palette and an adapted light palette, and every screen is checked against the accessibility bar in `constraints.md`.

## User stories

- As a **player**, I want screens that look like the Moonfall icon and are readable in a dim venue, so that I can follow the game at a glance.
- As an **organiser**, I want the Mac and iPad admin tools to share the same look, so that the apps feel like one product.
- As a **player using assistive tech**, I want every control labelled and every text legible, so that I can play on equal terms.

## Acceptance criteria

- [ ] **AC1**: Given the palette, when text and UI colours are checked against their backgrounds, then body text is at least 4.5:1 and UI/large text at least 3:1 in both dark and light (`ThemeContrastTests`).
- [ ] **AC2**: Given any target, when it launches, then its accent colour is the crimson of the theme and surfaces use the theme background, in dark and light.
- [ ] **AC3**: Given Dynamic Type at AX5, when any screen renders, then core content is not truncated.
- [ ] **AC4**: Given VoiceOver, when navigating any screen, then every interactive element has a label and a sensible trait.
- [ ] **AC5**: Given Reduce Motion or Reduce Transparency, when a screen animates or uses blur, then it falls back to a static or opaque version.
- [ ] **AC6**: Given any status or role indicator, when shown, then it has text or an icon in addition to colour.
- [ ] **AC7**: Given any iOS or iPad control, when laid out, then its hit area is at least 44x44 pt.

## UX

Dark: background near-black plum, raised surfaces slightly lighter, crimson for accents and primary buttons, warm white text. Light: warm off-white surfaces, near-black text, deeper crimson. The Public Display is always dark.

Accessibility notes: red is never the only signal; use `StatusLabel`. Fixed font sizes are replaced by `scaledSystemFont` or text styles except on the Public Display.

## Data

None.

## Constraints check

- [x] Fits `specs/constraints.md` and target constraints
- [x] No new dependency

## Out of scope

- Custom fonts (SF Pro only), game rules, wire protocol, schema.

## Open questions

-

## Implementation notes

Filled by `codebase-sync`.
