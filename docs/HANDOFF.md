# Handoff: Money Matters

**Status:** MVP skeleton **built** (2026-05-29). Production feature pass **complete** (2026-05-31): false-positive hardening, per-source dashboard, real Firestore-backed categories, LLM classify Cloud Function + FCM trigger, and in-app "Needs your input" inbox. Not deployed or device-tested by agent.

**Selected direction:** S1 Cloud-handoff-first — Shortcuts POST → Firebase `ingestSms` → Flutter drain → rules parse → (LLM gate for ambiguous) → ledger UI + in-app classify.

---

## 2026-05-31 production pass

- **False positives fixed** — `rules_parser.dart` rejects loan/EMI/min-due/balance-only marketing even when an amount + credit verb is present (the ₹6,00,130 loan-offer bug). Requires a real debit/credit verb + account/card/UPI context.
- **Unmatched bucket** — transactions matching no saved bank/card are flagged `unmatched`, **excluded from dashboard totals**, and shown in their own bucket + the inbox.
- **Per-source dashboard** — spend grouped per bank/card; tap a source → its transactions → full detail with reclassify.
- **Categories** — persisted to `users/{uid}/categories` (seeded defaults + user merchant rules); replaced the in-memory list.
- **LLM classify** — `classifyTransaction` callable CF (Gemini, `asia-south1`, nodejs22) categorizes only uncategorized/ambiguous spends. Missing `GEMINI_API_KEY` → `needsConfig` fallback, no crash.
- **Push + in-app fallback** — `FcmService` registers tokens; `notifyClassification` CF pushes on need. Real APNs needs a paid Apple account, so the **in-app inbox/badge works now without push**.

### USER ACTIONS required to fully enable

1. **Gemini key:** `cd firebase/functions && firebase functions:secrets:set GEMINI_API_KEY` (Google AI Studio key). Until set, LLM returns `needsConfig` and the app uses the in-app inbox.
2. **Deploy functions:** `firebase deploy --only functions` (adds `classifyTransaction` + `notifyClassification`; Blaze plan required).
3. **Real push (optional):** a **paid Apple Developer account** + APNs key in Firebase to deliver classify notifications. The in-app inbox is the working fallback on a free personal team.

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

- Set `GEMINI_API_KEY` + deploy the two new functions (see USER ACTIONS above)
- Redacted real SMS samples to expand rules beyond HDFC/ICICI/Federal templates
- Category management UI (add/rename/delete) — currently seeded defaults + implicit merchant-rule learning
- Paid Apple account → enable real APNs push delivery for classify prompts

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
