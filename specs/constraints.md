---
status: draft
updated: 2026-10-22
---

# Constraints (all targets)

Hard rules for every target. Change them only through an ADR in `decisions/`.
Platform rules live in `apps/<slug>/constraints.md`. Items marked **TODO** still need a decision.

## Technology

- Swift 6 with strict concurrency set to `complete`. SwiftUI only: no UIKit or AppKit views without an ADR.
- Persistence: SwiftData, with a versioned schema from V1. Never mutate a shipped schema.
- Architecture: MVVM + repository protocols, with the composition root in `AppEnvironment` (see `CLAUDE.md`).
- One XcodeGen project (`project.yml`) with one target per platform. Releases go through Fastlane with Xcode automatic signing driven by the App Store Connect API key (`fastlane/Fastfile`).
- Code every target needs lives in `Shared/` and never branches with `#if os()`. Target differences are injected from the target folders. Never copy code between targets.
- No third-party dependencies without an ADR covering license, privacy manifest and maintenance.
- Networking: the Mac Admin app is the authoritative game host on the local network and every iOS device is a client ([ADR 0002](decisions/0002-mac-hosted-lan-authority.md)). An optional cloud host (`cloud/`) can replace the Mac as the single authority, switched by a registry, never both at once ([ADR 0009](decisions/0009-switchable-cloud-host.md)). The LAN host stays the default and the offline fallback.
- Game rules live in one pure engine in `Shared/` with an injected clock, never in views or transports ([ADR 0004](decisions/0004-pure-game-engine.md)).
- Timers are derived from host timestamps; clients never run authoritative timers.

## Privacy

- No third-party analytics, ads or tracking SDKs without an ADR. `NSPrivacyTracking = false`.
- Collect the minimum personal data. Data that exists: a display name per player, family membership and per-game events (stamps, kills, votes). It lives on the Mac host and on each player's own device for the current game only. While the cloud host is in use, or a cold-backup snapshot is uploaded, it also lives on the cloud server (state, selfies, booth map) until the next new game. No account, email or location data.
- Votes are anonymous: the host stores only the tally per round, never who voted for whom.
- Bluetooth (BLE) is used only for proximity between game devices, with no identifiers beyond a per-game random token.
- `Shared/Resources/PrivacyInfo.xcprivacy` stays accurate for every API used.

## Accessibility

- Dynamic Type up to the largest accessibility sizes, without truncating core content.
- VoiceOver labels on every interactive element. Never convey information by colour alone.
- Respect Reduce Motion and Reduce Transparency.

## Localization

- English only for now. All user-facing strings still go in String Catalogs from day one so another language can be added later.
- UI copy and code both follow the domain terms in `glossary.md`.

## Quality gates

- `fastlane lint` and every target's `fastlane <platform> test` pass, with no new compiler warnings.
- Every acceptance criterion in an implemented spec has a test or a documented manual check.
