# Money Matters — App Icon Brief (External Generation)

**Purpose:** Give designers and image-generation agents everything needed to produce a production-ready **SVG** app icon for Money Matters (iOS personal finance ledger). This document is the single source of truth for creative and technical constraints.

**Do not** embed app screenshots or prior in-repo concept art as mandatory references. Earlier SVG explorations were removed; the goal is a **new** mark that fits this brief.

---

## 1. App name & tagline

| Field | Value |
|-------|--------|
| **App name** | **Money Matters** |
| **Tagline (marketing)** | Turn bank and wallet SMS into a personal spending ledger — automatically, on your iPhone. |
| **Short tagline (optional)** | Your SMS spending ledger. |
| **Bundle ID** | `com.amritdash.moneymatters` (iOS only; sideloaded, not App Store) |

The name is intentional wordplay (see [Creative direction](#6-creative-direction)). The icon should evoke the product idea, not spell the name.

---

## 2. What the app does

Money Matters is a **personal finance ledger for iPhone** built around how people actually spend in **India**: debits, UPI, and card activity arrive as **SMS** from banks and wallets, not as a tidy export from one app.

Because stock iOS does not let third-party apps read the Messages inbox (including sideloaded builds), the app uses **iOS Shortcuts automations** to capture each financial SMS and POST it to the user’s own **Firebase** backend as it arrives—often while the app is closed. When the user opens Money Matters, it drains that queue, **parses** each message with rules-first logic tuned to Indian bank/UPI templates, links spend to saved banks and cards, and rolls everything into **weekly and monthly dashboards** with category breakdowns.

Ambiguous or unmatched items land in a **“Needs your input”** inbox where the user classifies once; the app can remember merchant rules for next time. Optional AI assists when rules are unsure, but the core experience is honest automation plus human review—not a corporate banking portal. Data syncs to the user’s Firebase project and is cached locally (SQLite) for fast, offline-friendly dashboards. Recovery tools cover gaps when Shortcuts fail (manual paste, queue sync, deep links).

In one sentence for icon context: **many scattered money alerts become one calm, organized record the user trusts.**

---

## 3. Target user

| Dimension | Detail |
|-----------|--------|
| **Geography & context** | **India** — UPI, multi-bank SMS, Rupee amounts (`₹`, `INR`, `Rs`), sender IDs like `VK-HDFCBK`, `FEDBNK-S` |
| **Device** | **iPhone**, iOS 17+, installed via Xcode / GitHub Actions sideload (Developer Mode) |
| **Ingestion mental model** | Financial **SMS** + **Shortcuts**, not email scraping or bank APIs |
| **User type** | Individual power user who wants a **private**, self-hosted ledger—not a neobank customer |
| **Jobs the icon should suggest** | Tracking, organizing, and **making sense of** day-to-day spend—not investing, lending, or “wealth management” |

The icon will sit on a personal home screen next to messaging and UPI apps; it should feel **native to that world** without copying their UI clichés.

---

## 4. Brand personality

Money Matters should feel:

- **Friendly and understated** — a helpful personal tool, not a institution
- **Calm and competent** — reliable parsing and review, not hype or gamification
- **Modern iOS-native** — rounded, simple shapes; comfortable on light and dark wallpapers
- **Honest about constraints** — human-in-the-loop when automation is unsure (dignity, not shame)

**Explicitly not:**

- Corporate **banking** or fintech-bro aesthetic (glass towers, shields, vaults, “premium black card”)
- Loud **startup gradient** energy or rainbow “insight pinwheels”
- Aggressive **growth/investing** symbolism (rockets, bull markets, coin stacks implying wealth)

**Stakeholder feedback (lock this in):** Early internal concepts used **bright multicolor** palettes (coral, amber, violet, sky, full-spectrum orbs). The product owner **rejected** that direction. Prefer **muted, two-tone** compositions (see [Icon requirements](#5-icon-requirements)). Warm neutrals plus **one** accent read as more “personal ledger” than “another finance app.”

Reference palette from the latest approved exploration direction (adjust slightly if needed for contrast):

| Role | Hex | Notes |
|------|-----|--------|
| Light background | `#F5F2ED` | Warm off-white |
| Dark background | `#2C3338` | Soft slate (for dark-variant icon) |
| Primary accent | `#C4A574` | Dusty gold — money without coin-bling |
| Alternate accent | `#6B8F71` | Sage — calm “tracking” tone |
| Secondary structure | ~14% opacity of slate on light bg | Ledger lines, dividers |

Avoid **bank green / teal** (#00A86B-style) finance-app defaults.

---

## 5. Icon requirements

### Format & canvas

| Requirement | Specification |
|-------------|----------------|
| **Master format** | **SVG** (vector paths/shapes; no embedded raster photos) |
| **Artboard** | **1024 × 1024** (`viewBox="0 0 1024 1024"`) |
| **Typography** | **None** on the icon — no “MM”, “₹”, words, or monogram letters |
| **Color count** | **Two tones maximum** per variant: background + one accent (secondary structure may use a single muted neutral at low opacity, e.g. 10–20%, still read as one “line” family) |
| **Gradients** | Avoid multistop rainbows; if used at all, one subtle tonal gradient on background only |
| **Small-size legibility** | Must read clearly at **~60×60 pt** (iPhone home screen @2x ≈ 120px) — one dominant silhouette, minimal interior detail |
| **iOS mask** | Design for **squircle** safe area: keep critical shapes inside ~**80–85%** of the canvas center; corners will be clipped by iOS |
| **Corners** | Do not rely on sharp corner anchors; iOS applies continuous corner radius |

### Light / dark

Deliver **two SVG masters** (or one SVG with documented swatches):

1. **Light** — warm off-white field (`#F5F2ED` or equivalent)
2. **Dark** — soft slate field (`#2C3338` or equivalent)

Accent color may stay the same (dusty gold or sage) if contrast passes on both.

### Style

- **Simple geometric or organic-minimal** forms (ledger row, coin disc with mark, single arc/track — not busy illustrations)
- **Filled shapes** preferred over hairline outlines at small sizes
- **No photorealism**, no 3D coin renders, no glassmorphism

### Prior internal explorations (context only)

| Generation | Tone | Owner reaction |
|------------|------|----------------|
| v1 (A/B/C) | SMS bubble + charts, multicolor tiles, orbital bubbles | Too literal / busy |
| v2 (D/E/F) | Coin ribbons, ledger leaf, gathering orbs | Still too colorful / generic sparkle |
| v3 (G/H/I) | Muted 2-tone: ledger row, coin notch, quiet arc | **Aligned** with current taste — use as caliber bar, not copy |

---

## 6. Creative direction

### The “Money Matters” pun

The name carries a **double meaning**:

1. **Money matters** — your finances are important worth caring about.
2. **Money matters** (noun) — individual **matters** / entries / line items in a ledger; “handling money matters” as ongoing maintenance.

The icon should hint at **importance + record-keeping** without illustrating both meanings literally. One strong metaphor is enough.

### Metaphors worth exploring (pick one, execute minimally)

| Metaphor | Visual idea | Why it fits |
|----------|-------------|-------------|
| **Ledger / line that matters** | 2–3 horizontal rules; **one** emphasized (gold) | Parsing many SMS into rows; one transaction highlighted for review |
| **Maintenance / care** | Subtle “tended” mark — notch, pulse, check — on a simple coin or dot | Ongoing upkeep of a personal ledger, not set-and-forget banking |
| **Quiet analytics** | Single rising stroke or arc from one dot | Trends without dashboard clutter (no bar charts) |
| **Indian money culture (abstract)** | Round disc, flow line, or tally — **no ₹ symbol**, no bank logo | UPI/coin familiarity without currency typography |

### Composition guidance

- **One hero shape** centered or slightly off-center; optional **one** secondary mark
- Prefer **vertical or centered** balance over diagonal “ribbon explosions”
- Negative space is a feature — the app UI is data-dense; the icon should **breathe**

### Emotional target

When glanced on the home screen: *“That’s my SMS ledger — calm, mine, not a bank.”*

---

## 7. What to avoid

| Avoid | Reason |
|-------|--------|
| **Rainbow orbs / pinwheels / multicolor ribbons** | Rejected; reads as generic “AI app” or old concepts C/F |
| **SMS speech bubble + bar chart** | Overused fintech cliché; v1 fatigue |
| **Message bubbles orbiting a center** | Literally depicts inbox the app cannot access |
| **Bank green / teal** | Instantly signals corporate finance |
| **Letters, “M” monogram, wordmark** | Illegible at small size; violates brief |
| **₹ rupee glyph or “INR”** | Typography; also narrows to currency mark not ledger |
| **Vault, shield, lock, credit card silhouette** | Security/bank marketing tropes |
| **Stock charts, candlesticks, bull horns** | Investing, not personal spend tracking |
| **Neon gradients, holographic spheres** | Conflicts with muted brand |
| **Coin stacks / gold bars** | Wealth flex, not SMS ledger |
| **Too many category-colored tiles** | v1 B direction; busy at 60px |

---

## 8. Technical deliverables (when finalized)

When a direction is approved, hand off the following to the engineering repo (`Money Matters`):

### Required files

Place in **`docs/assets/app-icon/`** (see that folder’s README):

| Deliverable | Spec |
|-------------|------|
| **`app-icon-master-light.svg`** | 1024×1024, light background variant |
| **`app-icon-master-dark.svg`** | 1024×1024, dark background variant |
| **Optional:** single SVG with named layers / CSS variables for swatches | Document swap values for export |

Do not commit PNG masters under `docs/assets/app-icon/`. After SVGs land, the maintainer runs `./scripts/export_app_icons.sh` to populate `AppIcon.appiconset` (and launch splash).

### iOS App Icon PNG export

Export from the chosen SVG into:

`ios/Runner/Assets.xcassets/AppIcon.appiconset/`

Filenames must match `Contents.json` (maintainer runs export script or Asset Catalog):

| Filename | Size (pt) | Scale | Pixels |
|----------|-----------|-------|--------|
| `Icon-App-20x20@2x.png` | 20 | 2x | 40 |
| `Icon-App-20x20@3x.png` | 20 | 3x | 60 |
| `Icon-App-29x29@1x.png` | 29 | 1x | 29 |
| `Icon-App-29x29@2x.png` | 29 | 2x | 58 |
| `Icon-App-29x29@3x.png` | 29 | 3x | 87 |
| `Icon-App-40x40@2x.png` | 40 | 2x | 80 |
| `Icon-App-40x40@3x.png` | 40 | 3x | 120 |
| `Icon-App-60x60@2x.png` | 60 | 2x | 120 |
| `Icon-App-60x60@3x.png` | 60 | 3x | 180 |
| `Icon-App-20x20@1x.png` | 20 | 1x | 20 (iPad) |
| `Icon-App-20x20@2x.png` | 20 | 2x | 40 (iPad) |
| `Icon-App-29x29@1x.png` | 29 | 1x | 29 (iPad) |
| `Icon-App-29x29@2x.png` | 29 | 2x | 58 (iPad) |
| `Icon-App-40x40@1x.png` | 40 | 1x | 40 (iPad) |
| `Icon-App-40x40@2x.png` | 40 | 2x | 80 (iPad) |
| `Icon-App-76x76@1x.png` | 76 | 1x | 76 (iPad) |
| `Icon-App-76x76@2x.png` | 76 | 2x | 152 (iPad) |
| `Icon-App-83.5x83.5@2x.png` | 83.5 | 2x | 167 (iPad Pro) |
| **`Icon-App-1024x1024@1x.png`** | 1024 | 1x | **1024** (App Store / marketing slot; required in asset catalog) |

**Export notes:**

- Apply **iOS squircle mask** at export (or export square PNG and let Xcode/asset pipeline mask — be consistent)
- PNG: sRGB, no transparency for home-screen icons (opaque background)
- Update **`ios/Runner/Assets.xcassets/AppIcon.appiconset/`** (including `Icon-App-1024x1024@1x.png` used in the README) after lock-in

### Verification

After export: `./scripts/build_ipa.sh` or Xcode → Run on physical iPhone; confirm readability on light and dark wallpapers.

---

## Appendix: Product facts for accuracy

| Topic | Fact |
|-------|------|
| Platform | iOS only; no Android |
| Distribution | Sideload (Developer Mode), not App Store |
| Ingest | Shortcuts POST → Firebase `ingestSms` → app drain |
| Parsing | Rules-first Indian SMS; optional Gemini for ambiguous cases |
| Primary UI | Dashboard (weekly/monthly), Review inbox, Accounts, Recovery |
| Deep link scheme | `moneymatters://` |

**References in repo (optional reading):** `README.md`, `docs/HANDOFF.md`, `docs/plans/money-matters-build-plan.md`.

---

*Brief version: 2026-06-02 — for external SVG icon generation.*
