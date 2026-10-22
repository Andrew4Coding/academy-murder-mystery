#!/usr/bin/env bash
set -uo pipefail

input="$(cat)"

if printf '%s' "$input" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
state="$root/.claude/hooks/sync-state.sh"

"$state" in-sync 2>/dev/null && exit 0

changed="$("$state" changed 2>/dev/null)"
count="$(printf '%s' "$changed" | grep -c . || true)"
areas="$(printf '%s\n' "$changed" | grep . | cut -d/ -f1 | sort -u | tr '\n' ' ' | sed 's/ $//')"
detail="${areas:+ ($count files in: $areas)}"

printf '{"decision":"block","reason":"%s"}\n' "Source changed since the last codebase sync${detail}. Commit the code changes as microcommits, then run the codebase-sync skill to update CLAUDE.md, specs, CHANGELOG and skills, and record the baseline with .claude/hooks/sync-state.sh record."
