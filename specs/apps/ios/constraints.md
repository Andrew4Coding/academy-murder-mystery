---
status: draft
updated: 2026-10-22
---

# Constraints: MurderMysteryiOS (iOS)

These add to [../../constraints.md](../../constraints.md) and never contradict it.

## Platform

- iOS 26.0+, iPhone and iPad (`TARGETED_DEVICE_FAMILY = 1,2`). No Mac Catalyst, and no "Designed for iPad" on Mac.
- Navigation: tabs in compact width, split view in regular width (see `iOS/App/RootView.swift`).

## Accessibility

- Minimum touch target is 44×44 pt.

## Performance

- Cold launch to the first interactive frame takes under 1.5 s on the oldest supported device. TODO: name the device.
