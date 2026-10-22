# Murder Mystery

One SwiftUI codebase (`project.yml` → `MurderMystery.xcodeproj`): a `Shared/` folder plus one app target per platform.

## Targets

| Target / scheme | Display name | Platform | Bundle ID | Version file | Specs |
|---|---|---|---|---|---|
| `MurderMysteryiOS` | Murder Mystery | iOS 26.0+, iPhone and iPad | `com.andrew4coding.MurderMystery` | `iOS/MurderMysteryiOS.xcconfig` | `specs/apps/ios/` |
| `MurderMysteryAdmin` | Murder Mystery Admin | macOS 26.0+ | `com.andrew4coding.MurderMystery.admin` | `Admin/MurderMysteryAdmin.xcconfig` | `specs/apps/admin/` |

App targets use the Swift module name `MurderMystery`, so tests write `@testable import MurderMystery`. Signing team: `92QV2QPDKA`.

Branches: `dev` (integration) → `staging` (release candidate) → `main` (released). Only `main` runs the CI build and test jobs.

## Working agreement (read first)

1. **Spec-driven.** No feature code until a spec reaches `status: approved`. Before designing anything, read `specs/README.md`, `specs/constraints.md` and `specs/apps/<slug>/constraints.md`. Use the `new-feature` skill.
2. **Branches.** Never commit on `main`, `staging` or `dev`.
   - Branch from `dev` as `<type>/<optional-spec-id->kebab-name` (e.g. `feature/0002-settings`), and open the PR into `dev`.
   - Promote `dev` → `staging` → `main`.
   - Rules: `.claude/rules/branches.md`.
3. **Microcommits.** Commit after every logical change, using the `commit` skill. Format: `type(scope): [ABC] summary`. Rules: `.claude/rules/commits.md`.
4. **No AI attribution.** Never add `Co-Authored-By`, "Generated with Claude", or anything similar to commits or PRs.
5. **Keep the map current.** After source changes, run the `codebase-sync` skill. The Stop hook reminds you.
6. **PRs.** Use `.github/pull_request_template.md`: fill in every section and link the spec. Never push unless the user asks.

## Commands

```bash
scripts/bootstrap.sh                   # hooks, brew bundle, bundle install, xcodegen generate
xcodegen generate                      # after adding, moving or removing files
xcodebuild build -project MurderMystery.xcodeproj -scheme MurderMysteryiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
bundle exec fastlane ios test          # MurderMysteryiOS on iPhone 17 Pro; override with TEST_DEVICE
bundle exec fastlane ios beta          # TestFlight; humans only (needs fastlane/.env)
xcodebuild build -project MurderMystery.xcodeproj -scheme MurderMysteryAdmin -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
bundle exec fastlane mac test          # MurderMysteryAdmin on macOS
bundle exec fastlane mac beta          # TestFlight; humans only (needs fastlane/.env)
bundle exec fastlane lint              # swiftlint --strict + swiftformat --lint
bundle exec fastlane bump app:ios type:minor
scripts/commit-code.sh                 # your committer code
scripts/check-branch-name.sh           # validate the current branch name
```

`project.yml` is the source of truth. `MurderMystery.xcodeproj` is generated and gitignored, so never edit it.

## Architecture rules

- One `@Observable @MainActor` view model per screen. Views create it in `init` with `@State`.
- Views never use `@Query` or `ModelContext`. View models talk to repository protocols only.
- `SwiftData*Repository` types are the only owners of `ModelContext`.
- Dependencies are constructed in `AppEnvironment` (the composition root) and passed by constructor.
- SwiftData is versioned: never edit a shipped `SchemaVn`. Add `SchemaVn+1` and a stage in `AppMigrationPlan`, then repoint the typealiases in `Shared/Models/`.
- Swift 6 strict concurrency. No `@unchecked Sendable` / `nonisolated(unsafe)` without a written reason.
- **Shared vs target code:**
  - Anything every target needs lives in `Shared/`, which never uses `#if os()`.
  - When targets differ, inject the difference: the shared type takes parameters, and the target supplies them.
  - Platform UI (navigation, sidebar, menu commands) lives in the target folder.
- Tests use Swift Testing, with a mock repository or an in-memory container. `Tests/Shared/` compiles into every test bundle.
- Game rules live only in `Shared/Game/GameEngine` (pure value type, time passed in as `at:`, randomness injected). Views, transports and BLE call it with `GameCommand`s and never re-implement a rule. Call `advance(to:)` on a timer so timeouts emit events; `apply` is atomic and leaves state untouched when it throws.
- SwiftFormat's `noForceUnwrapInTests` is disabled in `.swiftformat` and it rewrites key-path closures inside `#expect`: prefer plain closures or regular expressions there.
- BLE only works on real devices and in the foreground; the kill range check lives on the host (`GameHost+Proximity`), the phone only reports sightings.
- Never encode ballots: `GameState.votes` is excluded from `Codable` on purpose (anonymous votes). Shared display strings for roles, life states and outcomes live in `Shared/Game/GameLabels.swift`; do not redefine them per target.
- The Mac Admin app is the only authority: `GameHost` validates every client message through `GameEngine`, persists, then broadcasts a per-identity `ClientView`. Clients never run authoritative timers: use `ServerClock` / `GameClient.serverNow`.
- Network code uses closures that hop to the main actor via `MainActor.assumeIsolated`; keep logic in methods, not inside the closures (SwiftFormat strips the `self.` that the compiler wants there).
- Smoke-test UI by building both apps with `-derivedDataPath`, opening the Mac app (unsigned builds run unsandboxed and store `~/Library/Application Support/default.store`), then launching the iOS app in a simulator: Bonjour works between them on one machine.
- XcodeGen generates `iOS/Info.plist`; put new Info.plist keys in `project.yml`, not in the file.

## Layout

```
project.yml                  XcodeGen: one app target + one test bundle per platform
Shared/App                   AppEnvironment (composition root)
Shared/Game                  pure game engine: GameEngine, GameState, GameCommand, GameEvent, GameTypes, SeededGenerator
Shared/Host                  GameHost (authority, sessions, persistence), GameClient, HostController, HostState, ClientView, HostClock
Shared/Net                   wire messages, length-prefixed Network.framework transports, loopback transport
Shared/Data                  ModelContainerFactory, GameRepository (SwiftData + in-memory), Schema/ (SchemaV1: GameRecord, GameEventRecord)
Shared/Features              feature views shared by targets (Connection, Meeting/CountdownView)
Shared/Core                  DesignSystem tokens, QRCodeView
iOS/Bluetooth                ProximityService (CoreBluetooth advertise and scan)
Shared/Core                  DesignSystem tokens (Spacing, Radius)
Shared/Resources             PrivacyInfo.xcprivacy
iOS/                 MurderMysteryiOSApp, RootView (join, family lobby, game tabs), Features/ (Join, Lobby, Role, Meeting, Actions, Game), Info.plist (generated by XcodeGen), assets, MurderMysteryiOS.xcconfig
Admin/                 MurderMysteryAdminApp (min window 720×480), RootView (sidebar: Setup, Game, Devices), Features/ (Setup, Game, Devices), assets, entitlements, MurderMysteryAdmin.xcconfig
Tests/Shared                 compiled into every test bundle
Tests/<TargetDir>            target-only tests (bundle-identifier smoke test)
fastlane/                    Fastfile (shared lanes + one platform block per target), Appfile, Matchfile, metadata/<slug>
specs/                       product, constraints, glossary, roadmap, decisions/, templates/, features/, apps/<slug>/
.claude/                     settings.json, rules/{commits,branches}.md, skills/{codebase-sync,commit,new-feature}, hooks/, sync-state
.githooks/                   commit-msg (message format), pre-push (branch names, no direct pushes to main)
scripts/                     bootstrap.sh, commit-code.sh, check-branch-name.sh
.github/                     PR template, CI (branch and commit checks, lint, per-target tests on main)
CHANGELOG.md                 one file, with a subsection per target
```

## Releases

Targets are versioned independently: `bump app:<slug>` edits that target's xcconfig. TestFlight betas are cut from `staging`. Tag releases on `main` as `<slug>/vX.Y.Z`.

## Gotchas

- `PRODUCT_MODULE_NAME: MurderMystery` must stay on the app targets only. Project-wide, it renames the test bundles too and causes "Multiple commands produce MurderMystery.swiftmodule".
- `.claude/sync-state` holds a content fingerprint, not a commit SHA, so it survives squash merges. Update it only with `.claude/hooks/sync-state.sh record`.
- The hook scripts target macOS's stock bash 3.2: no `mapfile`, and no empty `"${array[@]}"` under `set -u`.
- `swiftlint` must be installed (`brew bundle`) for `fastlane lint`. Fastlane wants a UTF-8 locale (`export LC_ALL=en_US.UTF-8`).

## Before submitting

Run `apple-compliance-checker`, plus `apple-design-skill` for a UI review. Fill in `fastlane/metadata/<slug>` (replace the `TODO`s) and add real app icons to each target's `Assets.xcassets`.
