#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

git config core.hooksPath .githooks
chmod +x .githooks/* scripts/*.sh .claude/hooks/*.sh

command -v brew >/dev/null && brew bundle --no-upgrade
bundle install

xcodegen generate

echo "Committer code: $(scripts/commit-code.sh)"
echo "Override with: git config murdermystery.code ABC"
