# Contributing to Money Matters

Thanks for your interest in helping improve Money Matters — a personal iOS ledger that turns bank SMS into categorized spending insights.

## Before you start

- Read the [README](README.md) for project overview and setup.
- For architecture and module boundaries, see [`docs/plans/money-matters-build-plan.md`](docs/plans/money-matters-build-plan.md).
- For Firestore schema, see [`docs/FIRESTORE-DATA-MODEL.md`](docs/FIRESTORE-DATA-MODEL.md).

## Bugs and feature ideas

- **Bugs** — [bug report template](.github/ISSUE_TEMPLATE/bug_report.md) or [open an issue](https://github.com/amrit-dash/Money-Matters/issues/new/choose).
- **Features** — [feature request template](.github/ISSUE_TEMPLATE/feature_request.md).
- **Questions** — [GitHub Discussions](https://github.com/amrit-dash/Money-Matters/discussions) or an issue with a **question** label.

All participants are expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

No issue required for small typo fixes, but it's helpful for anything non-trivial.

## Development setup

1. **Clone and install dependencies**

   ```bash
   git clone https://github.com/amrit-dash/Money-Matters.git
   cd Money-Matters
   flutter pub get
   ```

2. **Firebase (optional for UI-only work)**

   Full device ingest requires Firebase Auth, Firestore, and Cloud Functions. See [`docs/SETUP-IPHONE.md`](docs/SETUP-IPHONE.md) and `firebase/README.md`. `GoogleService-Info.plist` is not committed — you'll need your own Firebase project or a shared dev setup.

3. **Run the app**

   ```bash
   open ios/Runner.xcworkspace   # set Team + Bundle ID, then Run from Xcode
   ```

   Money Matters targets **iOS only** (Shortcuts-based SMS ingest). A physical iPhone is needed for end-to-end testing.

4. **Verify before submitting**

   ```bash
   flutter analyze --fatal-infos
   flutter test
   ```

   CI runs these on every push to `main` (see `.github/workflows/ios-ipa.yml`).

## Code style

Match what's already in the repo:

- **Linting** — `package:flutter_lints` via [`analysis_options.yaml`](analysis_options.yaml). Fix analyzer warnings; CI treats infos as fatal (`--fatal-infos`).
- **Formatting** — run `dart format .` before committing. Keep diffs focused.
- **Layout** — feature screens in `lib/features/`, shared logic in `lib/services/`, domain types in `lib/models/`, parsing in `lib/parse/`, ingest in `lib/ingest/`. Mirror structure under `test/`.
- **Naming** — `snake_case` files, `PascalCase` types, `camelCase` members. Prefer dependency injection and small, testable services (see `AppServices`).
- **Tests** — add or update tests in `test/` for behavior you change, especially parsing, models, and services. Use `flutter_test` and `package:money_matters/...` imports.
- **Scope** — keep PRs small and focused. Don't mix unrelated refactors with feature work.

For Cloud Functions changes under `firebase/functions/`, also run `npm ci && npm run build` (and `npm run lint` if you touch TypeScript).

## Pull request process

1. **Fork** the repo on GitHub.
2. **Branch** from `main`. Use a short, descriptive name (e.g. `feat/dashboard-filters`, `fix/parse-upi-sms`).
3. **Commit** with [Conventional Commits](https://www.conventionalcommits.org/) style, matching existing history:
   - `feat(scope): add …`
   - `fix(scope): …`
   - `docs: …`
   - `refactor(scope): …`
4. **Test** — `flutter analyze --fatal-infos` and `flutter test` must pass.
5. **Open a PR** against `main` with:
   - What changed and why
   - How you tested it
   - Screenshots for UI changes (if applicable)

Maintainers review when they can. Be patient — this is a personal side project, not a corporate sprint.

Follow the [pull request template](.github/pull_request_template.md) when opening PRs.

## Institutional knowledge

Documented fixes and patterns live in [`docs/solutions/`](docs/solutions/) (YAML frontmatter: `module`, `tags`, `problem_type`). Search there before debugging areas that already have entries.

## Questions?

Open an issue with the **question** label, start a [Discussion](https://github.com/amrit-dash/Money-Matters/discussions), or comment on an existing thread. Happy to help you find a good first contribution.
