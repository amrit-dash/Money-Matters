# Money Matters — Firebase Backend

Cloud ingest queue for iOS Shortcuts SMS handoff. Shortcuts POST financial SMS to `ingestSms`; the Flutter app drains `raw_ingests` and processes `parse_jobs`.

## Prerequisites

- Node.js 22+ (Functions runtime; see `functions/package.json` `engines`)
- [Firebase CLI](https://firebase.google.com/docs/cli): `npm install -g firebase-tools` or use `npx firebase-tools@latest`
- A Firebase project with **Authentication**, **Firestore**, **Cloud Functions**, and **Cloud Messaging** enabled

## One-time setup

### 1. Create / select Firebase project

1. Create a project at [Firebase Console](https://console.firebase.google.com/) (or use an existing one).
2. Enable **Email/Password** auth (Authentication → Sign-in method).
3. Create a **Firestore** database (production mode; rules deploy from this repo).
4. Upgrade to **Blaze** plan (required for Cloud Functions outbound networking).

### 2. Configure project ID

Active project: **`money-matters-amrit`** (see `.firebaserc`).

```bash
firebase use money-matters-amrit
```

### 3. Install dependencies and build

```bash
cd firebase
npm run ci      # installs functions/ dependencies
npm run build
```

### 4. Deploy

```bash
# Rules + indexes + functions
firebase deploy

# Or separately:
npm run deploy:rules
npm run deploy:functions
```

After deploy, note the function URL (region `asia-south1`):

```
https://asia-south1-YOUR_PROJECT_ID.cloudfunctions.net/ingestSms
```

Copy this URL into Shortcuts as `INGEST_URL` (see `docs/shortcuts/setup.md`):

```
https://ingestsms-ajirc5tjmq-el.a.run.app
```

(Also reachable via `https://asia-south1-money-matters-amrit.cloudfunctions.net/ingestSms` if shown in Console.)

### Deploy failed with `iam.serviceaccounts.actAs` (403)

If `firebase deploy` fails creating `ingestSms` in `asia-south1`:

1. Open [Google Cloud Console IAM](https://console.cloud.google.com/iam-admin/iam?project=money-matters-amrit).
2. Find your Google account (the one used for `firebase login`).
3. Ensure roles include **Service Account User** (`roles/iam.serviceAccountUser`) and **Cloud Functions Admin** (or **Editor** on the project for personal use).
4. Retry:

   ```bash
   cd firebase && firebase deploy --only functions:ingestSms,firestore:rules
   ```

Alternatively: Firebase Console → **Functions** → grant permissions when prompted after first deploy attempt.

### Deploy failed: Eventarc Service Agent permission denied (HTTP 400)

Firestore-triggered v2 functions (e.g. `notifyClassification`) use **Eventarc**. On first deploy you may see:

> Permission denied while using the Eventarc Service Agent … verify that it has Eventarc Service Agent role

**Impact:** `classifyTransaction` and `ingestSms` can deploy and work without `notifyClassification`. Push is optional; the Flutter **Review** inbox is the primary classify path (especially on a free Apple team without APNs).

**Recovery:**

1. Wait **5–10 minutes** for service-agent propagation, then:

   ```bash
   cd firebase && firebase deploy --only functions:notifyClassification
   ```

2. In [GCP IAM](https://console.cloud.google.com/iam-admin/iam?project=money-matters-amrit), enable **Include Google-provided role grants**, find:

   `service-960400349210@gcp-sa-eventarc.iam.gserviceaccount.com`

   (use the project number from your error), and grant **Eventarc Service Agent** (`roles/eventarc.serviceAgent`) if absent. Retry the deploy.

   See [Eventarc troubleshooting — permission denied](https://cloud.google.com/eventarc/docs/troubleshooting#permission-denied-errors).

3. **Split deploy (workaround):** deploy callables first, push later:

   ```bash
   firebase deploy --only functions:ingestSms,functions:classifyTransaction
   # later, when Eventarc is ready:
   firebase deploy --only functions:notifyClassification
   ```

Do not remove `notifyClassification` from source unless you intentionally want to defer push indefinitely.

## Environment variables

The Cloud Function uses the **Firebase Admin SDK** with default application credentials — no extra env vars are required at runtime for `ingestSms`.

| Variable / config | Where | Notes |
|-------------------|-------|-------|
| Firebase project ID | `.firebaserc` | `money-matters-amrit` |
| `INGEST_URL` | Shortcuts + app onboarding | Function URL from deploy output |
| Device ingest token | Keychain + Shortcuts | Created by app onboarding; stored as `sha256` in Firestore |
| `deviceId` | App onboarding | UUID sent in POST body; must match `device_tokens` doc ID |
| `GEMINI_API_KEY` | Functions secret | **Optional legacy fallback.** Used only when the user has not saved BYOK settings in the app. Prefer **Profile → Agent settings** (provider + API key + model stored at `users/{uid}/settings/llm`). |

### LLM classify (`classifyTransaction`)

Rules-first parsing runs on-device; the callable CF only handles uncategorized/ambiguous debits. **No API key is required** for normal use — merchant rules and the in-app "Needs your input" inbox cover everything.

**Recommended:** In the app, open **Profile → Agent settings**, enable LLM, pick a provider (Gemini, Open Router, Grok, Mistral, or Other), enter your API key, test it, fetch models, and save. Cloud Functions read that config per user.

**Legacy:** Project-wide Gemini via Firebase secret:

```bash
cd firebase/functions
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions:classifyTransaction,functions:testLlmApiKey,functions:fetchLlmModels,functions:notifyClassification
```

**Never paste API keys in chat or Cursor** — only Firebase secrets or in-app Agent settings.

### Agent settings callables

| Callable | Purpose |
|----------|---------|
| `testLlmApiKey` | Verifies provider + API key (uses inline key from the request or saved settings) |
| `fetchLlmModels` | Lists models for the chosen provider |
| `classifyTransaction` | Auto-classify using saved user config (or legacy `GEMINI_API_KEY`) |
| `retryStuckParseJobs` | Scheduled every 6 h — marks pending jobs stuck >2 h; optional FCM sync nudge |

LLM errors and warnings are written to `users/{uid}/llm_logs` and shown in **Agent settings → LLM logs**.

### Push notifications (optional)

FCM/APNs push for "needs classification" prompts is **optional**. Sideloaded IPA on a free Apple ID works without push — use **Dashboard → Review** (in-app inbox). A paid Apple Developer account is only needed if you want background push delivery.

### Device token registration (automatic)

On **Connect SMS** (onboarding or Dashboard → SMS icon), the Flutter app:

1. Loads or creates a device id + bearer token (stored on the iPhone).
2. Writes `users/{uid}/device_tokens/{deviceId}` with `tokenHash: sha256(bearer)`.

No manual Firestore step is required for normal use.

### Seeding a device token (emergency / curl only)

If you need to test with curl without the app, create this document in Firestore Console:

```javascript
// tokenHash = sha256 of the raw secret you will send as Bearer
// Example: echo -n "test-secret-32bytes-minimum!!" | shasum -a 256
{
  "tokenHash": "<sha256-hex>",
  "createdAt": "<Firestore timestamp>",
  "label": "curl-test"
}
```

## Local emulators (optional)

```bash
cd firebase
npm run emulators
```

Emulator UI: http://localhost:4000

Point curl at `http://127.0.0.1:5001/YOUR_PROJECT_ID/asia-south1/ingestSms` when using the functions emulator.

## API: `ingestSms`

**POST** `https://asia-south1-<project>.cloudfunctions.net/ingestSms`

### Headers

| Header | Value |
|--------|-------|
| `Authorization` | `Bearer <deviceIngestToken>` |
| `Content-Type` | `application/json` |

### Body

```json
{
  "body": "Rs.500 debited from A/c **1234 on 29-05-26...",
  "sender": "VK-HDFCBK",
  "receivedAt": "2026-05-29T14:32:00+05:30",
  "deviceId": "uuid-from-app-onboarding",
  "source": "shortcuts-automation-v1",
  "batchHint": null
}
```

| Field | Required | Notes |
|-------|----------|-------|
| `body` | yes | Raw SMS text |
| `sender` | yes | Sender ID / short code |
| `receivedAt` | yes | ISO8601; used for idempotency minute bucket |
| `deviceId` | yes | Must match registered `device_tokens` doc |
| `source` | yes | `shortcuts-automation-v1` or `manual-paste` |
| `batchHint` | no | MVP: always `null`; reserved for future |

### Idempotency

```
idempotencyKey = sha256(normalize(sender) + "|" + normalize(body) + "|" + floor_to_minute(receivedAt))
```

- `normalize(sender)` = trim + lowercase
- `normalize(body)` = trim + collapse whitespace
- `floor_to_minute(receivedAt)` = ISO8601 UTC floored to minute

### Responses

| Status | Body | Meaning |
|--------|------|---------|
| `201` | `{ "ok": true, "duplicate": false, "id": "<key>" }` | New ingest + pending parse job |
| `200` | `{ "ok": true, "duplicate": true, "id": "<key>" }` | Exact retry deduplicated |
| `401` | `{ "ok": false, "error": "..." }` | Invalid/missing Bearer token |
| `400` | `{ "ok": false, "error": "..." }` | Validation error |
| `500` | `{ "ok": false, "error": "Internal server error" }` | Server error |

### curl example

Replace placeholders with your values:

```bash
export PROJECT_ID="YOUR_FIREBASE_PROJECT_ID"
export INGEST_URL="https://asia-south1-${PROJECT_ID}.cloudfunctions.net/ingestSms"
export INGEST_TOKEN="your-raw-device-token-from-onboarding"
export DEVICE_ID="your-device-uuid"

curl -sS -X POST "$INGEST_URL" \
  -H "Authorization: Bearer ${INGEST_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "body": "Rs.899 debited from A/c **4567 at ZUDIO on 29-05-26",
    "sender": "VK-HDFCBK",
    "receivedAt": "2026-05-29T14:32:00+05:30",
    "deviceId": "'"${DEVICE_ID}"'",
    "source": "shortcuts-automation-v1",
    "batchHint": null
  }'
```

Expected first call: HTTP 201. Repeat the same payload: HTTP 200 with `"duplicate": true`.

Verify in Firestore:

- `users/{uid}/raw_ingests/{idempotencyKey}`
- `users/{uid}/parse_jobs/{autoId}` with `status: "pending"`

## Firestore security rules

All paths under `users/{uid}/**` allow read/write only when `request.auth.uid == uid`.

Shortcuts never write Firestore directly — only the Cloud Function (Admin SDK) creates `raw_ingests` and `parse_jobs`.

## FCM (optional push)

FCM is **not** used for SMS ingestion. It can deliver human-in-the-loop prompts (unmatched payment source, ambiguous category) when configured with APNs.

**No paid Apple Developer account is required.** Sideload via Xcode on a free personal team; the in-app Review/classify inbox is the primary path. Push is a nice-to-have only.

Data message shape (implemented in Flutter; sent by `notifyClassification` CF):

```json
{
  "type": "transaction_review",
  "transactionId": "<firestore-doc-id>",
  "reason": "unmatched_source | ambiguous_category",
  "title": "Review transaction",
  "body": "Tap to link payment source or set category."
}
```

Topic or per-device token registration happens during app onboarding. `notifyClassification` is deployed; real APNs delivery requires a paid Apple account (optional).

## Optional: LLM auto-classify

If transactions stay in "Needs your input" and you want automatic categorization for ambiguous spends, set a Gemini API key (see **Environment variables** above). **This is optional** — rules parsing and manual classify in the app work without any key.

## Collections (reference)

| Path | Doc ID | Purpose |
|------|--------|---------|
| `users/{uid}` | uid | Profile |
| `users/{uid}/device_tokens/{deviceId}` | deviceId | Bearer token hash |
| `users/{uid}/raw_ingests/{idempotencyKey}` | idempotency key | Raw SMS audit log |
| `users/{uid}/parse_jobs/{auto}` | auto | Parse queue (`pending` → `done`/`failed`) |
| `users/{uid}/transactions/{auto}` | auto | Parsed ledger rows (app-written) |
| `users/{uid}/payment_sources/{auto}` | auto | Banks/cards (app-written) |
| `users/{uid}/categories/{id}` | category id | Seeded from app defaults; merged on upgrade |
| `users/{uid}/settings/llm` | `llm` | BYOK LLM: `enabled`, `provider`, `apiKey`, `model`, optional `baseUrl` |
| `users/{uid}/llm_logs/{auto}` | auto | LLM classify / test / fetch errors (app-readable) |

## TODOs for project owner

- [ ] Set Firebase project ID in `.firebaserc`
- [ ] Run `firebase login` if not authenticated
- [ ] Deploy: `cd firebase && npm ci && npm run build && firebase deploy`
- [ ] Copy `INGEST_URL` to Shortcuts automation
- [ ] Complete app onboarding to generate device token + `deviceId`
- [ ] Run `flutterfire configure` at repo root (Flutter streams; not part of this folder)
- [ ] Download `GoogleService-Info.plist` → `ios/Runner/` (not committed)

## Scripts

| Command | Description |
|---------|-------------|
| `npm ci` | Install function dependencies |
| `npm run build` | Compile TypeScript |
| `npm run deploy` | Deploy all Firebase resources |
| `npm run deploy:rules` | Firestore rules + indexes only |
| `npm run deploy:functions` | Cloud Functions only |
| `npm run emulators` | Local functions + Firestore emulators |
