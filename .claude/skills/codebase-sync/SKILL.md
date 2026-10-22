---
name: codebase-sync
description: Keep the agent's knowledge of this codebase current. Run after any change to Shared/, iOS/, Admin/, Tests/, project.yml or fastlane/Fastfile, and whenever the Stop hook reports "Source changed since the last codebase sync". Updates CLAUDE.md, CHANGELOG.md, feature spec status and skills, then records a new sync baseline.
---

# Codebase sync

The Stop hook (`.claude/hooks/stop-sync-check.sh`) compares a fingerprint of the watched files (`Shared/`, `iOS/`, `Admin/`, `Tests/`, `project.yml`, `fastlane/Fastfile`) with the one recorded in `.claude/sync-state`.
The fingerprint is a git tree hash of the files' *contents*, including uncommitted and untracked files. Squash merges and rebases rewrite commit SHAs but not contents, so the baseline stays valid after a PR is squashed. `.claude/hooks/sync-state.sh` computes and records it.

This skill reviews what changed since the last baseline and makes the repo's own docs and skills match the code.

## 0. Commit code first

Code changes must already be committed as microcommits (see the `commit` skill). Sync commits are `docs:` or `chore(claude):` only, and never contain source.

## 1. Collect the delta

```bash
base="$(git log -1 --format=%H -- .claude/sync-state)"   # last commit that recorded a baseline
.claude/hooks/sync-state.sh changed                        # watched files changed since then, plus untracked ones
git log --oneline "$base"..HEAD
git diff "$base" -- Shared iOS Admin Tests project.yml fastlane/Fastfile
```

If no commit has touched `.claude/sync-state` yet, treat the whole tree as new: read `CLAUDE.md`, `project.yml`, and every folder under `Shared/` and the target folders (`iOS/`, `Admin/`).

## 2. Update only what the delta made stale

| Target | Update when | How |
|---|---|---|
| `CLAUDE.md` | folders, targets, commands, lanes, architecture rules or dependencies changed, or you hit a non-obvious gotcha | Edit the Layout / Targets / Commands / Gotchas sections. Keep it a map, not a history. |
| `<TargetDir>/CLAUDE.md` | a gotcha applies to only one target | Create one only when there's something target-specific to say. Keep it short. |
| `CHANGELOG.md` | user-visible behaviour changed | Add one line under `## [Unreleased]`, in the target's subsection and the right group (Added / Changed / Fixed / Removed). If a `Shared/` change is user-visible, list it under every target. Skip refactors and tooling. |
| `specs/apps/<slug>/features/*.md`, `specs/features/*.md` | an acceptance criterion is now met, or scope moved | Tick `- [x]`, set `status:`, and add an Implementation notes bullet. Never rewrite requirements to match the code. If they diverged, add an Open Question and tell the user. |
| `specs/constraints.md`, `specs/apps/<slug>/constraints.md`, `specs/decisions/` | a new rule or architectural choice was made | Write an ADR from `specs/templates/adr.md`, then update the constraints. |
| `specs/glossary.md` | a new domain term appeared | Edit in place. |
| `.claude/skills/*` | the same multi-step pattern was done twice, or a skill's steps are now wrong | Fix the existing skill first. Name a new skill by its task, and keep each under ~80 lines. |

Don't touch anything the delta didn't make stale. No speculative docs.

## 3. Record the baseline and commit

```bash
.claude/hooks/sync-state.sh record     # writes the content fingerprint of the watched files
```

Commit as separate microcommits, for example:

```
docs: [ABC] sync claude.md with settings screen
docs(specs): [ABC] mark 0002-settings as implemented
docs: [ABC] add changelog entry for settings
chore(claude): [ABC] record codebase sync baseline
```

`sync-state` goes in the last commit. Record it after the source is committed. Docs commits don't touch watched files, so they don't change the fingerprint. Never hand-edit `sync-state`: run `record`, and run it again if source changes afterwards.

## 4. Report

Tell the user in two or three lines what you updated and anything that needs their decision.
