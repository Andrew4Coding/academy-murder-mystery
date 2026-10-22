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

## Entitlements

- Needs network server and client entitlements for the LAN host, and a Bonjour service type. No other new entitlement without a reason in its PR.

## Accessibility

- Full keyboard navigation, with visible focus rings.

## Performance

- Cold launch to the first interactive frame takes under 1.5 s on the oldest supported Mac (to be named after the venue dry run).
- The host persists game state after every accepted event and resumes after a restart.
