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

## If sync still fails

- Snackbar mentions **permission denied** → sign out and sign in again.
- **Accounts** must have at least one bank/card saved (cloud already has yours).
- Shortcut ingest URL must point at the deployed `ingestSms` function for this project.
