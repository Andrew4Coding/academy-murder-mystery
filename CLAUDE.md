# Moonfall

One SwiftUI codebase (`project.yml` → `Moonfall.xcodeproj`): a `Shared/` folder plus one app target per platform.

## Targets

| Target / scheme | Display name | Platform | Bundle ID | Version file | Specs |
|---|---|---|---|---|---|
| `MoonfalliOS` | Moonfall | iOS 26.0+, iPhone and iPad (embeds the `MoonfalliOSLiveActivity` widget extension, bundle ID `com.andrew4coding.Moonfall.LiveActivity`) | `com.andrew4coding.Moonfall` | `iOS/MoonfalliOS.xcconfig` | `specs/apps/ios/` |
| `MoonfallAdmin` | Moonfall Admin | macOS 26.0+ | `com.andrew4coding.Moonfall.admin` | `Admin/MoonfallAdmin.xcconfig` | `specs/apps/admin/` |
| `MoonfallAdminiPad` | Moonfall OC | iOS 26.0+, iPad only | `com.andrew4coding.Moonfall.adminpad` | `AdminiPad/MoonfallAdminiPad.xcconfig` | `specs/apps/admin/` |

App targets use the Swift module name `Moonfall`, so tests write `@testable import Moonfall`. Signing team: `92QV2QPDKA`.

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
xcodebuild build -project Moonfall.xcodeproj -scheme MoonfalliOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
bundle exec fastlane ios test          # MoonfalliOS on iPhone 17 Pro; override with TEST_DEVICE
bundle exec fastlane ios beta          # TestFlight; humans only (needs fastlane/.env)
xcodebuild build -project Moonfall.xcodeproj -scheme MoonfallAdmin -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
bundle exec fastlane mac test          # MoonfallAdmin on macOS
# Rehearsal: run the MoonfallAdmin-Testing scheme in Xcode (Debug, launches with -TestingTools)
bundle exec fastlane mac beta          # TestFlight; humans only (needs fastlane/.env)
bundle exec fastlane lint              # swiftlint --strict + swiftformat --lint
bundle exec fastlane ios adminpad_beta # TestFlight for MoonfallAdminiPad; humans only
bundle exec fastlane ios beta_external # also mac beta_external, ios adminpad_beta_external: submit the latest build to external testers (Beta App Review); needs BETA_REVIEW_* in fastlane/.env; humans only
bundle exec fastlane create_apps      # one-time: bundle IDs and ASC apps for all three targets (Apple ID login)
scripts/setup-ci.sh --dry-run          # validate fastlane/.env and upload the three ASC secrets to GitHub
bundle exec fastlane bump app:ios type:minor
scripts/commit-code.sh                 # your committer code
scripts/check-branch-name.sh           # validate the current branch name
```

`project.yml` is the source of truth. `Moonfall.xcodeproj` is generated and gitignored, so never edit it.

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
- BLE only works on real devices. `MoonfalliOS` has the `bluetooth-central` and `bluetooth-peripheral` background modes, so it keeps working while the phone is locked or the app is in the background, but not after a force-quit. iOS strips the advertised local name in the background, so `ProximityService` also exposes the token as a readable GATT characteristic and connects to name-less peers to read it and poll RSSI; the kill range check lives on the host (`GameHost+Proximity`), the phone only reports sightings.
- Admin sidebar rows must carry `.tag(section)`: `List(items, selection:)` only selects rows whose tag type equals the selection type, and the automatic tag is the item's `id` (a `String` here), so an untagged enum selection silently ignores clicks. Branch from `dev` loses this fix if it only lives on another branch: check it is there.
- The Public Display reads `PublicDisplayState` only. Never pass `GameState` or `GameView` to it; roles appear there only as reveals of expelled families, plus `PublicDisplayState.reveal` (every family, selfie and werewolf mark) once the werewolves have won.
- Stamping and the task win live outside the app (ADR 0008): `Family.tasks` is only the list of booths a family is told to visit (every family gets all of them, with `Booth.instructions` shown in the app), with no progress. Dead (killed or expelled) families never vote (`castVote` checks alive).
- Text that carries meaning never relies on colour: use `StatusLabel` (colour on the icon, text in the primary colour) and `scaledSystemFont` / `countdownDisplay()` instead of fixed `.system(size:)`. Check `accessibilityReduceMotion` before any animation or symbol effect. The family table lives in its own Families sidebar item (`Admin/Features/Families`, `AdminiPad/FamiliesTab`), not in the Game view; the iPad lists use `List` with swipe actions because `Table` has none, and `AdminCommand.removeDevice` signs a device out (players only in the lobby). Game actions on the Mac and iPad are `BentoButton` / `BentoTile` tiles in a `BentoGrid` (`Shared/Features/Actions`), not toolbar items; the toolbar keeps only Show Roles. Menus-as-tiles use `.buttonStyle(.plain)` and `.menuIndicator(.hidden)`.
- Timers are edited only through `GameCommand.adjustTimer(TimerTarget, seconds:)` (meeting, final-vote clock via `GameState.finalVoteOverride`, sabotage). Timers also pause and resume per target (`GameCommand.pauseTimer` / `resumeTimer`, `GameState.timerPausedAt`; resuming shifts the deadline by the paused gap). Both admins show `Shared/Features/Timers/TimerControls` under each timer in the phase card; the iPad sends the matching `AdminCommand`s. Phones and the Public Display do not yet freeze their countdowns while a timer is paused.
- Simulations use their own `GameHost` and in-memory repository and mark `state.simulated`; never point bots at the real host. They are deterministic per seed: draw all randomness from `Simulation`'s `SeededGenerator`.
- OC devices never receive roles: `OCView` carries the active sabotage only. Keep it that way when adding OC features.
- Players join with one game code (`HostState.gameCode`) and `GameHost.assignFamily` gives every joiner their own family (one person per family, ADR 0007). Selfies live only in `GameHost.selfies` (memory) and are cleared on `newGame`.
- `GameClient.send` is a no-op until the host confirms the identity; sending earlier produced a stray "Join a family or enter the OC PIN first" error after reconnects.
- The iPad admin is an OC device with `OCStation.admin` (signs in with the OC PIN): it gets `ClientView.admin` and may send `ClientMessage.admin`, checked in `GameHost.adminCommand`. It mirrors the Mac Game and Setup screens (every `AdminCommand`), and its `AdminFamilyRow.role` is only shown behind the Show Roles toggle. Other OC stations never receive roles. The iPad has no Simulation or Display.
- Never encode ballots: `GameState.votes` is excluded from `Codable` on purpose (anonymous votes). Shared display strings for roles, life states and outcomes live in `Shared/Game/GameLabels.swift`; do not redefine them per target.
- The cloud host (spec 0035/0036, ADR 0009) is a TypeScript port in `cloud/` of `GameEngine` and `GameHost`. It speaks the same Codable JSON over `wss://`, and only one host is authoritative at a time: the registry (`GET /registry` on the cloud) says which. Phones pick it through `AdaptiveClientTransport`, falling back to Bonjour. Keep the two engines equal: after any rule or wire change, regenerate the golden fixtures with `MOONFALL_WRITE_FIXTURES=<dir>/cloud/test/fixtures` (see `Tests/Shared/GoldenFixtureGenerator.swift`) and run `npm test` in `cloud/`. Swift never encodes ballots, so the golden comparison ignores `votes` and `skipVotes`. Snapshots are cold backups only; a switch carries `HostState`, selfies and the booth map, and votes in flight are lost.
- The Mac Admin app is the only authority on the LAN: `GameHost` validates every client message through `GameEngine`, persists, then broadcasts a per-identity `ClientView`. Clients never run authoritative timers: use `ServerClock` / `GameClient.serverNow`.
- Network code uses closures that hop to the main actor via `MainActor.assumeIsolated`; keep logic in methods, not inside the closures (SwiftFormat strips the `self.` that the compiler wants there).
- Smoke-test UI by building both apps with `-derivedDataPath`, opening the Mac app (unsigned builds run unsandboxed and store `~/Library/Application Support/default.store`), then launching the iOS app in a simulator: Bonjour works between them on one machine.
- Debug Mode (`GameSettings.debugMode`, optional so stored games decode; read it via `isDebug`) allows 2 families, zeroes kill and sabotage cooldowns, and makes kills and parity never end the game. Rules live in `GameEngine` and `setupIssues`, not in views.
- Rehearsal tools (one family and one phone is enough, chosen roles, sabotage trigger, adjustable cooldowns) sit behind `TestingTools.isEnabled` (`Shared/Host/TestingTools.swift`): Debug builds launched with `-TestingTools`, which only the `MoonfallAdmin-Testing` scheme passes. Never reach them from a normal path; `GameHost.startTestGame` refuses otherwise and marks the game `simulated` so a restart never restores it.
- The Live Activity (`MoonfalliOS` only, spec 0029) is built from `GameActivityState` and never contains role, allies, cooldowns, proximity, votes or other families' roles: villager and werewolf views must map to the same state. Countdowns come from absolute deadlines shifted by `ServerClock.offset` and rendered with `Text(timerInterval:)`; `Activity` is not `Sendable`, so `LiveActivityController` touches it only through `@concurrent` functions that take its id. The extension compiles just `GameActivityState.swift` and `GameActivityAttributes.swift`: do not add `GameView` or other app types to it.
- The booth map (spec 0030) is public venue info: it lives in `BoothMapStore` (a file on the Mac, outside `GameState`, so `newGame` keeps it) and travels as `ServerMessage.map` keyed by hash. Never put role or family data in it, and never show it on the Public Display.
- The sabotage cooldown (`GameState.sabotageReadyAt`) is one value for every werewolf family: it is set to the sabotage end plus the cooldown when one starts, and reset to resolve time plus the cooldown when it is resolved.
- Meetings and body reports are refused while `GameState.sabotage` is set (`RuleError.sabotageActive`). A majority of `skipVotes` opens voting immediately inside `GameEngine`; no OC approval step.
- `GameHost.startGame` starts the engine 10 seconds in the future (`startCountdown`, none in debug mode); phones show `GameView.startsAt` as a countdown and the Public Display uses `.starting`.
- Expelled roles are never sent: `ExpelledView.role` is nil and `FamilySummary.revealedRole` is set only after the game ends.
- `GameClient` sends `.sync` every 4 s and reconnects after 12 s of silence; `ServerClock` uses the largest of the last 8 offsets. The host evicts older sessions for the same identity, and `unknownDevice` does not sign the client out or count as a failed attempt.
- Colours come from `Theme` (`Shared/Resources/Theme.xcassets`, dark and light variants, contrast-checked by `ThemeContrastTests`): never hard-code a colour or change a palette value without updating that test. `AccentColor` lives only in that shared catalogue; the Public Display is always dark (spec 0031).
- Visual style is flat and vector: solid theme fills only, no shadows, gradients, blurs, glows or card borders, and SF Pro in its default design (no rounded, serif, monospaced or condensed). The one stroke allowed is the Public Display timer ring.
- Every screen has `#Preview`s in `iOS/Gallery`, `Admin/Gallery` and `AdminiPad/Gallery`, plus a gallery view per target, all `#if DEBUG`. Debug builds launch them with `-Gallery` (iOS, `-GalleryState <case>` for one state) `-DisplayGallery [n]` (Mac Public Display) and `-AdminGallery [n]` (Mac Admin screens); add `-DisplayGalleryCapture <png>` to snapshot the window and quit; fixtures are built from the real engine, so keep them in step with `GameView` / `AdminView` / `PublicDisplayState`.
- The Public Display lays out on a 1920x1080 canvas scaled to the window, and `FitToStage` shrinks tall content (rosters, reveals) to fit.
- XcodeGen generates `iOS/Info.plist`; put new Info.plist keys in `project.yml`, not in the file.

## Layout

```
project.yml                  XcodeGen: one app target + one test bundle per platform
Shared/App                   AppEnvironment (composition root)
Shared/Game                  pure game engine: GameEngine, GameState, GameCommand, GameEvent, GameTypes, SeededGenerator
Shared/Host                  GameHost (authority, sessions, persistence), GameClient, HostController, HostState, ClientView, HostClock, TestingTools; cloud switching: CloudConfig, HostRegistryClient, HostEndpointResolver, HostSnapshot, SnapshotUploader, HostModeController, CloudTakeoverController
Shared/Net                   wire messages, length-prefixed Network.framework transports, loopback transport
Shared/Data                  ModelContainerFactory, GameRepository (SwiftData + in-memory), Schema/ (SchemaV1: GameRecord, GameEventRecord)
Shared/Features              feature views shared by targets (Timers/TimerControls, Setup/SetupTiles, Connection, Meeting/CountdownView, Map/BoothMapCard and BoothMapViewer)
Shared/LiveActivity           GameActivityState (role-neutral Live Activity content) and its mapping from GameView; no ActivityKit, so it compiles into every target
Shared/Map                   BoothMap, BoothMapImporter (downscale to JPEG), BoothMapStore (file and in-memory)
Shared/Simulation            Simulation (seeded bots on a separate GameHost), SimulationController, SimulationLog
Shared/Core                  DesignSystem tokens, QRCodeView
Shared/Preview               DEBUG-only fixtures for #Preview galleries (ClientFixtures, AdminFixtures, DisplayFixtures)
iOS/Bluetooth                ProximityService (CoreBluetooth advertise and scan)
Shared/Core                  DesignSystem tokens (Spacing, Radius, Theme colours, ThemedBackground, ThemedCard, AccentFillButtonStyle)
Shared/Resources             PrivacyInfo.xcprivacy
iOS/                 MoonfalliOSApp, LiveActivity/ (GameActivityAttributes, LiveActivityController), Intents/ (kill and sabotage App Intents), Features/Selfie, RootView (join, family lobby, game tabs), Features/ (Join, Lobby, Role, Meeting, Actions incl. sabotage, OC, Game), Info.plist (generated by XcodeGen), assets, MoonfalliOS.xcconfig
Admin/                 MoonfallAdminApp (min window 720×480), RootView (sidebar: Setup, Game, Display, Simulation, Devices), a separate Public Display window, Features/ (Setup, Game, Display, Simulation, Devices), assets, entitlements, MoonfallAdmin.xcconfig
LiveActivity/          widget extension: MoonfallLiveActivityBundle, GameLiveActivity (Lock Screen and Dynamic Island), display strings
AdminiPad/             MoonfallAdminiPadApp, RootView (OC PIN sign-in), DashboardView (status, controls, family table); a client of the Mac host, never a host
cloud/                       TypeScript cloud host (Node, Docker, SQLite) that can replace the Mac; CONTRACT.md is the API; own tests with `npm test`
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

Targets are versioned independently: `bump app:<slug>` edits that target's xcconfig. TestFlight betas are cut from `staging`: a push there runs `.github/workflows/beta.yml`, which builds all three targets in parallel (`scripts/setup-ci.sh` uploads its secrets). Tag releases on `main` as `<slug>/vX.Y.Z`.

## Gotchas

- `PRODUCT_MODULE_NAME: Moonfall` must stay on the app targets only. Project-wide, it renames the test bundles too and causes "Multiple commands produce Moonfall.swiftmodule".
- `.claude/sync-state` holds a content fingerprint, not a commit SHA, so it survives squash merges. Update it only with `.claude/hooks/sync-state.sh record`.
- The hook scripts target macOS's stock bash 3.2: no `mapfile`, and no empty `"${array[@]}"` under `set -u`.
- `swiftlint` must be installed (`brew bundle`) for `fastlane lint`. Fastlane wants a UTF-8 locale (`export LC_ALL=en_US.UTF-8`).

## Before submitting

Run `apple-compliance-checker`, plus `apple-design-skill` for a UI review. Fill in `fastlane/metadata/<slug>` (replace the `TODO`s) and add real app icons. Each target owns its Icon Composer bundle (`iOS/Resources/AppIcon.icon`, `Admin/Resources/AppIcon.icon`, `AdminiPad/Resources/AppIcon.icon`; Admin and OC add a banner layer), so never add an `AppIcon.appiconset` to any target: both are named `AppIcon` and an empty set shows no icon, and never put an icon bundle in `Shared/`.
