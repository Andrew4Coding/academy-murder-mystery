<!-- Base branch: features and fixes → `dev` (squash). Promotions: `dev` → `staging`, `staging` → `main` (merge commit). Hotfixes → `main`. -->

## Summary

<!-- What changes for the user, and why. One short paragraph. -->

## Apps affected

- [ ] `Shared/` (every target)
- [ ] `iOS/`: MoonfalliOS (iOS)
- [ ] `Admin/`: MoonfallAdmin (macOS)
- [ ] repo-wide (specs, tooling, `.claude/`, CI)

## Spec

<!-- Every feature or behaviour change links its spec. Write "n/a: <reason>" only for tooling, chores or docs. -->

- Spec: `specs/apps/<app>/features/NNNN-name.md` or `specs/features/NNNN-name.md` (status after merge: `implemented` / `in-progress`)
- ADR: <!-- specs/decisions/NNNN-*.md if an architectural choice was made, else "none" -->

### Acceptance criteria covered

| AC | Covered by |
|---|---|
| AC1 | `SomeViewModelTests.testName` / manual check below |

## Type of change

- [ ] feat: new user-facing behaviour
- [ ] fix: bug fix
- [ ] refactor / perf: no behaviour change
- [ ] build / ci / chore: tooling
- [ ] docs: specs or documentation only
- [ ] ⚠️ breaking: schema migration or removed behaviour (explain below)

## Screenshots / recordings

<!-- Required for any UI change. Show before and after. For iPad: portrait, landscape and split view. For Mac: a resized window, light and dark mode. -->

| Before | After |
|---|---|
| | |

## How to test

1. `xcodegen generate`
2.
3.

## Risk and rollback

<!-- What could break, who is affected, how to revert. Schema changes: is the migration tested? -->

## Checklist

- [ ] Spec updated (criteria ticked, status set), or n/a
- [ ] `CHANGELOG.md` `[Unreleased]` updated under the right app for user-visible changes
- [ ] Tests added or updated; `bundle exec fastlane ios test` and `bundle exec fastlane mac test` pass for each affected target
- [ ] `fastlane lint` (repo root) passes; no new warnings
- [ ] Accessibility checked (VoiceOver labels, Dynamic Type, contrast)
- [ ] Privacy manifest still accurate; no new tracking or third-party SDKs
- [ ] Cross-target behaviour and `specs/glossary.md` are consistent across targets, or n/a
- [ ] Branch follows `<type>/<optional-spec-id->kebab-name` (`.claude/rules/branches.md`)
- [ ] Commits follow `type(scope): [ABC] summary`, one logical change each, with no AI attribution trailers
- [ ] Ran the `codebase-sync` skill (`CLAUDE.md`, skills current)
