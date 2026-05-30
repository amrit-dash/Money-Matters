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
| `transactions/{txId}` | same as raw ingest id | `IngestParsePipeline` on parse; app on relabel | drain, dashboard, review | `rawIngestId`, `amount`, `currency`, `merchant`, `timestamp`, `categoryId`, `paymentSourceId`, `unmatched`, `ambiguous`, `type`, `processedAt` |

## Flow

1. **SMS ingest** — iOS Shortcut or Recovery multi-paste POSTs to `ingestSms`. CF atomically creates `raw_ingests/{key}` + `parse_jobs/{auto}` with `status: pending`.
2. **Drain** — App pulls unprocessed ingests (`processedAt == null`), pending jobs, and recent transactions into local SQLite.
3. **Parse** — `IngestParsePipeline` runs rules parser, writes `transactions/{rawIngestId}`, sets `parse_jobs` → `done`, sets `raw_ingests.processedAt`. On error: job → `failed`, ingest stays unprocessed for retry.
4. **Review relabel** — Updates local SQLite + `transactions/{id}.categoryId` in Firestore.

## Categories

Not stored in Firestore. Default categories ship in `CategoryService` (in-memory). User relabels persist only on the transaction document.

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
