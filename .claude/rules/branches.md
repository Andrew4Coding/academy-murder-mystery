# Branch naming

Checked by `scripts/check-branch-name.sh`. The script runs from `.githooks/pre-push` and in CI on every PR.

## Format

```
<type>/<optional-spec-id->lowercase-kebab-case
```

- **type**: the same words as commit types: `feature` `fix` `refactor` `chore` `docs` `test` `perf` `build` `ci`
- **release / hotfix**: `release/<app>-<version>`, `hotfix/<app>-<version>`, where dots are allowed (`hotfix/ios-0.2.1`). `staging` is the normal release candidate, so `release/` is only for an exceptional cut.
- **long-lived**: `main`, `staging`, `dev` (see below)
- **spec id**: optional, the 4-digit feature spec number, when the branch implements one: `feature/0003-level-picker`
- lowercase letters, digits and single hyphens only; max 60 characters
- name it after the outcome, not the person or the ticket tool

| Good | Bad |
|---|---|
| `feature/level-picker` | `Feature/LevelPicker` (case) |
| `feature/0003-level-picker` | `feature/level_picker` (underscore) |
| `fix/home-title-truncation` | `andrew/stuff` (no type) |
| `refactor/single-xcode-project` | `feat/level-picker` (use `feature`) |
| `hotfix/ios-0.2.1` | `feature/level--picker` (double hyphen) |

## Long-lived branches

| Branch | Purpose | Gets changes from | CI |
|---|---|---|---|
| `dev` | integration of finished features | feature PRs (squash) | branch name, commits, lint |
| `staging` | release candidate, QA and TestFlight | `dev` promotion PR (merge commit) | branch name, commits, lint |
| `main` | released code | `staging` promotion PR (merge commit), `hotfix/*` PRs | everything, including both macOS build and test jobs |

`dev` and `staging` don't run the build and test jobs. A broken build is first caught when `staging` is promoted to `main`, so build and test locally before opening a feature PR.

## Flow

1. `git switch dev && git pull`
2. `git switch -c feature/<name>`, then run `scripts/check-branch-name.sh` to check the name
3. Microcommit on the branch (`.claude/rules/commits.md`)
4. Push, then open a PR into **`dev`** with the template filled in. **Squash** merge it.
5. Promote: PR `dev` → `staging`, then `staging` → `main`. Use a **merge commit** (not squash) so all three branches share history and later promotions stay conflict-free.
6. Hotfix: branch `hotfix/<app>-<version>` from `main` and PR it into `main`. Then merge `main` back into `staging` and `dev`.
7. Delete feature branches after merge. Never delete `dev`, `staging` or `main`.

`main` only changes through PRs. `pre-push` blocks direct pushes to an existing remote `main`; bypass that only with `ALLOW_MAIN_PUSH=1`, and only when the user explicitly asks. Direct pushes to `dev` and `staging` are allowed but should be rare; prefer PRs.

## For the agent

- Before the first commit of a task, if you're on `main`, `staging` or `dev`, create a branch from an up-to-date `dev` that follows this format (hotfixes branch from `main`). Derive the slug from the spec title or the task.
- If you're already on a correctly named branch for this task, stay on it. Never rename a branch the user created without asking.
- Never push unless the user asks. Open feature PRs against `dev`, not `main`.
