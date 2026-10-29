#!/usr/bin/env bash
# One-shot TestFlight CI setup: validates fastlane/.env, optionally creates the apps and signing
# assets, and uploads the secrets the Beta workflow needs to GitHub.
#
#   scripts/setup-ci.sh --dry-run        show what would happen, change nothing
#   scripts/setup-ci.sh                  upload secrets
#   scripts/setup-ci.sh --create-apps    also register bundle IDs and ASC apps (Apple ID login, 2FA)
#   scripts/setup-ci.sh --signing        also create certs and profiles in the match repo
#   scripts/setup-ci.sh --trigger        also dispatch the Beta workflow afterwards
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

DRY_RUN=0 CREATE_APPS=0 SIGNING=0 TRIGGER=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --create-apps) CREATE_APPS=1 ;;
    --signing) SIGNING=1 ;;
    --trigger) TRIGGER=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

ENV_FILE=fastlane/.env
WORKFLOW=.github/workflows/beta.yml
LANES=("ios signing" "mac signing" "ios adminpad_signing")

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

for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_CONTENT MATCH_PASSWORD MATCH_GIT_URL; do
  [ -n "${!var:-}" ] || fail "$var is missing in $ENV_FILE"
done
echo "ASC key id: $ASC_KEY_ID"

case "$ASC_KEY_CONTENT" in
  *BEGIN*PRIVATE\ KEY*END*PRIVATE\ KEY*) echo "ASC_KEY_CONTENT: raw .p8" ;;
  *BEGIN*) fail "ASC_KEY_CONTENT looks truncated: BEGIN without END (is the .p8 pasted completely and quoted?)" ;;
  *) echo "ASC_KEY_CONTENT: base64" ;;
esac

CI_MATCH_URL=$MATCH_GIT_URL
CI_MATCH_AUTH=${MATCH_GIT_BASIC_AUTHORIZATION:-}
if [ -z "$CI_MATCH_AUTH" ]; then
  case "$MATCH_GIT_URL" in
    git@github.com:*)
      CI_MATCH_URL="https://github.com/${MATCH_GIT_URL#git@github.com:}"
      echo "MATCH_GIT_URL is SSH; CI needs https + a token, so the secret becomes: $CI_MATCH_URL" ;;
  esac
  case "$CI_MATCH_URL" in
    https://*)
      echo "MATCH_GIT_BASIC_AUTHORIZATION is not set. CI needs a GitHub PAT with read access to the certificates repo."
      if [ "$DRY_RUN" = 0 ]; then
        read -r -p "GitHub username for the PAT (blank to skip): " pat_user
        if [ -n "$pat_user" ]; then
          read -r -s -p "PAT: " pat_token; echo
          CI_MATCH_AUTH=$(printf '%s:%s' "$pat_user" "$pat_token" | base64 | tr -d '\n')
        fi
      fi ;;
  esac
fi
[ -n "$CI_MATCH_AUTH" ] || echo "warning: no MATCH_GIT_BASIC_AUTHORIZATION; CI cannot clone a private certificates repo without it"

if [ "$CREATE_APPS" = 1 ]; then
  step "Creating apps in App Store Connect"
  [ -n "${FASTLANE_APPLE_ID:-}" ] || fail "set FASTLANE_APPLE_ID in $ENV_FILE (and FASTLANE_ITC_TEAM_ID if you have several teams)"
  if [ "$DRY_RUN" = 1 ]; then echo "would run: bundle exec fastlane create_apps"
  else bundle exec fastlane create_apps; fi
fi

if [ "$SIGNING" = 1 ]; then
  for lane in "${LANES[@]}"; do
    step "Signing assets: fastlane $lane"
    if [ "$DRY_RUN" = 1 ]; then echo "would run: bundle exec fastlane $lane"
    else bundle exec fastlane $lane; fi
  done
fi

step "GitHub secrets on $REPO"
set_secret() {
  local name=$1 value=$2
  [ -n "$value" ] || return 0
  if [ "$DRY_RUN" = 1 ]; then echo "would set $name"
  else printf '%s' "$value" | gh secret set "$name" --repo "$REPO" --body - >/dev/null && echo "set $name"; fi
}
set_secret ASC_KEY_ID "$ASC_KEY_ID"
set_secret ASC_ISSUER_ID "$ASC_ISSUER_ID"
set_secret ASC_KEY_CONTENT "$ASC_KEY_CONTENT"
set_secret MATCH_PASSWORD "$MATCH_PASSWORD"
set_secret MATCH_GIT_URL "$CI_MATCH_URL"
set_secret MATCH_GIT_BASIC_AUTHORIZATION "$CI_MATCH_AUTH"

if [ "$TRIGGER" = 1 ]; then
  step "Dispatching Beta"
  if [ "$DRY_RUN" = 1 ]; then echo "would run: gh workflow run beta.yml --ref staging"
  else gh workflow run beta.yml --repo "$REPO" --ref staging; fi
fi

step "Done"
cat <<MSG
Still manual, once:
  - the Beta workflow file must be on the default branch before workflow_dispatch works
  - first build of each app needs its ASC app record (--create-apps) and a match profile (--signing)
  - then push or merge to staging; CI builds iOS, Mac Admin and iPad Admin in parallel
MSG
