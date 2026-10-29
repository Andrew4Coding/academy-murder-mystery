#!/usr/bin/env bash
# One-shot TestFlight CI setup: validates fastlane/.env, optionally creates the apps in
# App Store Connect, and uploads the secrets the Beta workflow needs to GitHub.
# Signing is Xcode automatic signing driven by the ASC API key, so there are no certificates to manage.
#
#   scripts/setup-ci.sh --dry-run        show what would happen, change nothing
#   scripts/setup-ci.sh                  upload secrets
#   scripts/setup-ci.sh --create-apps    also register bundle IDs and ASC apps (Apple ID login, 2FA)
#   scripts/setup-ci.sh --trigger        also dispatch the Beta workflow afterwards
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

DRY_RUN=0 CREATE_APPS=0 TRIGGER=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --create-apps) CREATE_APPS=1 ;;
    --trigger) TRIGGER=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

ENV_FILE=fastlane/.env
WORKFLOW=.github/workflows/beta.yml

fail() { echo "error: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

step "Preflight"
command -v gh >/dev/null || fail "gh is not installed (brew install gh)"
gh auth status >/dev/null 2>&1 || fail "gh is not logged in (gh auth login)"
[ -f "$ENV_FILE" ] || fail "$ENV_FILE not found (see fastlane/.env.default)"
[ -f "$WORKFLOW" ] || fail "$WORKFLOW not found"
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner) || fail "cannot resolve the GitHub repo"
echo "repo: $REPO"

set -a
# shellcheck disable=SC1090
. "./$ENV_FILE"
set +a

for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_CONTENT; do
  [ -n "${!var:-}" ] || fail "$var is missing in $ENV_FILE"
done
echo "ASC key id: $ASC_KEY_ID"

case "$ASC_KEY_CONTENT" in
  *BEGIN*PRIVATE\ KEY*END*PRIVATE\ KEY*) echo "ASC_KEY_CONTENT: raw .p8" ;;
  *BEGIN*) fail "ASC_KEY_CONTENT looks truncated: BEGIN without END (is the .p8 pasted completely and quoted?)" ;;
  *) echo "ASC_KEY_CONTENT: base64" ;;
esac

if [ "$CREATE_APPS" = 1 ]; then
  step "Creating apps in App Store Connect"
  [ -n "${FASTLANE_APPLE_ID:-}" ] || fail "set FASTLANE_APPLE_ID in $ENV_FILE (and FASTLANE_ITC_TEAM_ID if you have several teams)"
  if [ "$DRY_RUN" = 1 ]; then echo "would run: bundle exec fastlane create_apps"
  else bundle exec fastlane create_apps; fi
fi

step "GitHub secrets on $REPO"
set_secret() {
  local name=$1 value=$2
  if [ "$DRY_RUN" = 1 ]; then echo "would set $name"
  else printf '%s' "$value" | gh secret set "$name" --repo "$REPO" --body - >/dev/null && echo "set $name"; fi
}
set_secret ASC_KEY_ID "$ASC_KEY_ID"
set_secret ASC_ISSUER_ID "$ASC_ISSUER_ID"
set_secret ASC_KEY_CONTENT "$ASC_KEY_CONTENT"

if [ "$TRIGGER" = 1 ]; then
  step "Dispatching Beta"
  if [ "$DRY_RUN" = 1 ]; then echo "would run: gh workflow run beta.yml --ref staging"
  else gh workflow run beta.yml --repo "$REPO" --ref staging; fi
fi

step "Done"
cat <<MSG
Still manual, once:
  - the Beta workflow file must be on the default branch before workflow_dispatch works
  - each app needs its ASC record first (--create-apps, or create it in App Store Connect)
  - then push or merge to staging; CI builds iOS, Mac Admin and iPad Admin in parallel
MSG
