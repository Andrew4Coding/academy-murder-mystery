#!/usr/bin/env bash
# The baseline is a content fingerprint, not a commit SHA: squash merges and rebases rewrite
# commits, so a SHA recorded on a feature branch is unreachable from main afterwards.
# Written for macOS's stock bash 3.2 (no mapfile, no empty "${array[@]}" under set -u).
set -eo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

state_file=".claude/sync-state"
paths=()
for path in Shared iOS Admin Tests project.yml fastlane/Fastfile; do
  [[ -e "$path" ]] && paths+=("$path")
done

if [[ ${#paths[@]} -eq 0 ]]; then
  echo "sync-state: none of the watched paths exist" >&2
  exit 2
fi

fingerprint() {
  local tmp tree
  tmp="$(mktemp -d)"
  GIT_INDEX_FILE="$tmp/index" git read-tree HEAD
  GIT_INDEX_FILE="$tmp/index" git add -A -- "${paths[@]}"
  tree="$(GIT_INDEX_FILE="$tmp/index" git write-tree)"
  rm -rf "$tmp"
  git ls-tree "$tree" -- "${paths[@]}" | git hash-object --stdin
}

recorded() {
  tr -d '[:space:]' 2>/dev/null < "$state_file" || true
}

changed() {
  local base
  base="$(git log -1 --format=%H -- "$state_file")"
  {
    if [[ -n "$base" ]]; then
      git diff --name-only "$base" -- "${paths[@]}"
    else
      git ls-files -- "${paths[@]}"
    fi
    git ls-files --others --exclude-standard -- "${paths[@]}"
  } | sort -u
}

case "$1" in
  fingerprint) fingerprint ;;
  recorded) recorded ;;
  in-sync) [[ "$(recorded)" == "$(fingerprint)" ]] ;;
  changed) changed ;;
  record) fingerprint > "$state_file" && cat "$state_file" ;;
  *)
    echo "usage: $0 fingerprint|recorded|in-sync|changed|record" >&2
    exit 2
    ;;
esac
