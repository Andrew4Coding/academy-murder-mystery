---
name: commit
description: Turn working-tree changes into convention-compliant microcommits ("feat(scope): [ABC] summary") on a correctly named branch. Use whenever committing in this repo, after each logical change rather than once at the end.
---

# Microcommit

The rules are in `.claude/rules/commits.md` and `.claude/rules/branches.md`. This is the procedure.

1. **Branch.** Check `git branch --show-current`. If you're on `main`, `staging` or `dev`, create a branch from an up-to-date `dev` first: `git switch -c <type>/<optional-spec-id->kebab-name`, then run `scripts/check-branch-name.sh`.
2. **Code.** Get the committer code with `scripts/commit-code.sh`. If that fails, ask the user for their 3-letter code and run `git config murdermystery.code ABC`.
3. **Group.** Run `git status --short` and `git diff`. Group the hunks by concern: one feature step, one fix, one refactor, one test addition, or one docs update.
   - `Shared/` changes affect every target. Keep them in their own commit, separate from target-folder changes (`iOS/`, `Admin/`).
4. **Scope.** Pick it by where the change lives:
   - `shared` or a target slug (`ios`, `admin`) for target-wide changes
   - a feature or area for narrower ones (`home`, `schema`, `fastlane`, `specs`, `claude`)
5. **Commit each group**, in dependency order (protocols before implementations, model before view model before view):
   - Stage it with `git add <paths>`, or `git add -p <file>` to split a file.
   - If it contains Swift or `project.yml`, run `xcodegen generate` and build every scheme it affects (see CLAUDE.md Commands). A `Shared/` change builds both schemes. If the group doesn't build alone, merge it into the group it depends on.
   - Commit with `git commit -m "<type>(<scope>): [ABC] <summary>"`. Add a body only to explain *why*.
6. **Never** pass `--no-verify`, and never add `Co-Authored-By` or any AI attribution. If the hook rejects a message, fix the message.
7. After the code commits, run the `codebase-sync` skill. Never push unless the user asks.
