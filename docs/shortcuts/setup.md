# Money Matters — Shortcuts Setup

Step-by-step guide for **Automation A** (ingest SMS) and **Shortcut B** (sync now) on stock iOS.

## Prerequisites

1. Complete app onboarding through **Connect SMS** — copy:
   - **Ingest URL** (Cloud Function `ingestSms`)
   - **Bearer token** (device ingest token)
   - **Device ID** (UUID from onboarding)
2. Firebase project deployed with `ingestSms` function (see `firebase/README.md`).

---

## Automation A — Money Matters Ingest SMS

Personal Automation that POSTs each matching financial SMS while the app is **closed**.

### Trigger

| Setting | Value |
|---------|--------|
| Type | **Personal Automation** → **Message** |
| Sender | Any Sender (MVP) |
| Message Contains | One or more keywords (OR via multiple automations): `debited`, `credited`, `INR`, `Rs`, `spent`, `payment`, `UPI`, `card` |
| Run | **Run Immediately** (required) |

> **Tip:** Shortcuts may limit OR filters. Create separate automations per keyword if needed.

### Actions (in order)

1. **Get Shortcut Input** → **Content** → set variable `body`
2. **Get Shortcut Input** → **Sender** → set variable `sender`
3. **Current Date** → Format **ISO 8601** → set variable `receivedAt`
4. **Get Contents of URL**
   - Method: **POST**
   - URL: paste **Ingest URL** from app
   - Headers:
     - `Authorization`: `Bearer <INGEST_TOKEN>` (from app onboarding)
     - `Content-Type`: `application/json`
   - Request Body: **JSON** (see below)
5. *(Optional)* **Open URL** when app may be foreground:
   - `moneymatters://ingest?body=<url-encoded>&sender=<url-encoded>&receivedAt=<url-encoded>`
   - Truncate long `body` in query; POST remains source of truth.

### JSON request body

```json
{
  "body": "<Shortcut Input Content>",
  "sender": "<Shortcut Input Sender>",
  "receivedAt": "<ISO8601 from Current Date>",
  "deviceId": "<UUID from app onboarding>",
  "source": "shortcuts-automation-v1",
  "batchHint": null
}
```

Map Shortcuts variables into each field. Do **not** merge multiple SMS into one POST.

### Health check

- Run **Test POST** in the app, or send yourself a test financial SMS after enabling the automation.
- Confirm HTTP `201` or `200` (duplicate) in Shortcuts history, then **Manual confirm** in app.

---

## Shortcut B — Sync now

Manual shortcut for recovery awareness — opens the app to the Recovery screen. Does **not** fetch SMS history (no inbox API on stock iOS).

### Actions

1. **Open App** → Money Matters  
   **or**
2. **Open URL** → `moneymatters://recovery`

Add to Home Screen for quick access after travel, Focus mode, or iOS updates.

---

## Troubleshooting

| Symptom | Check |
|---------|--------|
| No POST in Firebase | Automation disabled, Focus, Low Power, or keyword mismatch |
| HTTP 401 | Bearer token mismatch — re-copy from app onboarding |
| HTTP 400 | Missing JSON field or invalid `receivedAt` |
| Duplicate ignored | Same SMS retried within same minute — expected (idempotency) |
| Missed transactions | Use Recovery → multi-paste in app |

---

## Security note

The Bearer token is stored in Shortcuts on your personal device. Use a personal Firebase project; rotate token from app if device is lost.

---

## References

- Payload examples: `docs/shortcuts/payload-examples.json`
- Ingest contract: `docs/brainstorms/money-matters-sms-ledger-requirements.md` (F2)
- Build plan: `docs/plans/money-matters-build-plan.md`
