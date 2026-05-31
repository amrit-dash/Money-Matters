# Firestore data model

All user data lives under `users/{uid}/`. Firestore rules require `request.auth.uid == uid` for every read/write.

Project: `money-matters-amrit`

## Subcollections

| Path | Doc ID | Writer | Reader | Key fields |
|------|--------|--------|--------|------------|
| `device_tokens/{deviceId}` | device UUID | `DeviceTokenService` (onboarding) | `ingestSms` CF via collection-group query on `tokenHash` | `tokenHash`, `label`, `createdAt` |
| `payment_sources/{sourceId}` | app UUID | `PaymentSourceService` | parse pipeline, Accounts screen | `name`, `type`, `last4`, `senderHints[]`, `createdAt` |
| `raw_ingests/{idempotencyKey}` | SHA-based key from sender+body+receivedAt | `ingestSms` CF (atomic with parse_job) | `IngestRepository.drainPending` | `body`, `sender`, `receivedAt`, `deviceId`, `source`, `batchHint`, `createdAt`, `processedAt` |
| `parse_jobs/{auto}` | auto | `ingestSms` CF creates `pending`; app sets `done`/`failed` | drain + pipeline | `rawIngestId`, `status`, `rulesVersion`, `error`, `updatedAt` |
| `transactions/{txId}` | same as raw ingest id | `IngestParsePipeline` on parse; app on classify | drain, dashboard, review | `rawIngestId`, `amount`, `currency`, `merchant`, `timestamp`, `categoryId`, `paymentSourceId`, `unmatched`, `ambiguous`, `type`, `needsClassification`, `merchantNormalized`, `userNotes`, `shoppingItems`, `classifiedBy`, `processedAt` |
| `categories/{categoryId}` | slug (`food`, `shopping`, …) | `CategoryService` (seeds defaults on first load); user adds merchant rules | parse pipeline (auto-categorize), classify UI | `name`, `system`, `merchantRules[]`, `createdAt` |
| `fcm_tokens/{token}` | FCM registration token | `FcmService` on sign-in / token refresh | `notifyClassification` CF | `token`, `platform`, `createdAt`, `updatedAt` |

### New transaction fields (v2)

| Field | Type | Meaning |
|-------|------|---------|
| `type` | `debit` \| `credit` | Spend vs income. Credits are excluded from spend totals. |
| `unmatched` | bool | No saved bank/card matched. **Excluded from dashboard totals**; surfaced in its own bucket. |
| `needsClassification` | bool | Debit with no confident category — drives the in-app "Needs your input" inbox and FCM prompt. |
| `merchantNormalized` | string? | Cleaned merchant name (rules/LLM), preferred for display. |
| `userNotes` | string? | Free-text note added during the classify flow. |
| `shoppingItems` | string[] | Optional items captured during classify. |
| `classifiedBy` | `rules` \| `llm` \| `user` | Provenance of the current category. |

## Flow

1. **SMS ingest** — iOS Shortcut or Recovery multi-paste POSTs to `ingestSms`. CF atomically creates `raw_ingests/{key}` + `parse_jobs/{auto}` with `status: pending`.
2. **Drain** — App pulls unprocessed ingests (`processedAt == null`), pending jobs, and recent transactions into local SQLite.
3. **Parse** — `IngestParsePipeline` runs rules parser, matches a payment source and category, writes `transactions/{rawIngestId}`, sets `parse_jobs` → `done`, sets `raw_ingests.processedAt`. On error: job → `failed`, ingest stays unprocessed for retry.
4. **LLM gate (rules-first)** — Only for `needsClassification`/`ambiguous` debits, the pipeline calls the `classifyTransaction` callable CF (Gemini). On success it sets `categoryId`/`merchantNormalized` and clears the flags; on error or missing API key it leaves the transaction for the in-app inbox (never blocks the drain).
5. **Notify** — `notifyClassification` (Firestore trigger) sends an FCM "categorize" push to `fcm_tokens` when a transaction needs input. Requires a paid Apple Developer account for real APNs delivery; the in-app inbox is the always-working fallback.
6. **Classify (in-app HITL)** — Review inbox → Classify screen writes `categoryId`, `userNotes`, `shoppingItems`, `classifiedBy: user` to local SQLite + `transactions/{id}` in Firestore, and optionally teaches a `categories/{id}.merchantRules` rule.

## Categories

Stored in `users/{uid}/categories`. `CategoryService` seeds nine defaults (food, groceries, transport, shopping, bills, entertainment, health, transfer, other) on first load, each with `merchantRules[]` used for rules-first auto-categorization. Classifying with "remember this merchant" appends a rule via `arrayUnion`. Falls back to in-memory defaults when signed out or offline.

## Console verification

1. Open [Firebase Console → Firestore](https://console.firebase.google.com/project/money-matters-amrit/firestore).
2. Navigate to `users/{your-uid}/`.
3. After onboarding: confirm `device_tokens/{deviceId}` with `tokenHash` (not the raw token).
4. After adding accounts: confirm `payment_sources/` docs with `createdAt`.
5. After Shortcut health-check or Recovery paste: confirm `raw_ingests/` doc + matching `parse_jobs/` with `status: pending`.
6. Open app (drain + parse runs): `parse_jobs` → `done`, `raw_ingests.processedAt` set, `transactions/` doc appears.
7. Review relabel: `transactions/{id}.categoryId` updates in console.

## Indexes

Defined in `firebase/firestore.indexes.json`:

- `raw_ingests`: `processedAt ASC`, `createdAt ASC` — drain unprocessed
- `parse_jobs`: `status ASC`, `updatedAt ASC` — drain pending
- `parse_jobs`: `rawIngestId ASC`, `status ASC` — mark done/failed
- `device_tokens.tokenHash`: collection-group ASC — ingestSms auth

Deploy: `cd firebase && npm run deploy:rules`
