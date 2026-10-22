---
status: draft
updated: 2026-10-22
---

# Constraints: MurderMysteryAdmin (macOS)

These add to [../../constraints.md](../../constraints.md) and never contradict it.

## Platform

- macOS 26.0+, native SwiftUI (no Catalyst).
- Resizable windows, minimum 720×480. Sidebar navigation, plus menu commands and keyboard shortcuts for primary actions.
- App Sandbox and Hardened Runtime are always on. Every new entitlement needs a reason in its PR.

## Accessibility

- Full keyboard navigation, with visible focus rings.

## Performance

- Cold launch to the first interactive frame takes under 1.5 s on the oldest supported Mac. TODO: name the machine.
