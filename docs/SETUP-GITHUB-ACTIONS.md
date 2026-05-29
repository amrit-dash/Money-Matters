# iPhone install via GitHub Actions (no local Xcode)

GitHub’s `macos-latest` runners **include Xcode**. You never install Xcode on your Mac; you only need git, GitHub, and Apple Developer credentials for signing.

Primary cloud path: [`.github/workflows/ios-ipa.yml`](../.github/workflows/ios-ipa.yml).

**Automated:** `GOOGLE_SERVICE_INFO_PLIST_BASE64` can be set via `./scripts/setup_github_secrets.sh` (already run if you used it after push).

**Installable IPA:**  
- **Free Apple account (Personal Team):** **[SETUP-SIGNING-FREE-ACCOUNT.md](SETUP-SIGNING-FREE-ACCOUNT.md)** — Xcode only; ignore developer.apple.com Certificates pages.  
- **Paid $99/year program:** [SETUP-SIGNING.md](SETUP-SIGNING.md) / portal guides.

App Check is off until you opt in later.

## What you need

| Item | Where |
|------|--------|
| GitHub repo (private recommended) | Push this project |
| Apple Developer account | [developer.apple.com](https://developer.apple.com) |
| iPhone UDID | Xcode → Devices (borrow a Mac once) **or** [get.udid.io](https://get.udid.io) on device |
| Development cert + provisioning profile | Apple Developer → Certificates, Identifiers & Profiles |
| Firebase plist | Already on your Mac; add as GitHub secret for CI |

## One-time GitHub secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**

### Required for CI builds

| Secret | Value |
|--------|--------|
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | `base64 -i ios/Runner/GoogleService-Info.plist \| pbcopy` (paste) |

### Required for **installable** IPA on your iPhone

See **[SETUP-SIGNING.md](SETUP-SIGNING.md)** for step-by-step export. Quick upload:

```bash
./scripts/encode_signing_secrets.sh path/to/cert.p12 path/to/profile.mobileprovision
```

| Secret | Value |
|--------|--------|
| `BUILD_CERTIFICATE_BASE64` | **Apple Development** `.p12` as base64 |
| `P12_PASSWORD` | Password for the `.p12` |
| `BUILD_PROVISION_PROFILE_BASE64` | `.mobileprovision` for `com.moneymatters.moneyMatters` + your UDID |
| `KEYCHAIN_PASSWORD` | Any random string (workflow-only) |
| `APPLE_TEAM_ID` | Optional; CI reads Team ID from the profile if omitted |

CI generates `ios/ExportOptions.ci.plist` from the profile during the build (manual signing + profile name).

## Run a build

1. Push to `main` or **Actions → iOS IPA → Run workflow**.
2. If signing secrets are set → download **MoneyMatters-ipa** artifact.
3. Install on iPhone: **Apple Configurator**, **Sideloadly**, **AltStore**, or any Mac with Finder/Devices.

Without signing secrets, the workflow still runs **analyze + test + unsigned ios build** (not installable on device).

## Google Sign-In checklist (Firebase + iOS)

Already configured in repo if you downloaded the **updated** plist after enabling Google in Firebase:

- [x] `GoogleService-Info.plist` includes `CLIENT_ID` and `REVERSED_CLIENT_ID`
- [x] `Info.plist` URL scheme for `REVERSED_CLIENT_ID`
- [x] `firebase_options.dart` → `iosClientId`
- [ ] Firebase Console → Authentication → Google → **support email** set, provider enabled
- [ ] Test on **physical device** (Google Sign-In is unreliable on Simulator)

## After IPA is installed

1. Deploy backend (if not done): `cd firebase && firebase deploy --only functions,firestore:rules`
2. Copy **INGEST_URL** into Shortcuts — [`docs/shortcuts/setup.md`](shortcuts/setup.md)
3. Complete onboarding in app → register device token → enable Message automation

## Firebase project

**`money-matters-amrit`** — Blaze, Auth (Email + Google), Firestore enabled.
