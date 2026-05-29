# Money Matters — Shortcuts Setup

Step-by-step guide for **Automation A** (ingest SMS) and **Shortcut B** (sync now) on stock iOS.

## Prerequisites

1. Complete app onboarding through **Connect SMS** — copy:
  - **Ingest URL** (Cloud Function `ingestSms`)
  - **Bearer token** (device ingest token)
  - **Device ID** (UUID from onboarding)
2. Firebase project deployed with `ingestSms` function (see `firebase/README.md`).

---

## What is “Shortcut Input”?

When a **Message** personal automation runs, iOS passes the **SMS that triggered it** into the workflow as a special variable called **Shortcut Input**. You are not typing anything manually.

- **Where it comes from:** the incoming message that matched your automation (sender + keyword filter).
- **How you use it:** in any action’s text field, tap the variable button (×) above the keyboard → **Shortcut Input** → then choose **Content** (body), **Sender**, etc.
- **Same idea, different action names:** **Get Text from Input** with **Input** set to **Shortcut Input**, or **Get Details of Input** → Content / Sender.

This only exists **while the Message automation is running**. A separate shortcut does **not** automatically receive it unless you pass it (see Path B below).

---

## Automation A — Money Matters Ingest SMS

Goal: when a financial SMS arrives, POST its body to `ingestSms` without opening the app.

Pick **one** path below. Try **Path A** first (most reliable on current iOS).

### Path A — All actions inside the automation (recommended)

Many Message automations work best as **New Blank Automation** with actions inline (not “Run Shortcut”). Apple’s own examples use **Shortcut Input** directly in the automation.

1. **Automation** tab → **+** → **Message**
2. **Message Contains:** e.g. `debited` (duplicate automation per keyword if needed)
3. **Run Immediately:** ON
4. Tap **New Blank Automation** (not “Run Shortcut” only)
5. Add actions **in order:**


| Step | Action                  | Notes                                                                      |
| ---- | ----------------------- | -------------------------------------------------------------------------- |
| 1    | **Get Text from Input** | Input: **Shortcut Input** → tap result, pick **Content** → variable `body` |
| 2    | **Get Text from Input** | Input: **Shortcut Input** → **Sender** → variable `sender`                 |
| 3    | **Current Date**        | Format **ISO 8601** → variable `receivedAt`                                |
| 4    | **Get Contents of URL** | POST, headers, JSON body (below)                                           |


If you do not see **Get Contents of URL** when searching inside the automation, use **Path B**.

**Shortcut Input in a text field:** type nothing, tap **×** (variables) → **Shortcut Input** → tap the token → **Content** or **Sender**.

### Path B — Library shortcut + Run Shortcut (pass the message in)

Use this when the POST action only appears in a normal **Shortcut**, not in the automation editor.

**B1 — Create the shortcut** (Shortcuts → **+** → **Shortcut**)

Name: **Money Matters — Ingest SMS**

1. **Get Text from Input** → Input: **Shortcut Input** → **Content** → `body`
2. **Get Text from Input** → Input: **Shortcut Input** → **Sender** → `sender`
3. **Current Date** → ISO 8601 → `receivedAt`
4. **Get Contents of URL** → POST + JSON (below)

Optional shortcut setting: open the shortcut → **ⓘ** → ensure it can receive input when run from automations (wording varies by iOS version).

**B2 — Create the automation**

1. Message trigger + **Run Immediately** (same as Path A)
2. Single action: **Run Shortcut** → **Money Matters — Ingest SMS**
3. **Important:** tap the **Run Shortcut** action to expand it. Set **Input** (or “Shortcut Input”) to **Shortcut Input** / the **Message** from the trigger — **not** “Ask Each Time”. That forwards the triggering SMS into the shortcut.

If **Run Shortcut** has no Input field, or the shortcut still receives empty input, use **Path C** or switch to **Path A**.

### Path C — Find Messages fallback (when Shortcut Input is empty)

Your instinct is reasonable: if the automation does not pass the message into a child shortcut, read it from the Messages database instead.

**Caveats:**

- Requires Messages access when the shortcut runs.
- “Latest message” can be wrong if another SMS arrives in the same second — less ideal than **Shortcut Input** when that works.
- Prefer filtering by **Sender** when your bank sends from a fixed number/name.

**Example flow inside the shortcut or automation:**

1. **Find Messages** → Filter: **Message contains** `debited` (same keyword as automation) → **Limit** 1 → **Latest First** (or sort by date, get first item)
2. **Get Details of Messages** → **Body** → `body`
3. **Get Details of Messages** → **Sender** → `sender`
4. **Get Details of Messages** → **Date** → format as ISO 8601 → `receivedAt` (or **Current Date** if date detail is awkward)
5. **Get Contents of URL** → POST + JSON

Tighter variant if you know the bank sender ID:

1. **Find Messages** → **Sender** is `VK-HDFCBK` (example) → **Limit** 1 → latest
2. Then steps 2–5 above

Test by receiving a real bank SMS and checking the shortcut **run log** (last action’s output).

### JSON request body (Get Contents of URL)

```json
{
  "body": "<body variable>",
  "sender": "<sender variable>",
  "receivedAt": "<receivedAt ISO8601>",
  "deviceId": "<UUID from Connect SMS>",
  "source": "shortcuts-automation-v1",
  "batchHint": null
}
```

Map Shortcuts variables into each field. One SMS → one POST. Do not batch multiple messages.

### Health check

- **Test POST** in Money Matters (you already got `201` — backend is fine).
- Send a real SMS matching your keyword; open Shortcuts → **Automation** → confirm last run succeeded.
- Open Money Matters (signed in) to drain the queue.
- Optional: Firestore → `users/{uid}/raw_ingests` for a new row.

---

## Shortcut B — Sync now

Manual shortcut — opens Recovery. Does not read SMS history.

1. **Open App** → Money Matters **or**
2. **Open URL** → `moneymatters://recovery`

Add to Home Screen for manual sync after travel or Focus mode.

---

## Troubleshooting


| Symptom                                 | What to try                                                                  |
| --------------------------------------- | ---------------------------------------------------------------------------- |
| Don’t understand Shortcut Input         | It’s the **triggering SMS**, not manual typing — see section above           |
| Empty `body` / `sender` in Run Shortcut | Set **Run Shortcut → Input** to **Shortcut Input**; or use **Path A** inline |
| No Get Contents of URL in automation    | Use **Path B** (POST in library shortcut)                                    |
| Shortcut Input empty everywhere         | **Path C** (Find Messages), or **Path A** blank automation                   |
| No POST in Firestore                    | Automation off, Focus, keyword mismatch, or failed URL step                  |
| HTTP 401                                | Re-copy Bearer token from Connect SMS                                        |
| HTTP 400                                | Missing JSON field or bad `receivedAt`                                       |
| Duplicate `200`                         | Same SMS retried within one minute — expected                                |


---

## Security note

The Bearer token lives in Shortcuts on your device. Use a personal Firebase project; rotate from Connect SMS if the phone is lost.

---

## References

- Payload examples: `docs/shortcuts/payload-examples.json`
- Ingest contract: `docs/brainstorms/money-matters-sms-ledger-requirements.md` (F2)

