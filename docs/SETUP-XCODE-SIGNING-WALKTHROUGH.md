# Xcode signing walkthrough (then GitHub IPA)

You already have: **Team ID** `F4TFHKUQDA`, **Apple Development** cert, **manual profiles** downloaded, **App Attest** in Firebase.

This guide is only about linking the **Money Matters** app to your Personal Team in Xcode, then exporting files for GitHub Actions.

---

## Part A — Open the right project in Xcode

### 1. Open the workspace (not the `.xcodeproj` alone)

From Terminal:

```bash
cd "/Users/amrit/Downloads/DEV/Mobile App/Money Matters"
open ios/Runner.xcworkspace
```

Or in Finder: go to the project folder → `ios` → double-click **`Runner.xcworkspace`** (white Xcode icon).

**Why workspace?** Flutter iOS builds expect the workspace. The plain `Runner.xcodeproj` is the app shell inside it.

### 2. Wait for Xcode to finish indexing

First open may take a minute. If it asks to install extra components, accept only if prompted for **platform support** you need; Simulator runtime is still optional.

---

## Part B — Signing & Capabilities (the important screen)

### 3. Select the app target

In the **left sidebar** (Project Navigator):

1. Click the **blue “Runner” icon** at the very top (the project, not a folder).
2. In the main editor, under **TARGETS**, click **Runner** (the app — not `RunnerTests`).

### 4. Open Signing tab

At the top of the main editor, click **Signing & Capabilities**.

### 5. Configure signing

| Setting | What to choose |
|--------|----------------|
| **Automatically manage signing** | Turn **ON** (checked) |
| **Team** | **Amrit Dash (Personal Team)** — should show `F4TFHKUQDA` |
| **Bundle Identifier** | `com.moneymatters.moneyMatters` (must match Firebase / App ID) |

### 6. Success looks like this

Under **Signing (Debug)** and **Signing (Release)** you should see green text similar to:

- *Signing Certificate: Apple Development: …*
- *Provisioning Profile: Xcode Managed Profile* or a profile name including your app

If you see a **red error**:

| Error | Fix |
|-------|-----|
| No profiles for bundle ID | Xcode → **Settings → Accounts** → your account → **Download Manual Profiles** again |
| Failed to register bundle ID | Ensure App ID exists at [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list) |
| No signing certificate | **Manage Certificates…** → **+** → **Apple Development** |

You do **not** need to plug in your iPhone for this step. You are only telling Xcode which team signs the app.

### 7. Save and quit (optional)

**File → Close Project** or leave Xcode open. No Archive required for the GitHub path.

---

## Part C — Export files for GitHub Actions

GitHub needs a **`.p12`** (certificate + private key) and a **`.mobileprovision`** file.

### 8. Export the `.p12` certificate

1. Open **Keychain Access** (Spotlight → “Keychain Access”).
2. Left sidebar: **login** keychain → category **My Certificates**.
3. Find **Apple Development: Amrit Dash (…)** or similar.
4. Expand the row (▶) — there must be a **private key** underneath. If there is no private key, create the cert again in Xcode (**Manage Certificates → + → Apple Development**).
5. Select the **certificate** row (not only the key).
6. Menu **File → Export Items…**
7. Format: **Personal Information Exchange (.p12)** → save e.g. `MoneyMatters-Dev.p12` → set a password → remember it (**`P12_PASSWORD`** secret).

### 9. Find the provisioning profile file

After **Download Manual Profiles** or successful signing in Part B, profiles live here:

```bash
open ~/Library/MobileDevice/Provisioning\ Profiles/
```

- Double-click any `.mobileprovision` whose name mentions **Money Matters** or **`com.moneymatters.moneyMatters`**.
- Or copy one to Desktop, e.g. `MoneyMatters.mobileprovision`.

Verify bundle ID:

```bash
security cms -D -i ~/path/to/profile.mobileprovision | grep -A1 application-identifier
```

Should contain `com.moneymatters.moneyMatters`.

### 10. Push GitHub secrets

```bash
cd "/Users/amrit/Downloads/DEV/Mobile App/Money Matters"
./scripts/encode_signing_secrets.sh ~/Desktop/MoneyMatters-Dev.p12 ~/Desktop/MoneyMatters.mobileprovision
```

When prompted `y`, it uploads cert + profile. Then:

```bash
gh secret set P12_PASSWORD --repo amrit-dash/Money-Matters
# enter the .p12 export password

gh secret set KEYCHAIN_PASSWORD --repo amrit-dash/Money-Matters
# any random string, e.g. output of: openssl rand -base64 24
```

Already set: `GOOGLE_SERVICE_INFO_PLIST_BASE64`, `APPLE_TEAM_ID`.

### 11. Build the IPA on GitHub

1. Push latest code to `main` (if you have local doc/project changes).
2. GitHub → **Actions** → **iOS IPA** → **Run workflow**.
3. Download artifact **MoneyMatters-ipa** → install on iPhone (Sideloadly / AltStore / Finder).

---

## Part D — App Check on the device (after IPA installs)

App Attest is registered in Firebase. The app still ships with App Check **off** until you opt in:

```bash
# GitHub: add to workflow later, or local:
flutter build ipa --release --dart-define=ENABLE_APP_CHECK=true
```

Test on a **physical iPhone** first. When Auth/Firestore work, set **Enforce** in Firebase Console (keep `ingestSms` unenforced).

---

## Quick checklist

- [ ] Opened `Runner.xcworkspace`
- [ ] Target **Runner** → **Signing & Capabilities** → Team **Personal Team**
- [ ] Green signing status for Debug/Release
- [ ] Exported `.p12` with private key
- [ ] Located `.mobileprovision` for `com.moneymatters.moneyMatters`
- [ ] Ran `encode_signing_secrets.sh` + `P12_PASSWORD` + `KEYCHAIN_PASSWORD`
- [ ] GitHub Actions **iOS IPA** succeeded
- [ ] Installed IPA on iPhone
