# Install on iPhone without local Xcode

Use a **cloud Mac builder** to compile and sign the IPA. You still need an **Apple Developer account** (free or paid) and a way to install the IPA on your phone (AltStore, Apple Configurator, or Xcode Devices window on any Mac you borrow).

## Tradeoffs

| | Local Xcode | Cloud build (Codemagic / GitHub Actions) |
|---|-------------|------------------------------------------|
| Disk / install | ~12 GB Xcode on your Mac | No Xcode on your Mac |
| Apple account | Required | **Still required** (signing) |
| Install to iPhone | USB Run from Xcode | Download IPA → sideload |
| Shortcuts / SMS | Same | Same (on device) |
| Iteration speed | Fastest loop | Queue + build minutes |
| Firebase / Flutterfire | Either | Either |

**You cannot skip Apple signing entirely** for a real device. Cloud build only moves *compilation* off your machine.

## Recommended: Codemagic (simplest UI)

1. Push this repo to GitHub/GitLab/Bitbucket (private is fine).
2. Sign up at [codemagic.io](https://codemagic.io) → add application → select repo.
3. Codemagic detects [`codemagic.yaml`](../codemagic.yaml) at repo root.
4. **Code signing** (first time):
   - Connect Apple Developer account in Codemagic → **Automatic code signing**
   - Bundle ID: `com.moneymatters.moneyMatters`
   - Distribution type for personal testing: **Development** or **Ad Hoc** (register your iPhone UDID in Apple Developer → Devices).
5. Add environment variable or ensure `ios/Runner/GoogleService-Info.plist` is in the repo **or** upload as Codemagic secret file (plist is gitignored locally — for CI, use Codemagic’s **Secure files** or commit a copy to a private repo).
6. Start build → download **IPA** artifact.
7. Install IPA:
   - **AltStore / Sideloadly** on Windows/Mac, or
   - Any Mac with Xcode → Window → Devices → install IPA, or
   - Paid dev account → TestFlight (extra setup).

## Alternative: GitHub Actions

See [`.github/workflows/ios-ipa.yml`](../.github/workflows/ios-ipa.yml). Requires:

- Repo on GitHub
- Secrets: `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `BUILD_PROVISION_PROFILE_BASE64`, `KEYCHAIN_PASSWORD` (documented in workflow comments)

More manual than Codemagic for first-time iOS signing.

## What we already configured (Firebase)

- Project: **`money-matters-amrit`**
- iOS app + `GoogleService-Info.plist` (local, gitignored)
- `lib/core/config/firebase_options.dart` wired

## Still required in Firebase Console (you)

1. **Authentication** → enable Email/Password
2. **Firestore** → create database
3. **Blaze plan** → required before deploying `ingestSms` Cloud Function
4. Deploy from your machine (no Xcode needed):

   ```bash
   cd firebase
   firebase login   # if needed
   firebase deploy --only functions,firestore:rules
   ```

5. Copy **INGEST_URL** from deploy output into Shortcuts (see `docs/shortcuts/setup.md`).

## After IPA is on your iPhone

Follow [`SETUP-IPHONE.md`](SETUP-IPHONE.md) from **step 9** onward (onboarding, device token, Shortcuts automations).
