# Fix: Recovery shows jobs but nothing parses

## What was wrong

Your Firebase project **does** have data (`money-matters-amrit`):

- **10** `payment_sources` (banks/cards) under your user
- **13** `raw_ingests` and **13** pending `parse_jobs`

The app only downloaded **parse jobs** into the phone, not the SMS bodies, because Firestore treats “field missing” differently from `processedAt: null`. The drain query used `isNull` and matched **zero** legacy ingests, so Recovery showed **Parse jobs in queue: 13** with **Synced SMS: 0** and **Pending parse: 0**.

## What you need to do

1. **Install the latest IPA** built from `main` after this fix (not an older TestFlight/build).
2. Open the app while signed in → **Profile** → confirm **Firebase: money-matters-amrit** and your UID.
3. **Recovery** → tap **Sync and parse now**. You should see SMS download + transactions created.
4. In [Firebase Console](https://console.firebase.google.com/project/money-matters-amrit/firestore) → **Firestore** → `users` → *your UID*:
   - Expand **`payment_sources`** (10 docs) — scroll subcollections under the user doc, not only the top-level fields.
   - After sync: **`parse_jobs`** → `status: done`, **`raw_ingests`** → `processedAt` set, **`transactions`** populated.

## Optional: enable LLM auto-classify

Rules + the in-app **Review** inbox classify transactions without any API key. If you want the cloud function to auto-suggest categories for ambiguous spends:

```bash
cd firebase/functions
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions:classifyTransaction,functions:notifyClassification
```

Get a free key at [Google AI Studio](https://aistudio.google.com/apikey). **Never paste API keys in chat or Cursor** — only set them via Firebase secrets as above.

No paid Apple account needed — sideload IPA and use Review inbox as primary.

## `notifyClassification` deploy failed (Eventarc 400)

If deploy shows **`classifyTransaction` SUCCESS** but **`notifyClassification` FAILED** with:

> Permission denied while using the Eventarc Service Agent … verify that it has Eventarc Service Agent role

**You can keep using the app.** `classifyTransaction` (LLM auto-suggest) is independent. Classification prompts come from **Dashboard → Review** (“Needs your input”) — not from push. On a free Apple personal team, FCM/APNs push usually does not work anyway; the in-app inbox is the primary path.

### Fix (try in order)

1. **Wait 5–10 minutes** — first v2 Firestore trigger on a project often needs Eventarc IAM to propagate. Then redeploy only the push function:

   ```bash
   cd firebase
   firebase deploy --only functions:notifyClassification
   ```

2. **Verify Eventarc Service Agent IAM** (if retry still fails):

   - Open [IAM for money-matters-amrit](https://console.cloud.google.com/iam-admin/iam?project=money-matters-amrit).
   - Enable **Include Google-provided role grants**.
   - Find principal: `service-960400349210@gcp-sa-eventarc.iam.gserviceaccount.com`  
     (replace `960400349210` with your project number if the error shows a different one).
   - Ensure role **Eventarc Service Agent** (`roles/eventarc.serviceAgent`). Grant it if missing.
   - Retry step 1.

   Official troubleshooting: [Eventarc permission denied](https://cloud.google.com/eventarc/docs/troubleshooting#permission-denied-errors).

3. **Optional workaround — skip push for now:** deploy only what you need:

   ```bash
   firebase deploy --only functions:classifyTransaction
   ```

   Push stays off until `notifyClassification` deploys successfully. No app rebuild required.

## If sync still fails

- Snackbar mentions **permission denied** → sign out and sign in again.
- **Accounts** must have at least one bank/card saved (cloud already has yours).
- Shortcut ingest URL must point at the deployed `ingestSms` function for this project.
