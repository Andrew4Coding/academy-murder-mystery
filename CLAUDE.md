# Murder Mystery

One SwiftUI codebase (`project.yml` → `MurderMystery.xcodeproj`): a `Shared/` folder plus one app target per platform.

## Targets

| Target / scheme | Display name | Platform | Bundle ID | Version file | Specs |
|---|---|---|---|---|---|
| `MurderMysteryiOS` | Murder Mystery | iOS 26.0+, iPhone and iPad | `com.andrew4coding.MurderMystery` | `iOS/MurderMysteryiOS.xcconfig` | `specs/apps/ios/` |
| `MurderMysteryAdmin` | Murder Mystery Admin | macOS 26.0+ | `com.andrew4coding.MurderMystery.admin` | `Admin/MurderMysteryAdmin.xcconfig` | `specs/apps/admin/` |
| `MurderMysteryAdminiPad` | Murder Mystery Admin | iOS 26.0+, iPad only | `com.andrew4coding.MurderMystery.adminpad` | `AdminiPad/MurderMysteryAdminiPad.xcconfig` | `specs/apps/admin/` |

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
# Rehearsal: run the MurderMysteryAdmin-Testing scheme in Xcode (Debug, launches with -TestingTools)
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
- Every alive phone scans and a killed family's phones advertise until the death is announced, so scanning never reveals a werewolf; the host decides kill range and body reports.
- BLE only works on real devices and in the foreground; the kill range check lives on the host (`GameHost+Proximity`), the phone only reports sightings.
- Admin sidebar rows must carry `.tag(section)`: `List(items, selection:)` only selects rows whose tag type equals the selection type, and the automatic tag is the item's `id` (a `String` here), so an untagged enum selection silently ignores clicks. Branch from `dev` loses this fix if it only lives on another branch: check it is there.
- The Public Display reads `PublicDisplayState` only. Never pass `GameState` or `GameView` to it; roles appear there only as reveals of expelled families, plus `PublicDisplayState.reveal` (every family, selfie and werewolf mark) once the werewolves have won.
- Dead (killed or expelled) families keep stamping tasks, because villagers also win when every villager family is done; they never vote (`GameEngine.recordStamp` has no alive check, `castVote` does).
- Text that carries meaning never relies on colour: use `StatusLabel` (colour on the icon, text in the primary colour) and `scaledSystemFont` / `countdownDisplay()` instead of fixed `.system(size:)`. Check `accessibilityReduceMotion` before any animation or symbol effect. The Mac Game toolbar stays at five grouped items.
- Timers are edited only through `GameCommand.adjustTimer(TimerTarget, seconds:)` (meeting, final-vote clock via `GameState.finalVoteOverride`, sabotage). Both admins use `Shared/Features/Timers/TimerAdjustMenu`; the iPad sends `AdminCommand.adjustTimer`.
- Simulations use their own `GameHost` and in-memory repository and mark `state.simulated`; never point bots at the real host. They are deterministic per seed: draw all randomness from `Simulation`'s `SeededGenerator`.
- OC devices never receive roles: `OCView` rows carry stamp progress only. Keep it that way when adding OC features.
- Players join with one game code (`HostState.gameCode`) and `GameHost.assignFamily` gives every joiner their own family (one person per family, ADR 0007). Selfies live only in `GameHost.selfies` (memory) and are cleared on `newGame`.
- `GameClient.send` is a no-op until the host confirms the identity; sending earlier produced a stray "Join a family or enter the OC PIN first" error after reconnects.
- The iPad admin is an OC device with `OCStation.admin` (signs in with the OC PIN): it gets `ClientView.admin` and may send `ClientMessage.admin`, checked in `GameHost.adminCommand`. It never receives roles.
- Never encode ballots: `GameState.votes` is excluded from `Codable` on purpose (anonymous votes). Shared display strings for roles, life states and outcomes live in `Shared/Game/GameLabels.swift`; do not redefine them per target.
- The Mac Admin app is the only authority: `GameHost` validates every client message through `GameEngine`, persists, then broadcasts a per-identity `ClientView`. Clients never run authoritative timers: use `ServerClock` / `GameClient.serverNow`.
- Network code uses closures that hop to the main actor via `MainActor.assumeIsolated`; keep logic in methods, not inside the closures (SwiftFormat strips the `self.` that the compiler wants there).
- Smoke-test UI by building both apps with `-derivedDataPath`, opening the Mac app (unsigned builds run unsandboxed and store `~/Library/Application Support/default.store`), then launching the iOS app in a simulator: Bonjour works between them on one machine.
- Debug Mode (`GameSettings.debugMode`, optional so stored games decode; read it via `isDebug`) allows 2 families, zeroes kill and sabotage cooldowns, and makes kills and parity never end the game. Rules live in `GameEngine` and `setupIssues`, not in views.
- Rehearsal tools (one family and one phone is enough, chosen roles, sabotage trigger, adjustable cooldowns) sit behind `TestingTools.isEnabled` (`Shared/Host/TestingTools.swift`): Debug builds launched with `-TestingTools`, which only the `MurderMysteryAdmin-Testing` scheme passes. Never reach them from a normal path; `GameHost.startTestGame` refuses otherwise and marks the game `simulated` so a restart never restores it.
- XcodeGen generates `iOS/Info.plist`; put new Info.plist keys in `project.yml`, not in the file.

## Layout

```
project.yml                  XcodeGen: one app target + one test bundle per platform
Shared/App                   AppEnvironment (composition root)
Shared/Game                  pure game engine: GameEngine, GameState, GameCommand, GameEvent, GameTypes, SeededGenerator
Shared/Host                  GameHost (authority, sessions, persistence), GameClient, HostController, HostState, ClientView, HostClock, TestingTools
Shared/Net                   wire messages, length-prefixed Network.framework transports, loopback transport
Shared/Data                  ModelContainerFactory, GameRepository (SwiftData + in-memory), Schema/ (SchemaV1: GameRecord, GameEventRecord)
Shared/Features              feature views shared by targets (Connection, Meeting/CountdownView)
Shared/Simulation            Simulation (seeded bots on a separate GameHost), SimulationController, SimulationLog
Shared/Core                  DesignSystem tokens, QRCodeView
iOS/Bluetooth                ProximityService (CoreBluetooth advertise and scan)
Shared/Core                  DesignSystem tokens (Spacing, Radius)
Shared/Resources             PrivacyInfo.xcprivacy
iOS/                 MurderMysteryiOSApp, Intents/ (kill and sabotage App Intents), Features/Selfie, RootView (join, family lobby, game tabs), Features/ (Join, Lobby, Role, Meeting, Actions incl. sabotage, OC, Game), Info.plist (generated by XcodeGen), assets, MurderMysteryiOS.xcconfig
Admin/                 MurderMysteryAdminApp (min window 720×480), RootView (sidebar: Setup, Game, Display, Simulation, Devices), a separate Public Display window, Features/ (Setup, Game, Display, Simulation, Devices), assets, entitlements, MurderMysteryAdmin.xcconfig
AdminiPad/             MurderMysteryAdminiPadApp, RootView (OC PIN sign-in), DashboardView (status, controls, family table); a client of the Mac host, never a host
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

Run `apple-compliance-checker`, plus `apple-design-skill` for a UI review. Fill in `fastlane/metadata/<slug>` (replace the `TODO`s) and add real app icons. All three targets share one Icon Composer bundle (`Shared/Resources/AppIcon.icon`), so never add an `AppIcon.appiconset` to any target: both are named `AppIcon` and an empty set shows no icon.
