# Money Matters — user verification guide

## What was wrong (2026-05-31 fix pass)

| Issue | Root cause | Fix in app |
|-------|------------|------------|
| **Gemini “does nothing”** | LLM only runs on **new** parses; backlog stayed in Review after secret was set. Callable errors were silent (`null`). | Recovery sync + Accounts save now **re-run LLM on backlog**. Sync snackbar shows `auto-classified` or `LLM needs GEMINI_API_KEY secret`. |
| **SMS with last4 still unmatched** | Rematch ran on sync but **Accounts save did not** trigger rematch until next Recovery. | Saving Accounts now runs rematch + LLM backlog immediately. |
| **FEDBNK-S / FEDSCP-S SMS** | Rules need **sender hints** on the account; LLM did not receive SMS **sender id**. | Add hints (below). LLM prompt now includes sender id. |
| **Categories wrong / Food default** | Fixed in `adbf2b1` — classify screen no longer pre-selects Food; Zepto→groceries. | Install latest IPA; no extra action if already on current build. |

---

## Verification checklist

### 1. Install latest build

Install the IPA built from `main` **after** this fix (not an older sideload).

### 2. Firebase project

**Profile** → confirm **Firebase: money-matters-amrit** and your UID.

### 3. Accounts — sender hints + last4

**Accounts** → each bank/card needs:

| Account | Sender hints (comma-separated) | last4 |
|---------|-------------------------------|-------|
| Federal Bank (UPI) | `FEDBNK-S` | last 4 of account |
| Scapia Federal RuPay card | `FEDSCP-S` | last 4 of card |
| HDFC / others | e.g. `VK-HDFCBK`, `HDFCBK` | last 4 |

After save, snackbar should say e.g. **`Saved — 2 matched`** or **`3 auto-classified`**. If you see **`LLM needs GEMINI_API_KEY`**, complete section 4.

### 4. Enable Gemini auto-classify (optional)

Rules + **Review** inbox work **without** any API key. For cloud auto-suggest:

```bash
cd firebase/functions
firebase functions:secrets:set GEMINI_API_KEY
# paste key from https://aistudio.google.com/apikey when prompted
firebase deploy --only functions:classifyTransaction
```

**Never paste API keys in chat or Cursor** — only Firebase secrets.

Redeploy is required after setting the secret so the function binds `GEMINI_API_KEY`.

If `notifyClassification` fails with Eventarc 400, ignore it — push is optional; Review inbox is primary.

### 5. Re-sync existing SMS

**Recovery** → **Sync and parse now**.

Success signals:

- Snackbar: `N account(s) matched` and/or `N auto-classified`
- **Dashboard → Review** badge count **drops**
- Firestore `users/{uid}/transactions/{id}`: `categoryId` set, `needsClassification: false`, `classifiedBy: "llm"` when Gemini worked
- Firestore `paymentSourceId` set on previously unmatched rows

If snackbar says **`LLM needs GEMINI_API_KEY secret`** → secret not set or function not redeployed (section 4).

If snackbar says **`LLM classify error`** → sign out/in, check Functions logs in Firebase Console, confirm `classifyTransaction` deployed in **asia-south1**.

### 6. Confirm Gemini from the app (no Console)

1. Add a **new** ambiguous debit SMS (or use Review item).
2. Run **Sync and parse now**.
3. Snackbar **`1 auto-classified`** = Gemini path worked.
4. Open transaction → category should be set, `classifiedBy` llm in Firestore.

### 7. Categories sanity check

- **Zepto / Blinkit / Instamart** → **Groceries** (not Food).
- Classify screen opens with **no category pre-selected** (not Food).
- Shopping list only for **matched payment + Groceries/Shopping**.

---

## Recovery shows jobs but nothing parses

Your Firebase project **does** have data (`money-matters-amrit`):

- **10** `payment_sources` (banks/cards) under your user
- **13** `raw_ingests` and **13** pending `parse_jobs`

The app only downloaded **parse jobs** into the phone, not the SMS bodies, because Firestore treats “field missing” differently from `processedAt: null`. The drain query used `isNull` and matched **zero** legacy ingests, so Recovery showed **Parse jobs in queue: 13** with **Synced SMS: 0** and **Pending parse: 0**.

**Fix:** install latest IPA → **Recovery** → **Sync and parse now**.

In [Firebase Console](https://console.firebase.google.com/project/money-matters-amrit/firestore) → `users` → *your UID*:

- **`payment_sources`** — docs with `last4`, `senderHints`
- After sync: **`parse_jobs`** → `status: done`, **`transactions`** populated

---

## `notifyClassification` deploy failed (Eventarc 400)

If deploy shows **`classifyTransaction` SUCCESS** but **`notifyClassification` FAILED**:

**You can keep using the app.** Classification prompts come from **Dashboard → Review** — not push.

```bash
cd firebase
firebase deploy --only functions:notifyClassification
```

Or skip push:

```bash
firebase deploy --only functions:classifyTransaction
```

---

## If sync still fails

- Snackbar **permission denied** → sign out and sign in again.
- **Accounts** must have at least one bank/card with **last4 + sender hints**.
- Shortcut ingest URL must point at deployed `ingestSms` for `money-matters-amrit`.
