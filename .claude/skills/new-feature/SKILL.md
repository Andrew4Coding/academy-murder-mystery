---
name: new-feature
description: Spec-first recipe for adding a feature or screen to the MurderMysteryiOS target, the MurderMysteryAdmin target. Use when the user asks for a new feature, screen, flow or data type. Starts from specs/, then creates a feature/ branch from dev and builds View + ViewModel + repository following the MVVM rules.
---

# New feature (spec-driven)

## 1. Spec before code

- **Pick the scope**: which target(s): `ios`, `admin`, or `all`. If it's unclear, ask.
- **Find or write the spec.**
  - Look in `specs/apps/<slug>/features/`, or in `specs/features/` for work that spans targets.
  - If there's no spec, copy `specs/templates/feature.md` there as `NNNN-<kebab-name>.md`. Numbers are global (see `specs/README.md`).
  - Fill it in with the user and set `status: draft`.
- **Check it** against `specs/constraints.md`, `specs/apps/<slug>/constraints.md` and `specs/product.md`. Raise conflicts as Open Questions.
- **Branch**: `git switch dev && git pull`, then `git switch -c feature/NNNN-<kebab-name>`.
- **Wait for approval.** Write no code until the user approves and the spec is at `status: approved`. Then commit the spec: `docs(specs): [ABC] add NNNN-<name> spec`.
- **Start**: set `status: in-progress` when you begin.

## 2. Decide where the code goes

| The code is… | Put it in |
|---|---|
| models, schema, repositories, design tokens, view models and views every target uses | `Shared/` |
| only for the iOS target (its navigation, iOS-only screens, target configuration) | `iOS/` |
| only for the macOS target (sidebar, menu commands, Mac-only screens) | `Admin/` |

`Shared/` never uses `#if os()`. When targets need different content or behaviour, inject it: give the shared type parameters and let each target supply them, from an extension or factory in its own folder.

## 3. Build in microcommits (see the `commit` skill)

1. **Data**, if the feature persists anything:
   - Add the model to the current `Shared/Data/Schema/SchemaVn`. A shipped schema is frozen: add `SchemaVn+1` and a stage in `AppMigrationPlan`, then repoint the typealias in `Shared/Models/`.
   - Add `Shared/Data/<Name>Repository.swift`: a `@MainActor protocol <Name>Repository` plus a `SwiftData<Name>Repository`, which is the only type that holds a `ModelContext`.
   - Register it in `Shared/App/AppEnvironment.swift`.
2. **View model**: `<Shared|TargetDir>/Features/<Name>/<Name>ViewModel.swift`, an `@Observable @MainActor final class` that depends on repository protocols only. Follow `Shared/Features/Items` as the reference.
3. **View**: `<Name>View.swift` next to it. It owns its view model through `@State`, created in `init`. No `@Query` and no `ModelContext`. Use the `Shared/Core/DesignSystem` tokens.
4. **Navigation**: wire the view into each target's `App/RootView.swift`.
5. **Tests** (Swift Testing):
   - Shared logic goes in `Tests/Shared/`, which runs on every target. Target-only logic goes in `Tests/<TargetDir>/`.
   - Use a mock repository, and `ModelContainerFactory.make(inMemory: true)` for persistence.
   - Map every acceptance criterion to at least one test.
6. **Verify**: run `xcodegen generate`, then `bundle exec fastlane ios test` and `bundle exec fastlane mac test`.

## 4. Close the loop

Run `codebase-sync`: tick the criteria, set `status: implemented`, add the target's lines to `CHANGELOG.md`, and update the CLAUDE.md layout.

Then offer to open a PR into `dev`. Don't push unless the user asks. `dev` doesn't run build and test jobs in CI, so the local test runs in step 3.6 are the gate.

For UI work, also use `swiftui-expert:swiftui-expert-skill`, and `apple-design-skill` for a HIG review.
