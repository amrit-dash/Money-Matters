---
date: 2026-05-29
topic: money-matters-ios-shortcuts
run-id: a3f7c2e1
---

# Money Matters: iOS Shortcuts Ingestion Ideation

## Grounding Summary

**Mode:** Greenfield — empty workspace, no existing Flutter or Firebase code. Product decisions locked before ideation.

**Project shape:** Personal iOS-only finance ledger. Sideload via Xcode / Apple Developer Mode. Primary device is iPhone; all transaction SMS arrive there. India-focused bank/wallet SMS parsing (HDFC, ICICI, SBI, UPI, MobiKwik, LazyPay, SIMPL, etc.).

**Hard constraints (stock iOS):**

| Constraint | Implication |
|------------|-------------|
| No public SMS inbox API | Flutter cannot poll Messages |
| Sideload ≠ private SMS entitlement | Same sandbox as App Store apps |
| Shortcuts Personal Automation | Only reliable per-message trigger on stock iOS |
| Trigger payload = **that message only** | No "fetch last 5 SMS" at automation time |
| App process may be killed | POST to backend or App Group buffer required |
| Shortcuts can fail silently | Focus, Low Power, user disable, iOS updates |

**External context:** Community patterns (imsg-mcp, MacStories Shortcuts guides) confirm Message automations expose `Shortcut Input → Content` (body) and `Sender`. `Run Immediately` works with keyword filters. Cloud POST while app is killed is the established reliability pattern.

**Topic axes (from plan):**

1. **Shortcuts contract** — automations, filters, POST vs URL, Run Immediately pitfalls
2. **Reliability & recovery** — missed runs, manual sync, email backup, queue drain
3. **Parsing pipeline** — rules vs LLM; reminder vs spend classification
4. **Payment-source graph** — banks, cards, wallets; unmatched transactions
5. **Human-in-the-loop** — FCM prompts, free-text relabel, ambiguous category nudges
6. **Privacy & sideload** — data minimization, optional local-only mode, no App Store |

---

## Raw Ideas (~34 candidates)

Ideas generated across six ideation frames (pain/friction, inversion/automation, assumption-breaking, leverage/compounding, cross-domain analogy, constraint-flipping). Each tagged with axis and basis type.

### Shortcuts contract (Axis 1)

| # | Title | Summary | Basis |
|---|-------|---------|-------|
| 1 | Cloud-handoff-first (S1) | Automation POSTs JSON to Cloud Function on every financial SMS; app drains Firestore queue on launch/FCM. Works when Flutter killed. | direct: plan architecture |
| 2 | Local-only App Group (S2) | Shortcut writes to shared container; app drains on open. No raw SMS in cloud. | direct: plan Tier 1 local path |
| 3 | Dual POST + URL scheme | POST for reliability + `moneymatters://ingest` for instant UI when app foreground. | reasoned: URL fails when killed |
| 4 | Keyword-filtered automations | Filter on `debited`, `INR`, `UPI`, `Rs`, `credited` — reduce noise vs all-SMS trigger. | external: MacStories Shortcuts guides |
| 5 | Sender allowlist automation | Separate automation per bank short code after onboarding. | reasoned: reduces false triggers |
| 6 | Single-space "all messages" hack | Message Contains `" "` to fire on any SMS — higher volume, more parse cost. | external: community Shortcuts patterns |
| 7 | Bundled `.shortcut` in onboarding | Exportable Shortcut + iCloud link + step-by-step checklist. | direct: plan Phase C item 5 |
| 8 | Health-check Shortcut | Manual Shortcut pings backend; app shows "connected" status. | reasoned: user trust for automations |

### Reliability & recovery (Axis 2)

| # | Title | Summary | Basis |
|---|-------|---------|-------|
| 9 | Recovery trio | Manual sync Shortcut + multi-paste clipboard + optional email ingest. | direct: plan recovery design |
| 10 | Ingest ledger separate from transactions | Raw SMS store + parse attempts; supports re-parse without re-ingest. | direct: plan survivor seed #5 |
| 11 | Per-SMS idempotency keys | `hash(sender + normalized_body + minute_bucket)` — no merge of distinct nearby messages. | direct: user locked decision |
| 12 | Queue drain on every app launch | Pull pending ingest rows before showing dashboard. | reasoned: catches missed push |
| 13 | Email safety net v1.1 | Bank email alerts → forward filter → separate parser. | direct: plan Layer 4 |
| 14 | Ingest status UI | Show last successful automation time, pending queue depth. | reasoned: Shortcuts opacity |
| 15 | iOS 26 Search Messages catch-up | Best-effort manual Shortcut using Search Messages if available on target OS. | direct: plan Automation B caveat |
| 16 | Duplicate POST retry skip | Same body+sender+timestamp from network replay → skip, keep audit log. | direct: plan idempotency |

### Parsing pipeline (Axis 3)

| # | Title | Summary | Basis |
|---|-------|---------|-------|
| 17 | Rules-heavy parser (S3) | Indian bank SMS templates; LLM <10% of messages in v1. | direct: plan parsing intent |
| 18 | Reminder vs transaction classifier | Rules first: billing reminders excluded from spend ledger. | direct: plan classify intent |
| 19 | On-device LLM gate v1.1 | Small model (LiteRT / Qwen 0.6B class) only for flagged ambiguous rows. | direct: plan LLM minimal |
| 20 | Re-parse from raw ingest | User edits template rules; replay parse jobs without new SMS. | reasoned: compounding on ingest ledger |
| 21 | Promo/ad SMS filter | Keyword blocklist for marketing SMS that pass financial filter. | reasoned: keyword filter imperfection |

### Payment-source graph (Axis 4)

| # | Title | Summary | Basis |
|---|-------|---------|-------|
| 22 | Onboarding payment sources | Firebase Auth → register banks, cards (last-4), wallets. | direct: plan onboarding |
| 23 | Unmatched txn → FCM prompt | Unknown instrument triggers "add source" notification. | direct: plan product logic |
| 24 | Auto-link by last-4 / UPI handle | Rules match SMS instrument hints to saved sources. | reasoned: Indian SMS patterns |
| 25 | Category rules with confidence | Zudio → clothing when confident; flag Zepto/flatmate UPI. | direct: plan categories |

### Human-in-the-loop (Axis 5)

| # | Title | Summary | Basis |
|---|-------|---------|-------|
| 26 | FCM as product UI (S7) | Push for ambiguous txns and relabel — not SMS ingestion. | direct: plan survivor seed #7 |
| 27 | Free-text relabel | User corrects category via notification action or in-app. | reasoned: HITL for ambiguous |
| 28 | Weekly digest notification | Summary push — engagement, not ingestion. | reasoned: analytics product loop |

### Privacy & sideload (Axis 6)

| # | Title | Summary | Basis |
|---|-------|---------|-------|
| 29 | Personal Firebase project toggle | User owns cloud; raw SMS in their project with Auth. | direct: locked assumption |
| 30 | Local-only mode toggle (S2 variant) | Settings switch disables cloud POST; App Group only. | direct: plan privacy axis |
| 31 | Raw payload retention policy | Store for audit/re-parse; optional purge after N days. | reasoned: privacy vs recovery |
| 32 | No App Store privacy theater | Still document data use for personal clarity; no review strings needed. | direct: personal app decision |

### Explicitly rejected (not in raw pool)

| Idea | Rejection reason |
|------|------------------|
| Android SMS receiver | User locked: iOS only |
| Notification scraping (Messages banners) | iOS sandbox: UNUserNotificationCenter sees own app only |
| Flutter polling SMS inbox | No public API on stock iOS |
| Jailbreak `sms.db` reader as MVP | Security/update risk; optional fork only |
| WhatsApp transaction ingest | Out of scope; different channel |
| Merge 5 rapid SMS into one row | Violates user idempotency intent |
| EU default-messaging-app path | Impractical for India MVP |

### Cross-cutting combinations (+2)

| # | Title | Summary |
|---|-------|---------|
| 33 | Cloud POST + ingest ledger + rules parser | S1 + #10 + #17 — full pipeline with audit trail |
| 34 | Keyword filter + recovery trio + health UI | #4 + #9 + #14 — operational completeness for Shortcuts fragility |

---

## Adversarial Filter

**Survivor criteria:** (a) aligns with locked iOS+Shortcuts constraints, (b) delivers MVP value, (c) basis is verifiable, (d) low carrying cost for personal app, (e) composes with S1 default path.

### Rejected (representative, 27 ideas)

| Idea | Why rejected |
|------|--------------|
| Sender allowlist per bank (#5) | Premature — keyword filter sufficient for MVP; allowlist is v1.1 polish |
| All-SMS space hack (#6) | Noise/cost too high; keyword filter chosen |
| iOS 26 Search Messages (#15) | Unverified on target device; best-effort only, not MVP dependency |
| Email safety net (#13) | Deferred to v1.1 per scope |
| On-device LLM v1 (#19) | Deferred — rules-only MVP (S3) for v1 |
| Promo filter (#21) | Absorbed into rules parser; not standalone survivor |
| Weekly digest (#28) | Engagement nice-to-have; not core ingestion MVP |
| Raw payload purge (#31) | Planning detail; not ideation survivor |
| Dual-path complexity without toggle (#3 alone) | Kept as implementation detail of S1, not separate survivor |
| Jailbreak daemon | Outside stock iOS identity |
| Android anything | Locked out |
| Notification scraping | Technically blocked |
| Inbox API polling | Technically blocked |
| FCM for SMS ingest | Wrong tool — FCM is HITL only (#26 survives instead) |
| Merge nearby messages | Violates explicit user decision |
| WhatsApp ingest | Outside product identity |
| App Store release path | Locked: personal sideload only |

**Axis coverage:** All 6 axes represented in survivors. No recovery dispatch needed.

---

## Survivors (7)

Ranked by MVP leverage and alignment with locked decisions.

| Rank | ID | Title | Axis | Basis | Why it matters |
|------|-----|-------|------|-------|----------------|
| 1 | **S1** | **Cloud-handoff-first** | Shortcuts contract | direct | Only path that ingests reliably when app is killed. POST → Firestore queue → drain on launch/push. |
| 2 | S2 | Local-only App Group mode | Privacy | direct | User toggle for no raw SMS in cloud; Shortcut → shared container → drain. |
| 3 | — | Keyword-filtered automations | Shortcuts contract | external | Cuts automation volume; `debited`, `INR`, `UPI`, etc. |
| 4 | — | Ingest ledger separate from transactions | Reliability | direct | Raw SMS + parse attempts; re-run rules without re-ingest. |
| 5 | S3 | Rules-heavy parser | Parsing | direct | Indian bank templates; LLM deferred to v1.1. |
| 6 | — | Recovery trio | Reliability | direct | Manual Shortcut + multi-paste + email (email v1.1). |
| 7 | S7 | FCM as product UI | HITL | direct | Ambiguous txn / add-source prompts — not ingestion transport. |

**Combinations absorbed into S1 path:** #3 (POST+URL), #11 (idempotency), #12 (launch drain), #16 (dedupe retries), #33 (full pipeline).

---

## User Selection

**User unavailable — auto-selected survivor:**

> **S1: Cloud-handoff-first** — Shortcuts automation POSTs ingest payload to Firebase Cloud Function; app drains queue on launch and optional FCM wake. Optional URL scheme duplicate when app is foreground.

**Rationale for auto-pick:** Highest reliability on stock iOS when Flutter process is not running. Matches plan recommended default. Other survivors (S2 local toggle, keyword filter, ingest ledger, rules parser, recovery trio, FCM HITL) compose as requirements under S1 rather than competing architectures.

**Brainstorm focus:** Deep-product requirements for S1 + composed survivors. See `docs/brainstorms/money-matters-sms-ledger-requirements.md`.

---

## Next Steps

1. ~~User pick 1–2 survivors~~ → S1 auto-selected
2. ce-brainstorm Deep-product → requirements doc ✓
3. ce-plan when user requests implementation → see `docs/HANDOFF.md`
