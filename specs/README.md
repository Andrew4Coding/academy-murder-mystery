# Specs

This folder is the source of truth for **what** we build and **why**; the code answers *how*.
Agents and humans both read these before writing code, and update them in the same PR as the code.

## Layout

```
specs/
  product.md            vision, problem, personas, how the targets fit together
  constraints.md        rules every target follows (tech, privacy, accessibility, quality gates)
  glossary.md           domain vocabulary, also used for code names
  roadmap.md            Now / Next / Later
  decisions/            Architecture Decision Records (NNNN-title.md), append-only
  templates/            feature.md, adr.md: copy these, never edit them in place for a feature
  features/             specs that span every target (app: all)
  apps/
    ios/       MurderMysteryiOS (iOS): product.md, constraints.md, features/
    admin/       MurderMysteryAdmin (macOS): product.md, constraints.md, features/
```

A target's `constraints.md` adds to the root one and never contradicts it. To change a root rule, write an ADR.

## Flow

```
idea → feature spec (draft) → review → approved → in-progress → implemented
                            ↘ decisions/NNNN-*.md when an architectural choice is made
```

1. **Write** a spec from `templates/feature.md`: in `apps/<slug>/features/` for one target, or in `features/` with `app: all` for every target. Acceptance criteria must be testable (Given/When/Then).
2. **Check** it against `constraints.md`, the target's `constraints.md`, and `product.md`. Conflicts go under Open Questions; never resolve them silently.
3. **Approve**: a human sets `status: approved`. No code before this.
4. **Build** on a `feature/NNNN-name` branch cut from `dev`, in microcommits. Each acceptance criterion maps to at least one test.
5. **Sync**: the `codebase-sync` skill ticks the criteria, sets `status: implemented`, and updates `CHANGELOG.md`.

## Numbering

Feature numbers are **global** across the repo, so "spec 0007" is never ambiguous in a PR. ADRs have their own sequence. To find the last number used:

```bash
ls specs/features specs/apps/*/features | grep -oE '^[0-9]{4}' | sort | tail -1
```

## Status values

`draft` · `approved` · `in-progress` · `implemented` · `deprecated`
