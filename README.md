# Murder Mystery

| Target | Platform | Bundle ID |
|---|---|---|
| `MurderMysteryiOS` | iOS 26.0+ (iPhone and iPad) | `com.andrew4coding.MurderMystery` |
| `MurderMysteryAdmin` | macOS 26.0+ | `com.andrew4coding.MurderMystery.admin` |

## Setup

```bash
scripts/bootstrap.sh
open MurderMystery.xcodeproj
```

`bootstrap.sh` turns on the git hooks (`core.hooksPath .githooks`), installs the tools from `Brewfile` and `Gemfile`, and generates `MurderMystery.xcodeproj` from `project.yml`.
Your committer code defaults to the first 3 letters of `git config user.name`. To use your own: `git config murdermystery.code ABC`.

## How we work

- **Specs first**: see [specs/README.md](specs/README.md).
- **Branches**: `feature/…`, `fix/…`, `chore/…`, optionally with a spec id (`feature/0002-settings`). Branch from `dev`. See [.claude/rules/branches.md](.claude/rules/branches.md).
- **Commits**: `feat(scope): [ABC] lowercase imperative summary`, one logical change each. See [.claude/rules/commits.md](.claude/rules/commits.md).
- **PRs**:
  - Feature PRs go into `dev` (squash merge). Promote `dev` → `staging` → `main` with merge commits.
  - Fill in the [PR template](.github/pull_request_template.md).
  - CI runs branch, commit and lint checks on every branch. The build and test jobs run only for `main`.
  - Direct pushes to `main` are blocked.
- **Changelog**: [CHANGELOG.md](CHANGELOG.md), with a section per target.

## Lanes

| Lane | What it does |
|---|---|
| `lint` | SwiftLint and SwiftFormat over the whole repo |
| `generate` | Regenerate `MurderMystery.xcodeproj` |
| `bump app:<ios|admin> type:patch\|minor\|major` | Bump one target's `MARKETING_VERSION` (in its `.xcconfig`) |
| `ios test` / `ios signing` / `ios beta` / `ios release` | MurderMysteryiOS: tests on iPhone 17 Pro, signing assets, TestFlight, App Store (`submit_for_review:true` to submit) |
| `mac test` / `mac signing` / `mac beta` / `mac release` | MurderMysteryAdmin: tests on macOS, signing assets, TestFlight, App Store |

## Release setup (one time)

1. Create an app record in App Store Connect for each bundle ID above.
2. Create an App Store Connect API key, and put `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_CONTENT` (the base64 of the `.p8`) in `fastlane/.env`. See `fastlane/.env.default`.
3. Create a private certificates repo, then set `MATCH_GIT_URL` and `MATCH_PASSWORD`.
4. Run each target's `signing` lane once.
5. Fill in `fastlane/metadata/<slug>` and add the app icons.
6. Ship with each target's `beta` lane.
