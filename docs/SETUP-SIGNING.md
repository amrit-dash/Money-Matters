# iOS signing for GitHub Actions IPA

Goal: produce an **installable `.ipa`** on your iPhone. GitHub’s `macos-latest` runner has Xcode; you only create Apple certificates and provisioning profiles once, then store them as GitHub secrets.

**Have Xcode but skipping the ~10 GB iOS Simulator download?** That download is only for Simulator runs. Device IPAs use the SDK bundled inside Xcode — see **[SETUP-XCODE-MINIMAL.md](SETUP-XCODE-MINIMAL.md)** for Team ID + optional local build.

**Bundle ID:** `com.moneymatters.moneyMatters`  
**Repo workflow:** [`.github/workflows/ios-ipa.yml`](../.github/workflows/ios-ipa.yml)

App Check is **disabled** in the app for now. In Firebase Console → App Check, keep **Firestore** and **Authentication** on **Unenforced** until you enable App Check later.

---

## Checklist

| Step | What |
|------|------|
| 1 | iPhone **UDID** registered in Apple Developer |
| 2 | **App ID** for `com.moneymatters.moneyMatters` |
| 3 | **Apple Development** certificate (.p12) |
| 4 | **iOS App Development** provisioning profile (includes your UDID) |
| 5 | Five GitHub secrets (four signing + plist already set) |
| 6 | Run **Actions → iOS IPA** → download **MoneyMatters-ipa** |

---

## 1. Get your iPhone UDID

Pick one:

- On iPhone: open [get.udid.io](https://get.udid.io) in Safari and follow the profile install flow.
- On a Mac (any): connect the phone → **Finder** → select device → click serial number until **UDID** appears → copy.

You will add this UDID when creating the provisioning profile.

---

## 2. Apple Developer portal

Sign in at [developer.apple.com/account](https://developer.apple.com/account).

### Team ID

You need a **10-character Team ID** (e.g. `AB12CD34EF`). Find it under **Membership details**, or extract it later from the `.mobileprovision` using `./scripts/encode_signing_secrets.sh`.

If the Certificates page shows **“Team ID … does not belong to your team”**, sign out, sign back in, and do **not** use IDs from old Xcode projects. Free **Personal Team** accounts can still create Development certs and profiles once the portal lists your team.

### Register the App ID

1. **Certificates, Identifiers & Profiles → Identifiers → +**
2. **App IDs → App** → Description: `Money Matters`
3. Bundle ID: **Explicit** → `com.moneymatters.moneyMatters`
4. Enable capabilities you need (Push is optional for MVP). Save.

### Register your device

1. **Devices → +** → name + paste **UDID** → Continue.

---

## 3. Development certificate (.p12)

On your Mac (Keychain Access only — no full Xcode required):

1. **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority**
2. Email: your Apple ID email; **Saved to disk** → save `CertificateSigningRequest.certSigningRequest`
3. Portal → **Certificates → +** → **Apple Development** → upload CSR → Download `development.cer`
4. Double-click `development.cer` to install in Keychain
5. Keychain → **My Certificates** → expand **Apple Development: …** → right-click the **private key** row → **Export** → `.p12` → set a password (remember it → `P12_PASSWORD` secret)

---

## 4. Provisioning profile

1. Portal → **Profiles → +** → **iOS App Development**
2. App ID: `com.moneymatters.moneyMatters`
3. Certificate: your new Development cert
4. Devices: your iPhone
5. Name e.g. `Money Matters Development` → Download `.mobileprovision`

---

## 5. GitHub secrets

Already set (if you ran the script earlier):

| Secret | Status |
|--------|--------|
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | From `./scripts/setup_github_secrets.sh` |

Set signing secrets:

```bash
chmod +x scripts/encode_signing_secrets.sh
./scripts/encode_signing_secrets.sh ~/Downloads/MoneyMatters.p12 ~/Downloads/MoneyMatters_Development.mobileprovision
```

When prompted, set:

| Secret | Value |
|--------|--------|
| `BUILD_CERTIFICATE_BASE64` | Your `.p12` (script can upload) |
| `P12_PASSWORD` | Password you chose when exporting `.p12` |
| `BUILD_PROVISION_PROFILE_BASE64` | Your `.mobileprovision` |
| `KEYCHAIN_PASSWORD` | Any random string (only used on the CI runner) |
| `APPLE_TEAM_ID` | Optional; CI also reads Team ID from the profile |

Manual alternative:

```bash
gh secret set P12_PASSWORD --repo amrit-dash/Money-Matters
gh secret set KEYCHAIN_PASSWORD --repo amrit-dash/Money-Matters
base64 -i cert.p12 | gh secret set BUILD_CERTIFICATE_BASE64 --repo amrit-dash/Money-Matters
base64 -i profile.mobileprovision | gh secret set BUILD_PROVISION_PROFILE_BASE64 --repo amrit-dash/Money-Matters
```

Update local export plist for reference (optional if you only use CI):

```bash
# Shows Team ID and profile name
./scripts/encode_signing_secrets.sh cert.p12 profile.mobileprovision
# Edit ios/ExportOptions.plist → teamID
```

---

## 6. Build and install

1. GitHub → **Actions → iOS IPA → Run workflow** (or push to `main`).
2. Wait for green job → **Artifacts → MoneyMatters-ipa** → download `.ipa`.
3. Install on device:
   - **Sideloadly** / **AltStore** (Windows/Mac), or
   - Mac with **Apple Configurator** / **Finder** (Devices).

Trust the developer profile on iPhone: **Settings → General → VPN & Device Management**.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Workflow builds unsigned only | `BUILD_CERTIFICATE_BASE64` empty or detect step failed — re-run `encode_signing_secrets.sh` |
| `No signing certificate` on CI | `.p12` must include private key; use partition list step (already in workflow) |
| `Provisioning profile doesn't match` | Profile must be for `com.moneymatters.moneyMatters` and include your UDID |
| App installs but Firebase auth fails | Confirm `GOOGLE_SERVICE_INFO_PLIST_BASE64`; test Google Sign-In on **device** |
| Portal Team ID errors | Use only Team ID from **your** Membership or from the downloaded profile |

---

## Related docs

- [SETUP-GITHUB-ACTIONS.md](SETUP-GITHUB-ACTIONS.md) — workflow overview
- [SETUP-IPHONE.md](SETUP-IPHONE.md) — Shortcuts + onboarding after install
- [APP-CHECK.md](APP-CHECK.md) — enable later with `ENABLE_APP_CHECK=true`
