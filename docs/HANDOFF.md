# Handoff: Money Matters

**Status:** MVP skeleton **built** (2026-05-29). Plan, Firebase backend, Flutter iOS app, parser tests, UI screens, and Shortcuts docs are in repo. Not deployed or device-tested by agent.

**Selected direction:** S1 Cloud-handoff-first — Shortcuts POST → Firebase `ingestSms` → Flutter drain → rules parse → ledger UI.

---

## Built artifacts

| Area | Path | Notes |
|------|------|-------|
| Build plan | `docs/plans/money-matters-build-plan.md` | Architecture, parallel ownership, verification |
| Firebase | `firebase/functions/src/ingestSms.ts`, `firestore.rules`, `firebase/README.md` | Idempotency + Bearer auth |
| Flutter app | `lib/`, `ios/`, `pubspec.yaml` | iOS-only target |
| Parser tests | `test/parse/rules_parser_test.dart` | AE3, AE4, AE8 style fixtures |
| Shortcuts docs | `docs/shortcuts/setup.md`, `payload-examples.json` | Automation A/B |
| Integration | `lib/services/ingest_parse_pipeline.dart` | Drain → parse → Firestore + SQLite |

---

## User actions before first real ingest

1. Create Firebase project; run `flutterfire configure`
2. Add `GoogleService-Info.plist` to `ios/Runner/`
3. `firebase deploy --only functions,firestore:rules`
4. Register device ingest token (onboarding / Firestore `device_tokens`)
5. Install Shortcuts automations per `docs/shortcuts/setup.md`
6. Sideload app via Xcode to physical iPhone

---

## Next implementation passes

- Wire dashboard/review/recovery to `LocalDatabase` + Firestore (currently mock repositories in features)
- FCM handler for unmatched/ambiguous transactions
- Payment sources persist to Firestore from onboarding
- Firestore composite indexes if drain queries fail
- Redacted real SMS samples to expand rules beyond HDFC/ICICI templates

---

## Locked constraints (unchanged)

- iOS only, personal sideload
- Stock iOS + Shortcuts — no inbox API
- One ingest per SMS; idempotent on exact duplicate only
- Keyword-filtered automations
- Cloud POST OK for raw SMS (personal Firebase)

---

## References

- Requirements: `docs/brainstorms/money-matters-sms-ledger-requirements.md`
- Ideation: `docs/ideation/2026-05-29-money-matters-ios-shortcuts-ideation.md`
- Setup: root `README.md`
