# Agent instructions

Flutter iOS app — see [README.md](README.md) for product context, setup, and the docs index.

## Knowledge store

`docs/solutions/` — documented solutions to past problems (bugs, patterns, workflow), organized by category with YAML frontmatter (`module`, `tags`, `problem_type`). Relevant when implementing or debugging in documented areas.

## Key docs

| Path | Use |
|------|-----|
| `docs/HANDOFF.md` | Build status, icon/branding status, next steps |
| `docs/assets/app-icon/` | SVG masters (pending); see README there + `docs/app-icon-brief.md` |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | iOS home-screen icon PNGs (regenerate: `./scripts/export_app_icons.sh`) |
| `docs/plans/money-matters-build-plan.md` | Architecture and file ownership |
| `firebase/README.md` | Backend deploy and function tests |

Run `./scripts/verify_setup.sh`, `flutter analyze`, and `flutter test` before proposing changes.
