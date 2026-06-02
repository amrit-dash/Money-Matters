# Agent instructions

Flutter iOS app — see [README.md](README.md) for product context, setup, and the docs index.

## Knowledge store

`docs/solutions/` — documented solutions to past problems (bugs, patterns, workflow), organized by category with YAML frontmatter (`module`, `tags`, `problem_type`). Relevant when implementing or debugging in documented areas.

## Key docs

| Path | Use |
|------|-----|
| `docs/HANDOFF.md` | Build status, icon/branding status, next steps |
| `docs/assets/app-icon-preview.png` | README/doc icon preview (from `assets/icons/concepts/concept_a.svg`) |
| `assets/icons/concepts/README.md` | App icon concepts; iOS export → `AppIcon.appiconset` |
| `docs/plans/money-matters-build-plan.md` | Architecture and file ownership |
| `firebase/README.md` | Backend deploy and function tests |

Run `./scripts/verify_setup.sh`, `flutter analyze`, and `flutter test` before proposing changes.
