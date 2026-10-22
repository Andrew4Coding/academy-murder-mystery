#!/usr/bin/env bash
set -euo pipefail

name="${1:-$(git rev-parse --abbrev-ref HEAD)}"

case "$name" in
  main | staging | dev) exit 0 ;;
esac

types='feature|fix|refactor|chore|docs|test|perf|build|ci'
slug='[a-z0-9]+(-[a-z0-9]+)*'
work="^($types)/([0-9]{4}-)?$slug$"
release='^(release|hotfix)/[a-z0-9]+([.-][a-z0-9]+)*$'

if [[ ${#name} -le 60 && ( "$name" =~ $work || "$name" =~ $release ) ]]; then
  exit 0
fi

{
  echo "branch name '$name' does not follow the convention"
  echo "  format:   <type>/<optional-spec-id->lowercase-kebab-case   (max 60 chars)"
  echo "  long-lived branches: main, staging, dev"
  echo "  types:    feature fix refactor chore docs test perf build ci, plus release hotfix"
  echo "  examples: feature/level-picker  feature/0003-level-picker  fix/home-title-truncation"
  echo "            release/ios-0.2.0  hotfix/ios-0.1.1"
  echo "  rename:   git branch -m <new-name>"
  echo "  see .claude/rules/branches.md"
} >&2
exit 1
