# Money Matters

**Turn bank and wallet SMS into a personal spending ledger — automatically, on your iPhone.**

[![Flutter](https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-lightgrey?logo=apple)](docs/SETUP-IPHONE.md)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Money Matters is a personal finance ledger built for **stock iOS**. Because sideloaded apps cannot read your Messages inbox, the app uses **iOS Shortcuts automations** to capture incoming financial SMS and hand them off to a Firebase ingest queue. When you open the app, it drains the queue, parses each message with **rules-first logic**, and surfaces weekly and monthly spending insights — with a human-in-the-loop inbox for anything ambiguous.

Designed for sideload install via Xcode or GitHub Actions — not the App Store.

---

## Table of contents

- [What it does](#what-it-does)
- [How it works](#how-it-works)
- [Features](#features)
- [Screenshots](#screenshots)
- [Platform notes](#platform-notes)
- [Getting started](#getting-started)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Project structure](#project-structure)
- [License](#license)

---

## What it does

In India, most day-to-day spending arrives as SMS from banks, UPI apps, and card issuers. Money Matters closes the gap between those messages and a usable ledger:

1. **Capture** — iOS Shortcuts POST each financial SMS to the cloud as it arrives (no need to open the app).
2. **Parse** — A rules engine extracts amount, merchant, debit/credit type, and payment source; optional Gemini AI assists when rules are unsure.
3. **Organize** — Transactions link to your saved banks and cards, roll up into categories, and feed weekly/monthly analytics.
4. **Review** — Ambiguous or unmatched items land in a **Needs your input** inbox where you classify once and teach the app for next time.

All data syncs to your personal Firebase project and is cached locally in SQLite for fast dashboards offline.

---

## How it works

```
  Bank SMS ──► iOS Shortcuts ──► Firebase ingestSms ──► Firestore queue
                                                              │
  You open app ◄── Dashboard / Review ◄── Parse pipeline ◄────┘
                      ▲
                      └── SQLite cache + Firestore sync
```

**Deep links** (`moneymatters://`) open Recovery, Classify, or trigger a queue sync from Shortcuts without navigating manually.

---

## Features

### 📱 SMS ingestion via Shortcuts

- Personal Automation fires on financial keywords (`debited`, `UPI`, `INR`, `Rs`, `payment`, and more).
- Each SMS POSTs once to a secured Cloud Function — idempotent on exact duplicates.
- Onboarding walks you through ingest URL, bearer token, and device ID setup.

### 🧠 Rules-first parsing

- Extracts amount, merchant, timestamp, and debit vs credit from Indian bank/card SMS templates.
- Filters false positives — loan offers, EMI reminders, and balance-only marketing are rejected even when they contain amounts.
- Matches transactions to saved accounts using SMS sender hints, bank names in the body, and last-four digits.

### 📊 Spending dashboard

- **Weekly** and **monthly** views with period-over-period comparison.
- Totals, category breakdown charts, and per-source (bank/card) spend.
- **Unmatched** bucket for SMS that don't map to a saved account — excluded from totals until resolved.
- Pull-to-sync drains the ingest queue on demand.

### 🏷️ Categories & classification

- Nine default categories (food, groceries, transport, shopping, bills, entertainment, health, transfer, other) synced to Firestore.
- Merchant rules learned when you classify with "remember this merchant."
- Optional **Gemini AI** auto-classification via Cloud Functions for ambiguous debits (rules + manual classify work without any API key).

### 📥 Needs your input inbox

- Primary path for unresolved transactions — works without push notifications or a paid Apple Developer account.
- Full-screen classify flow: pick category, payment source, add notes or shopping items, view original SMS.
- Optional FCM push prompts when a paid Apple account and APNs are configured.

### 🏦 Accounts

- Add and edit banks and cards with SMS sender ID hints (e.g. `FEDBNK-S`, `VK-HDFCBK`).
- Saving account changes re-processes the backlog to rematch existing transactions.

### 🔄 Recovery & sync

- Pipeline status: pending ingests, failed parses, queue depth.
- **Sync now** drains and re-parses the queue.
- Manual paste for SMS that Shortcuts missed — single or batch.
- Shortcut B opens the app directly to Recovery via `moneymatters://recovery`.

### 🔐 Account & privacy

- Sign in with **email/password** or **Google**.
- Profile hub: reconnect SMS setup, manage accounts, view Gemini status.
- **Delete all data** — permanently removes transactions, ingests, accounts, categories, and device tokens from device and cloud (account kept until you sign out).

---

## Screenshots

| Dashboard | Needs your input |
| :---: | :---: |
| ![Dashboard](https://i.ibb.co/RkwbYx0P/image-2026-06-02-164708714.png) | ![Needs your input](https://i.ibb.co/fVkKpHhY/image.png) |
| *Weekly spend, categories, sync* | *Ambiguous transactions queue* |

| Classify | Accounts |
| :---: | :---: |
| ![Classify](https://i.ibb.co/k28SLVbT/image.png) | ![Accounts](https://i.ibb.co/d0g04m9x/image.png) |
| *Category, source, merchant rules* | *Banks, cards, sender hints* |

| Recovery |
| :---: |
| ![Recovery](https://i.ibb.co/YBJH15Xq/image.png) |
| *Queue status, manual paste* |

---

## Platform notes

| | |
|---|---|
| **Target** | iPhone, iOS 17+, sideloaded (Developer Mode) |
| **Not supported** | Android, App Store distribution, direct SMS inbox access |
| **Backend** | Personal Firebase (Auth, Firestore, Cloud Functions, optional FCM) |
| **Local storage** | SQLite via sqflite for fast reads and offline cache |

Stock iOS does not expose the Messages database to third-party apps. Shortcuts automations are the supported ingestion path; Recovery covers gaps when automations fail or are disabled.

---

## Getting started

Full setup lives in the docs — the README stays focused on the product.

| Goal | Start here |
|------|------------|
| Install on iPhone (no local Xcode) | [`docs/SETUP-GITHUB-ACTIONS.md`](docs/SETUP-GITHUB-ACTIONS.md) |
| Install on iPhone (local Xcode) | [`docs/SETUP-IPHONE.md`](docs/SETUP-IPHONE.md) |
| Configure Shortcuts automations | [`docs/shortcuts/setup.md`](docs/shortcuts/setup.md) |
| Deploy Firebase backend | [`firebase/README.md`](firebase/README.md) |

Quick sanity check after setup:

```bash
./scripts/verify_setup.sh
flutter analyze && flutter test
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/HANDOFF.md`](docs/HANDOFF.md) | Build status, production pass notes, next steps |
| [`USER-FIX.md`](USER-FIX.md) | Post-deploy verification (Gemini, sender hints, FCM) |
| [`docs/plans/money-matters-build-plan.md`](docs/plans/money-matters-build-plan.md) | Architecture, file ownership, integration plan |
| [`docs/brainstorms/money-matters-sms-ledger-requirements.md`](docs/brainstorms/money-matters-sms-ledger-requirements.md) | Product requirements and acceptance criteria |
| [`docs/FIRESTORE-DATA-MODEL.md`](docs/FIRESTORE-DATA-MODEL.md) | Firestore collections, fields, and data flow |
| [`docs/shortcuts/setup.md`](docs/shortcuts/setup.md) | Shortcuts Automation A (ingest) and B (sync) |
| [`docs/shortcuts/payload-examples.json`](docs/shortcuts/payload-examples.json) | Sample ingest POST bodies for testing |
| [`docs/ideation/2026-05-29-money-matters-ios-shortcuts-ideation.md`](docs/ideation/2026-05-29-money-matters-ios-shortcuts-ideation.md) | Ideation survivors and architecture selection |
| [`firebase/README.md`](firebase/README.md) | Cloud Functions, deploy, curl tests, secrets |
| [`docs/SETUP-IPHONE.md`](docs/SETUP-IPHONE.md) | Primary iPhone install checklist |
| [`docs/SETUP-GITHUB-ACTIONS.md`](docs/SETUP-GITHUB-ACTIONS.md) | Install IPA via GitHub Actions |
| [`docs/FIREBASE-BUNDLE-ID.md`](docs/FIREBASE-BUNDLE-ID.md) | Canonical bundle ID (`com.amritdash.moneymatters`) |
| [`AGENTS.md`](AGENTS.md) | Agent instructions and `docs/solutions/` index |

Additional setup guides (signing, Xcode, App Check) are in [`docs/`](docs/).

---

## Contributing

| Resource | Description |
|----------|-------------|
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Issues, PRs, local checks, and `docs/solutions/` |
| [`CHANGELOG.md`](CHANGELOG.md) | Release history ([Keep a Changelog](https://keepachangelog.com/)) |
| [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Community standards |
| [`SECURITY.md`](SECURITY.md) | Report vulnerabilities privately |
| [Bug report template](.github/ISSUE_TEMPLATE/bug_report.md) | Report a defect |
| [Feature request template](.github/ISSUE_TEMPLATE/feature_request.md) | Propose a feature |
| [Pull request template](.github/pull_request_template.md) | PR checklist |

---

## Project structure

```
lib/
├── features/
│   ├── onboarding/     Auth, payment sources, Shortcuts setup
│   ├── dashboard/    Weekly/monthly analytics, drill-downs
│   ├── review/       Needs your input inbox + classify flow
│   ├── recovery/     Queue sync, manual paste, pipeline status
│   ├── accounts/     Bank and card CRUD with sender hints
│   └── profile/      Settings, sign out, delete all data
├── ingest/             Firestore queue drain, deep link handler
├── parse/              Rules parser, optional LLM gate
├── models/             Domain models (transaction, category, …)
└── services/           Auth, categories, payment sources, pipeline

firebase/functions/     ingestSms, classifyTransaction, notifyClassification
docs/                   Setup guides, specs, shortcuts
test/                   Parser fixtures and service tests
```

---

## License

[MIT](LICENSE) — Copyright (c) 2026 Amrit Dash
