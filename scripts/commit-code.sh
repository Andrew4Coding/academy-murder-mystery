#!/usr/bin/env bash
set -euo pipefail

code="$(git config --get murdermystery.code || true)"

if [[ -z "$code" ]]; then
  name="$(git config --get user.name || true)"
  letters="$(printf '%s' "$name" | tr -cd '[:alpha:]')"
  first="$(printf '%s' "$name" | awk '{print $1}' | tr -cd '[:alpha:]')"
  # Short first names ("Al") borrow letters from the rest of the name so every code stays three letters.
  if [[ ${#first} -ge 3 ]]; then code="${first:0:3}"; else code="${letters:0:3}"; fi
fi

code="$(printf '%s' "$code" | tr '[:lower:]' '[:upper:]')"

if [[ ! "$code" =~ ^[A-Z]{3}$ ]]; then
  echo "Cannot derive a 3-letter committer code. Set one: git config murdermystery.code ABC" >&2
  exit 1
fi

printf '%s\n' "$code"
