# Commit convention

Enforced by `.githooks/commit-msg` (enable with `scripts/bootstrap.sh` or `git config core.hooksPath .githooks`).

## Format

```
<type>(<optional-scope>)!?: [ABC] <summary>

<optional body: why, not what>
```

- **type**: `feat` `fix` `refactor` `chore` `docs` `test` `style` `perf` `build` `ci` `revert`
- **scope**: optional, lowercase kebab-case. Use `shared` or a target slug (`ios`, `admin`) for target-wide changes, and a feature or area for narrower ones (`home`, `schema`, `fastlane`, `specs`, `claude`). Keep `Shared/` changes and target-only changes in separate commits.
- **`!`**: breaking change (schema migration, removed public behaviour)
- **[ABC]**: the committer code, from `scripts/commit-code.sh`:
  `git config moonfall.code` if set, otherwise the first 3 letters of the first word of `git config user.name`, uppercased.
  The agent always commits as the human it works for, with that human's code. Never invent a code.
- **summary**: lowercase, imperative mood ("add", not "added"/"adds"), no trailing period, whole subject ≤ 72 chars.

## Never

- No `Co-Authored-By:` trailers of any kind, no "Generated with Claude Code" lines, no `noreply@anthropic.com`.
- No `--no-verify`. If the hook rejects a message, fix the message.
- No commits that mix unrelated concerns.

## Microcommits

One commit = one logical change that builds on its own. Split by concern, not by file count.

Good sequence for a new feature:

```
docs(specs): [AND] add 0002-level-picker spec
feat(level-picker): [AND] add level repository protocol and swiftdata store
feat(level-picker): [AND] add level picker view model
feat(level-picker): [AND] add level picker view
feat(level-picker): [AND] wire level picker into root navigation
test(level-picker): [AND] cover level picker view model states
docs: [AND] sync claude.md, changelog and spec status
```

Bad:

```
Added level picker and fixed stuff.          # no type, no code, past tense, period
feat: [AND] level picker + refactor + tests   # three concerns
feat: [AND] WIP                               # not a logical unit
```

Before each code commit: `xcodegen generate` (if files were added/moved) and a build of the scheme. Docs-only commits skip the build.
