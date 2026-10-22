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
- One XcodeGen project (`project.yml`) with one target per platform. Releases go through Fastlane + match (`fastlane/Fastfile`).
- Code every target needs lives in `Shared/` and never branches with `#if os()`. Target differences are injected from the target folders. Never copy code between targets.
- No third-party dependencies without an ADR covering license, privacy manifest and maintenance.
- TODO: backend / sync (CloudKit? custom API? offline only?). Record it in an ADR.

## Privacy

- No third-party analytics, ads or tracking SDKs without an ADR. `NSPrivacyTracking = false`.
- Collect the minimum personal data. TODO: list exactly which data exists and where it lives.
- `Shared/Resources/PrivacyInfo.xcprivacy` stays accurate for every API used.

## Accessibility

- Dynamic Type up to the largest accessibility sizes, without truncating core content.
- VoiceOver labels on every interactive element. Never convey information by colour alone.
- Respect Reduce Motion and Reduce Transparency.

## Localization

- TODO: primary and secondary languages. All user-facing strings go in String Catalogs from day one.
- UI copy and code both follow the domain terms in `glossary.md`.

## Quality gates

- `fastlane lint` and every target's `fastlane <platform> test` pass, with no new compiler warnings.
- Every acceptance criterion in an implemented spec has a test or a documented manual check.
