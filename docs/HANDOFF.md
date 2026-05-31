# Handoff: Money Matters

**Status:** MVP skeleton **built** (2026-05-29). Production feature pass **complete** (2026-05-31): false-positive hardening, per-source dashboard, real Firestore-backed categories, LLM classify Cloud Function + FCM trigger, and in-app "Needs your input" inbox. **`classifyTransaction` deployed live** on `money-matters-amrit` (2026-05-31); **`notifyClassification` optional** — Eventarc IAM may fail on first deploy (see `USER-FIX.md`); in-app Review inbox is primary. Not device-tested by agent.

**Selected direction:** S1 Cloud-handoff-first — Shortcuts POST → Firebase `ingestSms` → Flutter drain → rules parse → (LLM gate for ambiguous) → ledger UI + in-app classify.

---

## 2026-05-31 production pass

- **False positives fixed** — `rules_parser.dart` rejects loan/EMI/min-due/balance-only marketing even when an amount + credit verb is present (the ₹6,00,130 loan-offer bug). Requires a real debit/credit verb + account/card/UPI context.
- **Unmatched bucket** — transactions matching no saved bank/card are flagged `unmatched`, **excluded from dashboard totals**, and shown in their own bucket + the inbox. Drill-down uses the same `isUnmatched` rules as the dashboard (includes orphaned `payment_source_id` refs when an account was deleted).
- **Payment source matching** — rules-first: SMS **sender hints** (e.g. `FEDBNK-S`, `FEDSCP-S`) and bank name in body; optional LLM via `classifyTransaction` when still unmatched (requires `GEMINI_API_KEY` secret — no keys in the app).
- **Per-source dashboard** — spend grouped per bank/card; tap a source → its transactions → full detail with reclassify.
- **Categories** — persisted to `users/{uid}/categories` (seeded defaults + user merchant rules); replaced the in-memory list.
- **LLM classify** — `classifyTransaction` callable CF (Gemini `gemini-2.0-flash`, `asia-south1`, nodejs22) categorizes only uncategorized/ambiguous spends. Missing `GEMINI_API_KEY` → `needsConfig` fallback, no crash. Rules + manual classify work without any API key.
- **Push (optional) + in-app primary** — `FcmService` registers tokens; `notifyClassification` CF can push on need. **No paid Apple Developer account is required** for sideloaded IPA — the **in-app Review/classify inbox and badge are the primary path** and work on a free personal team. Real APNs push is optional and needs a paid Apple account.

### Payment source sender hints (recommended)

In **Accounts**, edit each bank/card and add comma-separated **SMS sender IDs** exactly as they appear on your phone (case-insensitive), for example:

| Account | Example sender hints |
|---------|---------------------|
| Federal Bank (UPI debits) | `FEDBNK-S` |
| Scapia Federal RuPay card | `FEDSCP-S` |
| HDFC | `VK-HDFCBK`, `HDFCBK` |

After saving hints, run **Recovery / re-sync** (or wait for the next ingest drain) so existing SMS are re-parsed with the updated accounts. Rules matching works without any API key; LLM assignment only runs when hints/body/last4 are insufficient and `GEMINI_API_KEY` is set on Functions.

### USER ACTIONS required to fully enable

1. **Gemini key (optional, for auto-LLM classify):** `cd firebase/functions && firebase functions:secrets:set GEMINI_API_KEY` then `firebase deploy --only functions:classifyTransaction,functions:notifyClassification`. Get a free key at [Google AI Studio](https://aistudio.google.com/apikey). **Never paste API keys in chat or Cursor** — only Firebase secrets. Until set, LLM returns `needsConfig` and the app uses rules + the in-app inbox.
2. **Deploy functions:** `firebase deploy --only functions` (adds `classifyTransaction` + `notifyClassification`; Blaze plan required). If only `notifyClassification` fails with Eventarc 400, **`classifyTransaction` is already enough** — retry push later per `USER-FIX.md`.
3. **Real push (optional):** a **paid Apple Developer account** + APNs key in Firebase to deliver classify notifications. **Not required** — sideload via Xcode works fine; use the in-app inbox instead.

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

- Set `GEMINI_API_KEY` + deploy the two new functions (see USER ACTIONS above) — **optional**; rules + in-app classify work without it
- Redacted real SMS samples to expand rules beyond HDFC/ICICI/Federal templates
- Category management UI (add/rename/delete) — currently seeded defaults + implicit merchant-rule learning
- Paid Apple account → optional real APNs push for classify prompts (in-app inbox is primary)

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
