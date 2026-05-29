# Money Matters — iPhone live test setup

Complete these steps **in order** on your Mac and physical iPhone. Nothing ingests real SMS until Firebase, signing, and Shortcuts are configured on your side.

---

## Order of operations (1 → 12)

| Step | What | Who |
|------|------|-----|
| 1 | Apple Developer + Xcode + iPhone Developer Mode | **You** |
| 2 | Create Firebase project (Auth, Firestore, Blaze) | **You** |
| 3 | Set Firebase project ID in `firebase/.firebaserc` | **You** |
| 4 | Deploy Cloud Functions + Firestore rules | **You** |
| 5 | Download `GoogleService-Info.plist` → `ios/Runner/` | **You** |
| 6 | Run `flutterfire configure` | **You** |
| 7 | Verify local setup (`scripts/verify_setup.sh`) | **You** |
| 8 | Install app on iPhone (Path A or B below) | **You** |
| 9 | Sign in / complete onboarding in app | **You** |
| 10 | Register device ingest token (Bearer auth) | **You** (via app onboarding) |
| 11 | Build Shortcuts automations | **You** |
| 12 | Send test SMS → confirm dashboard | **You** |

Steps 1–8 block everything else. Shortcuts (11) require a **physical iPhone** — Message automations do not run reliably in Simulator.

---

## YOU must do (manual)

### 1. Apple Developer, Xcode, and iPhone Developer Mode

1. **Apple Developer account** — free Apple ID works for 7-day signing (re-install weekly); paid membership ($99/yr) for longer provisioning profiles and TestFlight.
2. **Install Xcode 15+** from the App Store (full app, not Command Line Tools only).
3. After install, run once in Terminal:

   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

4. **CocoaPods** (required for Flutter iOS plugins):

   ```bash
   sudo gem install cocoapods
   # or: brew install cocoapods
   ```

5. **Flutter** — confirm with `flutter doctor`; fix any iOS/Xcode items before building.

6. **On your iPhone (iOS 17+):**
   - Settings → Privacy & Security → **Developer Mode** → ON (device restarts).
   - Connect iPhone to Mac via USB (or enable wireless debugging in Xcode later).
   - When prompted on device, tap **Trust This Computer**.

7. **In Xcode** (after step 6 below): open `ios/Runner.xcworkspace` → select **Runner** target → **Signing & Capabilities** → choose your **Team** → ensure Bundle Identifier is `com.moneymatters.moneyMatters`.

### 2. Create Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/) → **Create a project** (or use existing).
2. **Authentication** → Sign-in method → enable **Email/Password** (Apple Sign-In optional for later).
3. **Firestore Database** → Create database (production mode; rules deploy from this repo).
4. **Upgrade to Blaze** (pay-as-you-go) — required for Cloud Functions with outbound networking.
5. Register an **iOS app** in Project settings:
   - Bundle ID: `com.moneymatters.moneyMatters`
   - Download **`GoogleService-Info.plist`** (step 5 below).

See also: [`firebase/README.md`](../firebase/README.md).

### 3. Configure Firebase project ID

Edit [`firebase/.firebaserc`](../firebase/.firebaserc) or run from the `firebase/` directory:

```bash
cd firebase
firebase login
firebase use --add YOUR_FIREBASE_PROJECT_ID
```

Replace `YOUR_FIREBASE_PROJECT_ID` with your actual project ID.

### 4. Deploy functions and Firestore rules

```bash
cd firebase
npm ci
npm run build
firebase deploy --only functions,firestore:rules
```

After deploy, copy the **`ingestSms`** URL from the output (region `asia-south1`):

```text
https://asia-south1-YOUR_FIREBASE_PROJECT_ID.cloudfunctions.net/ingestSms
```

Save this as **`INGEST_URL`** for Shortcuts and app onboarding.

Quick curl test (optional, after step 10): see [`firebase/README.md`](../firebase/README.md#curl-example).

### 5. Add GoogleService-Info.plist

1. Firebase Console → Project settings → Your apps → iOS app → download **`GoogleService-Info.plist`**.
2. Place it at:

   ```text
   ios/Runner/GoogleService-Info.plist
   ```

3. In Xcode, confirm the file appears under the **Runner** group (drag in if needed). **Do not commit** this file to git if the repo is shared publicly.

### 6. Run flutterfire configure

From the **repo root** (`Money Matters/`):

```bash
# One-time: install FlutterFire CLI
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"

# Link Flutter app to your Firebase project
flutterfire configure \
  --project=YOUR_FIREBASE_PROJECT_ID \
  --platforms=ios \
  --ios-bundle-id=com.moneymatters.moneyMatters \
  --out=lib/core/config/firebase_options.dart \
  --yes
```

This replaces the placeholder [`lib/core/config/firebase_options.dart`](../lib/core/config/firebase_options.dart) and sets `isConfigured = true`.

Then:

```bash
flutter pub get
cd ios && pod install && cd ..
```

### 7. Verify setup

```bash
./scripts/verify_setup.sh
```

Fix any reported failures before installing on device.

### 8. Install on iPhone

Choose **Path A** (fastest for personal dev) or **Path B** (IPA export).

#### Path A — Xcode Run to device (recommended)

Fastest loop for development. No IPA file needed.

1. Connect iPhone via USB.
2. Open workspace:

   ```bash
   open ios/Runner.xcworkspace
   ```

3. Xcode toolbar: select your **iPhone** as run destination (not Simulator).
4. **Runner** target → **Signing & Capabilities** → select your **Team**; fix any provisioning errors.
5. Either:
   - **Product → Run** (⌘R) in Xcode, **or**
   - From repo root:

     ```bash
     flutter run --release -d <your-iphone-device-id>
     ```

     List devices: `flutter devices`

6. On first launch, if iOS blocks the app: Settings → General → VPN & Device Management → trust your developer certificate.

#### Path B — Archive + export IPA

Use when you want a shareable `.ipa` (Ad Hoc / Development) or TestFlight path.

**Prerequisites:** same as Path A, plus a registered device UDID in your Apple Developer account for Ad Hoc exports.

1. Configure signing in Xcode (`ios/Runner.xcworkspace`) as in Path A.
2. Edit [`ios/ExportOptions.plist`](../ios/ExportOptions.plist):
   - Replace `YOUR_TEAM_ID` with your 10-character Apple Team ID (Xcode → Runner → Signing, or [developer.apple.com/account](https://developer.apple.com/account)).
   - For Ad Hoc: change `method` to `ad-hoc` and add your device UDIDs under `provisioningProfiles` if using manual profiles.
3. Build IPA:

   ```bash
   ./scripts/build_ipa.sh
   ```

4. Output locations:
   - **`build/ios/ipa/money_matters.ipa`** — when `flutter build ipa` succeeds.
   - **`build/ios/iphoneos/Runner.app`** — intermediate app bundle from `flutter build ios`.

5. Install IPA on device:
   - **Xcode → Window → Devices and Simulators** → select iPhone → **+** under Installed Apps → choose the `.ipa`, **or**
   - **Apple Configurator 2**, **or**
   - Third-party sideload tools you already use for personal dev.

**Note:** `flutter build ipa` requires valid code signing. It cannot complete on a machine without Xcode and your Apple ID team selected.

### 9. App onboarding (auth + payment sources)

1. Launch **Money Matters** on the iPhone.
2. **Sign in** or create account (Email/Password — must match Firebase Auth config).
3. Add at least one bank or card (names + sender hints for SMS matching).

### 10. Register device ingest token

On **Connect SMS** (onboarding or Dashboard → SMS icon), the app automatically:

1. Creates or loads a **Device ID** and **Bearer token** (saved on this iPhone).
2. Writes `sha256(Bearer token)` to Firestore at `users/{uid}/device_tokens/{deviceId}`.

Copy **Ingest URL**, **Bearer token**, and **Device ID** into Shortcuts (step 11). Re-opening Connect SMS re-syncs Firestore — no manual Console step needed.

Use **Test POST** on the Connect SMS screen to confirm HTTP `201` or `200` (duplicate).

### 11. Shortcuts automations

Follow [`docs/shortcuts/setup.md`](shortcuts/setup.md):

- **Automation A** — Message trigger with keywords (`debited`, `credited`, `INR`, `Rs`, `spent`, `payment`, `UPI`, `card`); **Run Immediately**; POST to `INGEST_URL` with Bearer token and JSON body.
- **Shortcut B** — Manual “Sync now” → opens `moneymatters://recovery`.

**Physical iPhone required** for Automation A.

Optional env reference (not loaded by the Flutter app at runtime — for your notes):

```bash
cp .env.example .env
# Edit INGEST_URL, FIREBASE_PROJECT_ID, etc.
```

### 12. End-to-end verify

1. Send yourself a test SMS matching a keyword (or use **Test POST** in app).
2. Open Money Matters → dashboard should show parsed activity after drain.
3. If missed: **Recovery** screen → multi-paste or check Shortcuts run history.

```bash
flutter analyze
flutter test
```

---

## AGENT / REPO already done

You do **not** need to implement these for a first live test — they are in the repo:

| Area | Location |
|------|----------|
| Flutter iOS app | `lib/`, `ios/`, `pubspec.yaml` |
| Ingest drain + URL scheme | `lib/ingest/` |
| Rules-first parser + tests | `lib/parse/`, `test/parse/` |
| Onboarding UI (auth → sources → Shortcuts) | `lib/features/onboarding/` |
| Cloud Function `ingestSms` | `firebase/functions/src/ingestSms.ts` |
| Firestore rules | `firebase/firestore.rules` |
| Shortcuts documentation | `docs/shortcuts/setup.md`, `payload-examples.json` |
| Build / verify scripts | `scripts/build_ipa.sh`, `scripts/verify_setup.sh` |
| Export options template | `ios/ExportOptions.plist` |
| Graceful “Firebase not configured” screen | `lib/features/setup/firebase_setup_screen.dart` |

See [`docs/HANDOFF.md`](HANDOFF.md) for MVP limitations (mock repos in some UI paths, FCM stub, etc.).

---

## IPA build reality check (this environment)

Automated check on the agent machine:

| Check | Result |
|-------|--------|
| `flutter doctor` | Flutter OK; **Xcode incomplete**; **CocoaPods not installed** |
| `flutter build ios --no-codesign` | **Failed** — “Application not configured for iOS” (no full Xcode/CocoaPods toolchain) |
| `flutter build ipa --release` | **Blocked** — requires your Mac with full Xcode, CocoaPods, and Apple signing team |

**Conclusion:** IPA and device install must run **on your Mac** with Xcode and your Apple ID. Use **Path A** for the fastest first test; use **Path B** when you need a distributable IPA.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| App shows “Firebase not configured” | Complete steps 5–6; rebuild |
| `verify_setup.sh` fails on plist | Download `GoogleService-Info.plist` to `ios/Runner/` |
| `pod install` errors | Install CocoaPods; run from `ios/` directory |
| Xcode signing errors | Select Team; unique bundle ID; register device |
| HTTP 401 on Test POST | Open Connect SMS again (re-syncs token); re-copy Bearer into Shortcuts |
| Shortcuts never fires | Physical device; automation enabled; keyword match; Run Immediately |
| Developer Mode missing | iOS 16+ required; enable in Settings → Privacy & Security |

---

## Related docs

- [`README.md`](../README.md) — project overview
- [`firebase/README.md`](../firebase/README.md) — backend deploy + API
- [`docs/shortcuts/setup.md`](shortcuts/setup.md) — automation steps
- [`docs/HANDOFF.md`](HANDOFF.md) — build status
