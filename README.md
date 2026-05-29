# Money Matters

Personal iOS ledger app that turns bank and wallet SMS into categorized spending insights. Built for sideload install (Xcode / Developer Mode), not the App Store.

**How it works:** iOS Shortcuts Personal Automations capture incoming financial SMS and POST them to a Firebase ingest queue. The Flutter app drains the queue on launch, parses transactions with rules-first logic, and surfaces weekly/monthly analytics.

**Status:** MVP skeleton built — see `docs/HANDOFF.md` and `docs/plans/money-matters-build-plan.md`.

## Get started on iPhone

**Primary onboarding:** [`docs/SETUP-GITHUB-ACTIONS.md`](docs/SETUP-GITHUB-ACTIONS.md) (IPA via GitHub Actions, no local Xcode) · [`docs/SETUP-IPHONE.md`](docs/SETUP-IPHONE.md) (local Xcode)

**Firebase project:** `money-matters-amrit`

Quick verify after setup:

```bash
./scripts/verify_setup.sh
./scripts/build_ipa.sh          # or Path A in SETUP-IPHONE.md (Xcode Run)
```

## Prerequisites

- Mac with Xcode 15+ and CocoaPods
- Flutter SDK 3.11+ (`flutter doctor`)
- **Paid Apple Developer account** recommended (free 7-day signing requires re-install weekly)
- iPhone with iOS 17+ and **Developer Mode** enabled
- Personal Firebase project (Auth, Firestore, Cloud Functions, FCM optional)

## Setup

See [`docs/SETUP-IPHONE.md`](docs/SETUP-IPHONE.md) for the full ordered checklist. Summary:

### 1. Firebase

```bash
cd firebase/functions
npm ci
npm run build
cd ../..
firebase login
firebase use --add   # select your project
firebase deploy --only functions,firestore:rules
```

Copy the deployed `ingestSms` URL from the deploy output. See `firebase/README.md` for curl test and device token setup.

### 2. Flutter + iOS

```bash
flutter pub get
dart pub global activate flutterfire_cli   # if needed
flutterfire configure   # generates lib/core/config/firebase_options.dart
```

Download **GoogleService-Info.plist** from Firebase Console → add to `ios/Runner/` (not committed).

```bash
open ios/Runner.xcworkspace
# Set your Team, Bundle ID com.moneymatters.money_matters
flutter build ios --no-codesign
```

Install on device via Xcode Run.

### 3. Shortcuts

Follow `docs/shortcuts/setup.md`. After onboarding, paste:

- **INGEST_URL** — Cloud Function URL
- **Bearer token** — device ingest token from app
- **deviceId** — from onboarding

Keyword filters: `debited`, `credited`, `INR`, `Rs`, `spent`, `payment`, `UPI`, `card`.

### 4. Verify

```bash
flutter analyze
flutter test
```

Manual: POST sample from `docs/shortcuts/payload-examples.json`, open app, check dashboard/recovery.

## Project layout

| Path | Purpose |
|------|---------|
| `lib/ingest/` | Firestore drain, URL scheme handler |
| `lib/parse/` | Rules parser, LLM gate stub |
| `lib/models/` | Domain models |
| `lib/features/` | Onboarding, dashboard, review, recovery |
| `lib/services/ingest_parse_pipeline.dart` | Drain → parse → persist |
| `firebase/functions/` | `ingestSms` Cloud Function |
| `docs/shortcuts/` | Automation setup + JSON examples |

## Docs

| Path | Purpose |
|------|---------|
| `docs/plans/money-matters-build-plan.md` | Architecture, file ownership, integration |
| `docs/brainstorms/money-matters-sms-ledger-requirements.md` | Product requirements |
| `docs/SETUP-IPHONE.md` | **Primary onboarding** — iPhone + Firebase + Shortcuts |
| `docs/HANDOFF.md` | Build status and next steps |
| `docs/ideation/2026-05-29-money-matters-ios-shortcuts-ideation.md` | Ideation survivors |

## User blockers

You must supply:

1. **Firebase project ID** — create at console.firebase.google.com
2. **GoogleService-Info.plist** — download, place in `ios/Runner/`
3. **flutterfire configure** — generates `firebase_options.dart`
4. **INGEST_URL + Bearer token** — register device token in Firestore via onboarding flow (see `firebase/README.md`)
5. **Physical iPhone** — Shortcuts Message automations do not run reliably in Simulator

## Platform constraints (stock iOS)

- No direct SMS inbox access from a sideloaded app
- Ingestion relies on user-installed Shortcuts automations
- Android, notification scraping, and jailbreak paths are out of scope
